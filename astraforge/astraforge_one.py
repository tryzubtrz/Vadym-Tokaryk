#!/usr/bin/env python3
"""
AstraForge AI — ONE FILE
========================
Autonomous crypto perpetual futures agent.

Minimal start (paper mode, no Telegram/LLM needed):
    pip install ccxt pandas httpx aiosqlite pydantic
    python astraforge_one.py

It will ask for your exchange API key + secret, then start trading
in paper/testnet mode with built-in safety limits.

Optional env vars (or answers at prompts):
    EXCHANGE_ID, EXCHANGE_API_KEY, EXCHANGE_API_SECRET
    TELEGRAM_BOT_TOKEN, TELEGRAM_ALLOWED_USER_IDS
    LLM_API_KEY, LLM_PROVIDER, LLM_MODEL
    TRADING_MODE=paper|live   LIVE_CONFIRMED=true (required for live)

Hard safety (cannot be disabled):
    daily loss 2.5% | max DD 7% | leverage ≤5x | position ≤4% equity
"""

from __future__ import annotations

import asyncio
import json
import os
import re
import sqlite3
import sys
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Any

# ---------------------------------------------------------------------------
# Optional deps — import with clear errors
# ---------------------------------------------------------------------------
try:
    import ccxt.async_support as ccxt
except ImportError:
    print("Install deps first:\n  pip install ccxt pandas httpx aiosqlite pydantic")
    raise SystemExit(1)

try:
    import pandas as pd
except ImportError:
    pd = None  # type: ignore

try:
    import httpx
except ImportError:
    httpx = None  # type: ignore

# ---------------------------------------------------------------------------
# HARD SAFETY CEILINGS — not overridable
# ---------------------------------------------------------------------------
HARD_MAX_DAILY_LOSS_PCT = 2.5
HARD_MAX_DRAWDOWN_PCT = 7.0
HARD_MAX_LEVERAGE = 5.0
HARD_MAX_POSITION_PCT = 4.0
HARD_MAX_OPEN_POSITIONS = 3
AGENT_INTERVAL_SEC = 60
SYMBOLS = [
    "BTC/USDT:USDT",
    "ETH/USDT:USDT",
    "SOL/USDT:USDT",
    "BNB/USDT:USDT",
    "XRP/USDT:USDT",
]
DB_PATH = Path(__file__).resolve().parent / "data" / "astraforge_one.db"
PAPER_START_EQUITY = 10_000.0


# ============================= Models ======================================


class Action(str, Enum):
    OPEN_LONG = "open_long"
    OPEN_SHORT = "open_short"
    CLOSE = "close"
    HOLD = "hold"


@dataclass
class Goal:
    target_usd: float | None = None
    target_pct: float | None = None
    profile: str = "balanced"
    raw: str = ""
    lang: str = "en"


@dataclass
class Position:
    symbol: str
    side: str
    size: float
    entry: float
    mark: float = 0.0
    upnl: float = 0.0
    leverage: float = 1.0


@dataclass
class Decision:
    action: Action
    symbol: str | None = None
    size_pct: float = 0.0
    leverage: float = 1.0
    confidence: float = 0.0
    reasoning: str = ""


@dataclass
class Config:
    exchange_id: str = "binance"
    api_key: str = ""
    api_secret: str = ""
    mode: str = "paper"  # paper | live
    live_confirmed: bool = False
    telegram_token: str = ""
    telegram_user_ids: list[int] = field(default_factory=list)
    llm_provider: str = "openai"
    llm_model: str = "gpt-4o-mini"
    llm_api_key: str = ""
    llm_base_url: str | None = None


# ============================= Helpers =====================================


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def today_key() -> str:
    return utcnow().strftime("%Y-%m-%d")


def detect_lang(text: str) -> str:
    cyr = sum(1 for c in text if "а" <= c.lower() <= "я" or c.lower() == "ё")
    lat = sum(1 for c in text if "a" <= c.lower() <= "z")
    return "ru" if cyr > lat else "en"


def ask(prompt: str, default: str = "", secret: bool = False) -> str:
    env_hint = f" [{default}]" if default else ""
    try:
        if secret:
            import getpass

            val = getpass.getpass(f"{prompt}{env_hint}: ").strip()
        else:
            val = input(f"{prompt}{env_hint}: ").strip()
    except EOFError:
        val = ""
    return val or default


