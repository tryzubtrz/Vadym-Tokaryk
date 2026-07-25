"""SQLite-backed state persistence for goals, equity, trades, decisions."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import aiosqlite

from astraforge.core.models import (
    BotStatus,
    EquityPoint,
    RiskProfile,
    TradeRecord,
    TradingGoal,
    TradingMode,
)
from astraforge.utils.logging import get_logger

logger = get_logger(__name__)


SCHEMA = """
CREATE TABLE IF NOT EXISTS kv (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS goals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payload TEXT NOT NULL,
    active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS trades (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    symbol TEXT NOT NULL,
    side TEXT NOT NULL,
    action TEXT NOT NULL,
    size REAL NOT NULL,
    price REAL NOT NULL,
    leverage REAL NOT NULL,
    pnl REAL NOT NULL DEFAULT 0,
    reasoning TEXT,
    mode TEXT NOT NULL,
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS equity_curve (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    equity REAL NOT NULL,
    pnl_today REAL NOT NULL DEFAULT 0,
    timestamp TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS decisions_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    payload TEXT NOT NULL,
    created_at TEXT NOT NULL
);
"""


def _utcnow() -> str:
    return datetime.now(timezone.utc).isoformat()


class StateManager:
    """Async SQLite state store — survives restarts."""

    def __init__(self, db_path: str) -> None:
        self.db_path = db_path
        self._db: aiosqlite.Connection | None = None

    async def connect(self) -> None:
        Path(self.db_path).parent.mkdir(parents=True, exist_ok=True)
        self._db = await aiosqlite.connect(self.db_path)
        self._db.row_factory = aiosqlite.Row
        await self._db.executescript(SCHEMA)
        await self._db.commit()
        logger.info("state_db_connected", path=self.db_path)

    async def close(self) -> None:
        if self._db:
            await self._db.close()
            self._db = None

    @property
    def db(self) -> aiosqlite.Connection:
        if self._db is None:
            raise RuntimeError("StateManager not connected")
        return self._db

    # --- KV helpers ---
    async def set_kv(self, key: str, value: Any) -> None:
        payload = json.dumps(value, default=str)
        await self.db.execute(
            """
            INSERT INTO kv(key, value, updated_at) VALUES (?, ?, ?)
            ON CONFLICT(key) DO UPDATE SET value=excluded.value, updated_at=excluded.updated_at
            """,
            (key, payload, _utcnow()),
        )
        await self.db.commit()

    async def get_kv(self, key: str, default: Any = None) -> Any:
        cur = await self.db.execute("SELECT value FROM kv WHERE key = ?", (key,))
        row = await cur.fetchone()
        if not row:
            return default
        return json.loads(row["value"])

    # --- Goals ---
    async def save_goal(self, goal: TradingGoal) -> None:
        await self.db.execute("UPDATE goals SET active = 0 WHERE active = 1")
        await self.db.execute(
            "INSERT INTO goals(payload, active, created_at) VALUES (?, 1, ?)",
            (goal.model_dump_json(), _utcnow()),
        )
        await self.set_kv("current_goal", goal.model_dump(mode="json"))
        await self.db.commit()
        logger.info("goal_saved", goal_type=goal.goal_type.value)

    async def get_active_goal(self) -> TradingGoal | None:
        cached = await self.get_kv("current_goal")
        if cached:
            g = TradingGoal.model_validate(cached)
            if g.active:
                return g
        cur = await self.db.execute(
            "SELECT payload FROM goals WHERE active = 1 ORDER BY id DESC LIMIT 1"
        )
        row = await cur.fetchone()
        if not row:
            return None
        return TradingGoal.model_validate_json(row["payload"])

    async def clear_goal(self) -> None:
        await self.db.execute("UPDATE goals SET active = 0 WHERE active = 1")
        await self.set_kv("current_goal", None)
        await self.db.commit()

    # --- Trades ---
    async def record_trade(self, trade: TradeRecord) -> int:
        cur = await self.db.execute(
            """
            INSERT INTO trades(symbol, side, action, size, price, leverage, pnl, reasoning, mode, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                trade.symbol,
                trade.side,
                trade.action,
                trade.size,
                trade.price,
                trade.leverage,
                trade.pnl,
                trade.reasoning,
                trade.mode,
                trade.created_at.isoformat(),
            ),
        )
        await self.db.commit()
        return int(cur.lastrowid or 0)

    async def recent_trades(self, limit: int = 50) -> list[TradeRecord]:
        cur = await self.db.execute(
            "SELECT * FROM trades ORDER BY id DESC LIMIT ?", (limit,)
        )
        rows = await cur.fetchall()
        result: list[TradeRecord] = []
        for r in rows:
            result.append(
                TradeRecord(
                    id=r["id"],
                    symbol=r["symbol"],
                    side=r["side"],
                    action=r["action"],
                    size=r["size"],
                    price=r["price"],
                    leverage=r["leverage"],
                    pnl=r["pnl"],
                    reasoning=r["reasoning"] or "",
                    mode=r["mode"],
                    created_at=datetime.fromisoformat(r["created_at"]),
                )
            )
        return result

    # --- Equity ---
    async def record_equity(self, point: EquityPoint) -> None:
        await self.db.execute(
            "INSERT INTO equity_curve(equity, pnl_today, timestamp) VALUES (?, ?, ?)",
            (point.equity, point.pnl_today, point.timestamp.isoformat()),
        )
        await self.set_kv(
            "last_equity",
            {"equity": point.equity, "pnl_today": point.pnl_today, "ts": point.timestamp.isoformat()},
        )
        await self.db.commit()

    async def equity_history(self, limit: int = 500) -> list[EquityPoint]:
        cur = await self.db.execute(
            "SELECT equity, pnl_today, timestamp FROM equity_curve ORDER BY id DESC LIMIT ?",
            (limit,),
        )
        rows = await cur.fetchall()
        return [
            EquityPoint(
                equity=r["equity"],
                pnl_today=r["pnl_today"],
                timestamp=datetime.fromisoformat(r["timestamp"]),
            )
            for r in reversed(rows)
        ]

    # --- Decisions log ---
    async def log_decision(self, payload: dict[str, Any]) -> None:
        await self.db.execute(
            "INSERT INTO decisions_log(payload, created_at) VALUES (?, ?)",
            (json.dumps(payload, default=str), _utcnow()),
        )
        await self.set_kv("last_decision", payload)
        await self.db.commit()

    async def recent_decisions(self, limit: int = 20) -> list[dict[str, Any]]:
        cur = await self.db.execute(
            "SELECT payload, created_at FROM decisions_log ORDER BY id DESC LIMIT ?",
            (limit,),
        )
        rows = await cur.fetchall()
        out: list[dict[str, Any]] = []
        for r in rows:
            item = json.loads(r["payload"])
            item["_created_at"] = r["created_at"]
            out.append(item)
        return out

    # --- Bot status helpers ---
    async def save_status_fields(
        self,
        *,
        risk_profile: RiskProfile | None = None,
        mode: TradingMode | None = None,
        trading_enabled: bool | None = None,
        peak_equity: float | None = None,
        day_start_equity: float | None = None,
        day_key: str | None = None,
        pnl_today: float | None = None,
    ) -> None:
        if risk_profile is not None:
            await self.set_kv("risk_profile", risk_profile.value)
        if mode is not None:
            await self.set_kv("trading_mode", mode.value)
        if trading_enabled is not None:
            await self.set_kv("trading_enabled", trading_enabled)
        if peak_equity is not None:
            await self.set_kv("peak_equity", peak_equity)
        if day_start_equity is not None:
            await self.set_kv("day_start_equity", day_start_equity)
        if day_key is not None:
            await self.set_kv("day_key", day_key)
        if pnl_today is not None:
            await self.set_kv("pnl_today", pnl_today)

    async def build_bot_status(
        self,
        *,
        running: bool,
        mode: TradingMode,
        circuit_breaker_active: bool,
        circuit_breaker_reason: str | None,
        daily_halted: bool,
        equity: float,
        open_positions: int,
        last_decision_summary: str = "",
        last_error: str | None = None,
    ) -> BotStatus:
        goal = await self.get_active_goal()
        pnl_today = float(await self.get_kv("pnl_today", 0.0) or 0.0)
        profile_raw = await self.get_kv("risk_profile", RiskProfile.BALANCED.value)
        try:
            profile = RiskProfile(profile_raw)
        except ValueError:
            profile = RiskProfile.BALANCED

        progress = 0.0
        if goal and goal.target_profit_usd and goal.target_profit_usd > 0:
            progress = max(0.0, min(100.0, (pnl_today / goal.target_profit_usd) * 100.0))
        elif goal and goal.target_profit_pct and goal.target_profit_pct > 0 and equity > 0:
            # Approximate using pnl vs equity
            pct_now = (pnl_today / equity) * 100.0
            progress = max(0.0, min(100.0, (pct_now / goal.target_profit_pct) * 100.0))

        trading_enabled = bool(await self.get_kv("trading_enabled", True))

        return BotStatus(
            running=running,
            trading_enabled=trading_enabled and not circuit_breaker_active,
            mode=mode,
            circuit_breaker_active=circuit_breaker_active,
            circuit_breaker_reason=circuit_breaker_reason,
            daily_halted=daily_halted,
            current_goal=goal,
            equity=equity,
            pnl_today=pnl_today,
            goal_progress_pct=progress,
            open_positions=open_positions,
            last_decision_summary=last_decision_summary,
            risk_profile=profile,
            last_error=last_error,
        )
