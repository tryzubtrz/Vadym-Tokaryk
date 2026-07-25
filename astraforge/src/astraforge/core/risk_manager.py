"""Non-bypassable risk manager.

All order intents MUST pass through RiskManager.validate_order().
The LLM cannot override these limits — they are enforced in Python.
"""

from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone

from astraforge.core.circuit_breaker import BreakerReason, CircuitBreaker, circuit_breaker
from astraforge.core.config import (
    HARD_MAX_LEVERAGE,
    HARD_MAX_POSITION_PCT,
    Settings,
    risk_profile_overrides,
)
from astraforge.core.models import (
    AccountSnapshot,
    ActionType,
    RiskProfile,
    TradeDecision,
)
from astraforge.utils.logging import get_logger

logger = get_logger(__name__)


@dataclass
class RiskCheckResult:
    allowed: bool
    reason: str = ""
    adjusted_decision: TradeDecision | None = None


class RiskManager:
    """Hard risk envelope around every trade decision."""

    def __init__(
        self,
        settings: Settings,
        breaker: CircuitBreaker | None = None,
    ) -> None:
        self.settings = settings
        self.breaker = breaker or circuit_breaker
        self._profile = settings.default_risk_profile
        self._limits = risk_profile_overrides(self._profile, settings)
        self._day_start_equity: float | None = None
        self._day_key: str | None = None
        self._peak_equity: float = 0.0

    @property
    def profile(self) -> RiskProfile:
        return self._profile

    @property
    def limits(self) -> dict[str, float]:
        return dict(self._limits)

    def set_profile(self, profile: RiskProfile) -> dict[str, float]:
        self._profile = profile
        self._limits = risk_profile_overrides(profile, self.settings)
        logger.info("risk_profile_set", profile=profile.value, limits=self._limits)
        return self.limits

    def _ensure_day(self, equity: float) -> None:
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        if self._day_key != today:
            self._day_key = today
            self._day_start_equity = equity
            logger.info("risk_day_reset", day=today, start_equity=equity)
        if equity > self._peak_equity:
            self._peak_equity = equity

    def restore_peak(self, peak: float) -> None:
        self._peak_equity = max(self._peak_equity, peak)

    def restore_day_start(self, equity: float, day_key: str) -> None:
        self._day_start_equity = equity
        self._day_key = day_key

    async def check_account_limits(self, account: AccountSnapshot) -> RiskCheckResult:
        """Evaluate daily loss & drawdown; trip breaker if breached."""
        self._ensure_day(account.equity)
        if self._day_start_equity is None:
            self._day_start_equity = account.equity

        # Update peak
        if account.equity > self._peak_equity:
            self._peak_equity = account.equity
        peak = max(self._peak_equity, account.peak_equity, account.equity)
        self._peak_equity = peak

        if peak > 0:
            dd_pct = ((peak - account.equity) / peak) * 100.0
        else:
            dd_pct = 0.0

        daily_loss_pct = 0.0
        if self._day_start_equity and self._day_start_equity > 0:
            daily_pnl = account.equity - self._day_start_equity
            if daily_pnl < 0:
                daily_loss_pct = abs(daily_pnl / self._day_start_equity) * 100.0

        max_dd = self._limits["max_drawdown_pct"]
        max_daily = self._limits["daily_loss_limit_pct"]

        if daily_loss_pct >= max_daily:
            await self.breaker.trip(
                BreakerReason.DAILY_LOSS,
                detail=f"Daily loss {daily_loss_pct:.2f}% >= limit {max_daily}%",
                daily=True,
            )
            return RiskCheckResult(
                allowed=False,
                reason=f"Daily loss limit hit ({daily_loss_pct:.2f}%)",
            )

        if dd_pct >= max_dd:
            await self.breaker.trip(
                BreakerReason.MAX_DRAWDOWN,
                detail=f"Drawdown {dd_pct:.2f}% >= limit {max_dd}%",
            )
            return RiskCheckResult(
                allowed=False,
                reason=f"Max drawdown hit ({dd_pct:.2f}%)",
            )

        if not self.breaker.trading_allowed:
            return RiskCheckResult(
                allowed=False,
                reason=f"Circuit breaker active: {self.breaker.reason}",
            )

        return RiskCheckResult(allowed=True)

    def validate_order(
        self,
        decision: TradeDecision,
        account: AccountSnapshot,
    ) -> RiskCheckResult:
        """Clamp / reject a single trade decision against hard limits.

        Returns an adjusted decision (leverage / size clamped) when possible.
        """
        # Risk-reducing actions are always allowed, even under circuit breaker.
        if decision.action in (ActionType.HOLD, ActionType.CLOSE, ActionType.REDUCE):
            return RiskCheckResult(allowed=True, adjusted_decision=decision)

        if not self.breaker.trading_allowed:
            return RiskCheckResult(
                allowed=False,
                reason=f"Circuit breaker: {self.breaker.reason}",
            )

        if decision.action not in (ActionType.OPEN_LONG, ActionType.OPEN_SHORT):
            return RiskCheckResult(allowed=False, reason="Unknown action")

        # Spot markets: no leveraged shorts
        if self.settings.is_spot and decision.action == ActionType.OPEN_SHORT:
            return RiskCheckResult(
                allowed=False,
                reason="Spot mode: shorts disabled (buy/sell only)",
            )

        open_count = len(account.positions)
        if open_count >= int(self.settings.max_open_positions):
            # Allow if reducing exposure on same symbol later; block new opens
            symbols_open = {p.symbol for p in account.positions}
            if decision.symbol not in symbols_open:
                return RiskCheckResult(
                    allowed=False,
                    reason=f"Max open positions ({self.settings.max_open_positions})",
                )

        max_lev = min(self._limits["max_leverage"], HARD_MAX_LEVERAGE)
        if self.settings.is_spot and account.equity < 100:
            max_pos = self.settings.effective_max_position_pct(account.equity)
        else:
            from astraforge.core.config import HARD_MAX_POSITION_PCT

            max_pos = min(float(self._limits["max_position_pct"]), HARD_MAX_POSITION_PCT)

        if self.settings.is_spot:
            max_lev = 1.0

        adj = decision.model_copy(deep=True)
        if self.settings.is_spot:
            adj.leverage = 1.0
        if adj.leverage > max_lev:
            logger.warning(
                "leverage_clamped",
                requested=adj.leverage,
                max=max_lev,
            )
            adj.leverage = max_lev
        if adj.size_pct_of_equity > max_pos:
            logger.warning(
                "position_size_clamped",
                requested=adj.size_pct_of_equity,
                max=max_pos,
            )
            adj.size_pct_of_equity = max_pos

        if adj.size_pct_of_equity <= 0:
            return RiskCheckResult(allowed=False, reason="Size is zero after clamps")

        if account.equity <= 0:
            return RiskCheckResult(allowed=False, reason="Equity is zero or negative")

        # Notional check: size_pct * equity * leverage should be sane
        notional = account.equity * (adj.size_pct_of_equity / 100.0) * adj.leverage
        if notional > account.equity * (max_pos / 100.0) * max_lev * 1.01:
            return RiskCheckResult(allowed=False, reason="Notional exceeds envelope")

        # Confidence floor — low-confidence opens rejected
        if adj.confidence < 0.35:
            return RiskCheckResult(
                allowed=False,
                reason=f"Confidence too low ({adj.confidence:.2f} < 0.35)",
            )

        return RiskCheckResult(allowed=True, adjusted_decision=adj)

    def max_realistic_daily_target_usd(self, equity: float) -> float:
        """Suggest an upper-bound realistic daily target given risk limits.

        Rough heuristic: ~1.5x daily loss budget as optimistic upside.
        """
        daily_budget = equity * (self._limits["daily_loss_limit_pct"] / 100.0)
        aggression = self._limits.get("target_aggression", 0.6)
        return round(daily_budget * (1.0 + aggression) * 1.5, 2)

    def is_goal_too_aggressive(
        self,
        *,
        equity: float,
        target_usd: float | None = None,
        target_pct: float | None = None,
    ) -> tuple[bool, float]:
        """Return (too_aggressive, suggested_max_usd)."""
        max_usd = self.max_realistic_daily_target_usd(equity)
        if target_pct is not None:
            target_usd = equity * (target_pct / 100.0)
        if target_usd is None:
            return False, max_usd
        # Aggressive if target > 3x daily loss budget (very hard without violating risk)
        threshold = max_usd * 1.25
        return target_usd > threshold, max_usd