def load_config_interactive() -> Config:
    """Load from env, prompt only for missing exchange keys."""
    cfg = Config(
        exchange_id=os.getenv("EXCHANGE_ID", "binance").lower(),
        api_key=os.getenv("EXCHANGE_API_KEY", ""),
        api_secret=os.getenv("EXCHANGE_API_SECRET", ""),
        mode=os.getenv("TRADING_MODE", "paper").lower(),
        live_confirmed=os.getenv("LIVE_CONFIRMED", "false").lower() in ("1", "true", "yes"),
        telegram_token=os.getenv("TELEGRAM_BOT_TOKEN", ""),
        llm_provider=os.getenv("LLM_PROVIDER", "openai").lower(),
        llm_model=os.getenv("LLM_MODEL", "gpt-4o-mini"),
        llm_api_key=os.getenv("LLM_API_KEY", ""),
        llm_base_url=os.getenv("LLM_BASE_URL") or None,
    )
    ids = os.getenv("TELEGRAM_ALLOWED_USER_IDS", "")
    cfg.telegram_user_ids = [int(x) for x in ids.split(",") if x.strip().isdigit()]

    print("\n=== AstraForge AI (one-file) ===")
    print("Paper mode by default. Live needs LIVE_CONFIRMED=true.\n")

    if not cfg.api_key:
        cfg.exchange_id = ask("Exchange (binance/bybit)", cfg.exchange_id).lower()
        cfg.api_key = ask("Exchange API KEY (Read + Futures only, NO withdraw)")
        cfg.api_secret = ask("Exchange API SECRET", secret=True)
    if not cfg.api_key or not cfg.api_secret:
        print("ERROR: Exchange API key + secret are required.")
        raise SystemExit(1)

    if not cfg.telegram_token:
        tg = ask("Telegram bot token (Enter to skip — use console chat)")
        cfg.telegram_token = tg
        if tg and not cfg.telegram_user_ids:
            uid = ask("Your Telegram user id (from @userinfobot)")
            if uid.isdigit():
                cfg.telegram_user_ids = [int(uid)]

    if not cfg.llm_api_key:
        print("⚠ For REAL AI brain (reads candles + order book) you NEED an LLM key.")
        print("  Get one: https://platform.openai.com/api-keys  (or Anthropic / xAI)")
        llm = ask("LLM API key (Enter = weak heuristic fallback, NOT real AI)")
        cfg.llm_api_key = llm

    if cfg.mode == "live" and not cfg.live_confirmed:
        print("⚠ LIVE requested but LIVE_CONFIRMED!=true → forcing PAPER.")
        cfg.mode = "paper"

    print(f"\nMode: {cfg.mode.upper()} | Exchange: {cfg.exchange_id}")
    print(f"Telegram: {'ON' if cfg.telegram_token else 'console'}")
    print(f"LLM: {'ON' if cfg.llm_api_key else 'heuristic'}")
    print(
        f"Safety: daily≤{HARD_MAX_DAILY_LOSS_PCT}% DD≤{HARD_MAX_DRAWDOWN_PCT}% "
        f"lev≤{HARD_MAX_LEVERAGE}x pos≤{HARD_MAX_POSITION_PCT}%\n"
    )
    return cfg


# ============================= State (SQLite) ==============================


