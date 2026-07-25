"""Async CCXT exchange wrapper for Binance Futures / Bybit (paper & live)."""

from __future__ import annotations

from typing import Any

import asyncio

import ccxt.async_support as ccxt

from astraforge.core.circuit_breaker import BreakerReason, CircuitBreaker, circuit_breaker
from astraforge.core.config import Settings
from astraforge.core.models import (
    AccountSnapshot,
    PositionInfo,
    Side,
    TradingMode,
)
from astraforge.utils.logging import get_logger

logger = get_logger(__name__)


def summarize_order_book(raw: dict[str, Any], depth: int = 10) -> dict[str, Any]:
    """Compress an L2 book into signals an LLM can reason about."""

    def _level(item: Any) -> tuple[float, float] | None:
        try:
            # CCXT usually [price, amount]; some venues add extra fields
            price = float(item[0])
            amount = float(item[1])
            return price, amount
        except Exception:  # noqa: BLE001
            return None

    bids_raw = (raw.get("bids") or [])[:depth]
    asks_raw = (raw.get("asks") or [])[:depth]
    bids = [lvl for lvl in (_level(x) for x in bids_raw) if lvl]
    asks = [lvl for lvl in (_level(x) for x in asks_raw) if lvl]
    bid_vol = sum(a for _, a in bids) if bids else 0.0
    ask_vol = sum(a for _, a in asks) if asks else 0.0
    best_bid = bids[0][0] if bids else 0.0
    best_ask = asks[0][0] if asks else 0.0
    mid = (best_bid + best_ask) / 2 if best_bid and best_ask else 0.0
    spread = (best_ask - best_bid) if best_bid and best_ask else 0.0
    spread_bps = (spread / mid * 10_000) if mid else 0.0
    total = bid_vol + ask_vol
    imbalance = ((bid_vol - ask_vol) / total) if total > 0 else 0.0

    def _wall(levels: list[tuple[float, float]]) -> dict[str, float] | None:
        if not levels:
            return None
        sizes = [a for _, a in levels]
        avg = sum(sizes) / len(sizes)
        idx = max(range(len(sizes)), key=lambda i: sizes[i])
        if sizes[idx] >= avg * 2.5:
            return {"price": levels[idx][0], "size": sizes[idx]}
        return None

    pressure = "neutral"
    if imbalance > 0.15:
        pressure = "bid_heavy"
    elif imbalance < -0.15:
        pressure = "ask_heavy"

    return {
        "best_bid": best_bid,
        "best_ask": best_ask,
        "mid": mid,
        "spread": spread,
        "spread_bps": round(spread_bps, 2),
        "bid_volume": round(bid_vol, 4),
        "ask_volume": round(ask_vol, 4),
        "imbalance": round(imbalance, 4),
        "pressure": pressure,
        "bid_wall": _wall(bids),
        "ask_wall": _wall(asks),
        "top_bids": [[p, a] for p, a in bids[:5]],
        "top_asks": [[p, a] for p, a in asks[:5]],
    }


