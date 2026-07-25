"""AstraForge Control Center — web cockpit APIs + UI."""

from __future__ import annotations

import hashlib
import hmac
import os
import secrets
from pathlib import Path
from typing import TYPE_CHECKING, Any

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, Field

if TYPE_CHECKING:
    from astraforge.core.engine import TradingEngine

TEMPLATES_DIR = Path(__file__).parent / "templates"
templates = Jinja2Templates(directory=str(TEMPLATES_DIR))


class LoginBody(BaseModel):
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
    # Secondary exchange (stored; switching applies on restart intent)
    exchange2_id: str | None = None
    exchange2_api_key: str | None = None
    exchange2_api_secret: str | None = None
    futures_enabled: bool | None = None
    copytrading_enabled: bool | None = None
    copytrading_leader: str | None = None
    # Primary key rotation (optional)
    exchange_api_key: str | None = None
    exchange_api_secret: str | None = None
    llm_api_key: str | None = None


def _dash_password() -> str:
    return os.getenv("DASHBOARD_PASSWORD", "astraforge")


def _token_secret() -> str:
    return os.getenv("DASHBOARD_TOKEN_SECRET", _dash_password() + "-secret")


def make_token(password: str) -> str:
    raw = f"{password}:{_token_secret()}"
    return hashlib.sha256(raw.encode()).hexdigest()


def valid_token(token: str | None) -> bool:
    if not token:
        return False
    expected = make_token(_dash_password())
    return hmac.compare_digest(token, expected)


async def require_auth(
    request: Request,
    x_astra_token: str | None = Header(default=None),
) -> None:
    token = x_astra_token or request.cookies.get("astra_token")
    if not valid_token(token):
        raise HTTPException(status_code=401, detail="unauthorized")