class State:
    def __init__(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        self.conn = sqlite3.connect(path)
        self.conn.row_factory = sqlite3.Row
        self.conn.executescript(
            """
            CREATE TABLE IF NOT EXISTS kv(key TEXT PRIMARY KEY, value TEXT);
            CREATE TABLE IF NOT EXISTS trades(
                id INTEGER PRIMARY KEY, symbol TEXT, side TEXT, action TEXT,
                size REAL, price REAL, leverage REAL, pnl REAL, reasoning TEXT,
                ts TEXT
            );
            CREATE TABLE IF NOT EXISTS decisions(
                id INTEGER PRIMARY KEY, payload TEXT, ts TEXT
            );
            """
        )
        self.conn.commit()

    def set(self, key: str, value: Any) -> None:
        self.conn.execute(
            "INSERT INTO kv(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value",
            (key, json.dumps(value, default=str)),
        )
        self.conn.commit()

    def get(self, key: str, default: Any = None) -> Any:
        row = self.conn.execute("SELECT value FROM kv WHERE key=?", (key,)).fetchone()
        return json.loads(row["value"]) if row else default

    def log_trade(self, **kw: Any) -> None:
        self.conn.execute(
            "INSERT INTO trades(symbol,side,action,size,price,leverage,pnl,reasoning,ts) "
            "VALUES(?,?,?,?,?,?,?,?,?)",
            (
                kw.get("symbol"),
                kw.get("side"),
                kw.get("action"),
                kw.get("size", 0),
                kw.get("price", 0),
                kw.get("leverage", 1),
                kw.get("pnl", 0),
                kw.get("reasoning", ""),
                utcnow().isoformat(),
            ),
        )
        self.conn.commit()

    def log_decision(self, payload: dict) -> None:
        self.conn.execute(
            "INSERT INTO decisions(payload,ts) VALUES(?,?)",
            (json.dumps(payload, default=str), utcnow().isoformat()),
        )
        self.conn.commit()

    def recent_decisions(self, n: int = 5) -> list[dict]:
        rows = self.conn.execute(
            "SELECT payload FROM decisions ORDER BY id DESC LIMIT ?", (n,)
        ).fetchall()
        return [json.loads(r["payload"]) for r in rows]


# ============================= Circuit + Risk ==============================


class CircuitBreaker:
    def __init__(self) -> None:
        self.tripped = False
        self.reason = ""
        self.daily_halt = False
        self.halt_day: str | None = None

    @property
    def trading_allowed(self) -> bool:
        if self.daily_halt and self.halt_day != today_key():
            self.daily_halt = False
            self.halt_day = None
            self.tripped = False
            self.reason = ""
        return not self.tripped and not self.daily_halt

    def trip(self, reason: str, *, daily: bool = False) -> None:
        self.tripped = True
        self.reason = reason
        if daily:
            self.daily_halt = True
            self.halt_day = today_key()
        print(f"🚨 CIRCUIT BREAKER: {reason}")

    def reset(self, force_daily: bool = False) -> bool:
        if self.daily_halt and self.halt_day == today_key() and not force_daily:
            return False
        self.tripped = False
        self.reason = ""
        if force_daily:
            self.daily_halt = False
            self.halt_day = None
        return True


class Risk:
    def __init__(self, breaker: CircuitBreaker) -> None:
        self.breaker = breaker
        self.day_start: float | None = None
        self.day: str | None = None
        self.peak = 0.0
        self.limits = {
            "daily_loss_pct": HARD_MAX_DAILY_LOSS_PCT,
            "max_dd_pct": min(6.0, HARD_MAX_DRAWDOWN_PCT),
            "max_leverage": HARD_MAX_LEVERAGE,
            "max_position_pct": min(3.5, HARD_MAX_POSITION_PCT),
        }

    def set_profile(self, profile: str) -> None:
        profiles = {
            "conservative": (1.5, 4.0, 3.0, 2.0),
            "balanced": (2.5, 6.0, 5.0, 3.5),
            "aggressive": (2.5, 7.0, 5.0, 4.0),
        }
        d, dd, lev, pos = profiles.get(profile, profiles["balanced"])
        self.limits = {
            "daily_loss_pct": min(d, HARD_MAX_DAILY_LOSS_PCT),
            "max_dd_pct": min(dd, HARD_MAX_DRAWDOWN_PCT),
            "max_leverage": min(lev, HARD_MAX_LEVERAGE),
            "max_position_pct": min(pos, HARD_MAX_POSITION_PCT),
        }

    def check_account(self, equity: float) -> str | None:
        if self.day != today_key():
            self.day = today_key()
            self.day_start = equity
        if equity > self.peak:
            self.peak = equity
        start = self.day_start or equity
        daily_loss = 0.0
        if start > 0 and equity < start:
            daily_loss = (start - equity) / start * 100
        dd = ((self.peak - equity) / self.peak * 100) if self.peak > 0 else 0.0
        if daily_loss >= self.limits["daily_loss_pct"]:
            self.breaker.trip(f"Daily loss {daily_loss:.2f}%", daily=True)
            return self.breaker.reason
        if dd >= self.limits["max_dd_pct"]:
            self.breaker.trip(f"Max drawdown {dd:.2f}%")
            return self.breaker.reason
        if not self.breaker.trading_allowed:
            return self.breaker.reason or "breaker"
        return None

    def clamp(self, d: Decision) -> Decision | None:
        if d.action in (Action.HOLD, Action.CLOSE):
            return d
        if not self.breaker.trading_allowed:
            return None
        d.leverage = min(max(1.0, d.leverage), self.limits["max_leverage"])
        d.size_pct = min(max(0.0, d.size_pct), self.limits["max_position_pct"])
        if d.confidence < 0.35 or d.size_pct <= 0:
            return None
        return d

    def max_realistic_target(self, equity: float) -> float:
        budget = equity * (self.limits["daily_loss_pct"] / 100)
        return round(budget * 2.4, 2)

    def too_aggressive(self, equity: float, target_usd: float) -> bool:
        return target_usd > self.max_realistic_target(equity) * 1.25


# ============================= Exchange ====================================


class Exchange:
    def __init__(self, cfg: Config, breaker: CircuitBreaker) -> None:
        self.cfg = cfg
        self.breaker = breaker
        self.ex: Any = None
        self.markets_ok = False
        self.paper_equity = PAPER_START_EQUITY
        self.paper_pos: dict[str, dict] = {}
        self.realized_today = 0.0

    async def connect(self) -> None:
        cls = {"binance": ccxt.binanceusdm, "bybit": ccxt.bybit}.get(self.cfg.exchange_id)
        if not cls:
            raise SystemExit(f"Unsupported exchange: {self.cfg.exchange_id}")
        self.ex = cls(
            {
                "apiKey": self.cfg.api_key,
                "secret": self.cfg.api_secret,
                "enableRateLimit": True,
                "options": {"defaultType": "swap"},
            }
        )
        if self.cfg.mode == "paper":
            try:
                self.ex.set_sandbox_mode(True)
                print("✓ Sandbox/testnet enabled")
            except Exception as e:  # noqa: BLE001
                print(f"Sandbox note: {e}")
        try:
            await self.ex.load_markets()
            self.markets_ok = True
            print(f"✓ Connected to {self.cfg.exchange_id} ({len(self.ex.markets)} markets)")
        except Exception as e:  # noqa: BLE001
            print(f"⚠ Exchange API connect failed ({e})")
            if self.cfg.mode == "paper":
                print("→ Using local paper ledger (still safe).")
            else:
                self.breaker.trip(f"API connect failed: {e}")
                raise

    async def close(self) -> None:
        if self.ex:
            await self.ex.close()

    async def ohlcv(self, symbol: str, limit: int = 100) -> list:
        if not self.markets_ok:
            return self._synthetic(limit)
        try:
            return await self.ex.fetch_ohlcv(symbol, "15m", limit=limit)
        except Exception as e:  # noqa: BLE001
            self.breaker.trip(f"OHLCV error: {e}")
            return []

    async def order_book(self, symbol: str, limit: int = 20) -> dict:
        """L2 book summary for the AI brain ('read the book')."""
        if not self.markets_ok:
            mid = 50_000.0 if "BTC" in symbol else 3_000.0
            bids = [[mid - i * 5, 1.0 + i * 0.1] for i in range(1, 11)]
            asks = [[mid + i * 5, 1.0 + i * 0.1] for i in range(1, 11)]
            return _summarize_book({"bids": bids, "asks": asks})
        try:
            raw = await self.ex.fetch_order_book(symbol, limit=limit)
            return _summarize_book(raw)
        except Exception as e:  # noqa: BLE001
            return {"error": str(e), "imbalance": 0.0, "pressure": "neutral"}

    async def ticker_price(self, symbol: str) -> float:
        if not self.markets_ok:
            return 50_000.0 if "BTC" in symbol else 3_000.0
        try:
            t = await self.ex.fetch_ticker(symbol)
            return float(t.get("last") or t.get("close") or 0) or 1.0
        except Exception as e:  # noqa: BLE001
            self.breaker.trip(f"Ticker error: {e}")
            return 0.0

    def positions(self) -> list[Position]:
        out = []
        for sym, p in self.paper_pos.items():
            out.append(
                Position(
                    symbol=sym,
                    side=p["side"],
                    size=p["size"],
                    entry=p["entry"],
                    mark=p.get("mark", p["entry"]),
                    upnl=p.get("upnl", 0.0),
                    leverage=p.get("leverage", 1.0),
                )
            )
        return out

    async def account(self) -> dict[str, Any]:
        # Paper mode always uses the local ledger (safe default for one-file).
        if self.cfg.mode == "paper":
            for sym, p in list(self.paper_pos.items()):
                price = await self.ticker_price(sym)
                if price > 0:
                    p["mark"] = price
                    d = 1 if p["side"] == "long" else -1
                    p["upnl"] = (price - p["entry"]) * p["size"] * d
            upnl = sum(p.get("upnl", 0) for p in self.paper_pos.values())
            equity = self.paper_equity + upnl
            return {
                "equity": equity,
                "upnl": upnl,
                "positions": self.positions(),
                "realized_today": self.realized_today,
            }

        try:
            bal = await self.ex.fetch_balance()
            usdt = bal.get("USDT") or {}
            total = float(usdt.get("total") or bal.get("total", {}).get("USDT") or 0)
            return {
                "equity": total,
                "upnl": 0.0,
                "positions": self.positions(),
                "realized_today": self.realized_today,
            }
        except Exception as e:  # noqa: BLE001
            self.breaker.trip(f"Balance error: {e}")
            return {
                "equity": 0.0,
                "upnl": 0.0,
                "positions": [],
                "realized_today": 0.0,
            }

    async def market_order(
        self, symbol: str, side: str, amount: float, *, reduce_only: bool = False
    ) -> dict:
        # Always use paper ledger in one-file for safety unless live+confirmed+markets
        use_live = self.cfg.mode == "live" and self.cfg.live_confirmed and self.markets_ok
        if not use_live:
            return await self._paper_fill(symbol, side, amount, reduce_only=reduce_only)
        try:
            params = {"reduceOnly": True} if reduce_only else {}
            return await self.ex.create_order(symbol, "market", side, amount, None, params)
        except Exception as e:  # noqa: BLE001
            self.breaker.trip(f"Order error: {e}")
            raise

    async def close_all(self) -> int:
        n = 0
        for pos in list(self.positions()):
            side = "sell" if pos.side == "long" else "buy"
            await self.market_order(pos.symbol, side, pos.size, reduce_only=True)
            n += 1
        self.paper_pos.clear()
        return n

    async def _paper_fill(
        self, symbol: str, side: str, amount: float, *, reduce_only: bool
    ) -> dict:
        price = await self.ticker_price(symbol)
        if symbol in self.paper_pos:
            p = self.paper_pos[symbol]
            d = 1 if p["side"] == "long" else -1
            p["mark"] = price
            p["upnl"] = (price - p["entry"]) * p["size"] * d

        if reduce_only or symbol in self.paper_pos:
            p = self.paper_pos.get(symbol)
            if not p:
                return {"status": "canceled"}
            closing = (p["side"] == "long" and side == "sell") or (
                p["side"] == "short" and side == "buy"
            )
            if closing:
                qty = min(amount, p["size"])
                d = 1 if p["side"] == "long" else -1
                pnl = (price - p["entry"]) * qty * d
                self.paper_equity += pnl
                self.realized_today += pnl
                p["size"] -= qty
                if p["size"] <= 1e-12:
                    del self.paper_pos[symbol]
                return {"status": "closed", "price": price, "amount": qty, "pnl": pnl}

        pos_side = "long" if side == "buy" else "short"
        if symbol in self.paper_pos and self.paper_pos[symbol]["side"] != pos_side:
            old = self.paper_pos[symbol]
            await self._paper_fill(
                symbol,
                "sell" if old["side"] == "long" else "buy",
                old["size"],
                reduce_only=True,
            )
        if symbol in self.paper_pos:
            p = self.paper_pos[symbol]
            total = p["size"] + amount
            p["entry"] = (p["entry"] * p["size"] + price * amount) / total
            p["size"] = total
            p["mark"] = price
        else:
            self.paper_pos[symbol] = {
                "side": pos_side,
                "size": amount,
                "entry": price,
                "mark": price,
                "leverage": 1.0,
                "upnl": 0.0,
            }
        return {"status": "closed", "price": price, "amount": amount, "pnl": 0.0}

    def _synthetic(self, limit: int) -> list:
        now = int(time.time() * 1000)
        step = 15 * 60 * 1000
        price = 50_000.0
        rows = []
        for i in range(limit):
            ts = now - (limit - i) * step
            o = price + ((i % 20) - 10) * 15
            c = o + ((i % 7) - 3) * 5
            rows.append([ts, o, o * 1.001, o * 0.999, c, 100 + i % 10])
            price = c
        return rows


# ============================= Indicators + AI =============================


def _summarize_book(raw: dict, depth: int = 10) -> dict[str, Any]:
    bids = (raw.get("bids") or [])[:depth]
    asks = (raw.get("asks") or [])[:depth]
    bid_vol = sum(float(x[1]) for x in bids) if bids else 0.0
    ask_vol = sum(float(x[1]) for x in asks) if asks else 0.0
    best_bid = float(bids[0][0]) if bids else 0.0
    best_ask = float(asks[0][0]) if asks else 0.0
    mid = (best_bid + best_ask) / 2 if best_bid and best_ask else 0.0
    spread = (best_ask - best_bid) if best_bid and best_ask else 0.0
    total = bid_vol + ask_vol
    imbalance = ((bid_vol - ask_vol) / total) if total > 0 else 0.0
    pressure = "neutral"
    if imbalance > 0.15:
        pressure = "bid_heavy"
    elif imbalance < -0.15:
        pressure = "ask_heavy"
    return {
        "best_bid": best_bid,
        "best_ask": best_ask,
        "mid": mid,
        "spread": spread,
        "bid_volume": round(bid_vol, 4),
        "ask_volume": round(ask_vol, 4),
        "imbalance": round(imbalance, 4),
        "pressure": pressure,
        "top_bids": [[float(p), float(s)] for p, s in bids[:5]],
        "top_asks": [[float(p), float(s)] for p, s in asks[:5]],
    }


def indicators(ohlcv: list) -> dict[str, Any]:
    if not ohlcv or len(ohlcv) < 30:
        return {"error": "few_candles"}
    if pd is None:
        closes = [r[4] for r in ohlcv]
        price = closes[-1]
        return {"price": price, "rsi": 50.0, "trend": "neutral", "macd_hist": 0.0}
    df = pd.DataFrame(ohlcv, columns=["ts", "open", "high", "low", "close", "volume"])
    close = df["close"]
    delta = close.diff()
    gain = delta.clip(lower=0).rolling(14).mean()
    loss = (-delta.clip(upper=0)).rolling(14).mean()
    rs = gain / loss.replace(0, pd.NA)
    rsi = float((100 - (100 / (1 + rs))).iloc[-1])
    ema_f = close.ewm(span=9, adjust=False).mean()
    ema_s = close.ewm(span=21, adjust=False).mean()
    trend = "bullish" if ema_f.iloc[-1] > ema_s.iloc[-1] else "bearish"
    macd = close.ewm(span=12, adjust=False).mean() - close.ewm(span=26, adjust=False).mean()
    signal = macd.ewm(span=9, adjust=False).mean()
    return {
        "price": float(close.iloc[-1]),
        "rsi": rsi,
        "trend": trend,
        "macd_hist": float((macd - signal).iloc[-1]),
    }


async def llm_decide(cfg: Config, context: dict) -> list[Decision] | None:
    if not cfg.llm_api_key or httpx is None:
        return None
    system = (
        "You are AstraForge AI trading brain for crypto perpetual futures. "
        "You READ candles + order_book (the book: bids/asks/imbalance/pressure) and DECIDE yourself. "
        "You are not a fixed rule script. Cite candle + book signals in reasoning. "
        "Return ONLY JSON: "
        '{"decisions":[{"action":"open_long|open_short|close|hold","symbol":"...|null",'
        '"size_pct_of_equity":0-4,"leverage":1-5,"confidence":0-1,"reasoning":"..."}]}'
        f" Hard limits: lev≤{HARD_MAX_LEVERAGE}, size≤{HARD_MAX_POSITION_PCT}%. Prefer HOLD if unsure."
    )
    base = cfg.llm_base_url or (
        "https://api.x.ai/v1"
        if cfg.llm_provider == "xai"
        else "https://api.openai.com/v1"
    )
    if cfg.llm_provider == "ollama":
        base = cfg.llm_base_url or "http://127.0.0.1:11434/v1"
    url = f"{base.rstrip('/')}/chat/completions"
    body = {
        "model": cfg.llm_model,
        "temperature": 0.2,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": json.dumps(context)},
        ],
    }
    try:
        async with httpx.AsyncClient(timeout=45) as client:
            r = await client.post(
                url,
                headers={
                    "Authorization": f"Bearer {cfg.llm_api_key}",
                    "Content-Type": "application/json",
                },
                json=body,
            )
            r.raise_for_status()
            content = r.json()["choices"][0]["message"]["content"]
        text = content.strip().strip("`")
        if text.startswith("json"):
            text = text[4:].strip()
        data = json.loads(text)
        out = []
        for item in data.get("decisions", []):
            try:
                out.append(
                    Decision(
                        action=Action(item["action"]),
                        symbol=item.get("symbol"),
                        size_pct=float(item.get("size_pct_of_equity") or 0),
                        leverage=float(item.get("leverage") or 1),
                        confidence=float(item.get("confidence") or 0),
                        reasoning=str(item.get("reasoning") or ""),
                    )
                )
            except Exception:  # noqa: BLE001
                continue
        return out or None
    except Exception as e:  # noqa: BLE001
        print(f"LLM fallback → heuristic ({e})")
        return None


