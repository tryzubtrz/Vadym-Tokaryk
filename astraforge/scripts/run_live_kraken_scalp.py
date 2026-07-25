"""LIVE momentum-scalp runner for Kraken Spot (real money)."""
from __future__ import annotations

import asyncio
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)

for line in (ROOT / ".env").read_text().splitlines():
    if not line.strip() or line.startswith("#") or "=" not in line:
        continue
    k, v = line.split("=", 1)
    os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

# LIVE SETTINGS
os.environ["EXCHANGE_ID"] = "kraken"
os.environ["TRADING_MODE"] = "live"
os.environ["LIVE_CONFIRMED"] = "true"
os.environ["TRADE_SYMBOLS"] = (
    "BTC/USD,ETH/USD,SOL/USD,XRP/USD,ADA/USD,DOGE/USD,LINK/USD,LTC/USD,AVAX/USD,DOT/USD"
)
os.environ["TRADING_STYLE"] = "momentum_scalp"
os.environ["CANDLE_TIMEFRAME"] = "5m"
os.environ["AGENT_LOOP_INTERVAL_SEC"] = "30"
os.environ["MAX_POSITION_PCT"] = "30"
os.environ["MAX_OPEN_POSITIONS"] = "2"
os.environ["DEFAULT_RISK_PROFILE"] = "balanced"
os.environ["DATABASE_PATH"] = str((ROOT / "data" / "astraforge_live.db").resolve())

from astraforge.core.config import Settings, get_settings
from astraforge.core.engine import TradingEngine
from astraforge.core.models import TradingMode
from astraforge.utils.logging import setup_logging

get_settings.cache_clear()
setup_logging(os.getenv("LOG_LEVEL", "INFO"))


async def main() -> None:
    settings = Settings(
        telegram_bot_token="",
        telegram_allowed_user_ids="",
        exchange_id="kraken",
        exchange_api_key=os.environ["EXCHANGE_API_KEY"],
        exchange_api_secret=os.environ["EXCHANGE_API_SECRET"],
        trading_mode=TradingMode.LIVE,
        live_confirmed=True,
        llm_provider="openai",
        llm_model=os.getenv("LLM_MODEL", "gpt-4o-mini"),
        llm_api_key=os.environ["LLM_API_KEY"],
        trade_symbols=os.environ["TRADE_SYMBOLS"],
        trading_style="momentum_scalp",
        candle_timeframe="5m",
        agent_loop_interval_sec=30,
        max_position_pct=30.0,
        max_open_positions=2,
        daily_loss_limit_pct=2.5,
        max_drawdown_pct=6.0,
        max_leverage=1.0,
        database_path=os.environ["DATABASE_PATH"],
        default_risk_profile="balanced",
    )
    assert settings.trading_mode == TradingMode.LIVE
    engine = TradingEngine(settings)

    async def notify(msg: str) -> None:
        print(f"\n=== NOTIFY ===\n{msg}\n==============\n", flush=True)

    engine.set_notify(notify)
    await engine.start()
    print("⚠️ LIVE MODE — real Kraken Spot money", flush=True)
    print(await engine.startup_message(), flush=True)

    reply = await engine.handle_user_text(
        "работай активно, цель 1$, частые маленькие сделки"
    )
    print("GOAL:", reply, flush=True)
    print(await engine.format_status("ru"), flush=True)

    print("Continuous LIVE loop...", flush=True)
    while engine._running:
        await asyncio.sleep(15)
        st = await engine.get_status_model()
        print(
            f"[live] equity=${st.equity:.2f} pnl=${st.pnl_today:.2f} "
            f"pos={st.open_positions} last={st.last_decision_summary}",
            flush=True,
        )


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("stopped", flush=True)
