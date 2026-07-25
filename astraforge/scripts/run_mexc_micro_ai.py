"""MEXC micro AI sleeve — $5 bankroll, ~$1 notional, hard stop at -$5.

Option B: regular perpetual (not Up/Down event). Reads multi-TF candles,
scores direction, opens only on strong signal. Fee-aware exits.
"""

from __future__ import annotations

import asyncio
import json
import os
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import ccxt.async_support as ccxt

ROOT = Path(__file__).resolve().parents[1]
STATE_PATH = ROOT / "data" / "mexc_micro_ai.json"
REPORT_PATH = ROOT / "data" / "morning_report.md"
DEFAULT_SYMBOL = "XRP/USDC:USDC"


def _utcnow() -> str:
    return datetime.now(timezone.utc).isoformat()


def _load_env() -> None:
    env = ROOT / ".env"
    if not env.exists():
        return
    for line in env.read_text().splitlines():
        if not line.strip() or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))


def _default_state() -> dict[str, Any]:
    return {
        "enabled": True,
        "symbol": os.environ.get("MEXC_MICRO_SYMBOL") or DEFAULT_SYMBOL,
        "bankroll_usdc": 5.0,
        "stake_usdc": 1.0,
        "max_loss_usdc": 5.0,
        "max_losses": 5,  # hard stop after 5 losing $1 tickets
        "min_tp_pct": 0.24,  # just above RT~0.16%
        "early_tp_pct": 0.18,
        "early_after_sec": 480,  # 8m
        "stale_tp_pct": 0.12,  # after stale_after_sec take tiny green / cut wait
        "stale_after_sec": 1_200,  # 20m
        "stop_pct": 0.40,
        "max_hold_sec": 1_800,  # 30m hard flat/exit — no endless holds
        "cooldown_sec": 90,
        "min_score": 0.40,
        "base_min_score": 0.40,
        "learn_score_step": 0.03,
        "leverage": 1,
        "open": None,
        "last_open_at": "",
        "last_close_at": "",
        "realized_pnl_usdc": 0.0,
        "wins": 0,
        "losses": 0,
        "trades": 0,
        "stopped": False,
        "stop_reason": "",
        "measured_taker_pct": 0.08,
        "last_signal": {},
        "trade_log": [],
        "lessons": [],  # fingerprints of losing setups to avoid
        "night_started_at": _utcnow(),
        "updated_at": _utcnow(),
    }


def load_state() -> dict[str, Any]:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    base = _default_state()
    if STATE_PATH.exists():
        try:
            raw = json.loads(STATE_PATH.read_text(encoding="utf-8"))
            base.update(raw or {})
        except Exception:
            pass
    env_sym = os.environ.get("MEXC_MICRO_SYMBOL")
    if env_sym:
        base["symbol"] = env_sym
    base["leverage"] = 1
    base["bankroll_usdc"] = min(max(float(base.get("bankroll_usdc") or 5.0), 1.0), 5.0)
    base["stake_usdc"] = min(max(float(base.get("stake_usdc") or 1.0), 0.5), 1.0)
    # Speed profile: never wait forever (override stale JSON from older runs)
    if os.environ.get("MEXC_SPEED_MODE", "true").lower() in {"1", "true", "yes"}:
        base["min_tp_pct"] = 0.24
        base["early_tp_pct"] = 0.18
        base["early_after_sec"] = 480
        base["stale_tp_pct"] = 0.12
        base["stale_after_sec"] = 1_200
        base["stop_pct"] = 0.40
        base["max_hold_sec"] = 1_800
        base["cooldown_sec"] = 90
        base["base_min_score"] = min(float(base.get("base_min_score") or 0.40), 0.40)
        base["min_score"] = min(float(base.get("min_score") or 0.40), 0.45)
    else:
        base["min_tp_pct"] = max(float(base.get("min_tp_pct") or 0.24), 0.20)
        base["early_tp_pct"] = max(float(base.get("early_tp_pct") or 0.18), 0.16)
        base["early_after_sec"] = min(max(float(base.get("early_after_sec") or 480), 180), 3600)
        base["stale_tp_pct"] = max(float(base.get("stale_tp_pct") or 0.12), 0.08)
        base["stale_after_sec"] = min(max(float(base.get("stale_after_sec") or 1200), 300), 3600)
        base["cooldown_sec"] = min(max(float(base.get("cooldown_sec") or 90), 45), 3600)
        base["max_hold_sec"] = min(max(float(base.get("max_hold_sec") or 1800), 300), 3600)
    base["max_losses"] = int(min(max(int(base.get("max_losses") or 5), 1), 5))
    base["max_loss_usdc"] = min(float(base.get("max_loss_usdc") or 5.0), 5.0)
    if not isinstance(base.get("trade_log"), list):
        base["trade_log"] = []
    if not isinstance(base.get("lessons"), list):
        base["lessons"] = []
    return base