def heuristic_decide(
    markets: dict[str, dict],
    positions: list[Position],
    goal: Goal | None,
    pnl_today: float,
    open_count: int,
) -> list[Decision]:
    if goal and goal.target_usd and pnl_today >= goal.target_usd:
        if positions:
            return [
                Decision(Action.CLOSE, p.symbol, confidence=0.9, reasoning="Goal reached — close")
                for p in positions
            ]
        return [Decision(Action.HOLD, confidence=0.8, reasoning="Goal reached — flat")]

    for p in positions:
        ind = markets.get(p.symbol) or {}
        rsi = ind.get("rsi")
        if rsi is not None:
            if p.side == "long" and rsi > 75:
                return [
                    Decision(
                        Action.CLOSE, p.symbol, confidence=0.7, reasoning=f"RSI {rsi:.0f} close long"
                    )
                ]
            if p.side == "short" and rsi < 25:
                return [
                    Decision(
                        Action.CLOSE,
                        p.symbol,
                        confidence=0.7,
                        reasoning=f"RSI {rsi:.0f} close short",
                    )
                ]

    if not goal or open_count >= HARD_MAX_OPEN_POSITIONS:
        return [Decision(Action.HOLD, confidence=0.5, reasoning="Wait / no goal / max positions")]

    best_sym, best_score, best_action = None, 0.0, None
    for sym, ind in markets.items():
        if ind.get("error"):
            continue
        rsi, trend, hist = ind.get("rsi"), ind.get("trend"), ind.get("macd_hist") or 0
        if trend == "bullish" and rsi and 40 <= rsi <= 60:
            score = 0.55 + (0.1 if hist > 0 else 0)
            if score > best_score:
                best_sym, best_score, best_action = sym, score, Action.OPEN_LONG
        elif trend == "bearish" and rsi and 40 <= rsi <= 60:
            score = 0.55 + (0.1 if hist < 0 else 0)
            if score > best_score:
                best_sym, best_score, best_action = sym, score, Action.OPEN_SHORT

    if best_sym and best_action and best_score >= 0.55:
        return [
            Decision(
                best_action,
                best_sym,
                size_pct=2.5,
                leverage=3.0,
                confidence=best_score,
                reasoning=f"Heuristic {best_action.value} {best_sym}",
            )
        ]
    return [Decision(Action.HOLD, confidence=0.5, reasoning="No clear setup")]


