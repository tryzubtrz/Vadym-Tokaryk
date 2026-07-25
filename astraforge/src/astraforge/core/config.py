"""Application configuration with hard-coded safety ceilings.

Risk limits defined here are absolute. Environment / YAML values may only
tighten them — never exceed the ceilings. The LLM cannot override these.
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Any, Literal

import yaml
from pydantic import Field, field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

from astraforge.core.models import RiskProfile, TradingMode

# Absolute safety ceilings — NOT overridable above these values.
HARD_MAX_DAILY_LOSS_PCT = 2.5
HARD_MAX_DRAWDOWN_PCT = 7.0
HARD_MAX_LEVERAGE = 5.0
HARD_MAX_POSITION_PCT = 4.0
HARD_MAX_OPEN_POSITIONS = 3


class Settings(BaseSettings):
    """Runtime settings loaded from environment / .env."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
        case_sensitive=False,
    )

    # Telegram
    telegram_bot_token: str = ""
    telegram_allowed_user_ids: str = ""

    # Exchange
    exchange_id: Literal["binance", "bybit", "kraken"] = "binance"
    exchange_api_key: str = ""
    exchange_api_secret: str = ""

    # Mode
    trading_mode: TradingMode = TradingMode.PAPER
    live_confirmed: bool = False

    # LLM
    llm_provider: Literal["openai", "anthropic", "ollama", "xai"] = "openai"
    llm_model: str = "gpt-4o-mini"
    llm_api_key: str = ""
    llm_base_url: str | None = None

    # Risk (clamped to hard ceilings in validators)
    daily_loss_limit_pct: float = Field(default=2.5, ge=0.1, le=HARD_MAX_DAILY_LOSS_PCT)
    max_drawdown_pct: float = Field(default=6.0, ge=1.0, le=HARD_MAX_DRAWDOWN_PCT)
    max_leverage: float = Field(default=5.0, ge=1.0, le=HARD_MAX_LEVERAGE)
    max_position_pct: float = Field(default=3.5, ge=0.5, le=HARD_MAX_POSITION_PCT)
    max_open_positions: int = Field(default=3, ge=1, le=HARD_MAX_OPEN_POSITIONS)

    # Universe
    trade_symbols: str = (
        "BTC/USDT:USDT,ETH/USDT:USDT,SOL/USDT:USDT,BNB/USDT:USDT,XRP/USDT:USDT"
    )

    # App
    database_path: str = "./data/astraforge.db"
    log_level: str = "INFO"
    dashboard_host: str = "0.0.0.0"
    dashboard_port: int = 8080
    agent_loop_interval_sec: int = 60
    default_risk_profile: RiskProfile = RiskProfile.BALANCED
    paper_starting_equity: float = 10_000.0
    config_yaml_path: str = "./config/default.yaml"

    @field_validator(
        "daily_loss_limit_pct",
        "max_drawdown_pct",
        "max_leverage",
        "max_position_pct",
        mode="before",
    )
    @classmethod
    def clamp_risk(cls, v: Any, info: Any) -> float:
        """Clamp risk values to hard-coded ceilings (LLM / .env cannot exceed)."""
        value = float(v)
        ceilings = {
            "daily_loss_limit_pct": HARD_MAX_DAILY_LOSS_PCT,
            "max_drawdown_pct": HARD_MAX_DRAWDOWN_PCT,
            "max_leverage": HARD_MAX_LEVERAGE,
            "max_position_pct": HARD_MAX_POSITION_PCT,
        }
        ceiling = ceilings.get(info.field_name, value)
        return min(value, ceiling)

    @model_validator(mode="after")
    def validate_live_mode(self) -> Settings:
        """Live trading requires explicit confirmation flag."""
        if self.trading_mode == TradingMode.LIVE and not self.live_confirmed:
            # Force paper if live not confirmed — never silently go live
            object.__setattr__(self, "trading_mode", TradingMode.PAPER)
        return self

    @property
    def allowed_user_ids(self) -> set[int]:
        if not self.telegram_allowed_user_ids.strip():
            return set()
        return {
            int(x.strip())
            for x in self.telegram_allowed_user_ids.split(",")
            if x.strip().isdigit()
        }

    @property
    def symbols(self) -> list[str]:
        raw = [s.strip() for s in self.trade_symbols.split(",") if s.strip()]
        if self.exchange_id == "kraken":
            return [normalize_symbol_for_exchange(s, "kraken") for s in raw]
        return raw

    @property
    def is_paper(self) -> bool:
        return self.trading_mode == TradingMode.PAPER

    @property
    def effective_llm_base_url(self) -> str | None:
        if self.llm_base_url:
            return self.llm_base_url
        if self.llm_provider == "ollama":
            return "http://host.docker.internal:11434/v1"
        if self.llm_provider == "xai":
            return "https://api.x.ai/v1"
        return None


def normalize_symbol_for_exchange(symbol: str, exchange_id: str) -> str:
    """Map common USDT-perp symbols onto exchange-native symbols."""
    if exchange_id != "kraken":
        return symbol
    mapping = {
        "BTC/USDT:USDT": "BTC/USD:USD",
        "ETH/USDT:USDT": "ETH/USD:USD",
        "SOL/USDT:USDT": "SOL/USD:USD",
        "BNB/USDT:USDT": "BNB/USD:USD",
        "XRP/USDT:USDT": "XRP/USD:USD",
        "BTC/USDT": "BTC/USD:USD",
        "ETH/USDT": "ETH/USD:USD",
    }
    if symbol in mapping:
        return mapping[symbol]
    # Already Kraken-style
    if symbol.endswith(":USD") or "/USD" in symbol:
        return symbol
    # Generic USDT swap → USD linear on Kraken Futures
    if ":USDT" in symbol:
        return symbol.replace("USDT", "USD")
    return symbol


def load_yaml_config(path: str | Path | None = None) -> dict[str, Any]:
    """Load optional YAML defaults (non-secret)."""
    cfg_path = Path(path or "./config/default.yaml")
    if not cfg_path.exists():
        return {}
    with cfg_path.open("r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


@lru_cache
def get_settings() -> Settings:
    """Cached settings singleton."""
    return Settings()


def risk_profile_overrides(profile: RiskProfile, settings: Settings) -> dict[str, float]:
    """Return tightened risk params for a named profile (never above hard ceilings)."""
    yaml_cfg = load_yaml_config(settings.config_yaml_path)
    profiles = yaml_cfg.get("risk_profiles", {})
    raw = profiles.get(profile.value, {})

    return {
        "daily_loss_limit_pct": min(
            float(raw.get("daily_loss_limit_pct", settings.daily_loss_limit_pct)),
            HARD_MAX_DAILY_LOSS_PCT,
            settings.daily_loss_limit_pct,
        ),
        "max_drawdown_pct": min(
            float(raw.get("max_drawdown_pct", settings.max_drawdown_pct)),
            HARD_MAX_DRAWDOWN_PCT,
            settings.max_drawdown_pct,
        ),
        "max_leverage": min(
            float(raw.get("max_leverage", settings.max_leverage)),
            HARD_MAX_LEVERAGE,
            settings.max_leverage,
        ),
        "max_position_pct": min(
            float(raw.get("max_position_pct", settings.max_position_pct)),
            HARD_MAX_POSITION_PCT,
            settings.max_position_pct,
        ),
        "target_aggression": float(raw.get("target_aggression", 0.6)),
    }
