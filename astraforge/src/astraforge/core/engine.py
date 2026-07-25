"""Main trading loop orchestrator.

Wires exchange → AI agent → risk → executor → Telegram notifications.
"""

from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from typing import Any, Awaitable, Callable

from astraforge.core.ai_agent import AIAgent
from astraforge.core.bucket_store import BucketStore
from astraforge.core.circuit_breaker import BreakerReason, CircuitBreaker, circuit_breaker
from astraforge.core.config import Settings
from astraforge.core.exchange import ExchangeClient
from astraforge.core.fx_scalper import FxMultiScalper
from astraforge.core.goal_interpreter import GoalInterpreter
from astraforge.core.models import (
    AccountSnapshot,
    ActionType,
    EquityPoint,
    GoalType,
    RiskProfile,
    Side,
    TradeDecision,
    TradingGoal,
    TradingMode,
)
from astraforge.core.order_executor import OrderExecutor
from astraforge.core.risk_manager import RiskManager
from astraforge.core.state_manager import StateManager
from astraforge.utils.logging import get_logger
from pathlib import Path

logger = get_logger(__name__)

NotifyFn = Callable[[str], Awaitable[None]]


class TradingEngine:
    """Autonomous agent runtime."""

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self.state = StateManager(settings.database_path)
        self.breaker: CircuitBreaker = circuit_breaker
        self.exchange = ExchangeClient(settings, self.breaker)
        self.risk = RiskManager(settings, self.breaker)
        self.agent = AIAgent(settings)
        self.executor = OrderExecutor(self.exchange, self.risk, self.state, self.breaker)
        self.goals = GoalInterpreter(settings, self.risk)
        bucket_path = Path(settings.database_path).with_name("buckets.json")
        self.buckets = BucketStore(bucket_path)
        # Seed buckets from settings on first run
        if float(self.buckets.data.get("fx_bucket_usd") or 0) <= 0:
            self.buckets.data["fx_bucket_usd"] = float(getattr(settings, "fx_bucket_usd", 20.0))
        if float(self.buckets.data.get("crypto_hold_usd") or 0) <= 0:
            self.buckets.data["crypto_hold_usd"] = float(getattr(settings, "crypto_bucket_usd", 8.0))
        self.buckets.data["max_slots"] = int(getattr(settings, "fx_max_slots", 10))
        self.buckets.data["target_slot_usd"] = float(getattr(settings, "fx_target_slot_usd", 2.0))
        self.buckets.save()
        self.fx = FxMultiScalper(settings, self.buckets, self.exchange, self.agent)

        self._running = False
        self._loop_task: asyncio.Task[None] | None = None
        self._notify: NotifyFn | None = None
        self._last_status_summary = ""
        self._last_error: str | None = None
        self._goal_reached_notified = False
        self._last_report_day: str | None = None
        self._last_fx_tick: dict[str, Any] = {}

    def set_notify(self, fn: NotifyFn) -> None:
        self._notify = fn
        self.breaker.set_notify(fn)

    async def notify(self, text: str) -> None:
        if self._notify:
            try:
                await self._notify(text)
            except Exception as exc:  # noqa: BLE001
                logger.warning("notify_failed", error=str(exc))

    async def start(self) -> None:
        await self.state.connect()
        await self._restore_state()
        await self.exchange.connect()

        # Initial equity snapshot
        peak = float(await self.state.get_kv("peak_equity", 0.0) or 0.0)
        account = await self.exchange.get_account_snapshot(peak_equity=peak)
        await self.state.save_status_fields(
            peak_equity=max(peak, account.equity),
            mode=self.settings.trading_mode,
            trading_enabled=True,
        )
        await self.state.record_equity(
            EquityPoint(equity=account.equity, pnl_today=float(await self.state.get_kv("pnl_today", 0) or 0))
        )

        self._running = True
        self._loop_task = asyncio.create_task(self._run_loop(), name="astraforge-loop")
        logger.info("engine_started", mode=self.settings.trading_mode.value)

    async def stop(self) -> None:
        self._running = False
        if self._loop_task:
            self._loop_task.cancel()
            try:
                await self._loop_task
            except asyncio.CancelledError:
                pass
            self._loop_task = None
        await self.exchange.close()
        await self.state.close()
        logger.info("engine_stopped")

    async def _restore_state(self) -> None:
        profile_raw = await self.state.get_kv(
            "risk_profile", self.settings.default_risk_profile.value
        )
        try:
            self.risk.set_profile(RiskProfile(profile_raw))
        except ValueError:
            self.risk.set_profile(self.settings.default_risk_profile)

        peak = float(await self.state.get_kv("peak_equity", 0.0) or 0.0)
        self.risk.restore_peak(peak)
        day_start = await self.state.get_kv("day_start_equity")
        day_key = await self.state.get_kv("day_key")
        if day_start is not None and day_key:
            self.risk.restore_day_start(float(day_start), str(day_key))

        goal = await self.state.get_active_goal()
        if goal:
            logger.info("restored_active_goal", raw=goal.raw_text)

        # Spot average entries (needed for tiny take-profits / zero-fee exits)
        if self.settings.is_spot:
            basis = await self.state.get_kv("spot_cost_basis", {}) or {}
            if not basis:
                basis = await self._rebuild_spot_cost_basis_from_trades()
            if basis:
                self.exchange.set_spot_cost_basis(basis)
                await self.state.set_kv("spot_cost_basis", self.exchange.get_spot_cost_basis())
                logger.info("restored_spot_cost_basis", symbols=list(basis.keys()))

    async def _rebuild_spot_cost_basis_from_trades(self) -> dict[str, dict[str, float]]:
        """VWAP entry from recorded buys minus sells (best effort after restart)."""
        trades = await self.state.recent_trades(200)
        books: dict[str, dict[str, float]] = {}
        # oldest → newest
        for t in reversed(trades):
            sym = t.symbol
            if not sym or sym == "ALL":
                continue
            action = (t.action or "").lower()
            qty = float(t.size or 0)
            px = float(t.price or 0)
            if qty <= 0 or px <= 0:
                continue
            cur = books.get(sym)
            if action in {"open_long", "buy"}:
                if cur and cur["size"] > 0:
                    total = cur["size"] + qty
                    cur["entry"] = (cur["entry"] * cur["size"] + px * qty) / total
                    cur["size"] = total
                else:
                    books[sym] = {"entry": px, "size": qty}
            elif action in {"close", "reduce", "close_all", "sell"}:
                if not cur:
                    continue
                left = cur["size"] - qty
                if left <= 1e-12:
                    books.pop(sym, None)
                else:
                    cur["size"] = left
        return books

    async def _run_loop(self) -> None:
        interval = max(15, int(self.settings.agent_loop_interval_sec))
        while self._running:
            try:
                await self.tick()
            except Exception as exc:  # noqa: BLE001
                self._last_error = str(exc)
                logger.exception("engine_tick_failed", error=str(exc))
                await self.breaker.trip(BreakerReason.ANOMALY, detail=str(exc))
            await asyncio.sleep(interval)

    async def tick(self) -> None:
        """One decision cycle."""
        peak = float(await self.state.get_kv("peak_equity", 0.0) or 0.0)
        account = await self.exchange.get_account_snapshot(peak_equity=peak)

        # Day tracking
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        day_key = await self.state.get_kv("day_key")
        if day_key != today:
            await self.state.save_status_fields(
                day_key=today,
                day_start_equity=account.equity,
                pnl_today=0.0,
            )
            self._goal_reached_notified = False
            self.risk.restore_day_start(account.equity, today)

        day_start = float(
            await self.state.get_kv("day_start_equity", account.equity) or account.equity
        )
        # Prefer exchange realized if available; else equity delta
        pnl_today = account.equity - day_start
        # Blend with paper realized
        if abs(account.realized_pnl_today) > 0:
            pnl_today = account.realized_pnl_today + account.unrealized_pnl
        await self.state.save_status_fields(
            pnl_today=pnl_today,
            peak_equity=max(peak, account.equity),
        )
        await self.state.record_equity(EquityPoint(equity=account.equity, pnl_today=pnl_today))

        # Risk checks (may trip breaker)
        risk_ok = await self.risk.check_account_limits(account)
        trading_enabled = bool(await self.state.get_kv("trading_enabled", True))

        goal = await self.state.get_active_goal()

        # Daily report once per day near end or on first tick after goal
        await self._maybe_daily_report(account.equity, pnl_today, goal)

        if goal and goal.target_profit_usd and pnl_today >= goal.target_profit_usd:
            if not self._goal_reached_notified:
                self._goal_reached_notified = True
                await self.notify(
                    f"🎯 Цель достигнута! PnL сегодня: ${pnl_today:.2f} "
                    f"(цель ${goal.target_profit_usd:.2f}). Фиксирую / защищаю прибыль."
                )

        # Always manage open FX slots (take profit / emergency) even if new entries paused.
        # Rate-limit / soft API trips must not strand an open scalp.
        fx_style = getattr(self.settings, "trading_style", "") == "fx_multi_scalp"
        if fx_style and self.buckets.open_slot_count() > 0:
            try:
                closed_only = await self.fx.manage_open_slots()
                closed_ok = [
                    c
                    for c in (closed_only or [])
                    if c.get("ok")
                    and not c.get("held")
                    and c.get("action") not in {"hold", "absorb_cash"}
                ]
                absorbs = [
                    c
                    for c in (closed_only or [])
                    if c.get("ok") and c.get("action") == "absorb_cash"
                ]
                holds = [
                    c
                    for c in (closed_only or [])
                    if c.get("ok") and (c.get("held") or c.get("action") == "hold")
                ]
                if closed_ok or holds or absorbs:
                    parts = [
                        f"FX close {c.get('symbol')} pnl={float(c.get('pnl') or 0):+.4f}"
                        for c in closed_ok
                    ]
                    parts.extend(
                        f"FX absorb {c.get('symbol')} keep-cash "
                        f"{float(c.get('pnl_pct') or 0):+.3f}%"
                        for c in absorbs
                    )
                    parts.extend(
                        f"FX hold {c.get('symbol')} {float(c.get('pnl_pct') or 0):+.3f}% "
                        f"{float(c.get('age_sec') or 0):.0f}s"
                        for c in holds
                    )
                    self._last_status_summary = " | ".join(parts)
                    logger.info("fx_manage_while_paused", summary=self._last_status_summary)
            except Exception as exc:  # noqa: BLE001
                logger.warning("fx_manage_while_paused_failed", error=str(exc))

        if not trading_enabled or not risk_ok.allowed or not self.breaker.trading_allowed:
            reason = risk_ok.reason or self.breaker.reason or "trading disabled"
            br = (self.breaker.reason or "")
            # Auto-clear transient Kraken rate-limit trips
            if "rate limit" in br.lower():
                await self.breaker.reset(force_daily=False)
                logger.info("rate_limit_breaker_auto_reset")
            if not trading_enabled or not risk_ok.allowed or not self.breaker.trading_allowed:
                self._last_status_summary = f"paused: {reason}"
                return

        # FX multi-scalp path (priority strategy) + fierce crypto on leftover bucket
        if fx_style:
            # $20 FX + rest crypto (auto, based on live equity)
            split = self.buckets.sync_to_equity(account.equity, fx_target=20.0)
            fx_result = await self.fx.tick(available_usd=float(account.available_balance))
            self._last_fx_tick = fx_result
            opened = fx_result.get("opened") or {}
            closed = fx_result.get("closed") or []
            ai = fx_result.get("ai") or {}
            parts = [
                f"split FX=${split['fx_bucket_usd']:.2f}/crypto=${split['crypto_hold_usd']:.2f}"
            ]
            if not bool(self.buckets.data.get("crypto_trading_enabled", False)):
                parts[0] = f"FX-only ${split['fx_bucket_usd']:.2f}"
            for c in closed:
                if not c.get("ok"):
                    if c.get("error"):
                        parts.append(f"FX err {c.get('symbol')}:{c.get('error')}")
                    continue
                if c.get("held") or c.get("action") == "hold":
                    need = c.get("reason") or ""
                    parts.append(
                        f"FX hold {c.get('symbol')} {float(c.get('pnl_pct') or 0):+.3f}% "
                        f"{float(c.get('age_sec') or 0):.0f}s"
                        + (f" ({need[:48]})" if need else "")
                    )
                    continue
                if c.get("action") == "absorb_cash":
                    parts.append(
                        f"FX absorb {c.get('symbol')} keep-cash "
                        f"{float(c.get('pnl_pct') or 0):+.3f}%"
                    )
                    continue
                parts.append(
                    f"FX close {c.get('symbol')} pnl={float(c.get('pnl') or 0):+.4f}"
                )
            if opened.get("ok"):
                slot = opened.get("slot") or {}
                parts.append(f"FX open {slot.get('symbol')} @ {slot.get('entry')}")
            elif opened.get("soft_fail"):
                parts.append(f"FX soft_fail: {opened.get('error')}")
            elif opened.get("skipped"):
                parts.append(f"FX wait: {opened.get('reason')}")
            pick = (ai.get("pick") or {})
            if pick:
                parts.append(
                    f"AI:{pick.get('action')}:{pick.get('symbol') or '-'} ({pick.get('reason','')[:80]})"
                )

            # Crypto scalp only if explicitly enabled
            if bool(self.buckets.data.get("crypto_trading_enabled", False)):
                try:
                    crypto_parts = await self._run_crypto_bucket_scalp(account, pnl_today)
                    parts.extend(crypto_parts)
                except Exception as exc:  # noqa: BLE001
                    logger.warning("crypto_bucket_scalp_failed", error=str(exc))
                    parts.append(f"crypto_err:{exc}")
            else:
                parts.append("crypto:OFF")

            self._last_status_summary = " | ".join(parts) or "FX idle"
            await self.state.log_decision(
                {
                    "type": "fx_crypto_tick",
                    "result": fx_result,
                    "split": split,
                    "pnl_today": pnl_today,
                    "equity": account.equity,
                    "reasoning": self._last_status_summary,
                }
            )
            logger.info("tick_complete", summary=self._last_status_summary)
            return

        if goal is None:
            self._last_status_summary = "idle: waiting for goal"
            return

        if goal.goal_type in (GoalType.STOP_TRADING, GoalType.STATUS, GoalType.REPORT):
            return

        markets = await self.agent.analyze_markets(self.exchange, self.settings.symbols)

        # Hard scalp exits (esp. zero-fee): lock tiny green without waiting on LLM
        auto_closes = await self._zero_fee_auto_exits(account, markets)
        results = []
        if auto_closes:
            for decision in auto_closes:
                result = await self.executor.execute(decision, account)
                results.append(result)
                if result.get("ok") and not result.get("rejected"):
                    account = await self.exchange.get_account_snapshot(
                        peak_equity=float(await self.state.get_kv("peak_equity", 0) or 0)
                    )
            closed_syms = {d.symbol for d in auto_closes if d.symbol}
            self._last_status_summary = (
                "[zero-fee auto TP] "
                + "; ".join(
                    f"close:{d.symbol}({d.confidence:.2f})" for d in auto_closes
                )
            )
            await self.state.log_decision(
                {
                    "batch": {"decisions": [d.model_dump() for d in auto_closes]},
                    "results": results,
                    "pnl_today": pnl_today,
                    "equity": account.equity,
                    "reasoning": self._last_status_summary,
                }
            )
            logger.info("tick_complete", summary=self._last_status_summary)
            # Skip new entries this tick after locking profits
            if closed_syms:
                return

        batch = await self.agent.decide(
            account=account,
            markets=markets,
            goal=goal,
            risk_limits=self.risk.limits,
            pnl_today=pnl_today,
        )

        # FX-only: never open/scale crypto via the general agent path
        if not bool(self.buckets.data.get("crypto_trading_enabled", False)):
            fx_bases = {"USD", "EUR", "GBP", "AUD", "CAD"}
            kept = []
            for d in batch.decisions:
                sym = (getattr(d, "symbol", None) or "").upper()
                base = sym.split("/")[0] if "/" in sym else ""
                act = getattr(d, "action", None)
                act_s = (act.value if hasattr(act, "value") else str(act or "")).lower()
                is_fx = base in fx_bases and ("/" in sym)
                if act_s in {"open_long", "open_short", "buy", "long", "scale_in"} and not is_fx:
                    continue
                kept.append(d)
            batch.decisions = kept

        for decision in batch.decisions:
            result = await self.executor.execute(decision, account)
            results.append(result)
            # Refresh account after each fill
            if result.get("ok") and not result.get("rejected"):
                account = await self.exchange.get_account_snapshot(
                    peak_equity=float(await self.state.get_kv("peak_equity", 0) or 0)
                )

        payload = {
            "batch": batch.model_dump(),
            "results": results,
            "pnl_today": pnl_today,
            "equity": account.equity,
            "reasoning": self.agent.last_reasoning,
        }
        await self.state.log_decision(payload)
        self._last_status_summary = self.agent.last_reasoning
        logger.info("tick_complete", summary=self._last_status_summary)

    def _crypto_symbols(self) -> list[str]:
        """Coins affordable on a ~$6–15 crypto bucket (Kraken spot mins)."""
        raw = [
            "XRP/USD",
            "DOGE/USD",
            "ADA/USD",
            "DOT/USD",
            "ETH/USD",
            "BTC/USD",
            "AVAX/USD",
            "SOL/USD",
            "SHIB/USD",
            "LINK/USD",
        ]
        # Prefer settings trade list crypto entries if present
        from_settings = [
            s for s in self.settings.symbols if s.endswith("/USD") and s.split("/")[0] not in {
                "USD", "EUR", "GBP", "AUD", "CAD"
            }
        ]
        out: list[str] = []
        for s in from_settings + raw:
            if s not in out:
                out.append(s)
        return out[:8]

    async def _run_crypto_bucket_scalp(self, account: AccountSnapshot, pnl_today: float) -> list[str]:
        """Aggressive momentum scalp using ONLY the leftover crypto bucket (~$6+)."""
        if not bool(self.buckets.data.get("crypto_trading_enabled", False)):
            return ["crypto:OFF"]
        snap = self.buckets.snapshot()
        budget = float(snap.get("crypto_hold_usd") or 0)
        if budget < 1.5:
            return [f"crypto skip: budget ${budget:.2f} too small"]

        free_usd = float(await self.exchange.free_balance("USD"))
        # CAD float covers much of FX — give crypto bucket priority on remaining USD
        cad_usd = 0.0
        try:
            cad = float(await self.exchange.free_balance("CAD"))
            if cad > 0:
                t = await self.exchange.fetch_ticker("USD/CAD")
                px = float(t.get("last") or 0)
                if px > 0:
                    cad_usd = cad / px
        except Exception:  # noqa: BLE001
            pass
        # Leave a small USD buffer for FX EUR/GBP lots (~$5), rest up to crypto budget
        usd_buffer_for_fx = 5.0 if cad_usd < 4 else 2.0
        crypto_cash = min(budget, max(0.0, free_usd - usd_buffer_for_fx)) * 0.98
        if crypto_cash < 1.5 and free_usd >= 1.5:
            # Last resort: still allow tiny crypto if any USD left
            crypto_cash = min(budget, free_usd * 0.90)
        if crypto_cash < 1.5:
            return [f"crypto skip: cash ${crypto_cash:.2f} (usd={free_usd:.2f}, cad≈${cad_usd:.2f})"]

        symbols = self._crypto_symbols()
        markets = await self.agent.analyze_markets(self.exchange, symbols)

        # Crypto positions only (spot holdings that are coins)
        crypto_pos = [
            p for p in (account.positions or [])
            if p.symbol in symbols or (p.symbol and p.symbol.endswith("/USD") and not p.symbol.startswith(("EUR", "GBP", "AUD", "USD")))
        ]
        crypto_account = AccountSnapshot(
            equity=max(budget, crypto_cash),
            available_balance=crypto_cash,
            used_margin=0.0,
            unrealized_pnl=sum(float(p.unrealized_pnl or 0) for p in crypto_pos),
            realized_pnl_today=0.0,
            peak_equity=max(budget, crypto_cash),
            drawdown_pct=0.0,
            positions=crypto_pos,
            mode=account.mode,
        )

        # Aggressive temporary profile for crypto opens
        prev_profile = self.risk._profile
        self.risk.set_profile(RiskProfile.AGGRESSIVE)

        parts: list[str] = [f"crypto ${crypto_cash:.2f}/{budget:.2f}"]
        try:
            auto_closes = await self._zero_fee_auto_exits(crypto_account, markets)
            for decision in auto_closes:
                # Size close against full live account (need real balances)
                result = await self.executor.execute(decision, account)
                if result.get("ok") and not result.get("rejected"):
                    pnl = float(result.get("pnl") or 0)
                    self.buckets.record_crypto_profit(pnl)
                    parts.append(f"CRYPTO close {decision.symbol} {pnl:+.4f}")
                    account = await self.exchange.get_account_snapshot(
                        peak_equity=float(await self.state.get_kv("peak_equity", 0) or 0)
                    )
                    crypto_account.positions = [
                        p for p in account.positions if p.symbol in symbols
                    ]

            goal = await self.state.get_active_goal()
            crypto_goal = TradingGoal(
                goal_type=GoalType.PROFIT_USD,
                target_profit_usd=max(0.5, float(getattr(goal, "target_profit_usd", None) or 0.5)),
                risk_profile=RiskProfile.AGGRESSIVE,
                period="day",
                raw_text="fierce crypto scalp on leftover bucket — frequent small wins",
                language="en",
                active=True,
            )

            # Refresh cash after closes
            free_usd = float(await self.exchange.free_balance("USD"))
            crypto_cash = min(budget, max(0.0, free_usd - usd_buffer_for_fx)) * 0.98
            if crypto_cash < 1.5 and free_usd >= 1.5:
                crypto_cash = min(budget, free_usd * 0.90)
            crypto_account.available_balance = max(0.0, crypto_cash)
            crypto_account.equity = max(budget, crypto_cash)

            # Force momentum_scalp style for this decide call
            old_style = self.settings.trading_style
            object.__setattr__(self.settings, "trading_style", "momentum_scalp")
            try:
                batch = await self.agent.decide(
                    account=crypto_account,
                    markets=markets,
                    goal=crypto_goal,
                    risk_limits=self.risk.limits,
                    pnl_today=pnl_today,
                )
            finally:
                object.__setattr__(self.settings, "trading_style", old_style)

            for decision in batch.decisions:
                if decision.action == ActionType.OPEN_LONG:
                    # Spend from crypto bucket only
                    decision.size_pct_of_equity = max(
                        float(decision.size_pct_of_equity or 0),
                        55.0,  # fierce: use most of micro bucket
                    )
                    decision.confidence = max(float(decision.confidence or 0), 0.45)
                # Execute against crypto-capped account for sizing opens;
                # closes need live account positions
                exec_account = crypto_account if decision.action == ActionType.OPEN_LONG else account
                result = await self.executor.execute(decision, exec_account)
                act = decision.action.value if hasattr(decision.action, "value") else str(decision.action)
                if result.get("ok") and not result.get("rejected"):
                    parts.append(f"CRYPTO {act} {decision.symbol}")
                    if decision.action in {ActionType.CLOSE, ActionType.REDUCE}:
                        self.buckets.record_crypto_profit(float(result.get("pnl") or 0))
                    if decision.action == ActionType.OPEN_LONG:
                        # Shrink virtual crypto cash after fill
                        spent = float(result.get("amount") or 0) * float(result.get("price") or 0)
                        crypto_account.available_balance = max(
                            0.0, crypto_account.available_balance - spent
                        )
                    account = await self.exchange.get_account_snapshot(
                        peak_equity=float(await self.state.get_kv("peak_equity", 0) or 0)
                    )
                elif result.get("rejected") or not result.get("ok"):
                    why = result.get("reason") or result.get("error") or "rejected"
                    if decision.action == ActionType.OPEN_LONG:
                        parts.append(f"crypto skip {decision.symbol}:{why}")
                if len(parts) > 8:
                    break
            if self.agent.last_reasoning:
                parts.append(f"cryptoAI:{(self.agent.last_reasoning or '')[:100]}")
        finally:
            self.risk.set_profile(prev_profile)

        return parts

    async def _zero_fee_auto_exits(
        self,
        account: Any,
        markets: list[Any],
    ) -> list[TradeDecision]:
        """Close winners with tiny green fast — better small win than long wait."""
        if not getattr(self.settings, "zero_fee_mode", True):
            return []
        if not account.positions:
            return []
        min_tp = float(getattr(self.settings, "min_take_profit_pct", 0.04))
        lock_tp = max(min_tp * 1.5, 0.08)  # bank quickly
        out: list[TradeDecision] = []
        for p in account.positions:
            if p.side != Side.LONG or p.entry_price <= 0 or p.mark_price <= 0:
                continue
            pnl_pct = ((p.mark_price - p.entry_price) / p.entry_price) * 100.0
            if pnl_pct < min_tp:
                continue
            m = next((x for x in markets if x.symbol == p.symbol), None)
            ind = (m.indicators if m else None) or {}
            book = (m.order_book if m else None) or {}
            mom = float(ind.get("momentum_5m_pct") or 0.0)
            rsi = ind.get("rsi")
            pressure = str(book.get("pressure") or "neutral")
            # Fierce: any green past min_tp is enough; don't wait for moon
            cool = (
                True
                if pnl_pct >= lock_tp
                else (
                    mom < 0.15
                    or pressure == "ask_heavy"
                    or (rsi is not None and float(rsi) >= 62)
                    or pnl_pct >= min_tp
                )
            )
            if not cool:
                continue
            out.append(
                TradeDecision(
                    action=ActionType.CLOSE,
                    symbol=p.symbol,
                    side=p.side,
                    confidence=0.9,
                    reasoning=(
                        f"Quick small TP: +{pnl_pct:.3f}% "
                        f"(min={min_tp:.2f}%) mom5m={mom:.3f} "
                        f"rsi={rsi} book={pressure}"
                    ),
                    take_profit_pct=round(pnl_pct, 3),
                )
            )
        return out

    async def _maybe_daily_report(
        self,
        equity: float,
        pnl_today: float,
        goal: TradingGoal | None,
    ) -> None:
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        hour = datetime.now(timezone.utc).hour
        if hour >= 21 and self._last_report_day != today:
            self._last_report_day = today
            text = await self.format_report(lang="ru")
            await self.notify(text)

    # --- User-facing actions ---
    async def handle_user_text(self, text: str) -> str:
        peak = float(await self.state.get_kv("peak_equity", 0.0) or 0.0)
        account = await self.exchange.get_account_snapshot(peak_equity=peak)
        interpreted = self.goals.interpret(text, equity=account.equity)

        if not interpreted.understood or interpreted.goal is None:
            return interpreted.reply_text

        goal = interpreted.goal

        if goal.goal_type == GoalType.STATUS:
            return await self.format_status(lang=interpreted.language)

        if goal.goal_type == GoalType.REPORT:
            return await self.format_report(lang=interpreted.language)

        if goal.goal_type == GoalType.STOP_TRADING:
            await self.state.save_status_fields(trading_enabled=False)
            await self.breaker.trip(BreakerReason.MANUAL_STOP, detail="User stop")
            return interpreted.reply_text

        if goal.goal_type == GoalType.CLOSE_ALL:
            await self.executor.emergency_flatten()
            return interpreted.reply_text

        if goal.goal_type == GoalType.SET_PROFILE:
            self.risk.set_profile(goal.risk_profile)
            await self.state.save_status_fields(risk_profile=goal.risk_profile)
            return interpreted.reply_text

        # Profit goals
        if interpreted.is_aggressive:
            return interpreted.reply_text

        self.risk.set_profile(goal.risk_profile)
        await self.state.save_status_fields(
            risk_profile=goal.risk_profile,
            trading_enabled=True,
        )
        # Clear manual stop if user sets a new goal
        if self.breaker.reason and "manual_stop" in (self.breaker.reason or ""):
            await self.breaker.reset(force_daily=False)
            # reset may fail on daily halt — that's ok
            if not self.breaker.trading_allowed and not self.breaker.is_daily_halted:
                await self.breaker.reset(force_daily=True)

        await self.state.save_goal(goal)
        self._goal_reached_notified = False
        return interpreted.reply_text

    async def emergency_stop(self) -> str:
        await self.state.save_status_fields(trading_enabled=False)
        await self.breaker.trip(BreakerReason.MANUAL_STOP, detail="emergency_stop")
        orders = await self.executor.emergency_flatten()
        return (
            f"🛑 EMERGENCY STOP\n"
            f"Trading disabled. Closed {len(orders)} order(s).\n"
            f"Circuit breaker active."
        )

    async def resume_trading(self) -> str:
        ok = await self.breaker.reset(force_daily=False)
        if not ok:
            return (
                "❌ Cannot resume: daily loss halt is active until next UTC day.\n"
                "Safety rules cannot be overridden."
            )
        await self.state.save_status_fields(trading_enabled=True)
        return "✅ Trading resumed (within risk limits)."

    async def get_status_model(self, *, live: bool = True):
        peak = float(await self.state.get_kv("peak_equity", 0.0) or 0.0)
        equity = 0.0
        open_pos = 0
        if live:
            try:
                account = await self.exchange.get_account_snapshot(peak_equity=peak)
                equity = account.equity
                open_pos = len(account.positions)
            except Exception:  # noqa: BLE001
                live = False
        if not live:
            last = await self.state.get_kv("last_equity", {}) or {}
            equity = float(last.get("equity") or peak or 0)
            open_pos = int(self.buckets.open_slot_count())

        return await self.state.build_bot_status(
            running=self._running,
            mode=self.settings.trading_mode,
            circuit_breaker_active=self.breaker.is_tripped,
            circuit_breaker_reason=self.breaker.reason,
            daily_halted=self.breaker.is_daily_halted,
            equity=equity,
            open_positions=open_pos,
            last_decision_summary=self._last_status_summary,
            last_error=self._last_error,
        )

    async def format_status(self, lang: str = "ru") -> str:
        st = await self.get_status_model()
        goal_line = "—"
        if st.current_goal:
            g = st.current_goal
            if g.target_profit_usd:
                goal_line = f"${g.target_profit_usd:g}"
            elif g.target_profit_pct:
                goal_line = f"{g.target_profit_pct:g}%"
            goal_line += f" ({g.risk_profile.value})"

        if lang == "ru":
            return (
                f"📊 *AstraForge статус*\n"
                f"Режим: `{st.mode.value}`\n"
                f"Equity: `${st.equity:,.2f}`\n"
                f"PnL сегодня: `${st.pnl_today:,.2f}`\n"
                f"Цель: {goal_line}\n"
                f"Прогресс цели: `{st.goal_progress_pct:.1f}%`\n"
                f"Позиций: `{st.open_positions}`\n"
                f"Профиль риска: `{st.risk_profile.value}`\n"
                f"Торговля: `{'ON' if st.trading_enabled else 'OFF'}`\n"
                f"Circuit breaker: `{'ACTIVE — ' + (st.circuit_breaker_reason or '') if st.circuit_breaker_active else 'ok'}`\n"
                f"Последнее решение: {st.last_decision_summary or '—'}"
            )
        return (
            f"📊 *AstraForge status*\n"
            f"Mode: `{st.mode.value}`\n"
            f"Equity: `${st.equity:,.2f}`\n"
            f"PnL today: `${st.pnl_today:,.2f}`\n"
            f"Goal: {goal_line}\n"
            f"Goal progress: `{st.goal_progress_pct:.1f}%`\n"
            f"Positions: `{st.open_positions}`\n"
            f"Risk profile: `{st.risk_profile.value}`\n"
            f"Trading: `{'ON' if st.trading_enabled else 'OFF'}`\n"
            f"Circuit breaker: `{'ACTIVE — ' + (st.circuit_breaker_reason or '') if st.circuit_breaker_active else 'ok'}`\n"
            f"Last decision: {st.last_decision_summary or '—'}"
        )

    async def format_report(self, lang: str = "ru") -> str:
        st = await self.get_status_model()
        decisions = await self.state.recent_decisions(5)
        trades = await self.state.recent_trades(10)
        lines = []
        if lang == "ru":
            lines.append("📈 *Дневной отчёт AstraForge*")
        else:
            lines.append("📈 *AstraForge daily report*")
        lines.append(f"Equity: ${st.equity:,.2f} | PnL: ${st.pnl_today:,.2f}")
        lines.append(f"Mode: {st.mode.value} | Positions: {st.open_positions}")
        lines.append("\n*Recent reasoning:*")
        for d in decisions[:3]:
            lines.append(f"• {d.get('reasoning') or d.get('batch', {}).get('goal_progress_note', '—')}")
        lines.append("\n*Recent trades:*")
        if not trades:
            lines.append("• —")
        for t in trades[:5]:
            lines.append(
                f"• {t.action} {t.symbol} {t.side} size={t.size:.4f} @ {t.price:.4f}"
            )
        return "\n".join(lines)

    async def startup_message(self) -> str:
        mode = self.settings.trading_mode.value
        if self.settings.trading_mode == TradingMode.LIVE:
            return (
                "⚠️ Бот запущен в LIVE mode. Реальные средства под риском.\n"
                "Готов принимать цели. Напиши, сколько хочешь заработать сегодня."
            )
        return (
            f"Бот запущен в {mode} mode. Готов принимать цели. "
            f"Напиши, сколько хочешь заработать сегодня."
        )
