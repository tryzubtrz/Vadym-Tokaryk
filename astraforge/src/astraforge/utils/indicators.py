"""Technical indicator helpers built on pandas / pandas_ta."""

from __future__ import annotations

from typing import Any

import pandas as pd

try:
    import pandas_ta as ta
except ImportError:  # pragma: no cover - fallback if pandas_ta missing
    ta = None  # type: ignore[assignment]


def ohlcv_to_dataframe(ohlcv: list[list[float]]) -> pd.DataFrame:
    """Convert CCXT OHLCV list into a typed DataFrame."""
    df = pd.DataFrame(
        ohlcv,
        columns=["timestamp", "open", "high", "low", "close", "volume"],
    )
    df["timestamp"] = pd.to_datetime(df["timestamp"], unit="ms", utc=True)
    return df


def compute_indicators(
    df: pd.DataFrame,
    *,
    rsi_period: int = 14,
    ema_fast: int = 9,
    ema_slow: int = 21,
    atr_period: int = 14,
    macd_fast: int = 12,
    macd_slow: int = 26,
    macd_signal: int = 9,
) -> dict[str, Any]:
    """Compute a compact indicator snapshot for the AI agent."""
    if df.empty or len(df) < max(ema_slow, macd_slow, atr_period, rsi_period) + 5:
        return {"error": "insufficient_candles", "rows": len(df)}

    close = df["close"]
    high = df["high"]
    low = df["low"]

    if ta is not None:
        rsi = ta.rsi(close, length=rsi_period)
        ema_f = ta.ema(close, length=ema_fast)
        ema_s = ta.ema(close, length=ema_slow)
        atr = ta.atr(high, low, close, length=atr_period)
        macd_df = ta.macd(close, fast=macd_fast, slow=macd_slow, signal=macd_signal)
        macd_col = f"MACD_{macd_fast}_{macd_slow}_{macd_signal}"
        signal_col = f"MACDs_{macd_fast}_{macd_slow}_{macd_signal}"
        hist_col = f"MACDh_{macd_fast}_{macd_slow}_{macd_signal}"
        macd = macd_df[macd_col] if macd_df is not None else None
        macd_sig = macd_df[signal_col] if macd_df is not None else None
        macd_hist = macd_df[hist_col] if macd_df is not None else None
    else:
        # Minimal fallback without pandas_ta
        delta = close.diff()
        gain = delta.clip(lower=0).rolling(rsi_period).mean()
        loss = (-delta.clip(upper=0)).rolling(rsi_period).mean()
        rs = gain / loss.replace(0, pd.NA)
        rsi = 100 - (100 / (1 + rs))
        ema_f = close.ewm(span=ema_fast, adjust=False).mean()
        ema_s = close.ewm(span=ema_slow, adjust=False).mean()
        prev_close = close.shift(1)
        tr = pd.concat(
            [
                (high - low),
                (high - prev_close).abs(),
                (low - prev_close).abs(),
            ],
            axis=1,
        ).max(axis=1)
        atr = tr.rolling(atr_period).mean()
        ema_macd_fast = close.ewm(span=macd_fast, adjust=False).mean()
        ema_macd_slow = close.ewm(span=macd_slow, adjust=False).mean()
        macd = ema_macd_fast - ema_macd_slow
        macd_sig = macd.ewm(span=macd_signal, adjust=False).mean()
        macd_hist = macd - macd_sig

    last = df.iloc[-1]
    prev = df.iloc[-2]

    def _f(series: pd.Series | None, idx: int = -1) -> float | None:
        if series is None or series.empty:
            return None
        val = series.iloc[idx]
        if pd.isna(val):
            return None
        return float(val)

    price = float(last["close"])
    ema_fast_v = _f(ema_f)
    ema_slow_v = _f(ema_s)
    trend = "neutral"
    if ema_fast_v is not None and ema_slow_v is not None:
        if ema_fast_v > ema_slow_v:
            trend = "bullish"
        elif ema_fast_v < ema_slow_v:
            trend = "bearish"

    return {
        "price": price,
        "change_1bar_pct": ((price - float(prev["close"])) / float(prev["close"])) * 100,
        "rsi": _f(rsi),
        "ema_fast": ema_fast_v,
        "ema_slow": ema_slow_v,
        "atr": _f(atr),
        "atr_pct": (_f(atr) / price * 100) if _f(atr) else None,
        "macd": _f(macd),
        "macd_signal": _f(macd_sig),
        "macd_hist": _f(macd_hist),
        "trend": trend,
        "volume": float(last["volume"]),
        "high_24": float(df["high"].tail(96).max()) if len(df) >= 10 else float(df["high"].max()),
        "low_24": float(df["low"].tail(96).min()) if len(df) >= 10 else float(df["low"].min()),
    }
