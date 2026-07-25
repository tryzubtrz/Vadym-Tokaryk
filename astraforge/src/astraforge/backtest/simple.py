"""Minimal vectorized backtest for heuristic signal validation."""

from __future__ import annotations

from dataclasses import dataclass

import pandas as pd

from astraforge.utils.indicators import compute_indicators, ohlcv_to_dataframe


@dataclass
class BacktestResult:
    trades: int
    win_rate: float
    total_return_pct: float
    max_drawdown_pct: float


def run_rsi_trend_backtest(ohlcv: list[list[float]], *, fee_bps: float = 4.0) -> BacktestResult:
    """Long when bullish trend + RSI mid; flat otherwise. Educational only."""
    df = ohlcv_to_dataframe(ohlcv)
    if len(df) < 50:
        return BacktestResult(0, 0.0, 0.0, 0.0)

    equity = 1.0
    peak = 1.0
    max_dd = 0.0
    position = 0  # 1 long, 0 flat
    entry = 0.0
    wins = 0
    trades = 0
    fee = fee_bps / 10_000.0

    for i in range(40, len(df)):
        window = df.iloc[: i + 1]
        ind = compute_indicators(window)
        price = float(df.iloc[i]["close"])
        trend = ind.get("trend")
        rsi = ind.get("rsi")

        want_long = trend == "bullish" and rsi is not None and 40 <= rsi <= 65

        if position == 0 and want_long:
            position = 1
            entry = price * (1 + fee)
            trades += 1
        elif position == 1 and not want_long:
            exit_px = price * (1 - fee)
            ret = (exit_px - entry) / entry
            equity *= 1 + ret
            if ret > 0:
                wins += 1
            position = 0

        peak = max(peak, equity)
        dd = (peak - equity) / peak * 100.0
        max_dd = max(max_dd, dd)

    if position == 1:
        price = float(df.iloc[-1]["close"])
        ret = (price * (1 - fee) - entry) / entry
        equity *= 1 + ret
        if ret > 0:
            wins += 1

    win_rate = (wins / trades * 100.0) if trades else 0.0
    total_return = (equity - 1.0) * 100.0
    return BacktestResult(
        trades=trades,
        win_rate=win_rate,
        total_return_pct=total_return,
        max_drawdown_pct=max_dd,
    )


def summarize(result: BacktestResult) -> str:
    return (
        f"trades={result.trades} win_rate={result.win_rate:.1f}% "
        f"return={result.total_return_pct:.2f}% maxDD={result.max_drawdown_pct:.2f}%"
    )
