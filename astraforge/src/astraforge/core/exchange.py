"""Async CCXT exchange wrapper for Binance Futures / Bybit (paper & live)."""

from __future__ import annotations

from typing import Any

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
    bids = (raw.get("bids") or [])[:depth]
    asks = (raw.get("asks") or [])[:depth]
    bid_vol = sum(float(x[1]) for x in bids) if bids else 0.0
    ask_vol = sum(float(x[1]) for x in asks) if asks else 0.0
    best_bid = float(bids[0][0]) if bids else 0.0
    best_ask = float(asks[0][0]) if asks else 0.0
    mid = (best_bid + best_ask) / 2 if best_bid and best_ask else 0.0
    spread = (best_ask - best_bid) if best_bid and best_ask else 0.0
    spread_bps = (spread / mid * 10_000) if mid else 0.0
    total = bid_vol + ask_vol
    imbalance = ((bid_vol - ask_vol) / total) if total > 0 else 0.0
    # Simple wall detection: largest level vs average
    def _wall(levels: list) -> dict[str, float] | None:
        if not levels:
            return None
        sizes = [float(x[1]) for x in levels]
        avg = sum(sizes) / len(sizes)
        idx = max(range(len(sizes)), key=lambda i: sizes[i])
        if sizes[idx] >= avg * 2.5:
            return {"price": float(levels[idx][0]), "size": sizes[idx]}
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
        "imbalance": round(imbalance, 4),  # + = more bids (buy pressure)
        "pressure": pressure,
        "bid_wall": _wall(bids),
        "ask_wall": _wall(asks),
        "top_bids": [[float(p), float(s)] for p, s in bids[:5]],
        "top_asks": [[float(p), float(s)] for p, s in asks[:5]],
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

        # Paper ledger (used when testnet unavailable or for local sim)
        self._paper_equity = settings.paper_starting_equity
        self._paper_positions: dict[str, dict[str, Any]] = {}
        self._paper_realized_today = 0.0

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
            "kraken": ccxt.krakenfutures,
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
        # Kraken Futures uses USD-margined linear perps by default
        if exchange_id == "kraken":
            params["options"] = {"defaultType": "future"}

        self._exchange = cls(params)

        if self.is_paper:
            # Prefer testnet / sandbox
            try:
                self._exchange.set_sandbox_mode(True)
                logger.info("exchange_sandbox_enabled", exchange=exchange_id)
            except Exception as exc:  # noqa: BLE001
                logger.warning("sandbox_mode_failed", error=str(exc))

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

    async def fetch_balance_raw(self) -> dict[str, Any]:
        if not self._exchange:
            return {}
        try:
            return await self._exchange.fetch_balance()
        except Exception as exc:  # noqa: BLE001
            logger.error("fetch_balance_failed", error=str(exc))
            await self.breaker.trip(BreakerReason.API_ERROR, detail=str(exc))
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
        positions = await self.fetch_positions()
        unrealized = sum(p.unrealized_pnl for p in positions)

        if self.is_paper and (not self._exchange or not self._markets_loaded):
            equity = self._paper_equity + unrealized
            available = max(0.0, self._paper_equity - sum(p.notional / max(p.leverage, 1) for p in positions))
            peak = max(peak_equity, equity)
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

        bal = await self.fetch_balance_raw()
        total = 0.0
        free = 0.0
        if bal:
            # Binance/Bybit → USDT; Kraken Futures → USD (fallback to USDT)
            quote = bal.get("USD") or bal.get("USDT") or {}
            total = float(
                quote.get("total")
                or bal.get("total", {}).get("USD")
                or bal.get("total", {}).get("USDT")
                or 0
            )
            free = float(
                quote.get("free")
                or bal.get("free", {}).get("USD")
                or bal.get("free", {}).get("USDT")
                or 0
            )

        if total <= 0 and self.is_paper:
            total = self._paper_equity + unrealized
            free = max(0.0, self._paper_equity)

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

    async def set_leverage(self, symbol: str, leverage: float) -> None:
        if not self._exchange or self.is_paper and not self._markets_loaded:
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
        """Place a market order. In pure paper mode, update local ledger."""
        order_params = dict(params or {})
        if reduce_only:
            order_params["reduceOnly"] = True

        if self.is_paper and (not self._exchange or not self._markets_loaded):
            return await self._paper_fill(symbol, side, amount, reduce_only=reduce_only)

        assert self._exchange is not None
        try:
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
            if "margin" in err or "insufficient" in err:
                await self.breaker.trip(BreakerReason.MARGIN_CALL, detail=str(exc))
            else:
                await self.breaker.trip(BreakerReason.API_ERROR, detail=str(exc))
            raise

    async def close_position(self, symbol: str) -> dict[str, Any] | None:
        positions = await self.fetch_positions()
        target = next((p for p in positions if p.symbol == symbol), None)
        if not target:
            return None
        side = "sell" if target.side == Side.LONG else "buy"
        return await self.create_market_order(
            symbol, side, target.size, reduce_only=True
        )

    async def close_all_positions(self) -> list[dict[str, Any]]:
        results: list[dict[str, Any]] = []
        for pos in await self.fetch_positions():
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
