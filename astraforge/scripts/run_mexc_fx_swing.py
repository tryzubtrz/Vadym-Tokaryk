"""MEXC range-swing sleeve (~$20) — buy low / sell high like Kraken FX.

Fiat FX pairs (EUR/CAD/GBP/AUD/JPY) are geo-blocked on this account.
Uses SILVER/USDC (openable with USDC) with the same swing logic:
rare entries in the lower range zone, exit only when move clears fees.
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
STATE_PATH = ROOT / "data" / "mexc_fx_swing.json"
REPORT_PATH = ROOT / "data" / "morning_report.md"
DEFAULT_SYMBOL = "SILVER/USDC:USDC"


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
        "symbol": os.environ.get("MEXC_FX_SYMBOL") or DEFAULT_SYMBOL,
        "bankroll_usdc": 20.0,
        "target_notional_usdc": 8.0,  # ~40% of $20, like Kraken working capital
        "min_tp_pct": 0.24,
        "early_tp_pct": 0.18,
        "early_after_sec": 600,  # 10m
        "stale_tp_pct": 0.12,
        "stale_after_sec": 1_500,  # 25m
        "stop_pct": 0.45,
        "max_hold_sec": 3_600,  # 1h hard cap
        "open_cooldown_sec": 300,  # 5 min
        "range_lookback": 40,
        "buy_zone_pct": 0.45,
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
        "trade_log": [],
        "note": "Fiat FX geo-blocked; SILVER/USDC used with Kraken-style range swing",
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
    env_sym = os.environ.get("MEXC_FX_SYMBOL")
    if env_sym:
        base["symbol"] = env_sym
    base["leverage"] = 1
    base["bankroll_usdc"] = min(max(float(base.get("bankroll_usdc") or 20.0), 5.0), 22.0)
    base["target_notional_usdc"] = min(
        max(float(base.get("target_notional_usdc") or 8.0), 3.0),
        float(base["bankroll_usdc"]) * 0.55,
    )
    if os.environ.get("MEXC_SPEED_MODE", "true").lower() in {"1", "true", "yes"}:
        base["min_tp_pct"] = 0.24
        base["early_tp_pct"] = 0.18
        base["early_after_sec"] = 600
        base["stale_tp_pct"] = 0.12
        base["stale_after_sec"] = 1_500
        base["stop_pct"] = 0.45
        base["max_hold_sec"] = 3_600
        base["open_cooldown_sec"] = 300
        base["buy_zone_pct"] = 0.45
    else:
        base["min_tp_pct"] = max(float(base.get("min_tp_pct") or 0.24), 0.20)
        base["early_tp_pct"] = max(float(base.get("early_tp_pct") or 0.18), 0.16)
        base["early_after_sec"] = min(max(float(base.get("early_after_sec") or 600), 180), 7200)
        base["buy_zone_pct"] = min(max(float(base.get("buy_zone_pct") or 0.45), 0.20), 0.55)
        base["open_cooldown_sec"] = min(max(float(base.get("open_cooldown_sec") or 300), 60), 3600)
        base["max_hold_sec"] = min(max(float(base.get("max_hold_sec") or 3600), 600), 14400)
    if not isinstance(base.get("trade_log"), list):
        base["trade_log"] = []
    return base


def save_state(state: dict[str, Any]) -> None:
    state["updated_at"] = _utcnow()
    STATE_PATH.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")
    _patch_morning_report(state)


def _patch_morning_report(state: dict[str, Any]) -> None:
    """Append FX-swing block into morning briefing if present."""
    bank = float(state.get("bankroll_usdc") or 20)
    realized = float(state.get("realized_pnl_usdc") or 0)
    left = bank + realized
    block = [
        "",
        "## FX-style swing (~$20)",
        f"- Symbol: `{state.get('symbol')}` (fiat FX blocked → metals/proxy)",
        f"- Sleeve: **{left:.2f}/{bank:.0f} USDC** | PnL **{realized:+.4f}**",
        f"- W/L: {state.get('wins', 0)}/{state.get('losses', 0)} trades={state.get('trades', 0)}",
        f"- Open: `{json.dumps(state.get('open'), ensure_ascii=False) if state.get('open') else 'немає'}`",
        f"- Updated: `{_utcnow()}`",
        "",
    ]
    if REPORT_PATH.exists():
        text = REPORT_PATH.read_text(encoding="utf-8")
        marker = "## FX-style swing"
        if marker in text:
            pre = text.split(marker)[0].rstrip()
            text = pre + "\n" + "\n".join(block)
        else:
            text = text.rstrip() + "\n" + "\n".join(block)
        REPORT_PATH.write_text(text + "\n", encoding="utf-8")
    else:
        REPORT_PATH.write_text("# Ранковий будок\n" + "\n".join(block), encoding="utf-8")


class MexcFxSwing:
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
        print(
            f"FEE note: using measured taker≈{self.account_taker*100:.3f}%/side "
            f"(API often lies zero_fee)",
            flush=True,
        )

    async def close(self) -> None:
        await self.ex.close()

    def sleeve_left(self) -> float:
        return float(self.state.get("bankroll_usdc") or 20) + float(self.state.get("realized_pnl_usdc") or 0)

    def _halt_if_needed(self) -> str | None:
        if self.state.get("stopped"):
            return f"STOPPED: {self.state.get('stop_reason')}"
        left = self.sleeve_left()
        if left <= 1.0:
            self.state["stopped"] = True
            self.state["stop_reason"] = f"sleeve low {left:.2f}"
            self.state["enabled"] = False
            save_state(self.state)
            return f"STOPPED: {self.state['stop_reason']}"
        if not self.state.get("enabled", True):
            return "disabled"
        return None

    async def free_margin(self) -> float:
        raw = await self.ex.contractPrivateGetAccountAssetCurrency({"currency": self.settle})
        data = raw.get("data") or {}
        return float(data.get("availableBalance") or data.get("availableCash") or 0)

    async def mark(self) -> dict[str, float]:
        t = await self.ex.fetch_ticker(self.symbol)
        last = float(t.get("last") or 0)
        return {"last": last, "bid": float(t.get("bid") or last), "ask": float(t.get("ask") or last)}

    async def range_zone(self) -> dict[str, Any]:
        n = int(self.state.get("range_lookback") or 40)
        ohlcv = await self.ex.fetch_ohlcv(self.symbol, "15m", limit=n)
        if not ohlcv:
            return {"ok": False, "reason": "no_candles"}
        lows = [float(c[3]) for c in ohlcv]
        highs = [float(c[2]) for c in ohlcv]
        closes = [float(c[4]) for c in ohlcv]
        lo, hi = min(lows), max(highs)
        px = closes[-1]
        if hi <= lo:
            return {"ok": False, "reason": "flat_range", "price": px}
        pos = (px - lo) / (hi - lo)
        zone = float(self.state.get("buy_zone_pct") or 0.28)
        return {
            "ok": True,
            "price": px,
            "lo": lo,
            "hi": hi,
            "range_pos": pos,
            "in_buy_zone": pos <= zone,
            "zone": zone,
        }

    def _cooldown_ok(self) -> tuple[bool, str]:
        cd = float(self.state.get("open_cooldown_sec") or 2700)
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
            csize = float((self.market or {}).get("contractSize") or 1)
            parts = []
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
        early_after = float(self.state.get("early_after_sec") or 600)
        stale_tp = float(self.state.get("stale_tp_pct") or 0.12)
        stale_after = float(self.state.get("stale_after_sec") or 1500)
        stop_pct = float(self.state.get("stop_pct") or 0.45)
        age = 0.0
        try:
            opened = datetime.fromisoformat(str(open_pos.get("opened_at") or "").replace("Z", "+00:00"))
            age = (datetime.now(timezone.utc) - opened).total_seconds()
        except Exception:
            age = 0.0
        max_hold = float(self.state.get("max_hold_sec") or 3600)

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
                f"max{max_hold/60:.0f}m age={age:.0f}s px={px}"
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
        log = list(self.state.get("trade_log") or [])
        log.append(
            f"{_utcnow()} {action} entry={prev.get('entry')} pnl={realized:+.4f} "
            f"sleeve={self.sleeve_left():.2f}"
        )
        self.state["trade_log"] = log[-40:]
        self.state["open"] = None
        self.state["last_close_at"] = _utcnow()
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

        zone = await self.range_zone()
        if not zone.get("ok"):
            return f"skip: {zone.get('reason')}"
        if not zone.get("in_buy_zone"):
            return (
                f"wait: range_pos={float(zone.get('range_pos') or 0):.2f} "
                f"> buy_zone {float(zone.get('zone') or 0):.2f} "
                f"(buy low like Kraken)"
            )

        free = await self.free_margin()
        # leave room for micro AI ~$5 sleeve + buffer
        reserve = float(os.environ.get("MEXC_MICRO_RESERVE_USDC", "5.5"))
        usable = max(0.0, min(self.sleeve_left(), free - reserve))
        target = float(self.state.get("target_notional_usdc") or 8.0)
        stake = min(target, usable)
        if stake < 3.0:
            return f"skip: usable={usable:.2f} free={free:.2f} reserve={reserve:.1f} need≥3"

        m = await self.mark()
        px = m["ask"]
        csize = float((self.market or {}).get("contractSize") or 1)
        contracts = max(1.0, int(stake / (px * csize)))
        notional = contracts * px * csize
        while contracts > 1 and notional > stake * 1.05:
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
                "range_pos": zone.get("range_pos"),
            }
            self.state["last_open_at"] = _utcnow()
            save_state(self.state)
            return f"PAPER open {contracts} @ {px} (~{notional:.2f}) range_pos={zone.get('range_pos')}"

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
            "range_pos": zone.get("range_pos"),
        }
        self.state["last_open_at"] = _utcnow()
        save_state(self.state)
        return (
            f"OPEN {filled} @ {fill} (~{filled * fill * csize:.2f} {self.settle}) "
            f"range_pos={zone.get('range_pos')} {fee_txt}"
        )

    async def tick(self) -> str:
        await self._sync_clock()
        halt = self._halt_if_needed()
        free = await self.free_margin()
        m = await self.mark()
        managed = await self.manage()
        opened = "—"
        if not halt and not self.state.get("open"):
            opened = await self.maybe_open()
        elif halt and not self.state.get("open"):
            opened = halt
        save_state(self.state)
        left = self.sleeve_left()
        return (
            f"[{'LIVE' if self.live else 'PAPER'}] FXSWING {self.symbol} "
            f"sleeve={left:.2f}/{float(self.state.get('bankroll_usdc') or 20):.0f} "
            f"W/L={self.state.get('wins',0)}/{self.state.get('losses',0)} "
            f"{self.settle}={free:.2f} mark={m['last']:.6g} | {managed} | {opened} | "
            f"realized={float(self.state.get('realized_pnl_usdc') or 0):+.4f}"
        )


async def main() -> None:
    _load_env()
    interval = int(os.environ.get("MEXC_FX_LOOP_SEC", "60"))
    bot = MexcFxSwing()
    await bot.setup()
    print(
        f"MEXC FX-style swing | symbol={bot.symbol} live={bot.live} "
        f"bankroll={bot.state['bankroll_usdc']} notional≈{bot.state['target_notional_usdc']} "
        f"tp>={bot.state['min_tp_pct']}% buy_zone<={bot.state['buy_zone_pct']}",
        flush=True,
    )
    print(f"State: {STATE_PATH}", flush=True)
    print("NOTE: fiat FX geo-blocked; SILVER used with buy-low/sell-high swing.", flush=True)
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
