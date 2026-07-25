"""Persistent capital buckets for FX scalping + crypto hold."""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


def _utcnow() -> str:
    return datetime.now(timezone.utc).isoformat()


class BucketStore:
    """JSON-backed FX / crypto capital accounting (survives restarts)."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        self.data: dict[str, Any] = self._default()
        self.load()

    @staticmethod
    def _default() -> dict[str, Any]:
        return {
            "fx_bucket_usd": 20.0,
            "crypto_hold_usd": 8.0,
            "crypto_hold_symbol": "",
            "crypto_hold_units": 0.0,
            "max_slots": 10,
            "target_slot_usd": 2.0,  # preferred; raised to exchange min at runtime
            "daily_profit_usd": 0.0,
            "day_key": "",
            "realized_fx_pnl_total": 0.0,
            "open_slots": [],  # list of slot dicts
            "fx_pairs": [
                "USD/CAD",
                "EUR/CAD",
                "EUR/USD",
                "GBP/USD",
                "AUD/USD",
            ],
            "take_profit_pips_min": 12,
            "take_profit_pips_max": 18,
            "range_lookback": 40,
            "buy_zone_pct": 0.30,  # bottom 30% of range
            "emergency_stop_mode": "yearly_low",
            "profit_to_crypto_pct": 0.10,  # of daily profit
            "updated_at": _utcnow(),
        }

    def load(self) -> None:
        if not self.path.exists():
            self.save()
            return
        try:
            raw = json.loads(self.path.read_text(encoding="utf-8"))
            base = self._default()
            base.update(raw or {})
            self.data = base
        except Exception:
            self.data = self._default()
            self.save()

    def save(self) -> None:
        self.data["updated_at"] = _utcnow()
        self.path.write_text(
            json.dumps(self.data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def ensure_day(self) -> None:
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        if self.data.get("day_key") != today:
            # allocate yesterday's daily profit split before reset
            prev = float(self.data.get("daily_profit_usd") or 0)
            if prev > 0:
                crypto_cut = prev * float(self.data.get("profit_to_crypto_pct") or 0.10)
                fx_keep = prev - crypto_cut
                self.data["fx_bucket_usd"] = float(self.data["fx_bucket_usd"]) + fx_keep
                self.data["crypto_hold_usd"] = float(self.data["crypto_hold_usd"]) + crypto_cut
                self.data.setdefault("pending_crypto_buy_usd", 0.0)
                self.data["pending_crypto_buy_usd"] = (
                    float(self.data.get("pending_crypto_buy_usd") or 0) + crypto_cut
                )
            self.data["day_key"] = today
            self.data["daily_profit_usd"] = 0.0
            self.save()

    def snapshot(self) -> dict[str, Any]:
        self.ensure_day()
        return dict(self.data)

    def open_slot_count(self) -> int:
        return len(self.data.get("open_slots") or [])

    def add_slot(self, slot: dict[str, Any]) -> None:
        slots = list(self.data.get("open_slots") or [])
        slots.append(slot)
        self.data["open_slots"] = slots
        self.save()

    def remove_slot(self, slot_id: str) -> dict[str, Any] | None:
        slots = list(self.data.get("open_slots") or [])
        kept: list[dict[str, Any]] = []
        found: dict[str, Any] | None = None
        for s in slots:
            if str(s.get("id")) == str(slot_id):
                found = s
            else:
                kept.append(s)
        self.data["open_slots"] = kept
        self.save()
        return found

    def record_fx_profit(self, pnl: float) -> None:
        self.ensure_day()
        self.data["daily_profit_usd"] = float(self.data.get("daily_profit_usd") or 0) + pnl
        self.data["realized_fx_pnl_total"] = (
            float(self.data.get("realized_fx_pnl_total") or 0) + pnl
        )
        # Compound immediately into FX bucket for next sizing
        self.data["fx_bucket_usd"] = float(self.data.get("fx_bucket_usd") or 0) + pnl
        self.save()
