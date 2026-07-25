"""AstraForge AI process entrypoint.

Starts:
1. Trading engine (decision loop)
2. Telegram bot (primary UI)
3. FastAPI dashboard (secondary monitoring)
"""

from __future__ import annotations

import asyncio
import signal

import uvicorn

from astraforge.core.config import get_settings
from astraforge.core.engine import TradingEngine
from astraforge.dashboard.app import create_app
from astraforge.telegram.bot import TelegramBotApp
from astraforge.utils.logging import get_logger, setup_logging

logger = get_logger(__name__)


async def run() -> None:
    settings = get_settings()
    setup_logging(settings.log_level)

    if not settings.telegram_bot_token:
        logger.error("TELEGRAM_BOT_TOKEN is required")
        raise SystemExit(1)

    engine = TradingEngine(settings)
    await engine.start()

    tg: TelegramBotApp | None = None
    if settings.telegram_bot_token:
        tg = TelegramBotApp(
            token=settings.telegram_bot_token,
            allowed_ids=settings.allowed_user_ids,
            engine=engine,
        )
        engine.set_notify(tg.broadcast)

    app = create_app(engine)
    config = uvicorn.Config(
        app,
        host=settings.dashboard_host,
        port=settings.dashboard_port,
        log_level=settings.log_level.lower(),
        loop="asyncio",
    )
    server = uvicorn.Server(config)

    stop_event = asyncio.Event()

    def _signal_handler(*_args: object) -> None:
        logger.info("shutdown_signal_received")
        stop_event.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, _signal_handler)
        except NotImplementedError:
            pass

    tasks = [
        asyncio.create_task(server.serve(), name="dashboard"),
    ]
    if tg is not None:
        tasks.append(asyncio.create_task(tg.run(), name="telegram"))

    logger.info(
        "astraforge_online",
        mode=settings.trading_mode.value,
        exchange=settings.exchange_id,
        dashboard=f"http://{settings.dashboard_host}:{settings.dashboard_port}",
    )

    await stop_event.wait()
    server.should_exit = True
    for t in tasks:
        t.cancel()
    await asyncio.gather(*tasks, return_exceptions=True)
    if tg:
        await tg.close()
    await engine.stop()


def main() -> None:
    asyncio.run(run())


if __name__ == "__main__":
    main()