def save_state(state: dict[str, Any]) -> None:
    state["updated_at"] = _utcnow()
    STATE_PATH.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
    write_morning_report(state)


def write_morning_report(state: dict[str, Any], extra: str = "") -> None:
    """Ukrainian morning briefing (будок) updated overnight."""
    bank = float(state.get("bankroll_usdc") or 5.0)
    realized = float(state.get("realized_pnl_usdc") or 0.0)
    left = bank + realized
    open_pos = state.get("open")
    sig = state.get("last_signal") or {}
    lessons = state.get("lessons") or []
    lines = [
        "# Ранковий будок (MEXC micro AI)",
        "",
        f"- Оновлено (UTC): `{_utcnow()}`",
        f"- Старт ночі: `{state.get('night_started_at') or '—'}`",
        f"- Символ: `{state.get('symbol')}`",
        f"- Рукав: **{left:.2f} / {bank:.0f} USDC**",
        f"- Realized PnL: **{realized:+.4f} USDC**",
        f"- Угоди: **{state.get('trades', 0)}** | W/L: **{state.get('wins', 0)}/{state.get('losses', 0)}** "
        f"(стоп після **{state.get('max_losses', 5)}** програшів)",
        f"- Stopped: `{state.get('stopped')}` {(state.get('stop_reason') or '')}".rstrip(),
        f"- Відкрита позиція: {'так' if open_pos else 'ні'}",
    ]
    if open_pos:
        lines.append(
            f"  - entry={open_pos.get('entry')} contracts={open_pos.get('contracts')} "
            f"score={open_pos.get('score')} since={open_pos.get('opened_at')}"
        )
    lines.extend(
        [
            f"- Останній score: `{sig.get('score')}` (поріг `{state.get('min_score')}`) "
            f"rsi1={sig.get('rsi1')} rsi5={sig.get('rsi5')} range={sig.get('range_pos')}",
            f"- Уроків з помилок: **{len(lessons)}**",
            "",
            "## Правила",
            "- ~$1 / 1x / long-only / TP≥0.40% / SL−0.55%",
            "- Макс **5 програшів** по ~$1, учиться на помилках (піднімає поріг score)",
            "- Жорсткий стоп рукава −$5",
            "",
        ]
    )
    hist = state.get("trade_log") or []
    if hist:
        lines.append("## Угоди за ніч")
        for row in hist[-30:]:
            lines.append(f"- {row}")
        lines.append("")
    if lessons:
        lines.append("## Уроки (уникати схожих сетапів)")
        for row in lessons[-10:]:
            lines.append(f"- {row}")
        lines.append("")
    if extra:
        lines.extend(["## Нотатка", extra, ""])
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text("\n".join(lines), encoding="utf-8")


def _ema(vals: list[float], period: int) -> float | None:
    if len(vals) < period:
        return None
    k = 2 / (period + 1)
    e = sum(vals[:period]) / period
    for v in vals[period:]:
        e = v * k + e * (1 - k)
    return e


def _rsi(closes: list[float], period: int = 14) -> float | None:
    if len(closes) < period + 1:
        return None
    gains = 0.0
    losses = 0.0
    for i in range(-period, 0):
        d = closes[i] - closes[i - 1]
        if d >= 0:
            gains += d
        else:
            losses -= d
    if losses <= 1e-12:
        return 100.0
    rs = (gains / period) / (losses / period)
    return 100 - (100 / (1 + rs))


