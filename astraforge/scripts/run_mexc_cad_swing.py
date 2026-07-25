"""MEXC CAD/USDT perpetual swing trial — 1x only, fee-aware exits.

Safety rules (hard):
- leverage forced to 1
- one position max
- close only when move clears fees (~0.25%+)
- small notional (~$8–10)
"""

from __future__ import annotations

import asyncio
import json
import os
import time
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import ccxt.async_support as ccxt

ROOT = Path(__file__).resolve().parents[1]
STATE_PATH = ROOT / "data" / "mexc_cad_swing.json"
SYMBOL = "CAD/USDT:USDT"


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
        "symbol": SYMBOL,
        "leverage": 1,
        "target_notional_usdt": 9.0,
        "min_tp_pct": 0.25,  # taker RT ~0.08% + buffer/funding
        "max_hold_sec": 43_200,  # 12h then flatten
        "open_cooldown_sec": 2_700,
        "range_lookback": 40,
        "buy_zone_pct": 0.30,
        "open": None,
        "last_open_at": "",
        "last_close_at": "",
        "realized_pnl_usdt": 0.0,
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
    # hard safety clamps
    base["leverage"] = 1
    base["min_tp_pct"] = max(float(base.get("min_tp_pct") or 0.25), 0.20)
    base["target_notional_usdt"] = min(max(float(base.get("target_notional_usdt") or 9.0), 3.0), 15.0)
    return base


def save_state(state: dict[str, Any]) -> None:
    state["leverage"] = 1
    state["updated_at"] = _utcnow()
    STATE_PATH.write_text(json.dumps(state, indent=2, ensure_ascii=False), encoding="utf-8")