class ExchangeClient:
    """Thin async wrapper around CCXT with paper-mode simulation fallback."""

    def __init__(
        self,
        settings: Settings,
        breaker: CircuitBreaker | None = None,
    ) -> None:
        self.settings = settings
        self.breaker = breaker or circuit_breaker
        self._exchange: ccxt.Exchange | None = None
        self._markets_loaded = False

        # Paper ledger (local simulation — never sends live orders in paper mode)
        self._paper_equity = settings.paper_starting_equity
        self._paper_positions: dict[str, dict[str, Any]] = {}
        self._paper_realized_today = 0.0
        # Spot cost basis: symbol -> {"entry": avg_price, "size": qty}
        self._spot_cost_basis: dict[str, dict[str, float]] = {}
        self._private_lock = asyncio.Lock()
        self._last_private_ts = 0.0

    @property
    def mode(self) -> TradingMode:
        return self.settings.trading_mode

    @property
    def is_paper(self) -> bool:
        return self.settings.is_paper

    async def connect(self) -> None:
        """Instantiate and authenticate the CCXT client."""
        exchange_id = self.settings.exchange_id
        class_map = {
            "binance": ccxt.binanceusdm,
            "bybit": ccxt.bybit,
            "kraken": ccxt.kraken,  # Spot (Kraken Pro)
            "kraken_futures": ccxt.krakenfutures,
        }
        cls = class_map.get(exchange_id)
        if cls is None:
            raise ValueError(f"Unsupported exchange: {exchange_id}")

        params: dict[str, Any] = {
            "apiKey": self.settings.exchange_api_key or None,
            "secret": self.settings.exchange_api_secret or None,
            "enableRateLimit": True,
            "options": {"defaultType": "swap"},
        }
        if exchange_id == "kraken":
            params["options"] = {
                "defaultType": "spot",
                # Reduce Invalid nonce races on busy private endpoints
                "adjustForTimeDifference": True,
            }
            params["enableRateLimit"] = True
            params["rateLimit"] = 350
        elif exchange_id == "kraken_futures":
            params["options"] = {"defaultType": "future"}

        self._exchange = cls(params)

        # Spot has no useful public sandbox with these keys — stay on live markets
        # but paper mode still uses local ledger for orders unless LIVE confirmed.
        if self.is_paper and exchange_id not in {"kraken"}:
            try:
                self._exchange.set_sandbox_mode(True)
                logger.info("exchange_sandbox_enabled", exchange=exchange_id)
            except Exception as exc:  # noqa: BLE001
                logger.warning("sandbox_mode_failed", error=str(exc))
        elif self.is_paper and exchange_id == "kraken":
            logger.info("kraken_spot_paper_uses_live_market_data_local_orders")

        try:
            await self._exchange.load_markets()
            self._markets_loaded = True
            logger.info(
                "exchange_connected",
                exchange=exchange_id,
                mode=self.mode.value,
                markets=len(self._exchange.markets or {}),
            )
        except Exception as exc:  # noqa: BLE001
            logger.error("exchange_connect_failed", error=str(exc))
            if self.is_paper:
                logger.warning("falling_back_to_local_paper_ledger")
            else:
                await self.breaker.trip(BreakerReason.API_ERROR, detail=str(exc))
                raise

    async def close(self) -> None:
        if self._exchange:
            await self._exchange.close()
            self._exchange = None

    async def fetch_ohlcv(
        self,
        symbol: str,
        timeframe: str = "15m",
        limit: int = 100,
    ) -> list[list[float]]:
        if not self._exchange or not self._markets_loaded:
            return self._synthetic_ohlcv(limit)
        try:
            return await self._exchange.fetch_ohlcv(symbol, timeframe=timeframe, limit=limit)
        except Exception as exc:  # noqa: BLE001
            logger.warning("fetch_ohlcv_failed", symbol=symbol, error=str(exc))
            await self.breaker.trip(BreakerReason.API_ERROR, detail=f"OHLCV {symbol}: {exc}")
            return []

    async def fetch_ticker(self, symbol: str) -> dict[str, Any]:
        if not self._exchange or not self._markets_loaded:
            return {"symbol": symbol, "last": 0.0}
        try:
            return await self._exchange.fetch_ticker(symbol)
        except Exception as exc:  # noqa: BLE001
            logger.warning("fetch_ticker_failed", symbol=symbol, error=str(exc))
            await self.breaker.trip(BreakerReason.API_ERROR, detail=f"ticker {symbol}: {exc}")
            return {"symbol": symbol, "last": 0.0}

    async def fetch_order_book(self, symbol: str, limit: int = 20) -> dict[str, Any]:
        """Fetch L2 order book and return a compact summary for the LLM brain."""
        if not self._exchange or not self._markets_loaded:
            return self._synthetic_order_book()
        try:
            raw = await self._exchange.fetch_order_book(symbol, limit=limit)
            return summarize_order_book(raw)
        except Exception as exc:  # noqa: BLE001
            logger.warning("fetch_order_book_failed", symbol=symbol, error=str(exc))
            # Order book failure should not always halt trading — return empty summary
            return {"error": str(exc), "imbalance": 0.0}

    @staticmethod
    def _synthetic_order_book() -> dict[str, Any]:
        mid = 50_000.0
        bids = [[mid - i * 5, 1.0 + i * 0.1] for i in range(1, 11)]
        asks = [[mid + i * 5, 1.0 + i * 0.1] for i in range(1, 11)]
        return summarize_order_book({"bids": bids, "asks": asks})

    async def _private_gate(self) -> None:
        """Serialize Kraken private calls to reduce Invalid nonce races."""
        async with self._private_lock:
            now = asyncio.get_event_loop().time()
            wait = 0.55 - (now - self._last_private_ts)
            if wait > 0:
                await asyncio.sleep(wait)
            self._last_private_ts = asyncio.get_event_loop().time()

    async def fetch_balance_raw(self) -> dict[str, Any]:
        if not self._exchange:
            return {}
        last_exc: Exception | None = None
        for attempt in range(5):
            try:
                await self._private_gate()
                await asyncio.sleep(0.25 * attempt)
                return await self._exchange.fetch_balance()
            except Exception as exc:  # noqa: BLE001
                last_exc = exc
                err = str(exc).lower()
                if "nonce" in err and attempt < 4:
                    logger.warning("balance_nonce_retry", attempt=attempt + 1)
                    await asyncio.sleep(0.8 * (attempt + 1))
                    continue
                logger.error("fetch_balance_failed", error=str(exc))
                if "nonce" in err:
                    return {}
                await self.breaker.trip(BreakerReason.API_ERROR, detail=str(exc))
                return {}
        if last_exc:
            logger.error("fetch_balance_failed", error=str(last_exc))
        return {}

    async def fetch_positions(self) -> list[PositionInfo]:
        if self.is_paper and (not self._exchange or not self._markets_loaded):
            return self._paper_position_infos()

        if not self._exchange:
            return self._paper_position_infos() if self.is_paper else []

        try:
            raw = await self._exchange.fetch_positions()
            positions: list[PositionInfo] = []
            for p in raw or []:
                contracts = float(p.get("contracts") or p.get("contractSize") or 0)
                if abs(contracts) < 1e-12:
                    # also check notional
                    notional = float(p.get("notional") or 0)
                    if abs(notional) < 1e-8:
                        continue
                side_raw = (p.get("side") or "").lower()
                if side_raw not in ("long", "short"):
                    side_raw = "long" if contracts >= 0 else "short"
                positions.append(
                    PositionInfo(
                        symbol=str(p.get("symbol") or ""),
                        side=Side.LONG if side_raw == "long" else Side.SHORT,
                        size=abs(float(p.get("contracts") or 0)),
                        entry_price=float(p.get("entryPrice") or 0),
                        mark_price=float(p.get("markPrice") or p.get("entryPrice") or 0),
                        unrealized_pnl=float(p.get("unrealizedPnl") or 0),
                        leverage=float(p.get("leverage") or 1),
                        notional=abs(float(p.get("notional") or 0)),
                        liquidation_price=(
                            float(p["liquidationPrice"])
                            if p.get("liquidationPrice") not in (None, "")
                            else None
                        ),
                    )
                )
            if self.is_paper and not positions and self._paper_positions:
                return self._paper_position_infos()
            return positions
        except Exception as exc:  # noqa: BLE001
            logger.error("fetch_positions_failed", error=str(exc))
            if "margin" in str(exc).lower():
                await self.breaker.trip(BreakerReason.MARGIN_CALL, detail=str(exc))
            else:
                await self.breaker.trip(BreakerReason.API_ERROR, detail=str(exc))
            return self._paper_position_infos() if self.is_paper else []

    async def get_account_snapshot(self, peak_equity: float = 0.0) -> AccountSnapshot:
        # Paper mode: always use simulated ledger + live marks when possible
        if self.is_paper:
            positions = self._paper_position_infos()
            # refresh marks from tickers
            for p in positions:
                try:
                    t = await self.fetch_ticker(p.symbol)
                    price = float(t.get("last") or t.get("close") or p.mark_price or p.entry_price)
                    if p.symbol in self._paper_positions:
                        self._paper_positions[p.symbol]["mark"] = price
                        d = 1 if self._paper_positions[p.symbol]["side"] == "long" else -1
                        self._paper_positions[p.symbol]["upnl"] = (
                            (price - self._paper_positions[p.symbol]["entry"])
                            * self._paper_positions[p.symbol]["size"]
                            * d
                        )
                except Exception:  # noqa: BLE001
                    pass
            positions = self._paper_position_infos()
            unrealized = sum(p.unrealized_pnl for p in positions)
            equity = self._paper_equity + unrealized
            available = max(
                0.0,
                self._paper_equity
                - sum(p.notional / max(p.leverage, 1) for p in positions),
            )
            peak = max(peak_equity, equity, self._paper_equity)
            dd = ((peak - equity) / peak * 100.0) if peak > 0 else 0.0
            return AccountSnapshot(
                equity=equity,
                available_balance=available,
                used_margin=equity - available,
                unrealized_pnl=unrealized,
                realized_pnl_today=self._paper_realized_today,
                peak_equity=peak,
                drawdown_pct=dd,
                positions=positions,
                mode=TradingMode.PAPER,
            )

        # Live mode
        if self.settings.is_spot:
            positions = await self._spot_positions_from_balance()
        else:
            positions = await self.fetch_positions()
        unrealized = sum(p.unrealized_pnl for p in positions)

        bal = await self.fetch_balance_raw()
        total = 0.0
        free = 0.0
        if bal:
            quote = bal.get("USD") or bal.get("USDT") or {}
            free = float(
                quote.get("free")
                or bal.get("free", {}).get("USD")
                or bal.get("free", {}).get("USDT")
                or 0
            )
            total = float(
                quote.get("total")
                or bal.get("total", {}).get("USD")
                or bal.get("total", {}).get("USDT")
                or free
            )
            if self.settings.is_spot:
                # Cash + crypto mark-to-market (CAD converted via USD/CAD)
                eq = 0.0
                totals = bal.get("total") or {}
                cad_usd = 0.0
                try:
                    t = await self.fetch_ticker("USD/CAD")
                    px = float(t.get("last") or 0)
                    if px > 0:
                        cad_usd = 1.0 / px
                except Exception:  # noqa: BLE001
                    cad_usd = 0.0
                for asset, amt in totals.items():
                    a = float(amt or 0)
                    if a <= 0:
                        continue
                    if asset in {"USD", "USDT", "USDC", "ZUSD"}:
                        eq += a
                        continue
                    if asset == "CAD":
                        eq += a * cad_usd if cad_usd > 0 else a * 0.7
                        continue
                    if asset in {"EUR", "GBP"}:
                        # rough mark via /USD pair when available
                        sym = f"{asset}/USD"
                        if self._exchange and sym in (self._exchange.markets or {}):
                            try:
                                t = await self.fetch_ticker(sym)
                                px = float(t.get("last") or 0)
                                eq += a * px
                                continue
                            except Exception:  # noqa: BLE001
                                pass
                        eq += a
                        continue
                    sym = f"{asset}/USD"
                    if self._exchange and sym in (self._exchange.markets or {}):
                        try:
                            t = await self.fetch_ticker(sym)
                            px = float(t.get("last") or 0)
                            eq += a * px
                        except Exception:  # noqa: BLE001
                            pass
                if eq > 0:
                    total = eq

        # If private balance failed (nonce), keep last known peak as soft equity floor
        if total <= 0 and peak_equity > 0:
            total = peak_equity
            free = max(free, 0.0)

        peak = max(peak_equity, total)
        dd = ((peak - total) / peak * 100.0) if peak > 0 else 0.0

        return AccountSnapshot(
            equity=total,
            available_balance=free,
            used_margin=max(0.0, total - free),
            unrealized_pnl=unrealized,
            realized_pnl_today=self._paper_realized_today,
            peak_equity=peak,
            drawdown_pct=dd,
            positions=positions,
            mode=self.mode,
        )

    def set_spot_cost_basis(self, basis: dict[str, dict[str, float]]) -> None:
        """Restore / replace spot average entries (survives process restarts via state)."""
        self._spot_cost_basis = {
            str(sym): {
                "entry": float(v.get("entry") or 0),
                "size": float(v.get("size") or 0),
            }
            for sym, v in (basis or {}).items()
            if float((v or {}).get("entry") or 0) > 0
        }

    def get_spot_cost_basis(self) -> dict[str, dict[str, float]]:
        return {k: dict(v) for k, v in self._spot_cost_basis.items()}

    def update_spot_cost_basis_fill(
        self,
        symbol: str,
        *,
        side: str,
        amount: float,
        price: float,
    ) -> None:
        """Maintain VWAP entry for spot inventory after buys/sells."""
        if amount <= 0 or price <= 0:
            return
        cur = self._spot_cost_basis.get(symbol)
        if side == "buy":
            if cur and cur.get("size", 0) > 0:
                total = cur["size"] + amount
                cur["entry"] = (cur["entry"] * cur["size"] + price * amount) / total
                cur["size"] = total
            else:
                self._spot_cost_basis[symbol] = {"entry": price, "size": amount}
            return
        # sell / close
        if not cur:
            return
        left = cur["size"] - amount
        if left <= 1e-12:
            self._spot_cost_basis.pop(symbol, None)
        else:
            cur["size"] = left

    async def _spot_positions_from_balance(self) -> list[PositionInfo]:
        """Treat non-fiat crypto balances as long spot positions."""
        bal = await self.fetch_balance_raw()
        totals = bal.get("total") or {}
        out: list[PositionInfo] = []
        skip = {"USD", "USDT", "USDC", "EUR", "ZUSD", "GBP", "CAD"}
        for asset, amt in totals.items():
            qty = float(amt or 0)
            if qty <= 0 or asset in skip:
                continue
            symbol = f"{asset}/USD"
            if self._exchange and symbol not in (self._exchange.markets or {}):
                continue
            try:
                t = await self.fetch_ticker(symbol)
                px = float(t.get("last") or 0)
            except Exception:  # noqa: BLE001
                continue
            if px <= 0 or qty * px < 0.4:
                continue
            basis = self._spot_cost_basis.get(symbol) or {}
            entry = float(basis.get("entry") or 0) or px
            # Keep size in basis loosely in sync with exchange balance
            if basis:
                basis["size"] = qty
            upnl = (px - entry) * qty
            out.append(
                PositionInfo(
                    symbol=symbol,
                    side=Side.LONG,
                    size=qty,
                    entry_price=entry,
                    mark_price=px,
                    unrealized_pnl=upnl,
                    leverage=1.0,
                    notional=qty * px,
                )
            )
        return out

    async def set_leverage(self, symbol: str, leverage: float) -> None:
        if self.is_paper or not self._exchange:
            return
        if self.settings.is_spot:
            return
        try:
            await self._exchange.set_leverage(int(leverage), symbol)
        except Exception as exc:  # noqa: BLE001
            logger.warning("set_leverage_failed", symbol=symbol, error=str(exc))

    async def create_market_order(
        self,
        symbol: str,
        side: str,
        amount: float,
        *,
        reduce_only: bool = False,
        params: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Place a market order. Paper mode NEVER hits the live order endpoint."""
        order_params = dict(params or {})
        # Kraken spot does not use reduceOnly the same way as futures
        if reduce_only and not self.settings.is_spot:
            order_params["reduceOnly"] = True

        # Hard rule: paper/sim always uses local ledger (even if markets are loaded).
        if self.is_paper:
            return await self._paper_fill(symbol, side, amount, reduce_only=reduce_only)

        assert self._exchange is not None
        try:
            # Respect exchange amount precision / minimums when live
            try:
                amount = float(self._exchange.amount_to_precision(symbol, amount))
            except Exception:  # noqa: BLE001
                pass
            market = (self._exchange.markets or {}).get(symbol) or {}
            min_amt = float(((market.get("limits") or {}).get("amount") or {}).get("min") or 0)
            if min_amt and amount < min_amt:
                raise ValueError(
                    f"Order amount {amount} below exchange minimum {min_amt} for {symbol}"
                )
            await self._private_gate()
            order = await self._exchange.create_order(
                symbol,
                "market",
                side,
                amount,
                None,
                order_params,
            )
            logger.info(
                "order_placed",
                symbol=symbol,
                side=side,
                amount=amount,
                reduce_only=reduce_only,
                id=order.get("id"),
            )
            return order
        except Exception as exc:  # noqa: BLE001
            logger.error("order_failed", error=str(exc), symbol=symbol, side=side)
            err = str(exc).lower()
            if "minimum" in err or "invalid arguments" in err or "volume" in err:
                raise
            if "nonce" in err:
                last: Exception = exc
                for retry in range(3):
                    await asyncio.sleep(0.7 * (retry + 1))
                    try:
                        await self._private_gate()
                        order = await self._exchange.create_order(
                            symbol, "market", side, amount, None, order_params
                        )
                        logger.info(
                            "order_placed_after_nonce_retry",
                            symbol=symbol,
                            id=order.get("id"),
                            retry=retry + 1,
                        )
                        return order
                    except Exception as exc2:  # noqa: BLE001
                        last = exc2
                        if "nonce" not in str(exc2).lower():
                            break
                logger.error("order_failed", error=str(last), symbol=symbol, side=side)
                raise last
            if "margin" in err or "insufficient" in err:
                await self.breaker.trip(BreakerReason.MARGIN_CALL, detail=str(exc))
            else:
                await self.breaker.trip(BreakerReason.API_ERROR, detail=str(exc))
            raise

    async def close_position(self, symbol: str) -> dict[str, Any] | None:
        if self.settings.is_spot and not self.is_paper:
            positions = await self._spot_positions_from_balance()
        else:
            positions = await self.fetch_positions()
            if self.settings.is_spot and not positions:
                positions = await self._spot_positions_from_balance()
        target = next((p for p in positions if p.symbol == symbol), None)
        if not target:
            return None
        side = "sell" if target.side == Side.LONG else "buy"
        order = await self.create_market_order(
            symbol, side, target.size, reduce_only=True
        )
        if self.settings.is_spot and not self.is_paper:
            fill = float(order.get("average") or order.get("price") or target.mark_price or 0)
            self.update_spot_cost_basis_fill(
                symbol, side=side, amount=target.size, price=fill or target.mark_price
            )
        return order

    async def close_all_positions(self) -> list[dict[str, Any]]:
        results: list[dict[str, Any]] = []
        if self.settings.is_spot and not self.is_paper:
            positions = await self._spot_positions_from_balance()
        else:
            positions = await self.fetch_positions()
            if self.settings.is_spot and not positions:
                positions = await self._spot_positions_from_balance()
        for pos in positions:
            try:
                order = await self.close_position(pos.symbol)
                if order:
                    results.append(order)
            except Exception as exc:  # noqa: BLE001
                logger.error("close_all_failed", symbol=pos.symbol, error=str(exc))
        if self.is_paper:
            self._paper_positions.clear()
        return results

    # --- Paper helpers ---
    def _paper_position_infos(self) -> list[PositionInfo]:
        out: list[PositionInfo] = []
        for sym, p in self._paper_positions.items():
            out.append(
                PositionInfo(
                    symbol=sym,
                    side=Side(p["side"]),
                    size=float(p["size"]),
                    entry_price=float(p["entry"]),
                    mark_price=float(p.get("mark", p["entry"])),
                    unrealized_pnl=float(p.get("upnl", 0.0)),
                    leverage=float(p.get("leverage", 1)),
                    notional=float(p["size"]) * float(p.get("mark", p["entry"])),
                )
            )
        return out

    async def _paper_fill(
        self,
        symbol: str,
        side: str,
        amount: float,
        *,
        reduce_only: bool = False,
    ) -> dict[str, Any]:
        ticker = await self.fetch_ticker(symbol)
        price = float(ticker.get("last") or ticker.get("close") or 0) or 1.0

        # Mark-to-market existing
        if symbol in self._paper_positions:
            pos = self._paper_positions[symbol]
            pos["mark"] = price
            direction = 1 if pos["side"] == "long" else -1
            pos["upnl"] = (price - pos["entry"]) * pos["size"] * direction

        if reduce_only or symbol in self._paper_positions:
            pos = self._paper_positions.get(symbol)
            if not pos:
                return {"id": "paper-noop", "symbol": symbol, "status": "canceled"}
            # Closing / reducing
            close_side_long = pos["side"] == "long" and side == "sell"
            close_side_short = pos["side"] == "short" and side == "buy"
            if close_side_long or close_side_short:
                qty = min(amount, pos["size"])
                direction = 1 if pos["side"] == "long" else -1
                pnl = (price - pos["entry"]) * qty * direction
                self._paper_equity += pnl
                self._paper_realized_today += pnl
                pos["size"] -= qty
                if pos["size"] <= 1e-12:
                    del self._paper_positions[symbol]
                else:
                    pos["upnl"] = (price - pos["entry"]) * pos["size"] * direction
                return {
                    "id": f"paper-{symbol}-close",
                    "symbol": symbol,
                    "side": side,
                    "amount": qty,
                    "price": price,
                    "status": "closed",
                    "pnl": pnl,
                }

        # Open / increase
        pos_side = "long" if side == "buy" else "short"
        existing = self._paper_positions.get(symbol)
        if existing and existing["side"] != pos_side:
            # Flip: close first
            await self._paper_fill(
                symbol,
                "sell" if existing["side"] == "long" else "buy",
                existing["size"],
                reduce_only=True,
            )
            existing = None

        if existing:
            total_size = existing["size"] + amount
            existing["entry"] = (
                (existing["entry"] * existing["size"] + price * amount) / total_size
            )
            existing["size"] = total_size
            existing["mark"] = price
        else:
            self._paper_positions[symbol] = {
                "side": pos_side,
                "size": amount,
                "entry": price,
                "mark": price,
                "leverage": 1.0,
                "upnl": 0.0,
            }

        return {
            "id": f"paper-{symbol}-open",
            "symbol": symbol,
            "side": side,
            "amount": amount,
            "price": price,
            "status": "closed",
        }

    def set_paper_leverage(self, symbol: str, leverage: float) -> None:
        if symbol in self._paper_positions:
            self._paper_positions[symbol]["leverage"] = leverage

    def _synthetic_ohlcv(self, limit: int) -> list[list[float]]:
        """Deterministic synthetic candles for offline paper without network."""
        import time

        now = int(time.time() * 1000)
        step = 15 * 60 * 1000
        price = 50_000.0
        rows: list[list[float]] = []
        for i in range(limit):
            ts = now - (limit - i) * step
            # mild oscillation
            drift = ((i % 20) - 10) * 15.0
            o = price + drift
            h = o * 1.001
            l = o * 0.999
            c = o + ((i % 7) - 3) * 5
            v = 100 + (i % 10) * 3
            rows.append([ts, o, h, l, c, v])
            price = c
        return rows