# ============================= Goal parser =================================


def interpret_goal(text: str, equity: float, risk: Risk) -> tuple[str, Goal | None, str]:
    """Returns (reply, goal_or_none, special_cmd). special: status|report|stop|close|none"""
    raw = text.strip()
    lang = detect_lang(raw)
    lower = raw.lower()

    if re.search(r"^(стоп|stop|halt|пауза)$", lower):
        return (
            "🛑 Stopping. Closing all & halting new trades."
            if lang == "en"
            else "🛑 Стоп. Закрываю всё и останавливаю торговлю.",
            None,
            "stop",
        )
    if re.search(r"(закрой\s*(все|всё)?|close\s*all|flatten)", lower):
        return (
            "Closing all positions." if lang == "en" else "Закрываю все позиции.",
            None,
            "close",
        )
    if re.search(r"^(статус|status|pnl|баланс)$", lower):
        return ("", None, "status")
    if re.search(r"(отчёт|отчет|report|reasoning)", lower):
        return ("", None, "report")

    profile = "balanced"
    if re.search(r"(консервативн|conservative)", lower):
        profile = "conservative"
    elif re.search(r"(агрессивн|aggressive)", lower):
        profile = "aggressive"

    usd = None
    m = re.search(
        r"([+]?\d+(?:[.,]\d+)?)\s*(?:\$|usd|usdt|доллар|бакс)",
        raw,
        re.I,
    )
    if m:
        usd = float(m.group(1).replace(",", "."))
    if usd is None:
        m = re.search(r"(?:\$|usd)\s*([+]?\d+(?:[.,]\d+)?)", raw, re.I)
        if m:
            usd = float(m.group(1).replace(",", "."))
    if usd is None and "%" not in raw:
        m = re.search(
            r"(?:сделай|заработай|цель|make|earn|goal|target)\s+(?:мне\s+)?(?:сегодня\s+)?"
            r"([+]?\d+(?:[.,]\d+)?)",
            raw,
            re.I,
        )
        if m:
            usd = float(m.group(1).replace(",", "."))

    pct = None
    m = re.search(r"([+]?\d+(?:[.,]\d+)?)\s*%", raw)
    if m:
        pct = float(m.group(1).replace(",", "."))

    if usd is None and pct is None:
        if lang == "ru":
            return (
                "Не понял. Примеры:\n• сделай сегодня 200 долларов\n• цель +3%\n"
                "• работай консервативно, цель 150$\n• стоп / закрой все / статус",
                None,
                "none",
            )
        return (
            "Didn't get it. Examples:\n• make 200 dollars today\n• target +3%\n"
            "• conservative, goal $150\n• stop / close all / status",
            None,
            "none",
        )

    target_usd = usd
    if target_usd is None and pct is not None and equity > 0:
        target_usd = equity * pct / 100

    if target_usd and risk.too_aggressive(equity, target_usd):
        sug = risk.max_realistic_target(equity)
        if lang == "ru":
            return (
                f"⚠️ Цель слишком агрессивна для лимитов риска.\n"
                f"Реалистичнее ≈ ${sug:.0f}. Напиши: цель {sug:.0f}$",
                None,
                "none",
            )
        return (
            f"⚠️ Target too aggressive for risk limits.\n"
            f"More realistic ≈ ${sug:.0f}. Reply: goal {sug:.0f}$",
            None,
            "none",
        )

    goal = Goal(target_usd=usd, target_pct=pct, profile=profile, raw=raw, lang=lang)
    parts = []
    if usd is not None:
        parts.append(f"${usd:g}")
    if pct is not None:
        parts.append(f"{pct:g}%")
    if lang == "ru":
        reply = (
            f"✅ Цель принята: {' / '.join(parts)} | профиль {profile}.\n"
            f"Лимиты активны. Начинаю работу."
        )
    else:
        reply = (
            f"✅ Goal accepted: {' / '.join(parts)} | profile {profile}.\n"
            f"Safety limits on. Starting work."
        )
    return reply, goal, "none"


