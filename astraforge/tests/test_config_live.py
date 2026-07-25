"""Live mode requires explicit confirmation."""

from astraforge.core.config import Settings
from astraforge.core.models import TradingMode


def test_live_without_confirm_forced_to_paper() -> None:
    s = Settings(
        telegram_bot_token="x",
        trading_mode=TradingMode.LIVE,
        live_confirmed=False,
    )
    assert s.trading_mode == TradingMode.PAPER


def test_live_with_confirm() -> None:
    s = Settings(
        telegram_bot_token="x",
        trading_mode=TradingMode.LIVE,
        live_confirmed=True,
    )
    assert s.trading_mode == TradingMode.LIVE
