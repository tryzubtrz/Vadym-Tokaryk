"""Execute validated trade decisions via the exchange client."""

from __future__ import annotations

from typing import Any

from astraforge.core.circuit_breaker import CircuitBreaker, circuit_breaker
from astraforge.core.exchange import ExchangeClient
from astraforge.core.models import (
    AccountSnapshot,
    ActionType,
    Side,
    TradeDecision,
    TradeRecord,
    TradingMode,
)
from astraforge.core.risk_manager import RiskManager
from astraforge.core.state_manager import StateManager
from astraforge.utils.logging import get_logger

logger = get_logger(__name__)


class OrderExecutor:
    """Translate TradeDecision → exchange orders after risk checks."""

    def __init__(
        self,
        exchange: ExchangeClient,
        risk: RiskManager,
        state: StateManager,
        breaker: CircuitBreaker | None = None,
    ) -> None:
        self.exchange = exchange
        self.risk = risk
        self.state = state
        self.breaker = breaker or circuit_breaker

    async def execute(
        self,
        decision: TradeDecision,
        account: AccountSnapshot,
    ) -> dict[str, Any]:
        """Validate and execute one decision. Returns result dict."""
        check = self.risk.validate_order(decision, account)
        if not check.allowed or check.adjusted_decision is None:
            logger.info(
                "order_rejected_by_risk",
                action=decision.action.value,
                reason=check.reason,
            )
            return {
                "ok": False,
                "rejected": True,
                "reason": check.reason,
                "decision": decision.model_dump(),
            }

        adj = check.adjusted_decision

        if adj.action == ActionType.HOLD:
            return {"ok": True, "action": "hold", "reasoning": adj.reasoning}

        if adj.action in (ActionType.CLOSE, ActionType.REDUCE):
            return await self._close_or_reduce(adj, account)

        if adj.action in (ActionType.OPEN_LONG, ActionType.OPEN_SHORT):
            return await self._open(adj, account)

        return {"ok": False, "reason": "unsupported_action"}

    async def _open(
        self,
        decision: TradeDecision,
        account: AccountSnapshot,
    ) -> dict[str, Any]:
        if not decision.symbol:
            return {"ok": False, "reason": "missing_symbol"}

        symbol = decision.symbol
        side = "buy" if decision.action == ActionType.OPEN_LONG else "sell"
        pos_side = Side.LONG if side == "buy" else Side.SHORT

        # Position notional = equity * size_pct%; contracts ≈ notional / price
        ticker = await self.exchange.fetch_ticker(symbol)
        price = float(ticker.get("last") or ticker.get("close") or 0)
        if price <= 0:
            return {"ok": False, "reason": "invalid_price"}

        notional = account.equity * (decision.size_pct_of_equity / 100.0)
        # With leverage, margin used is notional/leverage; we size by margin budget
        # Amount in base currency:
        amount = (notional * decision.leverage) / price
        if amount <= 0:
            return {"ok": False, "reason": "zero_amount"}

        # Lift to exchange minimum if still within max position budget (micro accounts)
        try:
            amount = await self._ensure_min_amount(symbol, amount, price, account)
        except ValueError as exc:
            return {"ok": False, "reason": str(exc)}

        await self.exchange.set_leverage(symbol, decision.leverage)
        if self.exchange.is_paper:
            self.exchange.set_paper_leverage(symbol, decision.leverage)

        try:
            order = await self.exchange.create_market_order(symbol, side, amount)
        except Exception as exc:  # noqa: BLE001
            return {"ok": False, "reason": str(exc)}

        fill_price = float(order.get("average") or order.get("price") or price)
        if self.exchange.settings.is_spot and not self.exchange.is_paper:
            self.exchange.update_spot_cost_basis_fill(
                symbol, side=side, amount=amount, price=fill_price
            )
            await self.state.set_kv(
                "spot_cost_basis", self.exchange.get_spot_cost_basis()
            )
        await self.state.record_trade(
            TradeRecord(
                symbol=symbol,
                side=pos_side.value,
                action=decision.action.value,
                size=amount,
                price=fill_price,
                leverage=decision.leverage,
                pnl=float(order.get("pnl") or 0),
                reasoning=decision.reasoning,
                mode=account.mode.value,
            )
        )
        logger.info(
            "position_opened",
            symbol=symbol,
            side=pos_side.value,
            amount=amount,
            leverage=decision.leverage,
        )
        return {
            "ok": True,
            "action": decision.action.value,
            "symbol": symbol,
            "amount": amount,
            "price": fill_price,
            "order": order,
            "reasoning": decision.reasoning,
        }

    async def _ensure_min_amount(
        self,
        symbol: str,
        amount: float,
        price: float,
        account: AccountSnapshot,
    ) -> float:
        """Bump size to exchange minimum when equity is small, without exceeding cash."""
        ex = self.exchange._exchange
        if not ex or symbol not in (ex.markets or {}):
            return amount
        market = ex.markets[symbol]
        min_amt = float(((market.get("limits") or {}).get("amount") or {}).get("min") or 0)
        min_cost = float(((market.get("limits") or {}).get("cost") or {}).get("min") or 0)
        need = amount
        if min_amt and need < min_amt:
            need = min_amt
        if min_cost and need * price < min_cost:
            need = min_cost / price
        # Cap by available cash (~95%) and max position ceiling
        max_pos = self.exchange.settings.effective_max_position_pct(account.equity)
        max_notional = account.equity * (max_pos / 100.0)
        cash_cap = max(0.0, account.available_balance * 0.95)
        cap = min(max_notional, cash_cap) if cash_cap > 0 else max_notional
        if need * price > cap and price > 0:
            need = cap / price
        if min_amt and need < min_amt:
            # Cannot meet exchange minimum within risk budget
            raise ValueError(
                f"Need ≥{min_amt} {symbol} (${min_amt*price:.2f}) but risk budget "
                f"allows only ~${cap:.2f}"
            )
        try:
            need = float(ex.amount_to_precision(symbol, need))
        except Exception:  # noqa: BLE001
            pass
        return need

    async def _close_or_reduce(
        self,
        decision: TradeDecision,
        account: AccountSnapshot,
    ) -> dict[str, Any]:
        symbol = decision.symbol
        if not symbol:
            # Close all if no symbol
            orders = await self.exchange.close_all_positions()
            await self.state.record_trade(
                TradeRecord(
                    symbol="ALL",
                    side="flat",
                    action="close_all",
                    size=0,
                    price=0,
                    leverage=1,
                    reasoning=decision.reasoning,
                    mode=account.mode.value,
                )
            )
            return {"ok": True, "action": "close_all", "orders": orders}

        pos = next((p for p in account.positions if p.symbol == symbol), None)
        if not pos:
            return {"ok": False, "reason": "no_position"}

        if decision.action == ActionType.REDUCE and decision.size_pct_of_equity > 0:
            # Reduce by fraction of position (reuse size_pct as % of position)
            frac = min(1.0, decision.size_pct_of_equity / 100.0)
            amount = pos.size * frac
            side = "sell" if pos.side == Side.LONG else "buy"
            try:
                order = await self.exchange.create_market_order(
                    symbol, side, amount, reduce_only=True
                )
            except Exception as exc:  # noqa: BLE001
                return {"ok": False, "reason": str(exc)}
            if self.exchange.settings.is_spot and not self.exchange.is_paper:
                fill = float(order.get("average") or order.get("price") or pos.mark_price)
                self.exchange.update_spot_cost_basis_fill(
                    symbol, side=side, amount=amount, price=fill
                )
                await self.state.set_kv(
                    "spot_cost_basis", self.exchange.get_spot_cost_basis()
                )
        else:
            try:
                order = await self.exchange.close_position(symbol)
            except Exception as exc:  # noqa: BLE001
                return {"ok": False, "reason": str(exc)}
            if order is None:
                return {"ok": False, "reason": "close_failed"}
            if self.exchange.settings.is_spot and not self.exchange.is_paper:
                await self.state.set_kv(
                    "spot_cost_basis", self.exchange.get_spot_cost_basis()
                )

        fill_price = float(order.get("average") or order.get("price") or pos.mark_price)
        fill_size = float(order.get("amount") or pos.size)
        realized = 0.0
        if pos.entry_price > 0 and fill_price > 0:
            direction = 1.0 if pos.side == Side.LONG else -1.0
            realized = (fill_price - pos.entry_price) * fill_size * direction

        await self.state.record_trade(
            TradeRecord(
                symbol=symbol,
                side=pos.side.value,
                action=decision.action.value,
                size=fill_size,
                price=fill_price,
                leverage=pos.leverage,
                pnl=float(order.get("pnl") or realized),
                reasoning=decision.reasoning,
                mode=account.mode.value
                if isinstance(account.mode, TradingMode)
                else str(account.mode),
            )
        )
        return {
            "ok": True,
            "action": decision.action.value,
            "symbol": symbol,
            "order": order,
            "pnl": float(order.get("pnl") or realized),
            "reasoning": decision.reasoning,
        }

    async def emergency_flatten(self) -> list[dict[str, Any]]:
        """Close everything — used by /emergency_stop."""
        logger.warning("emergency_flatten")
        orders = await self.exchange.close_all_positions()
        if self.exchange.settings.is_spot and not self.exchange.is_paper:
            await self.state.set_kv(
                "spot_cost_basis", self.exchange.get_spot_cost_basis()
            )
        return orders
