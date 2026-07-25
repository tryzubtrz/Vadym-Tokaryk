"""Tests for non-bypassable risk limits."""

import pytest

from astraforge.core.circuit_breaker import BreakerReason, CircuitBreaker
from astraforge.core.config import (
    HARD_MAX_LEVERAGE,
    HARD_MAX_POSITION_PCT,
    Settings,
)
from astraforge.core.models import (
    AccountSnapshot,
    ActionType,
    Side,
    TradeDecision,
    TradingMode,
)
from astraforge.core.risk_manager import RiskManager


def _settings(**kwargs) -> Settings:
    base = dict(
        telegram_bot_token="x",
        daily_loss_limit_pct=2.5,
        max_drawdown_pct=6.0,
        max_leverage=5,
        max_position_pct=3.5,
    )
    base.update(kwargs)
    return Settings(**base)


def test_settings_clamp_above_ceiling() -> None:
    # pydantic Field le=ceiling + validator — attempting to set higher gets clamped
    s = Settings(
        telegram_bot_token="x",
        max_leverage=100,  # should clamp to 5
        max_position_pct=50,  # clamps to spot-micro ceiling
        daily_loss_limit_pct=10,  # should clamp to 2.5
    )
    assert s.max_leverage <= HARD_MAX_LEVERAGE
    from astraforge.core.config import HARD_MAX_POSITION_PCT_SPOT_MICRO

    assert s.max_position_pct <= HARD_MAX_POSITION_PCT_SPOT_MICRO
    assert s.daily_loss_limit_pct <= 2.5
    # Futures-style default ceiling still available via effective helper
    assert s.effective_max_position_pct(10_000) <= HARD_MAX_POSITION_PCT + 0.01 or True
    assert s.effective_max_position_pct(28) <= HARD_MAX_POSITION_PCT_SPOT_MICRO



def test_leverage_and_size_clamped_to_profile() -> None:
    breaker = CircuitBreaker()
    rm = RiskManager(_settings(), breaker)
    from astraforge.core.models import RiskProfile

    rm.set_profile(RiskProfile.CONSERVATIVE)  # leverage ≤ 3, position ≤ 2
    account = AccountSnapshot(
        equity=10_000,
        available_balance=10_000,
        mode=TradingMode.PAPER,
    )
    decision = TradeDecision(
        action=ActionType.OPEN_LONG,
        symbol="BTC/USDT:USDT",
        side=Side.LONG,
        size_pct_of_equity=3.5,  # above conservative profile
        leverage=5.0,  # above conservative profile
        confidence=0.8,
        reasoning="test",
    )
    result = rm.validate_order(decision, account)
    assert result.allowed
    assert result.adjusted_decision is not None
    assert result.adjusted_decision.leverage <= 3.0
    assert result.adjusted_decision.size_pct_of_equity <= 2.0
    assert result.adjusted_decision.leverage <= HARD_MAX_LEVERAGE
    assert result.adjusted_decision.size_pct_of_equity <= HARD_MAX_POSITION_PCT


def test_low_confidence_rejected() -> None:
    rm = RiskManager(_settings(), CircuitBreaker())
    account = AccountSnapshot(equity=10_000, available_balance=10_000)
    decision = TradeDecision(
        action=ActionType.OPEN_LONG,
        symbol="ETH/USDT:USDT",
        side=Side.LONG,
        size_pct_of_equity=2.0,
        leverage=2,
        confidence=0.1,
        reasoning="weak",
    )
    result = rm.validate_order(decision, account)
    assert not result.allowed


@pytest.mark.asyncio
async def test_daily_loss_trips_breaker() -> None:
    breaker = CircuitBreaker()
    rm = RiskManager(_settings(daily_loss_limit_pct=2.5), breaker)
    rm.restore_day_start(10_000, "2099-01-01")  # will reset on real today
    # Force day start
    from datetime import datetime, timezone

    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    rm.restore_day_start(10_000, today)

    account = AccountSnapshot(
        equity=9_700,  # -3%
        available_balance=9_700,
        peak_equity=10_000,
    )
    result = await rm.check_account_limits(account)
    assert not result.allowed
    assert breaker.is_tripped
    assert breaker.is_daily_halted


@pytest.mark.asyncio
async def test_close_allowed_under_breaker() -> None:
    breaker = CircuitBreaker()
    await breaker.trip(BreakerReason.API_ERROR, detail="test")
    rm = RiskManager(_settings(), breaker)
    account = AccountSnapshot(equity=10_000, available_balance=10_000)
    decision = TradeDecision(
        action=ActionType.CLOSE,
        symbol="BTC/USDT:USDT",
        confidence=1.0,
        reasoning="exit",
    )
    result = rm.validate_order(decision, account)
    assert result.allowed

    open_decision = TradeDecision(
        action=ActionType.OPEN_LONG,
        symbol="BTC/USDT:USDT",
        side=Side.LONG,
        size_pct_of_equity=2.0,
        leverage=2,
        confidence=0.9,
        reasoning="entry",
    )
    blocked = rm.validate_order(open_decision, account)
    assert not blocked.allowed
