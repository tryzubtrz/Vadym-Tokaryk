"""MEXC perpetual swing trial — 1x only, fee-aware exits.

Default symbol is XRP/USDC:USDC because:
- CAD/USDT (and several FX pairs) are geo-blocked for opens in some regions
- this account funded Futures with USDC, not USDT

Safety rules (hard):
- leverage forced to 1
- one position max
- close only when move clears measured fees
- small notional (~$8–10)
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
STATE_PATH = ROOT / "data" / "mexc_cad_swing.json"
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
        "symbol": os.environ.get("MEXC_SYMBOL") or DEFAULT_SYMBOL,
        "leverage": 1,
        "target_notional_usdt": 9.0,  # notional in settle coin (USDC/USDT)
        "min_tp_pct": 0.35,  # measured XRP_USDC fill fee ~0.08%/side → RT~0.16% + buffer
        "max_hold_sec": 43_200,  # 12h then flatten
        "open_cooldown_sec": 2_700,
        "range_lookback": 40,
        "buy_zone_pct": 0.30,
        "open": None,
        "last_open_at": "",
        "last_close_at": "",
        "realized_pnl_usdt": 0.0,
        "measured_taker_pct": None,
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
    # env symbol wins when set
    env_sym = os.environ.get("MEXC_SYMBOL")
    if env_sym:
        base["symbol"] = env_sym
    # hard safety clamps
    base["leverage"] = 1
    base["min_tp_pct"] = max(float(base.get("min_tp_pct") or 0.35), 0.25)
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
        self.symbol = str(self.state.get("symbol") or DEFAULT_SYMBOL)
        self.settle = "USDC" if ":USDC" in self.symbol or self.symbol.endswith("USDC") else "USDT"
        # fallback until account/fill measurement
        self.account_taker = 0.0008  # measured on first XRP_USDC fill (~0.08%)
        self.account_maker = 0.0008
        self.market: dict[str, Any] | None = None

    async def _sync_clock(self) -> None:
        try:
            await self.ex.load_time_difference()
            td = self.ex.options.get("timeDifference")
            print(f"clock sync timeDifference={td}ms", flush=True)
        except Exception as exc:  # noqa: BLE001
            print(f"clock sync soft-fail: {exc}", flush=True)

    async def _log_account_fees(self) -> None:
        """Print account fee + remind that fills can differ from advertised zero-fee."""
        market_id = (self.market or {}).get("id") or self.symbol.replace("/", "_").replace(":USDC", "").replace(":USDT", "")
        try:
            raw = await self.ex.contractPrivateGetAccountContractFeeRate({"symbol": market_id})
            rows = raw.get("data") or []
            row = rows[0] if rows else {}
            api_taker = float(row.get("takerFeeRate") or 0.0)
            api_maker = float(row.get("makerFeeRate") or 0.0)
            zero = bool(row.get("isZeroFeeRate") or row.get("isZeroFeeSymbol"))
            print(
                f"FEE API {market_id} | maker={api_maker*100:.3f}% taker={api_taker*100:.3f}% "
                f"zero_fee={zero} mode={row.get('feeRateMode')}",
                flush=True,
            )
            # Prefer measured fill fee when API advertises 0 (seen lying on XRP_USDC)
            measured = self.state.get("measured_taker_pct")
            if measured is not None:
                self.account_taker = float(measured) / 100.0
                self.account_maker = self.account_taker
                print(f"FEE MEASURED taker≈{float(measured):.3f}% (from live fills)", flush=True)
            elif api_taker > 0:
                self.account_taker = api_taker
                self.account_maker = api_maker if api_maker > 0 else api_taker
            else:
                print(
                    "FEE WARN: API says 0 — keeping conservative measured default "
                    f"{self.account_taker*100:.3f}%/side until first fill",
                    flush=True,
                )
            rt = self.account_taker * 2.0 * 100.0
            min_tp = float(self.state.get("min_tp_pct") or 0.35)
            need = rt + 0.15
            if min_tp < need:
                self.state["min_tp_pct"] = round(need, 2)
                print(f"FEE WARN: raised min_tp_pct -> {self.state['min_tp_pct']}% (RT≈{rt:.3f}% + buffer)", flush=True)
            print(
                f"FEE EFFECTIVE | taker={self.account_taker*100:.3f}% RT≈{rt:.3f}% "
                f"min_tp={float(self.state['min_tp_pct']):.2f}%",
                flush=True,
            )
        except Exception as exc:  # noqa: BLE001
            print(f"FEE CHECK soft-fail (using defaults): {exc}", flush=True)

    async def _fee_from_order(self, order_id: str | None, fill_px: float, amount: float) -> str:
        if not order_id:
            return "fee=n/a"
        try:
            trades = await self.ex.fetch_my_trades(self.symbol, limit=8)
            hit = [t for t in trades if str(t.get("order") or "") == str(order_id)]
            if not hit and trades:
                hit = trades[:1]
            parts = []
            for t in hit[:3]:
                fee = t.get("fee") or {}
                cost = float(fee.get("cost") or 0)
                px = float(t.get("price") or fill_px or 0)
                amt = float(t.get("amount") or amount or 0)
                notional = px * amt
                pct = (cost / notional * 100.0) if notional > 0 else 0.0
                if pct > 0:
                    self.state["measured_taker_pct"] = round(pct, 4)
                    self.account_taker = pct / 100.0
                parts.append(
                    f"tradeFee={cost} {fee.get('currency')} ({pct:.3f}%) "
                    f"price={px} amt={amt}"
                )
            return " | ".join(parts) if parts else "fee=n/a"
        except Exception as exc:  # noqa: BLE001
            return f"fee_lookup_fail={exc}"

    async def setup(self) -> None:
        await self._sync_clock()
        await self.ex.load_markets()
        if self.symbol not in self.ex.markets:
            raise RuntimeError(f"Unknown MEXC symbol: {self.symbol}")
        self.market = self.ex.markets[self.symbol]
        self.settle = str(self.market.get("settle") or self.settle).upper()
        await self._log_account_fees()
        for position_type in (1, 2):  # 1=long, 2=short
            try:
                await self.ex.set_leverage(
                    1,
                    self.symbol,
                    params={"openType": 2, "positionType": position_type},
                )
            except Exception as exc:  # noqa: BLE001
                print(f"set_leverage soft-fail posType={position_type}: {exc}", flush=True)
        try:
            await self.ex.set_margin_mode("cross", self.symbol)
        except Exception:
            pass

    async def close(self) -> None:
        await self.ex.close()

    async def free_margin(self) -> float:
        """Free balance in settle coin (USDC/USDT) from contract wallet."""
        try:
            raw = await self.ex.contractPrivateGetAccountAssetCurrency({"currency": self.settle})
            data = raw.get("data") or {}
            return float(data.get("availableBalance") or data.get("availableCash") or 0)
        except Exception:
            bal = await self.ex.fetch_balance()
            free = bal.get(self.settle) or {}
            return float(free.get("free") or bal.get("free", {}).get(self.settle) or 0)

    async def mark(self) -> dict[str, float]:
        t = await self.ex.fetch_ticker(self.symbol)
        last = float(t.get("last") or 0)
        bid = float(t.get("bid") or last)
        ask = float(t.get("ask") or last)
        return {"last": last, "bid": bid, "ask": ask}

    async def in_buy_zone(self) -> dict[str, Any]:
        ohlcv = await self.ex.fetch_ohlcv(self.symbol, "15m", limit=int(self.state.get("range_lookback") or 40))
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
        px = m["bid"] if side == "long" else m["ask"]
        pnl_pct = ((px - entry) / entry) * 100.0 if side == "long" else ((entry - px) / entry) * 100.0
        min_tp = float(self.state.get("min_tp_pct") or 0.35)
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
        order = await self.ex.create_order(
            self.symbol, "market", close_side, amount, params={"reduceOnly": True, "openType": 2}
        )
        fill = float(order.get("average") or order.get("price") or px)
        csize = float((self.market or {}).get("contractSize") or 1)
        realized = (fill - entry) * amount * csize if side == "long" else (entry - fill) * amount * csize
        fee_txt = await self._fee_from_order(str(order.get("id") or ""), fill, amount)
        self.state["realized_pnl_usdt"] = float(self.state.get("realized_pnl_usdt") or 0) + realized
        self.state["open"] = None
        self.state["last_close_at"] = _utcnow()
        save_state(self.state)
        return (
            f"CLOSE {action} pnl≈{realized:+.4f} {self.settle} ({reason}) "
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

        free = await self.free_margin()
        target = float(self.state.get("target_notional_usdt") or 9.0)
        if free < max(3.0, target * 0.5):
            return f"skip: {self.settle} free={free:.2f} need≈{target:.2f}"

        m = await self.mark()
        px = m["ask"]
        if px <= 0:
            return "skip: bad price"
        csize = float((self.market or {}).get("contractSize") or 1)
        # notional ≈ contracts * price * contractSize
        notional = min(target, free * 0.90)
        contracts = max(1.0, int(notional / (px * csize)))
        notional = contracts * px * csize
        if notional > free * 0.95:
            contracts = max(1.0, int((free * 0.85) / (px * csize)))
            notional = contracts * px * csize

        if not self.live:
            self.state["open"] = {
                "id": str(uuid.uuid4())[:8],
                "side": "long",
                "contracts": contracts,
                "entry": px,
                "notional_usdt": notional,
                "opened_at": _utcnow(),
                "mode": "paper",
                "symbol": self.symbol,
            }
            self.state["last_open_at"] = _utcnow()
            save_state(self.state)
            return f"PAPER open long {contracts} @ {px} (~{notional:.2f} {self.settle})"

        try:
            await self.ex.set_leverage(1, self.symbol, params={"openType": 2, "positionType": 1})
        except Exception:
            pass
        order = await self.ex.create_order(self.symbol, "market", "buy", contracts, params={"openType": 2})
        fill = float(order.get("average") or order.get("price") or px)
        filled_amt = float(order.get("amount") or contracts)
        fee_txt = await self._fee_from_order(str(order.get("id") or ""), fill, filled_amt)
        est_fee = filled_amt * fill * csize * self.account_taker
        self.state["open"] = {
            "id": str(uuid.uuid4())[:8],
            "side": "long",
            "contracts": filled_amt,
            "entry": fill,
            "notional_usdt": filled_amt * fill * csize,
            "opened_at": _utcnow(),
            "order_id": order.get("id"),
            "mode": "live",
            "symbol": self.symbol,
            "est_open_fee_usdt": est_fee,
        }
        self.state["last_open_at"] = _utcnow()
        save_state(self.state)
        return (
            f"OPEN long {filled_amt} @ {fill} (~{filled_amt * fill * csize:.2f} {self.settle}) "
            f"id={order.get('id')} est_fee≈{est_fee:.4f} {fee_txt}"
        )

    async def tick(self) -> str:
        # Re-sync each loop: VM clock jumps invalidate a stale timeDifference (MEXC 602).
        await self._sync_clock()
        free = await self.free_margin()
        m = await self.mark()
        managed = await self.manage()
        opened = "—"
        if not self.state.get("open"):
            opened = await self.maybe_open()
        save_state(self.state)
        return (
            f"[{'LIVE' if self.live else 'PAPER'}] {self.symbol} {self.settle}={free:.2f} "
            f"mark={m['last']:.6g} | {managed} | {opened} | "
            f"realized={float(self.state.get('realized_pnl_usdt') or 0):+.4f}"
        )


async def main() -> None:
    _load_env()
    interval = int(os.environ.get("MEXC_LOOP_SEC", "60"))
    bot = MexcCadSwing()
    await bot.setup()
    print(
        f"MEXC swing trial | symbol={bot.symbol} | live={bot.live} | lev=1 | "
        f"tp>={bot.state['min_tp_pct']}% | notional≈{bot.state['target_notional_usdt']} {bot.settle}",
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
