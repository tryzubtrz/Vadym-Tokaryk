"""Shared Pydantic models for AstraForge."""

from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Any, Literal

from pydantic import BaseModel, Field


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class TradingMode(str, Enum):
    PAPER = "paper"
    LIVE = "live"


class RiskProfile(str, Enum):
    CONSERVATIVE = "conservative"
    BALANCED = "balanced"
    AGGRESSIVE = "aggressive"


class Side(str, Enum):
    LONG = "long"
    SHORT = "short"


class ActionType(str, Enum):
    OPEN_LONG = "open_long"
    OPEN_SHORT = "open_short"
    CLOSE = "close"
    HOLD = "hold"
    REDUCE = "reduce"


class GoalType(str, Enum):
    PROFIT_USD = "profit_usd"
    PROFIT_PCT = "profit_pct"
    CLOSE_ALL = "close_all"
    STOP_TRADING = "stop_trading"
    STATUS = "status"
    SET_PROFILE = "set_profile"
    REPORT = "report"
    UNKNOWN = "unknown"


class TradingGoal(BaseModel):
    """User-defined profit / behaviour target."""

    goal_type: GoalType = GoalType.PROFIT_USD
    target_profit_usd: float | None = None
    target_profit_pct: float | None = None
    risk_profile: RiskProfile = RiskProfile.BALANCED
    period: Literal["day", "week", "custom"] = "day"
    raw_text: str = ""
    language: Literal["ru", "en"] = "ru"
    created_at: datetime = Field(default_factory=_utcnow)
    active: bool = True
    notes: str = ""


class PositionInfo(BaseModel):
    symbol: str
    side: Side
    size: float
    entry_price: float
    mark_price: float = 0.0
    unrealized_pnl: float = 0.0
    leverage: float = 1.0
    notional: float = 0.0
    liquidation_price: float | None = None


class AccountSnapshot(BaseModel):
    equity: float
    available_balance: float
    used_margin: float = 0.0
    unrealized_pnl: float = 0.0
    realized_pnl_today: float = 0.0
    peak_equity: float = 0.0
    drawdown_pct: float = 0.0
    positions: list[PositionInfo] = Field(default_factory=list)
    mode: TradingMode = TradingMode.PAPER
    timestamp: datetime = Field(default_factory=_utcnow)


class MarketSnapshot(BaseModel):
    symbol: str
    indicators: dict[str, Any] = Field(default_factory=dict)
    order_book: dict[str, Any] = Field(default_factory=dict)
    recent_candles: list[dict[str, float]] = Field(default_factory=list)
    timestamp: datetime = Field(default_factory=_utcnow)


class TradeDecision(BaseModel):
    """Strict JSON decision schema produced by the LLM agent."""

    action: ActionType
    symbol: str | None = None
    side: Side | None = None
    size_pct_of_equity: float = Field(default=0.0, ge=0.0, le=40.0)
    leverage: float = Field(default=1.0, ge=1.0, le=5.0)
    confidence: float = Field(default=0.0, ge=0.0, le=1.0)
    reasoning: str = ""
    stop_loss_pct: float | None = Field(default=None, ge=0.1, le=10.0)
    take_profit_pct: float | None = Field(default=None, ge=0.05, le=30.0)


class AgentDecisionBatch(BaseModel):
    decisions: list[TradeDecision] = Field(default_factory=list)
    goal_progress_note: str = ""
    risk_note: str = ""


class InterpretedGoal(BaseModel):
    """Output of GoalInterpreter."""

    understood: bool
    goal: TradingGoal | None = None
    reply_text: str
    is_aggressive: bool = False
    suggested_goal: TradingGoal | None = None
    language: Literal["ru", "en"] = "ru"


class BotStatus(BaseModel):
    running: bool = True
    trading_enabled: bool = True
    mode: TradingMode = TradingMode.PAPER
    circuit_breaker_active: bool = False
    circuit_breaker_reason: str | None = None
    daily_halted: bool = False
    current_goal: TradingGoal | None = None
    equity: float = 0.0
    pnl_today: float = 0.0
    goal_progress_pct: float = 0.0
    open_positions: int = 0
    last_decision_summary: str = ""
    risk_profile: RiskProfile = RiskProfile.BALANCED
    last_error: str | None = None


class TradeRecord(BaseModel):
    id: int | None = None
    symbol: str
    side: str
    action: str
    size: float
    price: float
    leverage: float
    pnl: float = 0.0
    reasoning: str = ""
    mode: str = "paper"
    created_at: datetime = Field(default_factory=_utcnow)


class EquityPoint(BaseModel):
    equity: float
    pnl_today: float = 0.0
    timestamp: datetime = Field(default_factory=_utcnow)
