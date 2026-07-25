"""MEXC USDT candle sleeve — ~$2 per candle on best openable pairs.

Uses USDT balance. Fiat FX still geo-blocked. Advertised zero-fee pairs
still charge ~0.08%/side on fills — exits stay fee-aware + speed caps.
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
STATE_PATH = ROOT / "data" / "mexc_usdt_candle.json"
# Best fit for ~$2 notional + tight spread + openable (probed)
UNIVERSE = [
    "XRP/USDT:USDT",
    "SUI/USDT:USDT",
    "AVAX/USDT:USDT",
    "ADA/USDT:USDT",
    "XLM/USDT:USDT",
]


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
    gains = losses = 0.0
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


def _default_state() -> dict[str, Any]:
    return {
        "enabled": True,
        "universe": list(UNIVERSE),
        "bankroll_usdt": 7.0,
        "stake_usdt": 2.0,
        "max_losses": 3,
        "min_tp_pct": 0.24,
        "early_tp_pct": 0.18,
        "early_after_sec": 480,
        "stale_tp_pct": 0.12,
        "stale_after_sec": 900,
        "stop_pct": 0.40,
        "max_hold_sec": 1_200,  # 20m — candle sleeve, no endless wait
        "cooldown_sec": 60,
        "min_score": 0.45,
        "candle_tf": "1m",
        "open": None,
        "last_open_at": "",
        "last_close_at": "",
        "realized_pnl_usdt": 0.0,
        "wins": 0,
        "losses": 0,
        "trades": 0,
        "stopped": False,
        "stop_reason": "",
        "measured_taker_pct": 0.08,
        "last_scan": [],
        "trade_log": [],
        "updated_at": _utcnow(),
    }


def load_state() -> dict[str, Any]:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    base = _default_state()
    if STATE_PATH.exists():
        try:
            base.update(json.loads(STATE_PATH.read_text(encoding="utf-8")) or {})
        except Exception:
            pass
    if os.environ.get("MEXC_SPEED_MODE", "true").lower() in {"1", "true", "yes"}:
        base["min_tp_pct"] = 0.24
        base["early_tp_pct"] = 0.18
        base["early_after_sec"] = 480
        base["stale_tp_pct"] = 0.12
        base["stale_after_sec"] = 900
        base["stop_pct"] = 0.40
        base["max_hold_sec"] = 1_200
        base["cooldown_sec"] = 60
        base["stake_usdt"] = 2.0
    base["stake_usdt"] = min(max(float(base.get("stake_usdt") or 2.0), 1.0), 2.0)
    base["bankroll_usdt"] = min(max(float(base.get("bankroll_usdt") or 7.0), 2.0), 7.0)
    base["max_losses"] = int(min(max(int(base.get("max_losses") or 3), 1), 3))
    if not isinstance(base.get("universe"), list) or not base["universe"]:
        base["universe"] = list(UNIVERSE)
    if not isinstance(base.get("trade_log"), list):
        base["trade_log"] = []
    return base


def save_state(state: dict[str, Any]) -> None:
    state["updated_at"] = _utcnow()
    STATE_PATH.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")


class MexcUsdtCandle:
    def __init__(self) -> None:
        key = os.environ.get("MEXC_API_KEY") or ""
        secret = os.environ.get("MEXC_API_SECRET") or ""
        if not key or not secret:
            raise RuntimeError("Missing MEXC keys")
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
        self.markets: dict[str, Any] = {}
        self.account_taker = float(self.state.get("measured_taker_pct") or 0.08) / 100.0

    async def setup(self) -> None:
        try:
            await self.ex.load_time_difference()
        except Exception as exc:  # noqa: BLE001
            print(f"clock soft-fail: {exc}", flush=True)
        await self.ex.load_markets()
        for sym in self.state["universe"]:
            if sym in self.ex.markets:
                self.markets[sym] = self.ex.markets[sym]
        print(
            f"USDT candle universe: {list(self.markets)} | "
            f"measured_taker≈{self.account_taker*100:.3f}%",
            flush=True,
        )

    async def close(self) -> None:
        await self.ex.close()

    def sleeve_left(self) -> float:
        return float(self.state.get("bankroll_usdt") or 7) + float(self.state.get("realized_pnl_usdt") or 0)

    def _halt(self) -> str | None:
        if self.state.get("stopped"):
            return f"STOPPED: {self.state.get('stop_reason')}"
        if int(self.state.get("losses") or 0) >= int(self.state.get("max_losses") or 3):
            self.state["stopped"] = True
            self.state["stop_reason"] = f"hit {self.state.get('max_losses')} losses"
            self.state["enabled"] = False
            save_state(self.state)
            return f"STOPPED: {self.state['stop_reason']}"
        if self.sleeve_left() < 1.5:
            self.state["stopped"] = True
            self.state["stop_reason"] = f"sleeve low {self.sleeve_left():.2f}"
            self.state["enabled"] = False
            save_state(self.state)
            return f"STOPPED: {self.state['stop_reason']}"
        if not self.state.get("enabled", True):
            return "disabled"
        return None

    async def free_usdt(self) -> float:
        raw = await self.ex.contractPrivateGetAccountAssetCurrency({"currency": "USDT"})
        data = raw.get("data") or {}
        return float(data.get("availableBalance") or data.get("availableCash") or 0)

    async def score_symbol(self, symbol: str) -> dict[str, Any]:
        tf = str(self.state.get("candle_tf") or "1m")
        o1 = await self.ex.fetch_ohlcv(symbol, tf, limit=60)
        o5 = await self.ex.fetch_ohlcv(symbol, "5m", limit=40)
        if not o1 or not o5:
            return {"ok": False, "symbol": symbol, "reason": "no_candles"}
        c1 = [float(x[4]) for x in o1]
        c5 = [float(x[4]) for x in o5]
        h1 = [float(x[2]) for x in o1[-20:]]
        l1 = [float(x[3]) for x in o1[-20:]]
        px = c1[-1]
        # last closed candle direction (previous bar)
        prev = o1[-2]
        body = float(prev[4]) - float(prev[1])
        candle_pct = body / float(prev[1]) * 100 if float(prev[1]) else 0.0
        ema_f = _ema(c5, 8)
        ema_s = _ema(c5, 21)
        rsi1 = _rsi(c1, 14)
        lo, hi = min(l1), max(h1)
        range_pos = (px - lo) / (hi - lo) if hi > lo else 0.5
        uptrend = bool(ema_f and ema_s and ema_f > ema_s)
        score = 0.0
        # long bias on green pullback candle
        if candle_pct > 0.05:
            score += 0.25
        elif candle_pct < -0.08:
            score -= 0.25
        if uptrend:
            score += 0.30
        else:
            score -= 0.15
        if rsi1 is not None:
            if 32 <= rsi1 <= 55:
                score += 0.30
            elif rsi1 < 30:
                score += 0.35
            elif rsi1 > 70:
                score -= 0.40
        if range_pos <= 0.40:
            score += 0.20
        elif range_pos >= 0.75:
            score -= 0.25
        score = max(-1.0, min(1.0, score))
        t = await self.ex.fetch_ticker(symbol)
        bid = float(t.get("bid") or px)
        ask = float(t.get("ask") or px)
        spread = (ask - bid) / px * 100 if px else 9
        return {
            "ok": True,
            "symbol": symbol,
            "score": round(score, 3),
            "side": "long" if score >= float(self.state.get("min_score") or 0.45) else None,
            "px": px,
            "bid": bid,
            "ask": ask,
            "spread_pct": round(spread, 4),
            "candle_pct": round(candle_pct, 4),
            "rsi1": None if rsi1 is None else round(rsi1, 1),
            "range_pos": round(range_pos, 3),
            "uptrend": uptrend,
        }

    async def scan(self) -> list[dict[str, Any]]:
        out = []
        for sym in list(self.markets):
            try:
                out.append(await self.score_symbol(sym))
            except Exception as exc:  # noqa: BLE001
                out.append({"ok": False, "symbol": sym, "reason": str(exc)[:120]})
            await asyncio.sleep(0.05)
        out.sort(key=lambda r: float(r.get("score") or -9), reverse=True)
        self.state["last_scan"] = out
        return out

    def _cooldown_ok(self) -> tuple[bool, str]:
        cd = float(self.state.get("cooldown_sec") or 60)
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

    async def _fee_txt(self, symbol: str, order_id: str | None, fill_px: float, amount: float) -> str:
        if not order_id:
            return "fee=n/a"
        try:
            trades = await self.ex.fetch_my_trades(symbol, limit=6)
            hit = [t for t in trades if str(t.get("order") or "") == str(order_id)] or trades[:1]
            csize = float((self.markets.get(symbol) or {}).get("contractSize") or 1)
            parts = []
            for t in hit[:2]:
                fee = t.get("fee") or {}
                cost = float(fee.get("cost") or 0)
                px = float(t.get("price") or fill_px)
                amt = float(t.get("amount") or amount)
                n = px * amt * csize
                pct = cost / n * 100 if n else 0
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
        symbol = str(open_pos["symbol"])
        t = await self.ex.fetch_ticker(symbol)
        entry = float(open_pos["entry"])
        px = float(t.get("bid") or t.get("last") or entry)
        pnl_pct = (px - entry) / entry * 100.0
        min_tp = float(self.state.get("min_tp_pct") or 0.24)
        early_tp = float(self.state.get("early_tp_pct") or 0.18)
        early_after = float(self.state.get("early_after_sec") or 480)
        stale_tp = float(self.state.get("stale_tp_pct") or 0.12)
        stale_after = float(self.state.get("stale_after_sec") or 900)
        stop_pct = float(self.state.get("stop_pct") or 0.40)
        max_hold = float(self.state.get("max_hold_sec") or 1200)
        age = 0.0
        try:
            opened = datetime.fromisoformat(str(open_pos.get("opened_at") or "").replace("Z", "+00:00"))
            age = (datetime.now(timezone.utc) - opened).total_seconds()
        except Exception:
            age = 0.0

        action = reason = None
        if pnl_pct >= min_tp:
            action, reason = "tp", f"+{pnl_pct:.3f}%>= {min_tp:.2f}%"
        elif age >= early_after and pnl_pct >= early_tp:
            action, reason = "early", f"+{pnl_pct:.3f}% after {age/60:.0f}m"
        elif age >= stale_after and pnl_pct >= stale_tp:
            action, reason = "stale", f"+{pnl_pct:.3f}% stale {age/60:.0f}m"
        elif pnl_pct <= -stop_pct:
            action, reason = "sl", f"{pnl_pct:.3f}%"
        elif age >= max_hold:
            action, reason = "time", f"held {age/60:.0f}m pnl={pnl_pct:+.3f}%"

        if not action:
            return f"hold {symbol} {pnl_pct:+.3f}% need+{min_tp:.2f}% age={age:.0f}s"

        amount = float(open_pos["contracts"])
        csize = float((self.markets.get(symbol) or {}).get("contractSize") or 1)
        if not self.live:
            realized = (px - entry) * amount * csize
            self._book(realized, action, open_pos)
            return f"PAPER close {action} {reason} pnl≈{realized:+.4f}"

        order = await self.ex.create_order(
            symbol, "market", "sell", amount, params={"reduceOnly": True, "openType": 2}
        )
        fill = float(order.get("average") or order.get("price") or px)
        realized = (fill - entry) * amount * csize
        fee_txt = await self._fee_txt(symbol, str(order.get("id") or ""), fill, amount)
        self._book(realized, action, open_pos)
        return f"CLOSE {action} {symbol} pnl≈{realized:+.4f} USDT ({reason}) {fee_txt}"

    def _book(self, realized: float, action: str, prev: dict[str, Any]) -> None:
        self.state["realized_pnl_usdt"] = float(self.state.get("realized_pnl_usdt") or 0) + realized
        self.state["trades"] = int(self.state.get("trades") or 0) + 1
        if realized >= 0:
            self.state["wins"] = int(self.state.get("wins") or 0) + 1
        else:
            self.state["losses"] = int(self.state.get("losses") or 0) + 1
        log = list(self.state.get("trade_log") or [])
        log.append(
            f"{_utcnow()} {action} {prev.get('symbol')} entry={prev.get('entry')} "
            f"pnl={realized:+.4f} sleeve={self.sleeve_left():.2f}"
        )
        self.state["trade_log"] = log[-40:]
        self.state["open"] = None
        self.state["last_close_at"] = _utcnow()
        self._halt()
        save_state(self.state)

    async def maybe_open(self) -> str:
        halt = self._halt()
        if halt:
            return halt
        if self.state.get("open"):
            return "skip: open"
        ok, why = self._cooldown_ok()
        if not ok:
            return f"skip: {why}"
        free = await self.free_usdt()
        stake = min(float(self.state.get("stake_usdt") or 2.0), self.sleeve_left(), free * 0.95)
        if stake < 1.0:
            return f"skip: USDT free={free:.2f} stake={stake:.2f}"

        scan = await self.scan()
        best = next((r for r in scan if r.get("ok") and r.get("side") == "long"), None)
        if not best:
            top = scan[0] if scan else {}
            return f"wait: best score={top.get('score')} {top.get('symbol')} < {self.state.get('min_score')}"

        symbol = str(best["symbol"])
        m = self.markets[symbol]
        px = float(best["ask"])
        csize = float(m.get("contractSize") or 1)
        contracts = max(1.0, int(stake / (px * csize)))
        notional = contracts * px * csize
        while contracts > 1 and notional > stake * 1.15:
            contracts -= 1
            notional = contracts * px * csize

        if not self.live:
            self.state["open"] = {
                "id": str(uuid.uuid4())[:8],
                "symbol": symbol,
                "side": "long",
                "contracts": contracts,
                "entry": px,
                "notional": notional,
                "opened_at": _utcnow(),
                "mode": "paper",
                "score": best.get("score"),
            }
            self.state["last_open_at"] = _utcnow()
            save_state(self.state)
            return f"PAPER open {symbol} {contracts} @ {px} (~{notional:.2f}) score={best.get('score')}"

        try:
            await self.ex.set_leverage(1, symbol, params={"openType": 2, "positionType": 1})
        except Exception:
            pass
        order = await self.ex.create_order(symbol, "market", "buy", contracts, params={"openType": 2})
        fill = float(order.get("average") or order.get("price") or px)
        filled = float(order.get("amount") or contracts)
        fee_txt = await self._fee_txt(symbol, str(order.get("id") or ""), fill, filled)
        self.state["open"] = {
            "id": str(uuid.uuid4())[:8],
            "symbol": symbol,
            "side": "long",
            "contracts": filled,
            "entry": fill,
            "notional": filled * fill * csize,
            "opened_at": _utcnow(),
            "order_id": order.get("id"),
            "mode": "live",
            "score": best.get("score"),
        }
        self.state["last_open_at"] = _utcnow()
        save_state(self.state)
        return (
            f"OPEN {symbol} {filled} @ {fill} (~{filled*fill*csize:.2f} USDT) "
            f"score={best.get('score')} candle={best.get('candle_pct')}% {fee_txt}"
        )

    async def tick(self) -> str:
        try:
            await self.ex.load_time_difference()
        except Exception:
            pass
        free = await self.free_usdt()
        managed = await self.manage()
        opened = "—"
        if not self.state.get("open"):
            opened = await self.maybe_open()
        save_state(self.state)
        scan = self.state.get("last_scan") or []
        top = ", ".join(
            f"{r.get('symbol','?').split('/')[0]}:{r.get('score')}" for r in scan[:3] if r.get("ok")
        )
        return (
            f"[{'LIVE' if self.live else 'PAPER'}] USDT-CANDLE "
            f"sleeve={self.sleeve_left():.2f}/{float(self.state.get('bankroll_usdt') or 7):.0f} "
            f"W/L={self.state.get('wins',0)}/{self.state.get('losses',0)} USDT={free:.2f} | "
            f"{managed} | {opened} | top[{top}] realized={float(self.state.get('realized_pnl_usdt') or 0):+.4f}"
        )


async def main() -> None:
    _load_env()
    interval = int(os.environ.get("MEXC_USDT_LOOP_SEC", "20"))
    bot = MexcUsdtCandle()
    await bot.setup()
    print(
        f"MEXC USDT candle | live={bot.live} stake={bot.state['stake_usdt']} "
        f"tp>={bot.state['min_tp_pct']}% max_hold={bot.state['max_hold_sec']}s "
        f"bankroll={bot.state['bankroll_usdt']}",
        flush=True,
    )
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