# ============================= Engine ======================================


class Engine:
    def __init__(self, cfg: Config) -> None:
        self.cfg = cfg
        self.state = State(DB_PATH)
        self.breaker = CircuitBreaker()
        self.risk = Risk(self.breaker)
        self.ex = Exchange(cfg, self.breaker)
        self.goal: Goal | None = None
        self.trading_enabled = True
        self.last_summary = ""
        self._notify = None  # async callable(str)
        self._running = True
        # restore
        g = self.state.get("goal")
        if g:
            self.goal = Goal(**g)
            self.risk.set_profile(self.goal.profile)
        peak = float(self.state.get("peak", 0) or 0)
        self.risk.peak = peak

    def set_notify(self, fn) -> None:
        self._notify = fn

    async def notify(self, text: str) -> None:
        print(text)
        if self._notify:
            try:
                await self._notify(text)
            except Exception as e:  # noqa: BLE001
                print(f"notify failed: {e}")

    async def start(self) -> None:
        await self.ex.connect()
        acc = await self.ex.account()
        self.risk.peak = max(self.risk.peak, acc["equity"])
        self.state.set("peak", self.risk.peak)
        msg = (
            f"Бот запущен в {self.cfg.mode} mode. Готов принимать цели. "
            f"Напиши, сколько хочешь заработать сегодня."
        )
        await self.notify(msg)

    async def stop(self) -> None:
        self._running = False
        await self.ex.close()
        self.state.conn.close()

    async def handle_text(self, text: str) -> str:
        acc = await self.ex.account()
        reply, goal, cmd = interpret_goal(text, acc["equity"], self.risk)
        if cmd == "stop":
            self.trading_enabled = False
            n = await self.ex.close_all()
            self.breaker.trip("manual_stop")
            return reply + f" Closed={n}"
        if cmd == "close":
            n = await self.ex.close_all()
            return reply + f" Closed={n}"
        if cmd == "status":
            return await self.status_text()
        if cmd == "report":
            return await self.report_text()
        if goal:
            self.goal = goal
            self.risk.set_profile(goal.profile)
            self.trading_enabled = True
            if "manual_stop" in self.breaker.reason:
                self.breaker.reset()
            self.state.set("goal", goal.__dict__)
        return reply

    async def status_text(self) -> str:
        acc = await self.ex.account()
        day_start = float(self.state.get("day_start", acc["equity"]) or acc["equity"])
        pnl = acc["equity"] - day_start
        g = "—"
        progress = 0.0
        if self.goal:
            if self.goal.target_usd:
                g = f"${self.goal.target_usd:g}"
                progress = max(0, min(100, pnl / self.goal.target_usd * 100))
            elif self.goal.target_pct:
                g = f"{self.goal.target_pct:g}%"
        return (
            f"📊 AstraForge\n"
            f"Mode: {self.cfg.mode}\n"
            f"Equity: ${acc['equity']:,.2f}\n"
            f"PnL today: ${pnl:,.2f}\n"
            f"Goal: {g} ({progress:.1f}%)\n"
            f"Positions: {len(acc['positions'])}\n"
            f"Trading: {'ON' if self.trading_enabled and self.breaker.trading_allowed else 'OFF'}\n"
            f"Breaker: {self.breaker.reason or 'ok'}\n"
            f"Last: {self.last_summary or '—'}"
        )

    async def report_text(self) -> str:
        lines = ["📈 Report"]
        for d in self.state.recent_decisions(5):
            lines.append(f"• {d.get('summary', d)}")
        return "\n".join(lines) if len(lines) > 1 else "📈 No decisions yet."

    async def tick(self) -> None:
        acc = await self.ex.account()
        equity = acc["equity"]
        if self.state.get("day") != today_key():
            self.state.set("day", today_key())
            self.state.set("day_start", equity)
            self.ex.realized_today = 0.0
        day_start = float(self.state.get("day_start", equity) or equity)
        pnl = equity - day_start
        self.state.set("peak", max(float(self.state.get("peak", 0) or 0), equity))
        self.risk.peak = float(self.state.get("peak", equity))

        blocked = self.risk.check_account(equity)
        if blocked or not self.trading_enabled:
            self.last_summary = f"paused: {blocked or 'disabled'}"
            return
        if not self.goal:
            self.last_summary = "idle: waiting for goal"
            return

        if self.goal.target_usd and pnl >= self.goal.target_usd:
            await self.notify(f"🎯 Goal reached! PnL ${pnl:.2f}")

        markets: dict[str, dict] = {}
        for sym in SYMBOLS:
            ohlcv = await self.ex.ohlcv(sym)
            book = await self.ex.order_book(sym)
            recent = [
                {
                    "o": float(r[1]),
                    "h": float(r[2]),
                    "l": float(r[3]),
                    "c": float(r[4]),
                    "v": float(r[5]),
                }
                for r in ohlcv[-8:]
            ]
            markets[sym] = {
                "indicators": indicators(ohlcv),
                "order_book": book,
                "recent_candles": recent,
            }

        context = {
            "equity": equity,
            "pnl_today": pnl,
            "goal": self.goal.__dict__,
            "positions": [p.__dict__ for p in acc["positions"]],
            "markets": markets,
            "limits": self.risk.limits,
            "instruction": "Read candles + order_book. Decide like a trader. Cite both.",
        }
        decisions = await llm_decide(self.cfg, context)
        if decisions is None:
            # Heuristic sees indicators only
            ind_only = {s: m.get("indicators", m) for s, m in markets.items()}
            decisions = heuristic_decide(
                ind_only, acc["positions"], self.goal, pnl, len(acc["positions"])
            )

        results = []
        for d in decisions:
            # enforce open position cap
            if d.action in (Action.OPEN_LONG, Action.OPEN_SHORT):
                if len(acc["positions"]) >= HARD_MAX_OPEN_POSITIONS:
                    results.append({"rejected": "max_positions"})
                    continue
            adj = self.risk.clamp(d)
            if not adj:
                results.append({"rejected": d.reasoning or "risk"})
                continue
            res = await self._execute(adj, equity)
            results.append(res)
            acc = await self.ex.account()

        summary = "; ".join(
            f"{d.action.value}:{d.symbol or '-'}" for d in decisions
        ) or "hold"
        self.last_summary = summary
        self.state.log_decision({"summary": summary, "results": results, "pnl": pnl})
        print(f"[{utcnow().strftime('%H:%M:%S')}] {summary} | pnl=${pnl:.2f}")

    async def _execute(self, d: Decision, equity: float) -> dict:
        if d.action == Action.HOLD:
            return {"ok": True, "action": "hold"}
        if d.action == Action.CLOSE:
            if not d.symbol:
                n = await self.ex.close_all()
                return {"ok": True, "closed": n}
            pos = next((p for p in self.ex.positions() if p.symbol == d.symbol), None)
            if not pos:
                return {"ok": False, "reason": "no_pos"}
            side = "sell" if pos.side == "long" else "buy"
            order = await self.ex.market_order(d.symbol, side, pos.size, reduce_only=True)
            self.state.log_trade(
                symbol=d.symbol,
                side=pos.side,
                action="close",
                size=pos.size,
                price=order.get("price", 0),
                leverage=pos.leverage,
                pnl=order.get("pnl", 0),
                reasoning=d.reasoning,
            )
            return {"ok": True, "action": "close", "symbol": d.symbol}

        if d.action in (Action.OPEN_LONG, Action.OPEN_SHORT) and d.symbol:
            price = await self.ex.ticker_price(d.symbol)
            if price <= 0:
                return {"ok": False, "reason": "price"}
            notional = equity * (d.size_pct / 100.0)
            amount = (notional * d.leverage) / price
            side = "buy" if d.action == Action.OPEN_LONG else "sell"
            if d.symbol in self.ex.paper_pos:
                self.ex.paper_pos[d.symbol]["leverage"] = d.leverage
            order = await self.ex.market_order(d.symbol, side, amount)
            if d.symbol in self.ex.paper_pos:
                self.ex.paper_pos[d.symbol]["leverage"] = d.leverage
            self.state.log_trade(
                symbol=d.symbol,
                side="long" if side == "buy" else "short",
                action=d.action.value,
                size=amount,
                price=order.get("price", price),
                leverage=d.leverage,
                reasoning=d.reasoning,
            )
            return {"ok": True, "action": d.action.value, "symbol": d.symbol, "amount": amount}
        return {"ok": False}

    async def loop(self) -> None:
        while self._running:
            try:
                await self.tick()
            except Exception as e:  # noqa: BLE001
                print(f"tick error: {e}")
                self.breaker.trip(f"anomaly: {e}")
            await asyncio.sleep(AGENT_INTERVAL_SEC)