def create_app(engine: TradingEngine | None = None) -> FastAPI:
    app = FastAPI(title="AstraForge Control Center", version="2.0.0")
    app.state.engine = engine
    app.state.chat_log: list[dict[str, str]] = []

    def eng() -> TradingEngine:
        e = app.state.engine
        if e is None:
            raise HTTPException(status_code=503, detail="engine_not_ready")
        return e

    @app.get("/api/health")
    async def health() -> dict[str, str]:
        return {"status": "ok", "app": "AstraForge Control Center"}

    @app.post("/api/login")
    async def login(body: LoginBody) -> JSONResponse:
        if not hmac.compare_digest(body.password, _dash_password()):
            raise HTTPException(status_code=401, detail="bad_password")
        token = make_token(body.password)
        resp = JSONResponse({"ok": True, "token": token})
        resp.set_cookie(
            "astra_token",
            token,
            httponly=False,
            samesite="lax",
            max_age=60 * 60 * 24 * 30,
        )
        return resp

    @app.get("/api/status")
    async def api_status(_: None = Depends(require_auth)) -> JSONResponse:
        st = await eng().get_status_model()
        snap = eng().breaker.snapshot()
        return JSONResponse(
            {
                **st.model_dump(mode="json"),
                "breaker": snap,
                "style": getattr(eng().settings, "trading_style", "momentum_scalp"),
                "timeframe": getattr(eng().settings, "candle_timeframe", "5m"),
                "exchange_id": eng().settings.exchange_id,
                "is_spot": eng().settings.is_spot,
            }
        )

    @app.get("/api/positions")
    async def api_positions(_: None = Depends(require_auth)) -> JSONResponse:
        peak = float(await eng().state.get_kv("peak_equity", 0) or 0)
        acc = await eng().exchange.get_account_snapshot(peak_equity=peak)
        return JSONResponse(
            {
                "equity": acc.equity,
                "available": acc.available_balance,
                "positions": [p.model_dump(mode="json") for p in acc.positions],
            }
        )

    @app.get("/api/trades")
    async def api_trades(_: None = Depends(require_auth)) -> JSONResponse:
        trades = await eng().state.recent_trades(100)
        return JSONResponse({"trades": [t.model_dump(mode="json") for t in trades]})

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
        return JSONResponse({"symbols": eng().settings.symbols})

    @app.post("/api/control/{action}")
    async def api_control(action: str, _: None = Depends(require_auth)) -> JSONResponse:
        e = eng()
        action = action.lower().strip()
        if action in {"stop", "pause"}:
            msg = await e.handle_user_text("стоп")
            return JSONResponse({"ok": True, "message": msg})
        if action in {"resume", "start"}:
            msg = await e.resume_trading()
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
        # First try command/goal path
        reply = await e.handle_user_text(user_msg)
        # If empty (status/report already filled) or unknown — ask LLM advisor
        if not reply or "Не понял" in reply or "Didn't get" in reply:
            advice = await _ai_advisor(e, user_msg)
            reply = advice or reply
        app.state.chat_log.append({"role": "user", "text": user_msg})
        app.state.chat_log.append({"role": "assistant", "text": reply})
        app.state.chat_log = app.state.chat_log[-80:]
        await e.state.log_decision(
            {"type": "chat", "user": user_msg, "assistant": reply}
        )
        return JSONResponse({"ok": True, "reply": reply, "history": app.state.chat_log[-20:]})

    @app.get("/api/chat/history")
    async def chat_history(_: None = Depends(require_auth)) -> JSONResponse:
        return JSONResponse({"history": app.state.chat_log[-40:]})

    @app.get("/api/settings")
    async def get_settings(_: None = Depends(require_auth)) -> JSONResponse:
        e = eng()
        stored = await e.state.get_kv("control_settings", {}) or {}
        s = e.settings
        return JSONResponse(
            {
                "exchange_id": s.exchange_id,
                "trading_mode": s.trading_mode.value,
                "live_confirmed": s.live_confirmed,
                "trade_symbols": s.trade_symbols,
                "trading_style": getattr(s, "trading_style", "momentum_scalp"),
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
                "note": "Зміна ключів/біржі зберігається; повне перемикання біржі застосовується після рестарту процесу.",
            }
        )

    @app.post("/api/settings")
    async def save_settings(body: SettingsBody, _: None = Depends(require_auth)) -> JSONResponse:
        e = eng()
        stored = await e.state.get_kv("control_settings", {}) or {}
        data = body.model_dump(exclude_none=True)
        # Never echo secrets back; store masked workflow
        for secret_key in (
            "exchange_api_key",
            "exchange_api_secret",
            "exchange2_api_key",
            "exchange2_api_secret",
            "llm_api_key",
        ):
            if secret_key in data and data[secret_key]:
                stored[secret_key] = data[secret_key]
                # Also update runtime settings when primary keys change
                if secret_key == "exchange_api_key":
                    object.__setattr__(e.settings, "exchange_api_key", data[secret_key])
                if secret_key == "exchange_api_secret":
                    object.__setattr__(e.settings, "exchange_api_secret", data[secret_key])
                if secret_key == "llm_api_key":
                    object.__setattr__(e.settings, "llm_api_key", data[secret_key])
                data.pop(secret_key, None)

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
        # Persist non-secret prefs into .env best-effort
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
        return JSONResponse({"ok": True, "saved": True, "settings": stored.get("exchange_id")})

    @app.get("/", response_class=HTMLResponse)
    async def index(request: Request) -> Any:
        html_path = TEMPLATES_DIR / "control.html"
        return HTMLResponse(html_path.read_text(encoding="utf-8"))

    return app


async def _ai_advisor(engine: Any, message: str) -> str:
    """Free-form chat with the LLM using live account context."""
    try:
        st = await engine.get_status_model()
        peak = float(await engine.state.get_kv("peak_equity", 0) or 0)
        acc = await engine.exchange.get_account_snapshot(peak_equity=peak)
        context = {
            "message": message,
            "status": st.model_dump(mode="json"),
            "positions": [p.model_dump() for p in acc.positions],
            "equity": acc.equity,
            "mode": engine.settings.trading_mode.value,
            "exchange": engine.settings.exchange_id,
        }
        system = (
            "Ти торговий AI-асистент AstraForge. Відповідай мовою користувача (укр/рос/англ). "
            "Давай конкретні підказки по ринку/ризику/позиціях. "
            "Якщо користувач просить дію (купи/продай/стоп) — скажи що саме виконати командою, "
            "але не стверджуй що вже зробив, якщо це лише порада. Коротко і по суті."
        )
        # Reuse agent LLM transport
        raw = await engine.agent._call_llm(system, __import__("json").dumps(context, ensure_ascii=False))
        return raw.strip()
    except Exception as exc:  # noqa: BLE001
        return f"Не вдалося отримати відповідь AI: {exc}"


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


def main() -> None:
    import uvicorn
    from astraforge.core.config import get_settings

    settings = get_settings()
    app = create_app(None)
    uvicorn.run(app, host=settings.dashboard_host, port=settings.dashboard_port)
