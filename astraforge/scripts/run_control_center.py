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
    "USD/CAD,EUR/USD",
)
os.environ.setdefault("TRADING_STYLE", "fx_multi_scalp")
os.environ.setdefault("CANDLE_TIMEFRAME", "15m")
os.environ.setdefault("AGENT_LOOP_INTERVAL_SEC", "90")
os.environ.setdefault("MAX_POSITION_PCT", "35")
os.environ.setdefault("MAX_OPEN_POSITIONS", "1")
os.environ["ZERO_FEE_MODE"] = "false"
os.environ.setdefault("MIN_TAKE_PROFIT_PCT", "0.65")
os.environ.setdefault("FX_BUCKET_USD", "26.5")
os.environ.setdefault("CRYPTO_BUCKET_USD", "0")
# Force 7% — .env may still say 6.0 from pre-FX-only days
os.environ["MAX_DRAWDOWN_PCT"] = "7"
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
        zero_fee_mode=os.getenv("ZERO_FEE_MODE", "false").lower() in {"1", "true", "yes"},
        min_take_profit_pct=float(os.getenv("MIN_TAKE_PROFIT_PCT", "0.50")),
        fx_bucket_usd=float(os.getenv("FX_BUCKET_USD", "26.5")),
        crypto_bucket_usd=float(os.getenv("CRYPTO_BUCKET_USD", "0")),
        max_drawdown_pct=float(os.getenv("MAX_DRAWDOWN_PCT", "7")),
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

    # FX-only + rare/larger-move swing settings
    try:
        b = engine.buckets.data
        b["crypto_trading_enabled"] = False
        b["profit_to_crypto_pct"] = 0.0
        b["crypto_hold_usd"] = 0.0
        b["pending_crypto_buy_usd"] = 0.0
        b["fx_mode"] = "swing"
        b["fx_instant_tp_pct"] = 0.65
        b["max_hold_sec_force_be"] = 43_200
        b["working_capital_pct"] = 0.35
        b["open_cooldown_sec"] = 2_700
        b["max_slots"] = 1
        b["target_slot_usd"] = 9.0
        b["buy_zone_pct"] = 0.25
        b["range_lookback"] = 60
        b["fx_pairs"] = ["USD/CAD", "EUR/USD"]
        engine.buckets.save()
    except Exception as exc:  # noqa: BLE001
        print(f"bucket swing soft-fail: {exc}", flush=True)

    try:
        peak = float(await engine.state.get_kv("peak_equity", 0) or 0)
        acc = await engine.exchange.get_account_snapshot(peak_equity=0.0, force=True)
        if acc.equity > 0:
            await engine.state.set_kv("peak_equity", acc.equity)
            engine.risk.restore_peak(acc.equity, force=True)
            print(f"peak_equity recalibrated to {acc.equity:.4f} (was {peak:.4f})", flush=True)
        await engine.breaker.reset(force_daily=True)
        await engine.state.save_status_fields(trading_enabled=True)
        print(
            "SWING MODE: rare entries, close only at >=0.65% (fee-aware), "
            "~35% working capital, 45min cooldown, pairs USD/CAD+EUR/USD.",
            flush=True,
        )
    except Exception as exc:  # noqa: BLE001
        print(f"peak recalibrate soft-fail: {exc}", flush=True)

    swing_goal = (
        "FX swing: рідкісні угоди, закриття лише від +0.55% після комісій, "
        "робочі ~35% депозиту, крипта вимкнена, ціль 1$ обережно."
    )
    if not await engine.state.get_active_goal():
        await engine.handle_user_text(swing_goal)
    else:
        g = await engine.state.get_active_goal()
        raw = (g.raw_text or "").lower() if g else ""
        if g and ("крипт" in raw or "0.04" in raw or "маленьк" in raw):
            await engine.handle_user_text(swing_goal)

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
