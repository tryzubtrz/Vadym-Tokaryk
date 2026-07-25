"""AstraForge Control Center — modern cockpit APIs + UI."""

from __future__ import annotations

import base64
import hashlib
import hmac
import os
import time
from pathlib import Path
from typing import TYPE_CHECKING, Any

from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, Request, UploadFile
from fastapi.responses import HTMLResponse, JSONResponse
from pydantic import BaseModel, EmailStr, Field

from astraforge.dashboard.email_auth import (
    generate_code,
    hash_code,
    hash_owner_password,
    make_session_token,
    owner_email,
    owner_password_configured,
    send_otp_email,
    valid_session_token,
    verify_owner_password,
)
from astraforge.core.fx_scalper import clear_news_cache, fetch_crypto_news

if TYPE_CHECKING:
    from astraforge.core.engine import TradingEngine

TEMPLATES_DIR = Path(__file__).parent / "templates"

# in-memory OTP challenges (also mirrored to state kv when engine ready)
_OTP: dict[str, dict[str, Any]] = {}


class LoginBody(BaseModel):
    password: str = ""


class OtpRequestBody(BaseModel):
    email: EmailStr


class OtpVerifyBody(BaseModel):
    email: EmailStr
    code: str = Field(min_length=4, max_length=12)


class OwnerPassBody(BaseModel):
    email: EmailStr
    password: str = Field(min_length=4, max_length=128)


class BindEmailBody(BaseModel):
    email: EmailStr
    password: str


class ChatBody(BaseModel):
    message: str = Field(min_length=1, max_length=4000)


class SettingsBody(BaseModel):
    exchange_id: str | None = None
    trading_mode: str | None = None
    live_confirmed: bool | None = None
    trade_symbols: str | None = None
    trading_style: str | None = None
    candle_timeframe: str | None = None
    max_position_pct: float | None = None
    agent_loop_interval_sec: int | None = None
    exchange2_id: str | None = None
    exchange2_api_key: str | None = None
    exchange2_api_secret: str | None = None
    futures_enabled: bool | None = None
    copytrading_enabled: bool | None = None
    copytrading_leader: str | None = None
    exchange_api_key: str | None = None
    exchange_api_secret: str | None = None
    llm_api_key: str | None = None
    fx_bucket_usd: float | None = None
    crypto_bucket_usd: float | None = None


class CloseSlotBody(BaseModel):
    slot_id: str


def _dash_password() -> str:
    return os.getenv("DASHBOARD_PASSWORD", "astraforge")


def _legacy_token(password: str) -> str:
    secret = os.getenv("DASHBOARD_TOKEN_SECRET", _dash_password() + "-secret")
    return hashlib.sha256(f"{password}:{secret}".encode()).hexdigest()


def _enrich_trade(t: dict[str, Any]) -> dict[str, Any]:
    action = str(t.get("action") or "").lower()
    pnl = float(t.get("pnl") or 0.0)
    size = float(t.get("size") or 0.0)
    price = float(t.get("price") or 0.0)
    is_open = action.startswith("open") or action in {"buy"}
    is_close = action in {"close", "reduce", "close_all", "sell"}
    if is_open:
        result, result_label = "open", "Відкриття"
    elif is_close:
        if pnl > 1e-7:
            result, result_label = "plus", "У плюс"
        elif pnl < -1e-7:
            result, result_label = "minus", "У мінус"
        else:
            result, result_label = "flat", "Без змін"
    else:
        result, result_label = "other", action or "—"
    out = dict(t)
    out.update(
        {
            "result": result,
            "result_label": result_label,
            "notional": round(abs(size * price), 6),
            "pnl": pnl,
            "pnl_abs": abs(pnl),
        }
    )
    return out


async def require_auth(
    request: Request,
    x_astra_token: str | None = Header(default=None),
) -> None:
    token = x_astra_token or request.cookies.get("astra_token")
    owner = owner_email()
    if owner and valid_session_token(token, owner):
        return
    # Legacy password token only if owner email not bound yet
    if not owner and token and hmac.compare_digest(token, _legacy_token(_dash_password())):
        return
    raise HTTPException(status_code=401, detail="unauthorized")


