"""Unified AstraForge Control Center: LIVE engine + web cockpit."""
from __future__ import annotations

import asyncio
import os
import signal
from pathlib import Path

import uvicorn

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)

for line in (ROOT / ".env").read_text().splitlines():
    if not line.strip() or line.startswith("#") or "=" not in line:
        continue
    k, v = line.split("=", 1)
    os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

os.environ.setdefault("EXCHANGE_ID", "kraken")
os.environ.setdefault("TRADING_MODE", "live")
os.environ.setdefault("LIVE_CONFIRMED", "true")
os.environ.setdefault(
    "TRADE_SYMBOLS",
    "BTC/USD,ETH/USD,SOL/USD,XRP/USD,ADA/USD,DOGE/USD,LINK/USD,LTC/USD,AVAX/USD,DOT/USD",
)
os.environ.setdefault("TRADING_STYLE", "momentum_scalp")
os.environ.setdefault("CANDLE_TIMEFRAME", "5m")
os.environ.setdefault("AGENT_LOOP_INTERVAL_SEC", "30")
os.environ.setdefault("MAX_POSITION_PCT", "30")
os.environ.setdefault("DASHBOARD_PASSWORD", "astraforge")
os.environ.setdefault("DASHBOARD_PORT", "8080")
os.environ["DATABASE_PATH"] = str((ROOT / "data" / "astraforge_live.db").resolve())

from astraforge.core.config import Settings, get_settings
from astraforge.core.engine import TradingEngine
from astraforge.core.models import TradingMode
from astraforge.dashboard.app import create_app
from astraforge.utils.logging import setup_logging

get_settings.cache_clear()
setup_logging(os.getenv("LOG_LEVEL", "INFO"))


async def main() -> None:
    settings = Settings(
        telegram_bot_token=os.getenv("TELEGRAM_BOT_TOKEN", ""),
        telegram_allowed_user_ids=os.getenv("TELEGRAM_ALLOWED_USER_IDS", ""),
        exchange_id=os.getenv("EXCHANGE_ID", "kraken"),  # type: ignore[arg-type]
        exchange_api_key=os.environ["EXCHANGE_API_KEY"],
        exchange_api_secret=os.environ["EXCHANGE_API_SECRET"],
        trading_mode=TradingMode.LIVE
        if os.getenv("TRADING_MODE", "live") == "live"
        else TradingMode.PAPER,
        live_confirmed=os.getenv("LIVE_CONFIRMED", "true").lower() in {"1", "true", "yes"},
        llm_provider="openai",  # type: ignore[arg-type]
        llm_model=os.getenv("LLM_MODEL", "gpt-4o-mini"),
        llm_api_key=os.environ["LLM_API_KEY"],
        trade_symbols=os.environ.get("TRADE_SYMBOLS", ""),
        trading_style=os.getenv("TRADING_STYLE", "momentum_scalp"),  # type: ignore[arg-type]
        candle_timeframe=os.getenv("CANDLE_TIMEFRAME", "5m"),
        agent_loop_interval_sec=int(os.getenv("AGENT_LOOP_INTERVAL_SEC", "30")),
        max_position_pct=float(os.getenv("MAX_POSITION_PCT", "30")),
        max_open_positions=int(os.getenv("MAX_OPEN_POSITIONS", "2")),
        max_leverage=1.0,
        database_path=os.environ["DATABASE_PATH"],
        dashboard_host=os.getenv("DASHBOARD_HOST", "0.0.0.0"),
        dashboard_port=int(os.getenv("DASHBOARD_PORT", "8080")),
        default_risk_profile="balanced",  # type: ignore[arg-type]
    )

    engine = TradingEngine(settings)
    app = create_app(engine)

    async def notify(msg: str) -> None:
        print(f"\n=== NOTIFY ===\n{msg}\n==============\n", flush=True)

    engine.set_notify(notify)
    await engine.start()

    # Keep previous goal if any; otherwise set active scalp goal
    if not await engine.state.get_active_goal():
        await engine.handle_user_text("работай активно, цель 1$, частые маленькие сделки")

    config = uvicorn.Config(
        app,
        host=settings.dashboard_host,
        port=settings.dashboard_port,
        log_level="info",
        loop="asyncio",
    )
    server = uvicorn.Server(config)

    stop = asyncio.Event()

    def _stop(*_a: object) -> None:
        stop.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, _stop)
        except NotImplementedError:
            pass

    print(
        f"Control Center: http://0.0.0.0:{settings.dashboard_port}/  "
        f"password={os.getenv('DASHBOARD_PASSWORD', 'astraforge')}",
        flush=True,
    )
    print(f"Mode={settings.trading_mode.value} exchange={settings.exchange_id}", flush=True)

    serve_task = asyncio.create_task(server.serve(), name="dashboard")
    await stop.wait()
    server.should_exit = True
    serve_task.cancel()
    await asyncio.gather(serve_task, return_exceptions=True)
    await engine.stop()


if __name__ == "__main__":
    asyncio.run(main())
