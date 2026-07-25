"""Indicator computation smoke tests."""

from astraforge.core.exchange import ExchangeClient
from astraforge.core.config import Settings
from astraforge.utils.indicators import compute_indicators, ohlcv_to_dataframe


def test_compute_indicators_on_synthetic() -> None:
    settings = Settings(telegram_bot_token="x")
    ex = ExchangeClient(settings)
    rows = ex._synthetic_ohlcv(120)
    df = ohlcv_to_dataframe(rows)
    ind = compute_indicators(df)
    assert "error" not in ind
    assert ind["price"] > 0
    assert ind["rsi"] is not None
    assert ind["trend"] in {"bullish", "bearish", "neutral"}