def create_app(engine: TradingEngine | None = None) -> FastAPI:
    app = FastAPI(title="AstraForge Control Center", version="3.0.0")
    app.state.engine = engine
    app.state.chat_log: list[dict[str, Any]] = []

    def eng() -> TradingEngine:
        e = app.state.engine
        if e is None:
            raise HTTPException(status_code=503, detail="engine_not_ready")
        return e

    @app.get("/api/health")
    async def health() -> dict[str, Any]:
        return {
            "status": "ok",
            "app": "AstraForge Control Center",
            "auth": "email_otp" if owner_email() else "setup_required",
        }

    @app.get("/api/auth/status")
    async def auth_status() -> JSONResponse:
        owner = owner_email()
        return JSONResponse(
            {
                "owner_bound": bool(owner),
                "owner_hint": (owner[:2] + "***@" + owner.split("@")[-1]) if owner and "@" in owner else "",
                "mode": "email_otp" if owner else "bind_email",
                "password_login": bool(owner) and owner_password_configured(),
            }
        )

    @app.post("/api/auth/login-password")
    async def login_owner_password(body: OwnerPassBody) -> JSONResponse:
        """Second login path: owner email + personal password only."""
        owner = owner_email()
        email = str(body.email).lower().strip()
        if not owner or email != owner:
            raise HTTPException(status_code=401, detail="invalid_credentials")
        if not owner_password_configured() or not verify_owner_password(body.password):
            raise HTTPException(status_code=401, detail="invalid_credentials")
        token = make_session_token(owner)
        resp = JSONResponse({"ok": True, "token": token, "email": owner, "mode": "password"})
        resp.set_cookie(
            "astra_token",
            token,
            httponly=False,
            samesite="lax",
            max_age=60 * 60 * 24 * 30,
        )
        return resp

    @app.post("/api/auth/bind-email")
    async def bind_email(body: BindEmailBody) -> JSONResponse:
        """One-time bind of owner email (requires current dashboard password)."""
        if owner_email():
            raise HTTPException(status_code=400, detail="owner_already_bound")
        if not hmac.compare_digest(body.password, _dash_password()):
            raise HTTPException(status_code=401, detail="bad_password")
        email = str(body.email).lower().strip()
        _patch_env({"DASHBOARD_OWNER_EMAIL": email})
        os.environ["DASHBOARD_OWNER_EMAIL"] = email
        return JSONResponse({"ok": True, "email": email, "next": "request_otp"})

    @app.post("/api/auth/request-otp")
    async def request_otp(body: OtpRequestBody) -> JSONResponse:
        owner = owner_email()
        email = str(body.email).lower().strip()
        if not owner:
            raise HTTPException(status_code=400, detail="bind_email_first")
        # Only owner email can receive codes — other emails silently fail-looking response
        if email != owner:
            # Do not reveal whether email exists
            return JSONResponse(
                {
                    "ok": True,
                    "sent": False,
                    "message": "Якщо email правильний — код надіслано",
                }
            )
        code = generate_code()
        _OTP[email] = {
            "hash": hash_code(email, code),
            "exp": time.time() + 600,
            "tries": 0,
        }
        delivery = send_otp_email(email, code)
        # Also notify engine logs
        try:
            await eng().notify(f"OTP login code generated for {email} via {delivery.get('via')}")
        except Exception:  # noqa: BLE001
            pass
        payload: dict[str, Any] = {
            "ok": True,
            "sent": bool(delivery.get("ok")),
            "via": delivery.get("via"),
            "message": "Код надіслано на вашу пошту" if delivery.get("ok") else "Не вдалося надіслати лист",
        }
        if delivery.get("warning"):
            payload["warning"] = delivery["warning"]
        # In outbox mode expose nothing in API (read file on server only)
        return JSONResponse(payload)

    @app.post("/api/auth/verify-otp")
    async def verify_otp(body: OtpVerifyBody) -> JSONResponse:
        owner = owner_email()
        email = str(body.email).lower().strip()
        if not owner or email != owner:
            raise HTTPException(status_code=401, detail="invalid_code")
        row = _OTP.get(email)
        if not row or time.time() > float(row["exp"]):
            raise HTTPException(status_code=401, detail="code_expired")
        row["tries"] = int(row.get("tries") or 0) + 1
        if row["tries"] > 8:
            _OTP.pop(email, None)
            raise HTTPException(status_code=401, detail="too_many_tries")
        if not hmac.compare_digest(row["hash"], hash_code(email, body.code.strip())):
            raise HTTPException(status_code=401, detail="invalid_code")
        _OTP.pop(email, None)
        token = make_session_token(email)
        resp = JSONResponse({"ok": True, "token": token, "email": email})
        resp.set_cookie(
            "astra_token",
            token,
            httponly=False,
            samesite="lax",
            max_age=60 * 60 * 24 * 30,
        )
        return resp

    @app.post("/api/login")
    async def login(body: LoginBody) -> JSONResponse:
        """Legacy password login — only allowed before owner email is bound."""
        if owner_email():
            raise HTTPException(status_code=400, detail="use_email_otp")
        if not hmac.compare_digest(body.password, _dash_password()):
            raise HTTPException(status_code=401, detail="bad_password")
        token = _legacy_token(body.password)
        resp = JSONResponse({"ok": True, "token": token, "mode": "legacy"})
        resp.set_cookie("astra_token", token, httponly=False, samesite="lax", max_age=60 * 60 * 24 * 30)
        return resp

    @app.get("/api/status")
    async def api_status(_: None = Depends(require_auth)) -> JSONResponse:
        st = await eng().get_status_model()
        snap = eng().breaker.snapshot()
        buckets = eng().buckets.snapshot()
        return JSONResponse(
            {
                **st.model_dump(mode="json"),
                "breaker": snap,
                "style": getattr(eng().settings, "trading_style", "fx_multi_scalp"),
                "timeframe": getattr(eng().settings, "candle_timeframe", "5m"),
                "exchange_id": eng().settings.exchange_id,
                "is_spot": eng().settings.is_spot,
                "buckets": buckets,
                "pnl_split": eng().buckets.pnl_breakdown(),
                "fx_ai": getattr(eng(), "_last_fx_tick", {}).get("ai")
                or getattr(eng().fx, "last_ai", {}),
            }
        )

    @app.get("/api/buckets")
    async def api_buckets(_: None = Depends(require_auth)) -> JSONResponse:
        return JSONResponse(
            {
                "buckets": eng().buckets.snapshot(),
                "pnl_split": eng().buckets.pnl_breakdown(),
            }
        )

    @app.get("/api/fx/slots")
    async def api_fx_slots(_: None = Depends(require_auth)) -> JSONResponse:
        return JSONResponse({"slots": eng().buckets.snapshot().get("open_slots") or []})

    @app.post("/api/fx/close-slot")
    async def api_close_slot(body: CloseSlotBody, _: None = Depends(require_auth)) -> JSONResponse:
        """Manual close of an FX slot (user may close reds)."""
        e = eng()
        slot = e.buckets.remove_slot(body.slot_id)
        if not slot:
            raise HTTPException(status_code=404, detail="slot_not_found")
        symbol = slot["symbol"]
        amount = float(slot["amount"])
        entry = float(slot["entry"])
        try:
            order = await e.exchange.create_market_order(symbol, "sell", amount, reduce_only=True)
            fill = float(order.get("average") or order.get("price") or entry)
            pnl = (fill - entry) * amount
            if symbol.endswith("/CAD") and fill > 0:
                pnl = pnl / fill
            e.buckets.record_fx_profit(pnl)
            return JSONResponse({"ok": True, "pnl": pnl, "order": order, "slot": slot})
        except Exception as exc:  # noqa: BLE001
            # put slot back if sell failed
            e.buckets.add_slot(slot)
            raise HTTPException(status_code=400, detail=str(exc)) from exc

    @app.get("/api/positions")
    async def api_positions(_: None = Depends(require_auth)) -> JSONResponse:
        peak = float(await eng().state.get_kv("peak_equity", 0) or 0)
        acc = await eng().exchange.get_account_snapshot(peak_equity=peak)
        return JSONResponse(
            {
                "equity": acc.equity,
                "available": acc.available_balance,
                "positions": [p.model_dump(mode="json") for p in acc.positions],
                "fx_slots": eng().buckets.snapshot().get("open_slots") or [],
            }
        )

    @app.get("/api/trades")
    async def api_trades(
        result: str = "all",
        limit: int = 300,
        _: None = Depends(require_auth),
    ) -> JSONResponse:
        raw = await eng().state.list_trades(limit=max(1, min(int(limit), 1000)))
        items = [_enrich_trade(t.model_dump(mode="json")) for t in raw]
        f = (result or "all").lower().strip()
        if f in {"plus", "win", "green", "+"}:
            items = [x for x in items if x["result"] == "plus"]
        elif f in {"minus", "loss", "red", "-"}:
            items = [x for x in items if x["result"] == "minus"]
        elif f in {"open", "opens"}:
            items = [x for x in items if x["result"] == "open"]
        elif f in {"closed", "close"}:
            items = [x for x in items if x["result"] in {"plus", "minus", "flat"}]
        stats = await eng().state.trade_stats()
        return JSONResponse({"trades": items, "stats": stats, "filter": f})

    @app.get("/api/trades/{trade_id}")
    async def api_trade_detail(trade_id: int, _: None = Depends(require_auth)) -> JSONResponse:
        t = await eng().state.get_trade(trade_id)
        if t is None:
            raise HTTPException(status_code=404, detail="trade_not_found")
        return JSONResponse({"trade": _enrich_trade(t.model_dump(mode="json"))})

    @app.get("/api/decisions")
    async def api_decisions(_: None = Depends(require_auth)) -> JSONResponse:
        return JSONResponse({"decisions": await eng().state.recent_decisions(40)})

    @app.get("/api/equity")
    async def api_equity(_: None = Depends(require_auth)) -> JSONResponse:
        points = await eng().state.equity_history(300)
        return JSONResponse({"points": [p.model_dump(mode="json") for p in points]})

    @app.get("/api/candles")
    async def api_candles(
        symbol: str,
        timeframe: str = "5m",
        limit: int = 80,
        _: None = Depends(require_auth),
    ) -> JSONResponse:
        rows = await eng().exchange.fetch_ohlcv(symbol, timeframe=timeframe, limit=limit)
        return JSONResponse(
            {
                "symbol": symbol,
                "timeframe": timeframe,
                "candles": [
                    {
                        "t": int(r[0]),
                        "o": float(r[1]),
                        "h": float(r[2]),
                        "l": float(r[3]),
                        "c": float(r[4]),
                        "v": float(r[5]),
                    }
                    for r in rows
                ],
            }
        )

    @app.get("/api/symbols")
    async def api_symbols(_: None = Depends(require_auth)) -> JSONResponse:
        fx = eng().buckets.snapshot().get("fx_pairs") or []
        return JSONResponse({"symbols": eng().settings.symbols, "fx_pairs": fx})

    @app.get("/api/news")
    async def api_news(
        limit: int = 30,
        refresh: int = 0,
        _: None = Depends(require_auth),
    ) -> JSONResponse:
        e = eng()
        if int(refresh or 0):
            clear_news_cache()
        items = await fetch_crypto_news(
            limit=max(5, min(int(limit), 40)),
            agent=getattr(e, "agent", None),
        )
        return JSONResponse({"news": items, "updated_at": time.time(), "lang": "uk"})

    @app.post("/api/control/{action}")
    async def api_control(action: str, _: None = Depends(require_auth)) -> JSONResponse:
        e = eng()
        action = action.lower().strip()
        if action in {"stop", "pause"}:
            msg = await e.handle_user_text("стоп")
            return JSONResponse({"ok": True, "message": msg})
        if action in {"resume", "start"}:
            # User-requested resume: allow forcing daily halt clear for live ops
            ok = await e.breaker.reset(force_daily=True)
            await e.state.save_status_fields(trading_enabled=True)
            # refresh day baseline so limit doesn't instantly re-trip
            peak = float(await e.state.get_kv("peak_equity", 0) or 0)
            acc = await e.exchange.get_account_snapshot(peak_equity=peak)
            await e.state.save_status_fields(day_start_equity=acc.equity, pnl_today=0.0)
            e.risk.restore_day_start(acc.equity, __import__("datetime").datetime.now(__import__("datetime").timezone.utc).strftime("%Y-%m-%d"))
            msg = "✅ Trading resumed" if ok else await e.resume_trading()
            return JSONResponse({"ok": True, "message": msg})
        if action in {"flatten", "close_all", "sell_all"}:
            msg = await e.handle_user_text("закрой все позиции")
            return JSONResponse({"ok": True, "message": msg})
        if action in {"emergency"}:
            msg = await e.emergency_stop()
            return JSONResponse({"ok": True, "message": msg})
        raise HTTPException(status_code=400, detail="unknown_action")

    @app.post("/api/chat")
    async def api_chat(body: ChatBody, _: None = Depends(require_auth)) -> JSONResponse:
        e = eng()
        user_msg = body.message.strip()
        reply = await e.handle_user_text(user_msg)
        if not reply or "Не понял" in reply or "Didn't get" in reply:
            reply = await _ai_advisor(e, user_msg)
        app.state.chat_log.append({"role": "user", "text": user_msg})
        app.state.chat_log.append({"role": "assistant", "text": reply})
        app.state.chat_log = app.state.chat_log[-80:]
        await e.state.log_decision({"type": "chat", "user": user_msg, "assistant": reply})
        return JSONResponse({"ok": True, "reply": reply, "history": app.state.chat_log[-20:]})

    @app.post("/api/chat/vision")
    async def api_chat_vision(
        message: str = Form(default="Що бачиш на скріні?"),
        image: UploadFile = File(...),
        _: None = Depends(require_auth),
    ) -> JSONResponse:
        e = eng()
        raw = await image.read()
        if len(raw) > 8_000_000:
            raise HTTPException(status_code=400, detail="image_too_large")
        mime = image.content_type or "image/jpeg"
        b64 = base64.b64encode(raw).decode("ascii")
        reply = await _ai_vision(e, message, b64, mime)
        app.state.chat_log.append({"role": "user", "text": f"[фото] {message}"})
        app.state.chat_log.append({"role": "assistant", "text": reply})
        app.state.chat_log = app.state.chat_log[-80:]
        return JSONResponse({"ok": True, "reply": reply, "history": app.state.chat_log[-20:]})

    @app.get("/api/chat/history")
    async def chat_history(_: None = Depends(require_auth)) -> JSONResponse:
        return JSONResponse({"history": app.state.chat_log[-40:]})

    @app.get("/api/settings")
    async def get_settings(_: None = Depends(require_auth)) -> JSONResponse:
        e = eng()
        stored = await e.state.get_kv("control_settings", {}) or {}
        s = e.settings
        b = e.buckets.snapshot()
        return JSONResponse(
            {
                "exchange_id": s.exchange_id,
                "trading_mode": s.trading_mode.value,
                "live_confirmed": s.live_confirmed,
                "trade_symbols": s.trade_symbols,
                "trading_style": getattr(s, "trading_style", "fx_multi_scalp"),
                "candle_timeframe": getattr(s, "candle_timeframe", "5m"),
                "max_position_pct": s.max_position_pct,
                "agent_loop_interval_sec": s.agent_loop_interval_sec,
                "has_exchange_key": bool(s.exchange_api_key),
                "has_llm_key": bool(s.llm_api_key),
                "exchange2_id": stored.get("exchange2_id", ""),
                "has_exchange2_key": bool(stored.get("exchange2_api_key")),
                "futures_enabled": bool(stored.get("futures_enabled", False)),
                "copytrading_enabled": bool(stored.get("copytrading_enabled", False)),
                "copytrading_leader": stored.get("copytrading_leader", ""),
                "fx_bucket_usd": b.get("fx_bucket_usd"),
                "crypto_hold_usd": b.get("crypto_hold_usd"),
                "fx_pairs": b.get("fx_pairs"),
                "note": "Lego-блоки: FX bucket, crypto hold, AI filter, новини, OTP.",
            }
        )

    @app.post("/api/settings")
    async def save_settings(body: SettingsBody, _: None = Depends(require_auth)) -> JSONResponse:
        e = eng()
        stored = await e.state.get_kv("control_settings", {}) or {}
        data = body.model_dump(exclude_none=True)
        for secret_key in (
            "exchange_api_key",
            "exchange_api_secret",
            "exchange2_api_key",
            "exchange2_api_secret",
            "llm_api_key",
        ):
            if secret_key in data and data[secret_key]:
                stored[secret_key] = data[secret_key]
                if secret_key == "exchange_api_key":
                    object.__setattr__(e.settings, "exchange_api_key", data[secret_key])
                if secret_key == "exchange_api_secret":
                    object.__setattr__(e.settings, "exchange_api_secret", data[secret_key])
                if secret_key == "llm_api_key":
                    object.__setattr__(e.settings, "llm_api_key", data[secret_key])
                data.pop(secret_key, None)

        if "fx_bucket_usd" in data:
            e.buckets.data["fx_bucket_usd"] = float(data.pop("fx_bucket_usd"))
            e.buckets.save()
        if "crypto_bucket_usd" in data:
            e.buckets.data["crypto_hold_usd"] = float(data.pop("crypto_bucket_usd"))
            e.buckets.save()

        for k, v in data.items():
            stored[k] = v
            if hasattr(e.settings, k) and k in {
                "trade_symbols",
                "trading_style",
                "candle_timeframe",
                "max_position_pct",
                "agent_loop_interval_sec",
            }:
                try:
                    object.__setattr__(e.settings, k, v)
                except Exception:  # noqa: BLE001
                    pass
        await e.state.set_kv("control_settings", stored)
        _patch_env(
            {
                "TRADE_SYMBOLS": stored.get("trade_symbols"),
                "TRADING_STYLE": stored.get("trading_style"),
                "CANDLE_TIMEFRAME": stored.get("candle_timeframe"),
                "MAX_POSITION_PCT": stored.get("max_position_pct"),
                "EXCHANGE_ID": stored.get("exchange_id"),
                "TRADING_MODE": stored.get("trading_mode"),
                "LIVE_CONFIRMED": str(stored.get("live_confirmed", "")).lower()
                if stored.get("live_confirmed") is not None
                else None,
            }
        )
        return JSONResponse({"ok": True, "saved": True})

    @app.get("/", response_class=HTMLResponse)
    async def index(request: Request) -> Any:
        html_path = TEMPLATES_DIR / "control.html"
        return HTMLResponse(html_path.read_text(encoding="utf-8"))

    return app