class MexcMicroAI:
    def __init__(self) -> None:
        key = os.environ.get("MEXC_API_KEY") or ""
        secret = os.environ.get("MEXC_API_SECRET") or ""
        if not key or not secret:
            raise RuntimeError("Missing MEXC_API_KEY / MEXC_API_SECRET")
        self.live = os.environ.get("MEXC_LIVE_CONFIRMED", "false").lower() in {"1", "true", "yes"}
        self.ex = ccxt.mexc(
            {
                "apiKey": key,
                "secret": secret,
                "enableRateLimit": True,
                "options": {
                    "defaultType": "swap",
                    "recvWindow": 60_000,
                    "fetchCurrencies": False,
                    "adjustForTimeDifference": True,
                },
            }
        )
        self.state = load_state()
        self.symbol = str(self.state.get("symbol") or DEFAULT_SYMBOL)
        self.settle = "USDC"
        self.market: dict[str, Any] | None = None
        self.account_taker = float(self.state.get("measured_taker_pct") or 0.08) / 100.0

    async def _sync_clock(self) -> None:
        try:
            await self.ex.load_time_difference()
        except Exception as exc:  # noqa: BLE001
            print(f"clock sync soft-fail: {exc}", flush=True)

    async def setup(self) -> None:
        await self._sync_clock()
        await self.ex.load_markets()
        if self.symbol not in self.ex.markets:
            raise RuntimeError(f"Unknown symbol {self.symbol}")
        self.market = self.ex.markets[self.symbol]
        self.settle = str(self.market.get("settle") or "USDC").upper()
        for pt in (1, 2):
            try:
                await self.ex.set_leverage(1, self.symbol, params={"openType": 2, "positionType": pt})
            except Exception:
                pass

    async def close(self) -> None:
        await self.ex.close()

    def sleeve_left(self) -> float:
        bank = float(self.state.get("bankroll_usdc") or 5.0)
        realized = float(self.state.get("realized_pnl_usdc") or 0.0)
        return bank + realized

    def _halt_if_needed(self) -> str | None:
        if self.state.get("stopped"):
            return f"STOPPED: {self.state.get('stop_reason') or 'halted'}"
        left = self.sleeve_left()
        max_loss = float(self.state.get("max_loss_usdc") or 5.0)
        max_losses = int(self.state.get("max_losses") or 5)
        realized = float(self.state.get("realized_pnl_usdc") or 0.0)
        losses = int(self.state.get("losses") or 0)
        if losses >= max_losses:
            self.state["stopped"] = True
            self.state["stop_reason"] = f"hit {max_losses} losses (learn-stop) realized={realized:+.3f}"
            self.state["enabled"] = False
            save_state(self.state)
            return f"STOPPED: {self.state['stop_reason']}"
        if realized <= -max_loss or left <= 0.05:
            self.state["stopped"] = True
            self.state["stop_reason"] = f"bankroll exhausted left={left:.3f} realized={realized:+.3f}"
            self.state["enabled"] = False
            save_state(self.state)
            return f"STOPPED: {self.state['stop_reason']}"
        if not self.state.get("enabled", True):
            return "disabled"
        return None

    def _lesson_fingerprint(self, sig: dict[str, Any] | None) -> str:
        sig = sig or {}
        rsi5 = float(sig.get("rsi5") or 50)
        rp = float(sig.get("range_pos") or 0.5)
        rsi_band = "os" if rsi5 < 35 else "mid" if rsi5 < 55 else "ob" if rsi5 < 70 else "xob"
        range_band = "low" if rp < 0.35 else "mid" if rp < 0.65 else "high"
        return f"rsi:{rsi_band}|range:{range_band}"

    def _learn_from_trade(self, realized: float, action: str) -> None:
        """After losses: raise bar + remember bad setup. After wins: ease slightly."""
        step = float(self.state.get("learn_score_step") or 0.03)
        base = float(self.state.get("base_min_score") or 0.48)
        cur = float(self.state.get("min_score") or base)
        prev = self.state.get("open") or {}
        # reconstruct approx signal from open score / last_signal
        sig = dict(self.state.get("last_signal") or {})
        if realized < 0:
            cur = min(0.70, cur + step)
            fp = self._lesson_fingerprint(sig)
            lessons = list(self.state.get("lessons") or [])
            note = (
                f"{_utcnow()} LOSS {action} fp={fp} score={prev.get('score')} "
                f"pnl={realized:+.4f} -> min_score={cur:.2f}"
            )
            lessons.append(note)
            self.state["lessons"] = lessons[-30:]
            # keep unique fingerprints list in state
            fps = list(self.state.get("bad_fingerprints") or [])
            if fp not in fps:
                fps.append(fp)
            self.state["bad_fingerprints"] = fps[-12:]
        else:
            cur = max(base, cur - step * 0.5)
        self.state["min_score"] = round(cur, 3)

    async def free_margin(self) -> float:
        try:
            raw = await self.ex.contractPrivateGetAccountAssetCurrency({"currency": self.settle})
            data = raw.get("data") or {}
            return float(data.get("availableBalance") or data.get("availableCash") or 0)
        except Exception:
            bal = await self.ex.fetch_balance()
            free = bal.get(self.settle) or {}
            return float(free.get("free") or 0)

    async def mark(self) -> dict[str, float]:
        t = await self.ex.fetch_ticker(self.symbol)
        last = float(t.get("last") or 0)
        return {
            "last": last,
            "bid": float(t.get("bid") or last),
            "ask": float(t.get("ask") or last),
        }

    async def score_signal(self) -> dict[str, Any]:
        """Multi-TF score in [-1, +1]; long only when score >= min_score."""
        o1 = await self.ex.fetch_ohlcv(self.symbol, "1m", limit=60)
        o5 = await self.ex.fetch_ohlcv(self.symbol, "5m", limit=60)
        o15 = await self.ex.fetch_ohlcv(self.symbol, "15m", limit=40)
        if not o1 or not o5 or not o15:
            return {"ok": False, "reason": "no_candles"}

        c1 = [float(x[4]) for x in o1]
        c5 = [float(x[4]) for x in o5]
        c15 = [float(x[4]) for x in o15]
        h15 = [float(x[2]) for x in o15]
        l15 = [float(x[3]) for x in o15]

        ema_fast = _ema(c5, 8)
        ema_slow = _ema(c5, 21)
        rsi1 = _rsi(c1, 14)
        rsi5 = _rsi(c5, 14)
        px = c1[-1]
        lo, hi = min(l15), max(h15)
        range_pos = (px - lo) / (hi - lo) if hi > lo else 0.5
        mom1 = (c1[-1] / c1[-6] - 1) * 100 if len(c1) >= 6 else 0.0  # ~5m momentum on 1m
        mom5 = (c5[-1] / c5[-4] - 1) * 100 if len(c5) >= 4 else 0.0

        score = 0.0
        parts: dict[str, float] = {}

        # trend alignment on 5m
        if ema_fast is not None and ema_slow is not None:
            trend = 1.0 if ema_fast > ema_slow else -1.0
            # magnitude by separation
            sep = abs(ema_fast - ema_slow) / px * 100
            t_score = trend * min(1.0, sep / 0.15)
            score += 0.35 * t_score
            parts["trend"] = t_score

        # RSI: oversold bounce OR cooling pullback in uptrend (not chase >70)
        uptrend = bool(ema_fast is not None and ema_slow is not None and ema_fast > ema_slow)
        if rsi5 is not None:
            if 30 <= rsi5 <= 52:
                r = 0.9
            elif 52 < rsi5 <= 62 and uptrend:
                r = 0.45  # mild continuation only with trend
            elif 22 <= rsi5 < 30:
                r = 1.0
            elif rsi5 > 70:
                r = -1.0  # hard no chase
            elif rsi5 > 65:
                r = -0.6
            else:
                r = 0.0
            score += 0.28 * r
            parts["rsi5"] = r

        if rsi1 is not None:
            if rsi1 < 32:
                r = 0.85
            elif 32 <= rsi1 <= 55 and uptrend:
                r = 0.55  # pullback entry zone
            elif rsi1 > 72:
                r = -0.9
            elif rsi1 > 65:
                r = -0.4
            else:
                r = 0.0
            score += 0.18 * r
            parts["rsi1"] = r

        # prefer lower half of 15m range
        if range_pos <= 0.40:
            rz = 1.0 - range_pos
            score += 0.18 * min(1.0, rz)
            parts["range"] = rz
        elif range_pos >= 0.75:
            score -= 0.25
            parts["range"] = -0.25
        else:
            parts["range"] = 0.0

        # momentum: allow gentle continuation, reject dumps / vertical spikes
        if 0.0 <= mom5 <= 0.30 and uptrend:
            score += 0.12
            parts["mom5"] = 0.12
        elif mom5 < -0.18:
            score -= 0.20
            parts["mom5"] = -0.20
        else:
            parts["mom5"] = 0.0

        if -0.08 <= mom1 <= 0.12 and uptrend:
            score += 0.08
            parts["mom1"] = 0.08
        elif mom1 < -0.15:
            score -= 0.12
            parts["mom1"] = -0.12
        elif mom1 > 0.20:
            score -= 0.10  # don't chase spike
            parts["mom1"] = -0.10
        else:
            parts["mom1"] = 0.0

        # clamp
        score = max(-1.0, min(1.0, score))
        # learn: penalize fingerprints that already lost tonight
        fp = self._lesson_fingerprint(
            {"rsi5": rsi5, "range_pos": range_pos}
        )
        bad = set(self.state.get("bad_fingerprints") or [])
        if fp in bad:
            score -= 0.25
            parts["lesson_penalty"] = -0.25
        min_score = float(self.state.get("min_score") or 0.48)
        side = None
        if score >= min_score:
            side = "long"
        # shorts disabled for micro sleeve (1x long-only simpler with USDC)

        out = {
            "ok": True,
            "score": round(score, 3),
            "side": side,
            "min_score": min_score,
            "px": px,
            "range_pos": round(range_pos, 3),
            "rsi1": None if rsi1 is None else round(rsi1, 1),
            "rsi5": None if rsi5 is None else round(rsi5, 1),
            "mom1": round(mom1, 3),
            "mom5": round(mom5, 3),
            "parts": {k: round(v, 3) for k, v in parts.items()},
        }
        self.state["last_signal"] = out
        return out

    def _cooldown_ok(self) -> tuple[bool, str]:
        cd = float(self.state.get("cooldown_sec") or 900)
        last = str(self.state.get("last_close_at") or self.state.get("last_open_at") or "")
        if not last:
            return True, ""
        try:
            dt = datetime.fromisoformat(last.replace("Z", "+00:00"))
            age = (datetime.now(timezone.utc) - dt).total_seconds()
            if age < cd:
                return False, f"cooldown_{int(cd - age)}s"
        except Exception:
            return True, ""
        return True, ""

    async def _fee_txt(self, order_id: str | None, fill_px: float, amount: float) -> str:
        if not order_id:
            return "fee=n/a"
        try:
            trades = await self.ex.fetch_my_trades(self.symbol, limit=6)
            hit = [t for t in trades if str(t.get("order") or "") == str(order_id)]
            if not hit and trades:
                hit = trades[:1]
            parts = []
            csize = float((self.market or {}).get("contractSize") or 1)
            for t in hit[:2]:
                fee = t.get("fee") or {}
                cost = float(fee.get("cost") or 0)
                px = float(t.get("price") or fill_px)
                amt = float(t.get("amount") or amount)
                n = px * amt * csize
                pct = (cost / n * 100.0) if n else 0.0
                if pct > 0:
                    self.state["measured_taker_pct"] = round(pct, 4)
                    self.account_taker = pct / 100.0
                parts.append(f"fee={cost:.6f}({pct:.3f}%)")
            return " ".join(parts) if parts else "fee=n/a"
        except Exception as exc:  # noqa: BLE001
            return f"fee_err={exc}"

    async def manage(self) -> str:
        open_pos = self.state.get("open")
        if not open_pos:
            return "flat"
        m = await self.mark()
        entry = float(open_pos["entry"])
        px = m["bid"]
        pnl_pct = (px - entry) / entry * 100.0
        min_tp = float(self.state.get("min_tp_pct") or 0.24)
        early_tp = float(self.state.get("early_tp_pct") or 0.18)
        early_after = float(self.state.get("early_after_sec") or 480)
        stale_tp = float(self.state.get("stale_tp_pct") or 0.12)
        stale_after = float(self.state.get("stale_after_sec") or 1200)
        stop_pct = float(self.state.get("stop_pct") or 0.40)
        age = 0.0
        try:
            opened = datetime.fromisoformat(str(open_pos.get("opened_at") or "").replace("Z", "+00:00"))
            age = (datetime.now(timezone.utc) - opened).total_seconds()
        except Exception:
            age = 0.0
        max_hold = float(self.state.get("max_hold_sec") or 1800)

        action = None
        reason = ""
        if pnl_pct >= min_tp:
            action, reason = "tp", f"+{pnl_pct:.3f}%>= {min_tp:.2f}%"
        elif age >= early_after and pnl_pct >= early_tp:
            action, reason = "early", f"+{pnl_pct:.3f}%>= {early_tp:.2f}% after {age/60:.0f}m"
        elif age >= stale_after and pnl_pct >= stale_tp:
            action, reason = "stale", f"+{pnl_pct:.3f}%>= {stale_tp:.2f}% stale {age/60:.0f}m"
        elif pnl_pct <= -stop_pct:
            action, reason = "sl", f"{pnl_pct:.3f}%<= -{stop_pct:.2f}%"
        elif age >= max_hold:
            action, reason = "time", f"held {age/60:.0f}m pnl={pnl_pct:+.3f}% (no endless wait)"

        if not action:
            return (
                f"hold long {pnl_pct:+.3f}% need+{min_tp:.2f}%/"
                f"e+{early_tp:.2f}%@{early_after/60:.0f}m/"
                f"s+{stale_tp:.2f}%@{stale_after/60:.0f}m "
                f"max{max_hold/60:.0f}m age={age:.0f}s"
            )

        amount = float(open_pos["contracts"])
        csize = float((self.market or {}).get("contractSize") or 1)
        if not self.live:
            realized = (px - entry) * amount * csize
            self._book_close(realized, action)
            return f"PAPER close {action} {reason} pnl≈{realized:+.4f}"

        order = await self.ex.create_order(
            self.symbol, "market", "sell", amount, params={"reduceOnly": True, "openType": 2}
        )
        fill = float(order.get("average") or order.get("price") or px)
        realized = (fill - entry) * amount * csize
        fee_txt = await self._fee_txt(str(order.get("id") or ""), fill, amount)
        self._book_close(realized, action)
        return f"CLOSE {action} pnl≈{realized:+.4f} {self.settle} ({reason}) {fee_txt}"

    def _book_close(self, realized: float, action: str) -> None:
        self.state["realized_pnl_usdc"] = float(self.state.get("realized_pnl_usdc") or 0) + realized
        self.state["trades"] = int(self.state.get("trades") or 0) + 1
        if realized >= 0:
            self.state["wins"] = int(self.state.get("wins") or 0) + 1
        else:
            self.state["losses"] = int(self.state.get("losses") or 0) + 1
        prev = self.state.get("open") or {}
        self._learn_from_trade(realized, action)
        log = list(self.state.get("trade_log") or [])
        log.append(
            f"{_utcnow()} {action} entry={prev.get('entry')} pnl={realized:+.4f} "
            f"score={prev.get('score')} losses={self.state.get('losses')}/"
            f"{self.state.get('max_losses', 5)} min_score={self.state.get('min_score')} "
            f"sleeve={self.sleeve_left():.2f}"
        )
        self.state["trade_log"] = log[-50:]
        self.state["open"] = None
        self.state["last_close_at"] = _utcnow()
        # stop after bankroll gone / 5 losses
        self._halt_if_needed()
        save_state(self.state)

    async def maybe_open(self) -> str:
        halt = self._halt_if_needed()
        if halt:
            return halt
        if self.state.get("open"):
            return "skip: open"
        ok, why = self._cooldown_ok()
        if not ok:
            return f"skip: {why}"

        left = self.sleeve_left()
        stake = min(float(self.state.get("stake_usdc") or 1.0), left)
        if stake < 0.5:
            self.state["stopped"] = True
            self.state["stop_reason"] = f"stake too small left={left:.3f}"
            save_state(self.state)
            return f"STOPPED: {self.state['stop_reason']}"

        sig = await self.score_signal()
        if not sig.get("ok"):
            return f"skip: {sig.get('reason')}"
        if sig.get("side") != "long":
            return f"wait: score={sig.get('score')} < {sig.get('min_score')} (no long)"

        free = await self.free_margin()
        if free < stake:
            return f"skip: {self.settle} free={free:.2f} < stake={stake:.2f}"

        m = await self.mark()
        px = m["ask"]
        csize = float((self.market or {}).get("contractSize") or 1)
        contracts = max(1.0, int(stake / (px * csize)))
        notional = contracts * px * csize
        # keep near $1
        while contracts > 1 and notional > stake * 1.15:
            contracts -= 1
            notional = contracts * px * csize

        if not self.live:
            self.state["open"] = {
                "id": str(uuid.uuid4())[:8],
                "side": "long",
                "contracts": contracts,
                "entry": px,
                "notional": notional,
                "opened_at": _utcnow(),
                "mode": "paper",
                "score": sig.get("score"),
            }
            self.state["last_open_at"] = _utcnow()
            save_state(self.state)
            return f"PAPER open {contracts} @ {px} (~{notional:.2f}) score={sig.get('score')}"

        try:
            await self.ex.set_leverage(1, self.symbol, params={"openType": 2, "positionType": 1})
        except Exception:
            pass
        order = await self.ex.create_order(self.symbol, "market", "buy", contracts, params={"openType": 2})
        fill = float(order.get("average") or order.get("price") or px)
        filled = float(order.get("amount") or contracts)
        fee_txt = await self._fee_txt(str(order.get("id") or ""), fill, filled)
        self.state["open"] = {
            "id": str(uuid.uuid4())[:8],
            "side": "long",
            "contracts": filled,
            "entry": fill,
            "notional": filled * fill * csize,
            "opened_at": _utcnow(),
            "order_id": order.get("id"),
            "mode": "live",
            "score": sig.get("score"),
        }
        self.state["last_open_at"] = _utcnow()
        save_state(self.state)
        return (
            f"OPEN {filled} @ {fill} (~{filled * fill * csize:.2f} {self.settle}) "
            f"score={sig.get('score')} {fee_txt}"
        )

    async def tick(self) -> str:
        await self._sync_clock()
        halt = self._halt_if_needed()
        free = await self.free_margin()
        m = await self.mark()
        managed = await self.manage() if not (halt and not self.state.get("open")) else (halt or "halt")
        # if halted but still open, manage must run to flatten on exits only — already handled
        opened = "—"
        if not halt and not self.state.get("open"):
            opened = await self.maybe_open()
        elif halt and not self.state.get("open"):
            opened = halt
        save_state(self.state)
        left = self.sleeve_left()
        return (
            f"[{'LIVE' if self.live else 'PAPER'}] MICRO {self.symbol} "
            f"sleeve={left:.2f}/{float(self.state.get('bankroll_usdc') or 5):.0f} "
            f"W/L={self.state.get('wins',0)}/{self.state.get('losses',0)} "
            f"{self.settle}={free:.2f} mark={m['last']:.6g} | {managed} | {opened} | "
            f"realized={float(self.state.get('realized_pnl_usdc') or 0):+.4f}"
        )


async def main() -> None:
    _load_env()
    interval = int(os.environ.get("MEXC_MICRO_LOOP_SEC", "45"))
    bot = MexcMicroAI()
    await bot.setup()
    print(
        f"MEXC MICRO AI | symbol={bot.symbol} live={bot.live} "
        f"bankroll={bot.state['bankroll_usdc']} stake={bot.state['stake_usdc']} "
        f"tp>={bot.state['min_tp_pct']}% sl={bot.state['stop_pct']}% "
        f"min_score={bot.state['min_score']}",
        flush=True,
    )
    print(f"State: {STATE_PATH}", flush=True)
    try:
        while True:
            try:
                print(f"{_utcnow()} {await bot.tick()}", flush=True)
            except Exception as exc:  # noqa: BLE001
                print(f"{_utcnow()} tick_error: {exc}", flush=True)
            await asyncio.sleep(interval)
    finally:
        await bot.close()


if __name__ == "__main__":
    asyncio.run(main())