# ============================= Telegram (optional) =========================


async def run_telegram(engine: Engine) -> None:
    try:
        from aiogram import Bot, Dispatcher, F
        from aiogram.filters import Command, CommandStart
        from aiogram.types import Message
    except ImportError:
        print("aiogram not installed — console mode.\n  pip install aiogram")
        await run_console(engine)
        return

    bot = Bot(engine.cfg.telegram_token)
    dp = Dispatcher()
    allowed = set(engine.cfg.telegram_user_ids)
    chats: set[int] = set(allowed)

    def ok(msg: Message) -> bool:
        uid = msg.from_user.id if msg.from_user else None
        if uid is None:
            return False
        if not allowed:
            return True
        return uid in allowed

    async def broadcast(text: str) -> None:
        for cid in list(chats):
            try:
                await bot.send_message(cid, text)
            except Exception:  # noqa: BLE001
                pass

    engine.set_notify(broadcast)

    @dp.message(CommandStart())
    async def start(msg: Message) -> None:
        if not ok(msg):
            await msg.answer("Access denied")
            return
        chats.add(msg.chat.id)
        await msg.answer(
            f"Бот запущен в {engine.cfg.mode} mode. Готов принимать цели. "
            "Напиши, сколько хочешь заработать сегодня."
        )

    @dp.message(Command("status"))
    async def status(msg: Message) -> None:
        if ok(msg):
            await msg.answer(await engine.status_text())

    @dp.message(Command("emergency_stop"))
    async def estop(msg: Message) -> None:
        if ok(msg):
            await msg.answer(await engine.handle_text("stop"))

    @dp.message(F.text)
    async def text(msg: Message) -> None:
        if not ok(msg):
            await msg.answer("Access denied")
            return
        chats.add(msg.chat.id)
        reply = await engine.handle_text(msg.text or "")
        if reply:
            await msg.answer(reply)

    # announce
    for uid in allowed:
        try:
            await bot.send_message(
                uid,
                f"Бот запущен в {engine.cfg.mode} mode. Готов принимать цели. "
                "Напиши, сколько хочешь заработать сегодня.",
            )
            chats.add(uid)
        except Exception:  # noqa: BLE001
            pass

    await dp.start_polling(bot)


