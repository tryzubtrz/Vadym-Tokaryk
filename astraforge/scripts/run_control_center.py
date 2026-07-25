"""Unified AstraForge Control Center: LIVE FX multi-scalp + web cockpit."""
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
    "USD/CAD,EUR/CAD,EUR/USD,GBP/USD,AUD/USD,SOL/USD,XRP/USD,DOGE/USD",
)
os.environ.setdefault("TRADING_STYLE", "fx_multi_scalp")
os.environ.setdefault("CANDLE_TIMEFRAME", "5m")
os.environ.setdefault("AGENT_LOOP_INTERVAL_SEC", "45")
os.environ.setdefault("MAX_POSITION_PCT", "30")
os.environ.setdefault("MAX_OPEN_POSITIONS", "10")
os.environ.setdefault("ZERO_FEE_MODE", "true")
os.environ.setdefault("MIN_TAKE_PROFIT_PCT", "0.05")
os.environ.setdefault("FX_BUCKET_USD", "20")
os.environ.setdefault("CRYPTO_BUCKET_USD", "8")
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
        trading_style=os.getenv("TRADING_STYLE", "fx_multi_scalp"),  # type: ignore[arg-type]
        candle_timeframe=os.getenv("CANDLE_TIMEFRAME", "5m"),
        agent_loop_interval_sec=int(os.getenv("AGENT_LOOP_INTERVAL_SEC", "45")),
        max_position_pct=float(os.getenv("MAX_POSITION_PCT", "30")),
        max_open_positions=int(os.getenv("MAX_OPEN_POSITIONS", "10")),
        max_leverage=1.0,
        zero_fee_mode=os.getenv("ZERO_FEE_MODE", "true").lower() in {"1", "true", "yes"},
        min_take_profit_pct=float(os.getenv("MIN_TAKE_PROFIT_PCT", "0.12")),
        fx_bucket_usd=float(os.getenv("FX_BUCKET_USD", "20")),
        crypto_bucket_usd=float(os.getenv("CRYPTO_BUCKET_USD", "0")),  # rest of equity after FX $20
        dashboard_owner_email=os.getenv("DASHBOARD_OWNER_EMAIL", ""),
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

    # Start dashboard ASAP; exchange connect happens inside engine.start
    config = uvicorn.Config(
        app,
        host=settings.dashboard_host,
        port=settings.dashboard_port,
        log_level="info",
        loop="asyncio",
    )
    server = uvicorn.Server(config)
    serve_task = asyncio.create_task(server.serve(), name="dashboard")

    await engine.start()
    await engine.state.save_status_fields(trading_enabled=True)
    try:
        await engine.breaker.reset(force_daily=True)
        peak = float(await engine.state.get_kv("peak_equity", 0) or 0)
        acc = await engine.exchange.get_account_snapshot(peak_equity=peak)
        if acc.equity > 0:
            today = __import__("datetime").datetime.now(
                __import__("datetime").timezone.utc
            ).strftime("%Y-%m-%d")
            await engine.state.save_status_fields(
                day_start_equity=acc.equity, pnl_today=0.0, day_key=today
            )
            engine.risk.restore_day_start(acc.equity, today)
    except Exception as exc:  # noqa: BLE001
        print(f"startup balance soft-fail: {exc}", flush=True)

    if not await engine.state.get_active_goal():
        await engine.handle_user_text(
            "FX $20 маленькі плюси + люта крипта на решті ~$6, ціль 1$ на день"
        )

    print("Buckets:", engine.buckets.snapshot(), flush=True)
    print(
        f"Control Center: http://0.0.0.0:{settings.dashboard_port}/",
        flush=True,
    )
    print(
        f"Mode={settings.trading_mode.value} style={settings.trading_style} exchange={settings.exchange_id}",
        flush=True,
    )
    print(
        "Auth: bind your email once, then OTP login. Set SMTP_* or RESEND_API_KEY for real email delivery.",
        flush=True,
    )

    stop = asyncio.Event()

    def _stop(*_a: object) -> None:
        stop.set()

    loop = asyncio.get_running_loop()
    for sig in (signal.SIGINT, signal.SIGTERM):
        try:
            loop.add_signal_handler(sig, _stop)
        except NotImplementedError:
            pass

    await stop.wait()
    server.should_exit = True
    serve_task.cancel()
    await asyncio.gather(serve_task, return_exceptions=True)
    await engine.stop()


if __name__ == "__main__":
    asyncio.run(main())