class MexcCadSwing:
    def __init__(self) -> None:
        key = os.environ.get("MEXC_API_KEY") or os.environ.get("EXCHANGE_API_KEY_MEXC") or ""
        secret = os.environ.get("MEXC_API_SECRET") or os.environ.get("EXCHANGE_API_SECRET_MEXC") or ""
        if not key or not secret:
            raise RuntimeError(
                "Missing MEXC_API_KEY / MEXC_API_SECRET in .env "
                "(create trade-only API key on MEXC; no withdrawal)"
            )
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
        self.account_taker = 0.0004
        self.account_maker = 0.0001

    async def _sync_clock(self) -> None:
        try:
            await self.ex.load_time_difference()
            td = self.ex.options.get("timeDifference")
            print(f"clock sync timeDifference={td}ms", flush=True)
        except Exception as exc:  # noqa: BLE001
            print(f"clock sync soft-fail: {exc}", flush=True)

    async def _log_account_fees(self) -> None:
        """Print account fee for CAD_USDT before any order (first-run check)."""
        try:
            raw = await self.ex.contractPrivateGetAccountContractFeeRate({"symbol": "CAD_USDT"})
            rows = raw.get("data") or []
            row = rows[0] if rows else {}
            self.account_taker = float(row.get("takerFeeRate") or self.account_taker)
            self.account_maker = float(row.get("makerFeeRate") or self.account_maker)
            zero = bool(row.get("isZeroFeeRate") or row.get("isZeroFeeSymbol"))
            rt = self.account_taker * 2.0 * 100.0
            print(
                f"FEE CHECK CAD_USDT | maker={self.account_maker*100:.3f}% "
                f"taker={self.account_taker*100:.3f}% RT≈{rt:.3f}% "
                f"zero_fee={zero} mode={row.get('feeRateMode')}",
                flush=True,
            )
            min_tp = float(self.state.get("min_tp_pct") or 0.25)
            if min_tp < rt + 0.05:
                print(
                    f"WARN: min_tp_pct={min_tp}% is tight vs RT≈{rt:.3f}% — "
                    f"raising floor mentally; prefer >= {rt + 0.15:.2f}%",
                    flush=True,
                )
        except Exception as exc:  # noqa: BLE001
            print(f"FEE CHECK soft-fail (using defaults 0.01/0.04%): {exc}", flush=True)

    async def _fee_from_order(self, order_id: str | None) -> str:
        if not order_id:
            return "fee=n/a"
        try:
            raw = await self.ex.contractPrivateGetOrderFeeDetails({"orderId": order_id})
            data = raw.get("data") or raw
            return f"fee_details={data}"
        except Exception:
            try:
                trades = await self.ex.fetch_my_trades(SYMBOL, limit=5)
                hit = [t for t in trades if str(t.get("order") or "") == str(order_id)]
                if not hit and trades:
                    hit = trades[:1]
                parts = []
                for t in hit[:3]:
                    fee = t.get("fee") or {}
                    parts.append(
                        f"tradeFee={fee.get('cost')} {fee.get('currency')} "
                        f"price={t.get('price')} amt={t.get('amount')}"
                    )
                return " | ".join(parts) if parts else "fee=n/a"
            except Exception as exc:  # noqa: BLE001
                return f"fee_lookup_fail={exc}"

    async def setup(self) -> None:
        await self._sync_clock()
        await self.ex.load_markets()
        await self._log_account_fees()
        # Force 1x — never higher for this trial (MEXC wants openType/positionType)
        for position_type in (1, 2):  # 1=long, 2=short
            try:
                await self.ex.set_leverage(
                    1,
                    SYMBOL,
                    params={"openType": 2, "positionType": position_type},  # 2=cross
                )
            except Exception as exc:  # noqa: BLE001
                print(f"set_leverage soft-fail posType={position_type}: {exc}", flush=True)
        try:
            await self.ex.set_margin_mode("cross", SYMBOL)
        except Exception:
            pass

    async def close(self) -> None:
        await self.ex.close()

    async def free_usdt(self) -> float:
        bal = await self.ex.fetch_balance()
        # swap wallet may be under USDT free
        free = bal.get("USDT") or {}
        return float(free.get("free") or bal.get("free", {}).get("USDT") or 0)

    async def mark(self) -> dict[str, float]:
        t = await self.ex.fetch_ticker(SYMBOL)
        last = float(t.get("last") or 0)
        bid = float(t.get("bid") or last)
        ask = float(t.get("ask") or last)
        return {"last": last, "bid": bid, "ask": ask}

    async def in_buy_zone(self) -> dict[str, Any]:
        ohlcv = await self.ex.fetch_ohlcv(SYMBOL, "15m", limit=int(self.state.get("range_lookback") or 40))
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
        zone = float(self.state.get("buy_zone_pct") or 0.30)
        return {
            "ok": True,
            "price": px,
            "range_pos": pos,
            "in_buy_zone": pos <= zone,
            "lo": lo,
            "hi": hi,
        }

    def _cooldown_ok(self) -> tuple[bool, str]:
        cd = float(self.state.get("open_cooldown_sec") or 2700)
        last = str(self.state.get("last_open_at") or self.state.get("last_close_at") or "")
        if not last or cd <= 0:
            return True, ""
        try:
            dt = datetime.fromisoformat(last.replace("Z", "+00:00"))
            age = (datetime.now(timezone.utc) - dt).total_seconds()
            if age < cd:
                return False, f"cooldown_{int(cd - age)}s"
        except Exception:
            return True, ""
        return True, ""

    async def manage(self) -> str:
        open_pos = self.state.get("open")
        if not open_pos:
            return "flat"
        m = await self.mark()
        entry = float(open_pos["entry"])
        side = str(open_pos.get("side") or "long")
        # long CADUSDT: exit on bid
        px = m["bid"] if side == "long" else m["ask"]
        pnl_pct = ((px - entry) / entry) * 100.0 if side == "long" else ((entry - px) / entry) * 100.0
        min_tp = float(self.state.get("min_tp_pct") or 0.25)
        age = 0.0
        try:
            opened = datetime.fromisoformat(str(open_pos.get("opened_at") or "").replace("Z", "+00:00"))
            age = (datetime.now(timezone.utc) - opened).total_seconds()
        except Exception:
            age = 0.0
        max_hold = float(self.state.get("max_hold_sec") or 43_200)

        action = None
        reason = ""
        if pnl_pct >= min_tp:
            action = "tp"
            reason = f"+{pnl_pct:.3f}% >= {min_tp:.2f}%"
        elif age >= max_hold:
            action = "time"
            reason = f"held {age/3600:.1f}h pnl={pnl_pct:+.3f}%"

        if not action:
            return f"hold {side} {pnl_pct:+.3f}% need+{min_tp:.2f}% age={age:.0f}s px={px}"

        amount = float(open_pos["contracts"])
        if not self.live:
            self.state["open"] = None
            self.state["last_close_at"] = _utcnow()
            save_state(self.state)
            return f"PAPER close {action} {reason}"

        close_side = "sell" if side == "long" else "buy"
        order = await self.ex.create_order(SYMBOL, "market", close_side, amount, params={"reduceOnly": True})
        fill = float(order.get("average") or order.get("price") or px)
        realized = (fill - entry) * amount if side == "long" else (entry - fill) * amount
        fee_txt = await self._fee_from_order(str(order.get("id") or ""))
        # contracts are CAD; PnL approx in USDT already for linear
        self.state["realized_pnl_usdt"] = float(self.state.get("realized_pnl_usdt") or 0) + realized
        self.state["open"] = None
        self.state["last_close_at"] = _utcnow()
        save_state(self.state)
        return (
            f"CLOSE {action} pnl≈{realized:+.4f} USDT ({reason}) "
            f"order={order.get('id')} {fee_txt}"
        )

    async def maybe_open(self) -> str:
        if self.state.get("open"):
            return "skip: already open"
        ok, why = self._cooldown_ok()
        if not ok:
            return f"skip: {why}"

        zone = await self.in_buy_zone()
        if not zone.get("ok"):
            return f"skip: {zone.get('reason')}"
        if not zone.get("in_buy_zone"):
            return f"wait: range_pos={float(zone.get('range_pos') or 0):.2f} not in buy zone"

        free = await self.free_usdt()
        target = float(self.state.get("target_notional_usdt") or 9.0)
        if free < max(3.0, target * 0.5):
            return f"skip: USDT free={free:.2f} need≈{target:.2f}"

        m = await self.mark()
        px = m["ask"]
        if px <= 0:
            return "skip: bad price"
        # 1 contract = 1 CAD ≈ px USDT notional
        notional = min(target, free * 0.95)
        contracts = max(1.0, int(notional / px))
        # recompute notional
        notional = contracts * px
        if notional > free * 0.98:
            contracts = max(1.0, int((free * 0.9) / px))
            notional = contracts * px

        if not self.live:
            self.state["open"] = {
                "id": str(uuid.uuid4())[:8],
                "side": "long",
                "contracts": contracts,
                "entry": px,
                "notional_usdt": notional,
                "opened_at": _utcnow(),
                "mode": "paper",
            }
            self.state["last_open_at"] = _utcnow()
            save_state(self.state)
            return f"PAPER open long {contracts} CAD @ {px} (~{notional:.2f} USDT)"

        # ensure leverage 1 each open
        try:
            await self.ex.set_leverage(
                1, SYMBOL, params={"openType": 2, "positionType": 1}
            )
        except Exception:
            pass
        order = await self.ex.create_order(SYMBOL, "market", "buy", contracts)
        fill = float(order.get("average") or order.get("price") or px)
        filled_amt = float(order.get("amount") or contracts)
        fee_txt = await self._fee_from_order(str(order.get("id") or ""))
        # first-live sanity: estimated taker fee vs fill notional
        est_fee = filled_amt * fill * self.account_taker
        self.state["open"] = {
            "id": str(uuid.uuid4())[:8],
            "side": "long",
            "contracts": filled_amt,
            "entry": fill,
            "notional_usdt": filled_amt * fill,
            "opened_at": _utcnow(),
            "order_id": order.get("id"),
            "mode": "live",
            "est_open_fee_usdt": est_fee,
        }
        self.state["last_open_at"] = _utcnow()
        save_state(self.state)
        return (
            f"OPEN long {filled_amt} CAD @ {fill} (~{filled_amt * fill:.2f} USDT) "
            f"id={order.get('id')} est_fee≈{est_fee:.4f} USDT {fee_txt}"
        )

    async def tick(self) -> str:
        free = await self.free_usdt()
        m = await self.mark()
        managed = await self.manage()
        opened = "—"
        if not self.state.get("open"):
            opened = await self.maybe_open()
        save_state(self.state)
        return (
            f"[{'LIVE' if self.live else 'PAPER'}] USDT={free:.2f} mark={m['last']:.4f} | "
            f"{managed} | {opened} | realized={float(self.state.get('realized_pnl_usdt') or 0):+.4f}"
        )


async def main() -> None:
    _load_env()
    interval = int(os.environ.get("MEXC_LOOP_SEC", "60"))
    bot = MexcCadSwing()
    await bot.setup()
    print(
        f"MEXC CADUSDT swing trial | live={bot.live} | lev=1 | "
        f"tp>={bot.state['min_tp_pct']}% | notional≈{bot.state['target_notional_usdt']} USDT",
        flush=True,
    )
    print(f"State: {STATE_PATH}", flush=True)
    try:
        while True:
            try:
                msg = await bot.tick()
                print(f"{_utcnow()} {msg}", flush=True)
            except Exception as exc:  # noqa: BLE001
                print(f"{_utcnow()} tick_error: {exc}", flush=True)
            await asyncio.sleep(interval)
    finally:
        await bot.close()


if __name__ == "__main__":
    asyncio.run(main())