# ============================= Console UI ==================================


async def run_console(engine: Engine) -> None:
    print("Console chat. Type goals like: make 100 dollars today")
    print("Commands: status | report | stop | close all | quit\n")

    async def _stdin() -> None:
        loop = asyncio.get_event_loop()
        while engine._running:
            line = await loop.run_in_executor(None, sys.stdin.readline)
            if not line:
                await asyncio.sleep(0.2)
                continue
            text = line.strip()
            if text.lower() in {"quit", "exit", "q"}:
                engine._running = False
                break
            reply = await engine.handle_text(text)
            if reply:
                print(reply)

    await _stdin()


# ============================= Main ========================================


async def amain() -> None:
    # Load .env if present
    env_path = Path(__file__).resolve().parent / ".env"
    if env_path.exists():
        for line in env_path.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

    cfg = load_config_interactive()
    engine = Engine(cfg)
    await engine.start()

    loop_task = asyncio.create_task(engine.loop(), name="loop")
    try:
        if cfg.telegram_token:
            await run_telegram(engine)
        else:
            await run_console(engine)
    finally:
        engine._running = False
        loop_task.cancel()
        try:
            await loop_task
        except asyncio.CancelledError:
            pass
        await engine.stop()
        print("Bye.")


def main() -> None:
    try:
        asyncio.run(amain())
    except KeyboardInterrupt:
        print("\nStopped.")


if __name__ == "__main__":
    main()
