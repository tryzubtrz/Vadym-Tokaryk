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

        await self.exchange.set_leverage(symbol, decision.leverage)
        if self.exchange.is_paper:
            self.exchange.set_paper_leverage(symbol, decision.leverage)

        try:
            order = await self.exchange.create_market_order(symbol, side, amount)
        except Exception as exc:  # noqa: BLE001
            return {"ok": False, "reason": str(exc)}

        fill_price = float(order.get("average") or order.get("price") or price)
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
        else:
            try:
                order = await self.exchange.close_position(symbol)
            except Exception as exc:  # noqa: BLE001
                return {"ok": False, "reason": str(exc)}
            if order is None:
                return {"ok": False, "reason": "close_failed"}

        await self.state.record_trade(
            TradeRecord(
                symbol=symbol,
                side=pos.side.value,
                action=decision.action.value,
                size=float(order.get("amount") or pos.size),
                price=float(order.get("average") or order.get("price") or pos.mark_price),
                leverage=pos.leverage,
                pnl=float(order.get("pnl") or 0),
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
            "reasoning": decision.reasoning,
        }

    async def emergency_flatten(self) -> list[dict[str, Any]]:
        """Close everything — used by /emergency_stop."""
        logger.warning("emergency_flatten")
        return await self.exchange.close_all_positions()
