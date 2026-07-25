"""Tests for natural-language goal parsing."""

from astraforge.core.config import Settings
from astraforge.core.goal_interpreter import GoalInterpreter, detect_language
from astraforge.core.models import GoalType, RiskProfile
from astraforge.core.risk_manager import RiskManager


def _gi() -> GoalInterpreter:
    settings = Settings(
        telegram_bot_token="x",
        daily_loss_limit_pct=2.5,
        max_drawdown_pct=6.0,
        max_leverage=5,
        max_position_pct=3.5,
        paper_starting_equity=10_000,
    )
    risk = RiskManager(settings)
    return GoalInterpreter(settings, risk)


def test_detect_russian() -> None:
    assert detect_language("сделай мне 200 долларов") == "ru"


def test_detect_english() -> None:
    assert detect_language("make me 200 dollars today") == "en"


def test_parse_usd_goal_ru() -> None:
    gi = _gi()
    result = gi.interpret("сделай мне сегодня 200 долларов", equity=10_000)
    assert result.understood
    assert result.goal is not None
    assert result.goal.goal_type == GoalType.PROFIT_USD
    assert result.goal.target_profit_usd == 200.0
    assert "Цель принята" in result.reply_text or "принята" in result.reply_text.lower()


def test_parse_pct_goal() -> None:
    gi = _gi()
    result = gi.interpret("цель на сегодня +3%", equity=10_000)
    assert result.understood
    assert result.goal is not None
    assert result.goal.target_profit_pct == 3.0


def test_conservative_with_usd() -> None:
    gi = _gi()
    result = gi.interpret("работай консервативно, цель 150$", equity=10_000)
    assert result.understood
    assert result.goal is not None
    assert result.goal.risk_profile == RiskProfile.CONSERVATIVE
    assert result.goal.target_profit_usd == 150.0


def test_close_all() -> None:
    gi = _gi()
    result = gi.interpret("закрой все позиции", equity=10_000)
    assert result.understood
    assert result.goal is not None
    assert result.goal.goal_type == GoalType.CLOSE_ALL


def test_aggressive_goal_rejected() -> None:
    gi = _gi()
    # 50% of equity in a day is absurd vs 2.5% daily loss budget
    result = gi.interpret("сделай 5000 долларов сегодня", equity=10_000)
    assert result.is_aggressive
    assert result.goal is None
    assert result.suggested_goal is not None
    assert "агрессив" in result.reply_text.lower() or "aggressive" in result.reply_text.lower()


def test_unknown() -> None:
    gi = _gi()
    result = gi.interpret("привет как дела у биткоина на марсе", equity=10_000)
    assert not result.understood
