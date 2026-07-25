"""Non-interactive paper start: Kraken Spot + AI goal."""
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

os.environ["EXCHANGE_ID"] = "kraken"
os.environ["TRADING_MODE"] = "paper"
os.environ["LIVE_CONFIRMED"] = "false"
os.environ["TRADE_SYMBOLS"] = "BTC/USD,ETH/USD,SOL/USD,XRP/USD"
os.environ["PAPER_STARTING_EQUITY"] = "28"
os.environ["AGENT_LOOP_INTERVAL_SEC"] = "60"
os.environ["DATABASE_PATH"] = str((ROOT / "data" / "astraforge_run.db").resolve())

from astraforge.core.config import Settings, get_settings
from astraforge.core.engine import TradingEngine
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
        trading_mode="paper",
        live_confirmed=False,
        llm_provider="openai",
        llm_model=os.getenv("LLM_MODEL", "gpt-4o-mini"),
        llm_api_key=os.environ["LLM_API_KEY"],
        trade_symbols="BTC/USD,ETH/USD,SOL/USD,XRP/USD",
        paper_starting_equity=28.0,
        agent_loop_interval_sec=60,
        database_path=os.environ["DATABASE_PATH"],
        default_risk_profile="conservative",
    )
    engine = TradingEngine(settings)

    async def notify(msg: str) -> None:
        print(f"\n=== NOTIFY ===\n{msg}\n==============\n", flush=True)

    engine.set_notify(notify)
    await engine.start()
    print(await engine.startup_message(), flush=True)

    reply = await engine.handle_user_text("работай консервативно, цель 1$")
    print("GOAL:", reply, flush=True)
    print(await engine.format_status("ru"), flush=True)

    for i in range(5):
        print(f"\n--- tick {i+1} ---", flush=True)
        await engine.tick()
        print("summary:", engine._last_status_summary, flush=True)
        print(await engine.format_status("ru"), flush=True)

    print("\nContinuous mode...", flush=True)
    while engine._running:
        await asyncio.sleep(60)
        st = await engine.get_status_model()
        print(
            f"[heartbeat] equity=${st.equity:.2f} pnl=${st.pnl_today:.2f} "
            f"pos={st.open_positions} last={st.last_decision_summary}",
            flush=True,
        )


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("stopped", flush=True)
