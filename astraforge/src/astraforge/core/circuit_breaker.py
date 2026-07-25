"""Circuit breaker — stops all new trades on API / margin / anomaly errors.

This module is non-bypassable by the LLM. Once tripped, only an explicit
user reset (or daily reset for daily-halt) can resume trading.
"""

from __future__ import annotations

from datetime import datetime, timezone
from enum import Enum
from typing import Callable, Awaitable

from astraforge.utils.logging import get_logger

logger = get_logger(__name__)

NotifyCallback = Callable[[str], Awaitable[None]]


class BreakerReason(str, Enum):
    API_ERROR = "api_error"
    MARGIN_CALL = "margin_call"
    ANOMALY = "anomaly"
    DAILY_LOSS = "daily_loss_limit"
    MAX_DRAWDOWN = "max_drawdown"
    MANUAL_STOP = "manual_stop"
    LIQUIDATION_RISK = "liquidation_risk"
    UNKNOWN = "unknown"


class CircuitBreaker:
    """Process-wide trading halt switch."""

    def __init__(self) -> None:
        self._tripped: bool = False
        self._reason: BreakerReason | None = None
        self._detail: str = ""
        self._tripped_at: datetime | None = None
        self._notify: NotifyCallback | None = None
        self._daily_halt: bool = False
        self._halt_date: str | None = None  # YYYY-MM-DD UTC

    def set_notify(self, callback: NotifyCallback) -> None:
        self._notify = callback

    @property
    def is_tripped(self) -> bool:
        return self._tripped

    @property
    def is_daily_halted(self) -> bool:
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        if self._daily_halt and self._halt_date != today:
            # New UTC day — auto-clear daily halt only
            if self._reason == BreakerReason.DAILY_LOSS:
                logger.info("daily_halt_cleared", previous_date=self._halt_date)
                self._daily_halt = False
                self._halt_date = None
                if self._reason == BreakerReason.DAILY_LOSS:
                    self._tripped = False
                    self._reason = None
                    self._detail = ""
                    self._tripped_at = None
        return self._daily_halt

    @property
    def trading_allowed(self) -> bool:
        """False when breaker is tripped or daily halt is active."""
        _ = self.is_daily_halted  # side-effect: may clear stale daily halt
        return not self._tripped and not self._daily_halt

    @property
    def reason(self) -> str | None:
        if self._reason is None:
            return None
        return f"{self._reason.value}: {self._detail}" if self._detail else self._reason.value

    @property
    def detail(self) -> str:
        return self._detail

    @property
    def tripped_at(self) -> datetime | None:
        return self._tripped_at

    async def trip(
        self,
        reason: BreakerReason,
        detail: str = "",
        *,
        daily: bool = False,
    ) -> None:
        """Trip the breaker and notify the user via Telegram if configured."""
        self._tripped = True
        self._reason = reason
        self._detail = detail
        self._tripped_at = datetime.now(timezone.utc)
        if daily or reason == BreakerReason.DAILY_LOSS:
            self._daily_halt = True
            self._halt_date = self._tripped_at.strftime("%Y-%m-%d")

        logger.error(
            "circuit_breaker_tripped",
            reason=reason.value,
            detail=detail,
            daily=self._daily_halt,
        )

        if self._notify:
            msg = (
                "🚨 CIRCUIT BREAKER\n"
                f"Reason: {reason.value}\n"
                f"Detail: {detail or 'n/a'}\n"
                "All new trades are STOPPED.\n"
                "Use /resume only after you understand the issue, "
                "or /emergency_stop to flatten everything."
            )
            try:
                await self._notify(msg)
            except Exception as exc:  # noqa: BLE001
                logger.warning("breaker_notify_failed", error=str(exc))

    async def reset(self, *, force_daily: bool = False) -> bool:
        """Reset breaker. Daily halt requires force_daily=True or new UTC day."""
        if self._daily_halt and not force_daily:
            today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
            if self._halt_date == today:
                logger.warning("cannot_reset_daily_halt_same_day")
                return False
        self._tripped = False
        self._reason = None
        self._detail = ""
        self._tripped_at = None
        if force_daily:
            self._daily_halt = False
            self._halt_date = None
        logger.info("circuit_breaker_reset")
        return True

    def snapshot(self) -> dict[str, object]:
        return {
            "tripped": self._tripped,
            "daily_halt": self._daily_halt,
            "reason": self.reason,
            "tripped_at": self._tripped_at.isoformat() if self._tripped_at else None,
            "trading_allowed": self.trading_allowed,
        }


# Process singleton
circuit_breaker = CircuitBreaker()