async def _ai_advisor(engine: Any, message: str) -> str:
    try:
        st = await engine.get_status_model()
        peak = float(await engine.state.get_kv("peak_equity", 0) or 0)
        acc = await engine.exchange.get_account_snapshot(peak_equity=peak)
        context = {
            "message": message,
            "status": st.model_dump(mode="json"),
            "positions": [p.model_dump() for p in acc.positions],
            "buckets": engine.buckets.snapshot(),
            "fx_ai": getattr(engine.fx, "last_ai", {}),
            "equity": acc.equity,
            "mode": engine.settings.trading_mode.value,
            "exchange": engine.settings.exchange_id,
        }
        system = (
            "Ти торговий AI AstraForge (FX multi-scalp + crypto). "
            "Відповідай українською, коротко і по суті звичайним текстом (не JSON). "
            "Пояснюй чи варто купувати зараз чи чекати нижче."
        )
        raw = await engine.agent._call_llm(
            system,
            __import__("json").dumps(context, ensure_ascii=False),
            json_mode=False,
        )
        return raw.strip()
    except Exception as exc:  # noqa: BLE001
        return f"Не вдалося отримати відповідь AI: {exc}"


async def _ai_vision(engine: Any, message: str, b64: str, mime: str) -> str:
    """Chat about an uploaded screenshot via OpenAI vision."""
    import httpx

    base = engine.settings.effective_llm_base_url or "https://api.openai.com/v1"
    url = f"{base.rstrip('/')}/chat/completions"
    headers = {"Content-Type": "application/json"}
    if engine.settings.llm_api_key:
        headers["Authorization"] = f"Bearer {engine.settings.llm_api_key}"
    body = {
        "model": engine.settings.llm_model if "gpt-4" in engine.settings.llm_model else "gpt-4o-mini",
        "temperature": 0.2,
        "messages": [
            {
                "role": "system",
                "content": (
                    "Ти аналітик графіків AstraForge. Опиши що на скріні, "
                    "чи варто купувати зараз чи чекати нижче. Мовою користувача."
                ),
            },
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": message},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:{mime};base64,{b64}"},
                    },
                ],
            },
        ],
    }
    async with httpx.AsyncClient(timeout=90.0) as client:
        resp = await client.post(url, headers=headers, json=body)
        if resp.status_code >= 400:
            return f"Не вдалося проаналізувати фото: LLM {resp.status_code}: {resp.text[:300]}"
        data = resp.json()
    return str(data["choices"][0]["message"]["content"]).strip()


def _patch_env(updates: dict[str, Any]) -> None:
    path = Path(".env")
    if not path.exists():
        return
    lines = path.read_text().splitlines()
    out: list[str] = []
    seen: set[str] = set()
    for line in lines:
        if "=" in line and not line.strip().startswith("#"):
            k = line.split("=", 1)[0].strip()
            if k in updates and updates[k] is not None and updates[k] != "":
                out.append(f"{k}={updates[k]}")
                seen.add(k)
                continue
        out.append(line)
    for k, v in updates.items():
        if k not in seen and v is not None and v != "":
            out.append(f"{k}={v}")
    path.write_text("\n".join(out) + "\n")
