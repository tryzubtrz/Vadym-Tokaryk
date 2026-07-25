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
            "fx_target_usd": 20.0,  # fixed FX allocation; rest of equity → crypto
            "auto_split_equity": True,
            "auto_convert_fx": True,
            # FX exit: >= instant_tp_pct → close now; else any green waits max_hold_sec_green
            "fx_instant_tp_pct": 0.04,
            "max_hold_sec_green": 120,   # 2 min for sub-0.04% greens
            "max_hold_sec_force_be": 300,
            "take_profit_pips_min": 4,
            "take_profit_pips_max": 8,
            "small_green_pips": 1,
            "range_lookback": 40,
            "buy_zone_pct": 0.30,
            "emergency_stop_mode": "yearly_low",
            "profit_to_crypto_pct": 0.10,
            "realized_crypto_pnl_total": 0.0,
            "fx_profit_total": 0.0,
            "fx_loss_total": 0.0,
            "crypto_profit_total": 0.0,
            "crypto_loss_total": 0.0,
            "daily_fx_pnl": 0.0,
            "daily_crypto_pnl": 0.0,
            "daily_fx_profit": 0.0,
            "daily_fx_loss": 0.0,
            "daily_crypto_profit": 0.0,
            "daily_crypto_loss": 0.0,
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
            self.data["daily_fx_pnl"] = 0.0
            self.data["daily_crypto_pnl"] = 0.0
            self.data["daily_fx_profit"] = 0.0
            self.data["daily_fx_loss"] = 0.0
            self.data["daily_crypto_profit"] = 0.0
            self.data["daily_crypto_loss"] = 0.0
            self.save()

    def sync_to_equity(self, equity: float, *, fx_target: float | None = None) -> dict[str, Any]:
        """Keep FX at ~$20 (or fx_target), put the rest into crypto hold.

        With ~$26 equity → FX $20 + crypto ~$6. Never allocate more than cash.
        Preserves PnL counters; only resizes working buckets.
        """
        eq = max(0.0, float(equity or 0))
        target = float(fx_target if fx_target is not None else (self.data.get("fx_target_usd") or 20.0))
        if target <= 0:
            target = 20.0
        fx = min(target, eq)
        crypto = max(0.0, round(eq - fx, 4))
        self.data["fx_target_usd"] = target
        self.data["fx_bucket_usd"] = round(fx, 4)
        self.data["crypto_hold_usd"] = crypto
        self.data["auto_split_equity"] = True
        self.data["auto_convert_fx"] = True
        self.data["fx_instant_tp_pct"] = float(self.data.get("fx_instant_tp_pct") or 0.04)
        if not self.data.get("fx_pairs"):
            self.data["fx_pairs"] = [
                "USD/CAD",
                "EUR/CAD",
                "EUR/USD",
                "GBP/USD",
                "AUD/USD",
            ]
        self.save()
        return {"fx_bucket_usd": fx, "crypto_hold_usd": crypto, "equity": eq}

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
        pnl = float(pnl or 0)
        self.data["daily_profit_usd"] = float(self.data.get("daily_profit_usd") or 0) + pnl
        self.data["daily_fx_pnl"] = float(self.data.get("daily_fx_pnl") or 0) + pnl
        self.data["realized_fx_pnl_total"] = float(self.data.get("realized_fx_pnl_total") or 0) + pnl
        if pnl >= 0:
            self.data["fx_profit_total"] = float(self.data.get("fx_profit_total") or 0) + pnl
            self.data["daily_fx_profit"] = float(self.data.get("daily_fx_profit") or 0) + pnl
        else:
            loss = abs(pnl)
            self.data["fx_loss_total"] = float(self.data.get("fx_loss_total") or 0) + loss
            self.data["daily_fx_loss"] = float(self.data.get("daily_fx_loss") or 0) + loss
        self.data["fx_bucket_usd"] = float(self.data.get("fx_bucket_usd") or 0) + pnl
        self.save()

    def record_crypto_profit(self, pnl: float) -> None:
        self.ensure_day()
        pnl = float(pnl or 0)
        self.data["daily_crypto_pnl"] = float(self.data.get("daily_crypto_pnl") or 0) + pnl
        self.data["realized_crypto_pnl_total"] = (
            float(self.data.get("realized_crypto_pnl_total") or 0) + pnl
        )
        if pnl >= 0:
            self.data["crypto_profit_total"] = float(self.data.get("crypto_profit_total") or 0) + pnl
            self.data["daily_crypto_profit"] = float(self.data.get("daily_crypto_profit") or 0) + pnl
        else:
            loss = abs(pnl)
            self.data["crypto_loss_total"] = float(self.data.get("crypto_loss_total") or 0) + loss
            self.data["daily_crypto_loss"] = float(self.data.get("daily_crypto_loss") or 0) + loss
        self.data["crypto_hold_usd"] = float(self.data.get("crypto_hold_usd") or 0) + pnl
        self.save()

    def pnl_breakdown(self) -> dict[str, float]:
        self.ensure_day()
        return {
            "fx_profit_total": float(self.data.get("fx_profit_total") or 0),
            "fx_loss_total": float(self.data.get("fx_loss_total") or 0),
            "fx_net_total": float(self.data.get("realized_fx_pnl_total") or 0),
            "crypto_profit_total": float(self.data.get("crypto_profit_total") or 0),
            "crypto_loss_total": float(self.data.get("crypto_loss_total") or 0),
            "crypto_net_total": float(self.data.get("realized_crypto_pnl_total") or 0),
            "daily_fx_profit": float(self.data.get("daily_fx_profit") or 0),
            "daily_fx_loss": float(self.data.get("daily_fx_loss") or 0),
            "daily_fx_pnl": float(self.data.get("daily_fx_pnl") or 0),
            "daily_crypto_profit": float(self.data.get("daily_crypto_profit") or 0),
            "daily_crypto_loss": float(self.data.get("daily_crypto_loss") or 0),
            "daily_crypto_pnl": float(self.data.get("daily_crypto_pnl") or 0),
        }