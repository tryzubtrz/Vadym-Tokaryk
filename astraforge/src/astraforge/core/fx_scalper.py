"""Multi-pair FX range scalper with AI entry filter and far emergency stops.

Design (agreed with user):
- Virtual FX bucket (~$20) split into small slots (respect exchange mins).
- Buy near bottom of recent range; take quick small profits; prefer many trades.
- Do NOT auto-sell at a normal loss — wait for breakeven/profit (user may close manually).
- Emergency stop only near yearly low (extremely far).
- AI decides buy_now vs wait_lower across FX pairs and rotates to best opportunity.
"""

from __future__ import annotations

import json
import uuid
from datetime import datetime, timezone
from typing import Any

import httpx

from astraforge.core.bucket_store import BucketStore
from astraforge.core.config import Settings
from astraforge.utils.logging import get_logger

logger = get_logger(__name__)


class FxMultiScalper:
    def __init__(self, settings: Settings, store: BucketStore, exchange: Any, agent: Any) -> None:
        self.settings = settings
        self.store = store
        self.exchange = exchange
        self.agent = agent
        self._year_lows: dict[str, float] = {}
        self._last_ai: dict[str, Any] = {}

    @property
    def last_ai(self) -> dict[str, Any]:
        return self._last_ai

    def effective_slot_usd(self, symbol: str) -> float:
        """Raise preferred $2 slot to exchange minimum when needed."""
        preferred = float(self.store.data.get("target_slot_usd") or 2.0)
        ex = getattr(self.exchange, "_exchange", None)
        min_cost = preferred
        min_amt_cost = preferred
        if ex and symbol in (ex.markets or {}):
            m = ex.markets[symbol]
            lim = m.get("limits") or {}
            min_amt = float(((lim.get("amount") or {}).get("min")) or 0)
            min_c = float(((lim.get("cost") or {}).get("min")) or 0)
            # For USD/CAD base is USD — amount min is in USD units
            ticker_px = 1.0
            try:
                # best-effort; caller may pass better price later
                pass
            except Exception:
                pass
            min_amt_cost = max(min_amt, preferred) if min_amt else preferred
            min_cost = max(min_c, preferred) if min_c else preferred
        return max(preferred, min_cost, min_amt_cost, 5.0)  # Kraken FX often min ~4–5

    async def yearly_low(self, symbol: str) -> float | None:
        if symbol in self._year_lows:
            return self._year_lows[symbol]
        try:
            rows = await self.exchange.fetch_ohlcv(symbol, timeframe="1d", limit=365)
            if not rows:
                return None
            low = min(float(r[3]) for r in rows)
            # small buffer under yearly low
            stop = low * 0.998
            self._year_lows[symbol] = stop
            return stop
        except Exception as exc:  # noqa: BLE001
            logger.warning("yearly_low_failed", symbol=symbol, error=str(exc))
            return None

    async def analyze_pair(self, symbol: str) -> dict[str, Any] | None:
        tf = self.settings.candle_timeframe or "5m"
        lookback = int(self.store.data.get("range_lookback") or 40)
        ohlcv = await self.exchange.fetch_ohlcv(symbol, timeframe=tf, limit=max(80, lookback + 5))
        if not ohlcv or len(ohlcv) < lookback:
            return None
        window = ohlcv[-lookback:]
        highs = [float(r[2]) for r in window]
        lows = [float(r[3]) for r in window]
        closes = [float(r[4]) for r in window]
        hi, lo, px = max(highs), min(lows), closes[-1]
        rng = hi - lo
        if rng <= 0 or px <= 0:
            return None
        pos = (px - lo) / rng  # 0 = bottom, 1 = top
        buy_zone = float(self.store.data.get("buy_zone_pct") or 0.30)
        pip = 0.0001 if "JPY" not in symbol else 0.01
        spread_est = 0.0
        try:
            book = await self.exchange.fetch_order_book(symbol, limit=5)
            bb = float((book.get("best_bid") or 0))
            ba = float((book.get("best_ask") or 0))
            if bb and ba:
                spread_est = (ba - bb) / pip
                px = (bb + ba) / 2
                pos = (px - lo) / rng
        except Exception:  # noqa: BLE001
            pass
        tp_min = float(self.store.data.get("take_profit_pips_min") or 12) * pip
        tp_max = float(self.store.data.get("take_profit_pips_max") or 18) * pip
        return {
            "symbol": symbol,
            "price": px,
            "range_high": hi,
            "range_low": lo,
            "range_pos": pos,
            "in_buy_zone": pos <= buy_zone,
            "spread_pips": spread_est,
            "tp_price_min": px + tp_min,
            "tp_price_max": px + tp_max,
            "pip": pip,
            "momentum_5m_pct": ((closes[-1] - closes[-3]) / closes[-3] * 100) if len(closes) >= 3 else 0.0,
        }

    async def ai_pick_entry(self, candidates: list[dict[str, Any]]) -> dict[str, Any]:
        """Ask LLM which pair to buy now vs wait."""
        if not candidates:
            return {"action": "wait", "symbol": None, "reason": "no candidates"}
        # Prefer rule filter first
        in_zone = [c for c in candidates if c.get("in_buy_zone")]
        pool = in_zone or candidates
        system = (
            "You are an FX scalp entry filter for Kraken spot. "
            "Prefer frequent small wins. Reply JSON only: "
            '{"action":"buy_now"|"wait","symbol":"USD/CAD"|null,"reason":"..."} '
            "Buy only near bottom of range (range_pos low). "
            "If spread_pips is high vs 12-18 pip target, wait. "
            "Never recommend short."
        )
        user = json.dumps(
            {
                "fx_bucket_usd": self.store.data.get("fx_bucket_usd"),
                "open_slots": len(self.store.data.get("open_slots") or []),
                "candidates": pool,
                "instruction": "Pick at most one buy_now pair or wait.",
            },
            ensure_ascii=False,
        )
        if not getattr(self.agent, "llm_configured", False):
            best = min(pool, key=lambda x: float(x.get("range_pos") or 1))
            if best.get("in_buy_zone") and float(best.get("spread_pips") or 0) < 14:
                return {"action": "buy_now", "symbol": best["symbol"], "reason": "heuristic buy zone"}
            return {"action": "wait", "symbol": None, "reason": "heuristic wait"}
        try:
            raw = await self.agent._call_llm(system, user)
            text = raw.strip()
            if text.startswith("```"):
                text = text.strip("`")
                if text.startswith("json"):
                    text = text[4:].strip()
            data = json.loads(text)
            return {
                "action": str(data.get("action") or "wait"),
                "symbol": data.get("symbol"),
                "reason": str(data.get("reason") or ""),
            }
        except Exception as exc:  # noqa: BLE001
            logger.warning("fx_ai_pick_failed", error=str(exc))
            best = min(pool, key=lambda x: float(x.get("range_pos") or 1))
            if best.get("in_buy_zone"):
                return {"action": "buy_now", "symbol": best["symbol"], "reason": f"fallback:{exc}"}
            return {"action": "wait", "symbol": None, "reason": f"fallback_wait:{exc}"}

    async def manage_open_slots(self) -> list[dict[str, Any]]:
        """Close only on profit / breakeven / emergency yearly-low stop."""
        results: list[dict[str, Any]] = []
        slots = list(self.store.data.get("open_slots") or [])
        for slot in slots:
            symbol = slot["symbol"]
            entry = float(slot["entry"])
            amount = float(slot["amount"])
            try:
                t = await self.exchange.fetch_ticker(symbol)
                px = float(t.get("last") or t.get("close") or 0)
            except Exception as exc:  # noqa: BLE001
                results.append({"ok": False, "symbol": symbol, "error": str(exc)})
                continue
            if px <= 0:
                continue
            pip = float(slot.get("pip") or 0.0001)
            pnl = (px - entry) * amount
            # Quick small green — take it (prefer rotate)
            tp_min = entry + float(self.store.data.get("take_profit_pips_min") or 12) * pip
            emergency = float(slot.get("emergency_stop") or 0)
            action = None
            reason = ""
            if emergency and px <= emergency:
                action = "emergency_stop"
                reason = f"yearly-low emergency stop hit @ {px}"
            elif px >= tp_min:
                action = "take_profit"
                reason = f"TP zone +{(px - entry) / pip:.1f} pips"
            elif px >= entry:  # breakeven or tiny green — optional early rotate if fading
                # Only close BE+ if we have at least a tiny green after fees/spread noise
                if (px - entry) / pip >= 3:
                    action = "small_green"
                    reason = f"small green +{(px - entry) / pip:.1f} pips — rotate"
            if not action:
                continue
            # Never sell normal red except emergency
            if action != "emergency_stop" and px < entry:
                continue
            try:
                order = await self.exchange.create_market_order(symbol, "sell", amount, reduce_only=True)
            except Exception as exc:  # noqa: BLE001
                results.append({"ok": False, "symbol": symbol, "error": str(exc)})
                continue
            fill = float(order.get("average") or order.get("price") or px)
            realized = (fill - entry) * amount
            self.store.remove_slot(slot["id"])
            self.store.record_fx_profit(realized)
            results.append(
                {
                    "ok": True,
                    "action": action,
                    "symbol": symbol,
                    "pnl": realized,
                    "reason": reason,
                    "order": order,
                }
            )
            logger.info("fx_slot_closed", symbol=symbol, action=action, pnl=realized)
        return results

    async def maybe_open(self, available_usd: float | None = None) -> dict[str, Any] | None:
        self.store.ensure_day()
        snap = self.store.snapshot()
        fx_cap = float(snap.get("fx_bucket_usd") or 0)
        crypto_reserve = float(snap.get("crypto_hold_usd") or 0)
        open_n = self.store.open_slot_count()
        max_slots = int(snap.get("max_slots") or 10)
        if open_n >= max_slots or fx_cap < 4:
            return {"skipped": True, "reason": "no_slot_capacity_or_capital"}

        cash_usd = float(available_usd) if available_usd is not None else float(
            await self.exchange.free_balance("USD")
        )
        # Count CAD working cash toward FX capacity (in USD terms)
        cad_usd = 0.0
        try:
            cad = await self.exchange.free_balance("CAD")
            if cad > 0:
                t = await self.exchange.fetch_ticker("USD/CAD")
                usdcad = float(t.get("last") or 0)
                if usdcad > 0:
                    cad_usd = cad / usdcad
        except Exception:  # noqa: BLE001
            cad_usd = 0.0
        cash = cash_usd + cad_usd
        spendable = min(fx_cap, max(0.0, cash - crypto_reserve))
        spendable = max(0.0, spendable * 0.98)
        if spendable < 4.0:
            return {
                "skipped": True,
                "reason": (
                    f"spendable_usd_{spendable:.2f}_below_min "
                    f"(usd={cash_usd:.2f}, cad_usd={cad_usd:.2f}, crypto_reserve={crypto_reserve:.2f})"
                ),
            }

        # Top up CAD working float so CAD pairs can trade (auto-convert from USD)
        convert_meta: dict[str, Any] | None = None
        if bool(snap.get("auto_convert_fx", True)):
            # Only convert from USD cash above crypto reserve
            usd_for_convert = max(0.0, cash_usd - crypto_reserve) * 0.98
            convert_meta = await self._ensure_cad_float(min(spendable, usd_for_convert))

        pairs = [p for p in (snap.get("fx_pairs") or []) if p]
        if not pairs:
            return {"skipped": True, "reason": "no_fx_pairs"}

        open_syms = {s.get("symbol") for s in (snap.get("open_slots") or [])}
        candidates: list[dict[str, Any]] = []
        for symbol in pairs:
            if symbol in open_syms:
                continue
            try:
                info = await self.analyze_pair(symbol)
            except Exception as exc:  # noqa: BLE001
                logger.debug("analyze_failed", symbol=symbol, error=str(exc))
                continue
            if info:
                candidates.append(info)
        pick = await self.ai_pick_entry(candidates)
        self._last_ai = {
            "pick": pick,
            "candidates": candidates[:8],
            "convert": convert_meta,
            "ts": datetime.now(timezone.utc).isoformat(),
        }
        if pick.get("action") != "buy_now" or not pick.get("symbol"):
            return {"skipped": True, "reason": pick.get("reason") or "ai_wait", "ai": pick, "convert": convert_meta}

        symbol = str(pick["symbol"])
        info = next((c for c in candidates if c["symbol"] == symbol), None)
        if not info or not info.get("in_buy_zone"):
            return {"skipped": True, "reason": "not_in_buy_zone_after_ai", "ai": pick}

        # Refresh USD after any conversion
        cash = float(await self.exchange.free_balance("USD"))
        spendable = min(fx_cap, max(0.0, cash - crypto_reserve)) * 0.98

        slot_usd = self.effective_slot_usd(symbol)
        used = sum(float(s.get("notional_usd") or 0) for s in (snap.get("open_slots") or []))
        free = max(0.0, min(fx_cap - used, spendable))
        if free < slot_usd:
            slot_usd = free
        if slot_usd < 4.0:
            return {"skipped": True, "reason": f"free_capital_{free:.2f}_below_min", "convert": convert_meta}

        px = float(info["price"])
        base, quote = symbol.split("/")
        # Order amount in BASE units
        if symbol.startswith("USD/"):
            # Buy USD paying CAD — amount is USD
            amount = slot_usd
            quote_need = amount * px  # CAD
        else:
            amount = slot_usd / px if px > 0 else 0.0
            quote_need = slot_usd  # roughly in quote if quote=USD; if CAD, cost≈amount*px

        if quote == "CAD":
            quote_need = amount * px
        elif quote == "USD":
            quote_need = amount * px

        try:
            ex = self.exchange._exchange
            if ex:
                market = (ex.markets or {}).get(symbol) or {}
                min_amt = float(((market.get("limits") or {}).get("amount") or {}).get("min") or 0)
                if min_amt and amount < min_amt:
                    amount = min_amt
                    if quote == "USD":
                        slot_usd = amount * px
                    elif quote == "CAD":
                        # notional in USD ≈ CAD cost / USD/CAD
                        try:
                            t = await self.exchange.fetch_ticker("USD/CAD")
                            usdcad = float(t.get("last") or 0) or px
                        except Exception:  # noqa: BLE001
                            usdcad = px if base == "USD" else 1.35
                        quote_need = amount * px
                        slot_usd = quote_need / usdcad if base != "USD" else amount
                    if slot_usd > free:
                        return {
                            "skipped": True,
                            "reason": f"min_lot_exceeds_free_{free:.2f}",
                            "symbol": symbol,
                        }
                quote_need = amount * px
                amount = float(ex.amount_to_precision(symbol, amount))
        except Exception:  # noqa: BLE001
            pass

        # Auto-convert quote currency if missing
        if bool(snap.get("auto_convert_fx", True)) and quote not in {"USD", "USDT", "USDC"}:
            ens = await self.exchange.ensure_currency(
                quote, quote_need, max_spend_usd=max(spendable, slot_usd * 1.15)
            )
            convert_meta = {"pre_float": convert_meta, "for_order": ens}
            if not ens.get("ok"):
                return {
                    "ok": False,
                    "soft_fail": True,
                    "error": f"auto_convert_{quote}:{ens.get('error')}",
                    "symbol": symbol,
                    "ai": pick,
                    "convert": convert_meta,
                }
        elif quote in {"USD", "USDT", "USDC"}:
            have_usd = await self.exchange.free_balance("USD")
            if have_usd < quote_need * 0.99:
                return {
                    "skipped": True,
                    "reason": f"usd_cash_{have_usd:.2f}_need_{quote_need:.2f}",
                    "convert": convert_meta,
                }

        emergency = await self.yearly_low(symbol)
        try:
            order = await self.exchange.create_market_order(symbol, "buy", amount)
        except Exception as exc:  # noqa: BLE001
            return {
                "ok": False,
                "soft_fail": True,
                "error": str(exc),
                "symbol": symbol,
                "ai": pick,
                "convert": convert_meta,
            }

        fill = float(order.get("average") or order.get("price") or px)
        slot = {
            "id": str(uuid.uuid4())[:8],
            "symbol": symbol,
            "side": "long",
            "amount": float(order.get("amount") or amount),
            "entry": fill,
            "notional_usd": slot_usd,
            "pip": info["pip"],
            "tp_min": info["tp_price_min"],
            "emergency_stop": emergency,
            "opened_at": datetime.now(timezone.utc).isoformat(),
            "ai_reason": pick.get("reason"),
            "convert": convert_meta,
        }
        self.store.add_slot(slot)
        logger.info("fx_slot_opened", symbol=symbol, amount=amount, entry=fill, convert=bool(convert_meta))
        return {"ok": True, "slot": slot, "order": order, "ai": pick, "convert": convert_meta}

    async def _ensure_cad_float(self, spendable_usd: float) -> dict[str, Any]:
        """Keep a CAD working balance (~35% of FX spendable) via USD/CAD sell."""
        target_usd = min(max(spendable_usd * 0.25, 0.0), 7.0)
        if target_usd < 5.0:
            # Not enough room for Kraken USD/CAD min convert
            return {"ok": True, "skipped": True, "reason": "cad_float_budget_below_min"}
        try:
            t = await self.exchange.fetch_ticker("USD/CAD")
            px = float(t.get("last") or 0)
        except Exception as exc:  # noqa: BLE001
            return {"ok": False, "error": str(exc)}
        if px <= 0:
            return {"ok": False, "error": "bad_usdcad"}
        have_cad = await self.exchange.free_balance("CAD")
        have_usd_equiv = have_cad / px
        if have_usd_equiv >= target_usd * 0.85:
            return {
                "ok": True,
                "converted": False,
                "have_cad": have_cad,
                "have_usd_equiv": have_usd_equiv,
                "target_usd": target_usd,
            }
        need_cad = (target_usd - have_usd_equiv) * px
        ens = await self.exchange.ensure_currency(
            "CAD",
            have_cad + need_cad,
            max_spend_usd=min(spendable_usd * 0.5, target_usd + 1.0),
        )
        return ens

    async def tick(self, available_usd: float | None = None) -> dict[str, Any]:
        closed = await self.manage_open_slots()
        opened = await self.maybe_open(available_usd=available_usd)
        return {
            "closed": closed,
            "opened": opened,
            "snapshot": self.store.snapshot(),
            "ai": self._last_ai,
        }


_NEWS_CACHE: dict[str, Any] = {"at": 0.0, "items": []}
_NEWS_CACHE_TTL_SEC = 12 * 60


def clear_news_cache() -> None:
    _NEWS_CACHE["at"] = 0.0
    _NEWS_CACHE["items"] = []


def _strip_html(text: str) -> str:
    out = text or ""
    while "<" in out and ">" in out:
        a = out.find("<")
        b = out.find(">", a)
        if b < 0:
            break
        out = (out[:a] + " " + out[b + 1 :]).strip()
    return " ".join(out.split())


async def fetch_crypto_news(limit: int = 25, agent: Any | None = None) -> list[dict[str, Any]]:
    """Global crypto headlines → Ukrainian actionable briefs (buy/sell/watch)."""
    import time as _time

    now = _time.time()
    cached = _NEWS_CACHE.get("items") or []
    if cached and now - float(_NEWS_CACHE.get("at") or 0) < _NEWS_CACHE_TTL_SEC:
        return cached[:limit]

    feeds = [
        "https://www.coindesk.com/arc/outboundfeeds/rss",
        "https://cointelegraph.com/rss",
        "https://decrypt.co/feed",
        "https://www.theblock.co/rss.xml",
        "https://cryptonews.com/news/feed/",
    ]
    raw_items: list[dict[str, Any]] = []
    async with httpx.AsyncClient(timeout=20.0, follow_redirects=True) as client:
        for url in feeds:
            try:
                r = await client.get(url, headers={"User-Agent": "AstraForge/2.0"})
                r.raise_for_status()
                text = r.text
            except Exception as exc:  # noqa: BLE001
                logger.debug("news_feed_failed", url=url, error=str(exc))
                continue
            parts = text.split("<item>")
            for part in parts[1:10]:
                def _tag(name: str) -> str:
                    a = part.find(f"<{name}>")
                    if a < 0:
                        a = part.find(f"<{name} ")
                        if a < 0:
                            return ""
                    start = part.find(">", a) + 1
                    end = part.find(f"</{name}>", start)
                    if end < 0:
                        return ""
                    val = part[start:end].strip()
                    return (
                        val.replace("<![CDATA[", "")
                        .replace("]]>", "")
                        .replace("&amp;", "&")
                        .replace("&lt;", "<")
                        .replace("&gt;", ">")
                        .replace("&quot;", '"')
                    )

                title = _tag("title")
                link = _tag("link")
                pub = _tag("pubDate") or _tag("published")
                desc = _strip_html(_tag("description"))[:320]
                source = url.split("/")[2].replace("www.", "")
                if title:
                    raw_items.append(
                        {
                            "title_en": title,
                            "url": link,
                            "published": pub,
                            "summary_en": desc,
                            "source": source,
                        }
                    )

    seen: set[str] = set()
    deduped: list[dict[str, Any]] = []
    for it in raw_items:
        key = it["title_en"].lower()
        if key in seen:
            continue
        seen.add(key)
        deduped.append(it)
        if len(deduped) >= max(limit * 2, 36):
            break

    localized = await _localize_global_news(deduped[:36], agent=agent, limit=limit)
    _NEWS_CACHE["at"] = now
    _NEWS_CACHE["items"] = localized
    return localized[:limit]


async def _localize_global_news(
    items: list[dict[str, Any]],
    *,
    agent: Any | None,
    limit: int,
) -> list[dict[str, Any]]:
    """Translate + prioritize world crypto news into Ukrainian trader briefs."""
    if not items:
        return []

    # Fallback without LLM: keep English (better than empty)
    fallback = [
        {
            "title": it["title_en"],
            "url": it.get("url", ""),
            "published": it.get("published", ""),
            "summary": it.get("summary_en", ""),
            "source": it.get("source", ""),
            "action": "watch",
            "action_uk": "Спостерігати",
            "lang": "en",
        }
        for it in items[:limit]
    ]
    if agent is None or not getattr(getattr(agent, "settings", None), "llm_api_key", None):
        return fallback

    payload = [
        {
            "i": idx,
            "title": it["title_en"],
            "summary": (it.get("summary_en") or "")[:220],
            "source": it.get("source", ""),
            "url": it.get("url", ""),
            "published": it.get("published", ""),
        }
        for idx, it in enumerate(items)
    ]
    system = (
        "Ти крипто-редактор для трейдера. Отримай світові новини англійською. "
        "Поверни JSON: {\"news\":[...]} — лише наймасштабніші/корисні для торгівлі. "
        "Пріоритет: лістинги/запуски нових токенів, дешеві точки входу, великі ризики dump, "
        "хаки/банкрутства, регуляція, ETF, кити, макро що рухає ринок. "
        "Ігноруй дрібні локальні/українські новини без ринкового впливу. "
        f"Максимум {limit} пунктів. Кожен пункт: "
        '{"i":number,"title_uk":"...","summary_uk":"1-2 речення українською",'
        '"action":"buy_watch|sell_risk|hold|watch","why_uk":"коротко чому"}. '
        "title_uk і summary_uk ТІЛЬКИ українською. Без вигаданих фактів."
    )
    try:
        raw = await agent._call_llm(system, json.dumps({"items": payload}, ensure_ascii=False))
        text = raw.strip()
        if text.startswith("```"):
            text = text.strip("`")
            if text.startswith("json"):
                text = text[4:].strip()
        data = json.loads(text)
        rows = data.get("news") if isinstance(data, dict) else data
        if not isinstance(rows, list):
            return fallback
    except Exception as exc:  # noqa: BLE001
        logger.warning("news_localize_failed", error=str(exc))
        return fallback

    action_uk = {
        "buy_watch": "Можна дивитись на купівлю",
        "sell_risk": "Ризик — краще продати / зменшити",
        "hold": "Тримати / не панікувати",
        "watch": "Спостерігати",
    }
    by_i = {idx: it for idx, it in enumerate(items)}
    out: list[dict[str, Any]] = []
    for row in rows:
        if not isinstance(row, dict):
            continue
        try:
            idx = int(row.get("i"))
        except Exception:  # noqa: BLE001
            continue
        src = by_i.get(idx)
        if not src:
            continue
        act = str(row.get("action") or "watch").lower().strip()
        if act not in action_uk:
            act = "watch"
        title_uk = str(row.get("title_uk") or "").strip()
        summary_uk = str(row.get("summary_uk") or "").strip()
        why = str(row.get("why_uk") or "").strip()
        if why and why not in summary_uk:
            summary_uk = f"{summary_uk} {why}".strip()
        if not title_uk:
            continue
        out.append(
            {
                "title": title_uk,
                "url": src.get("url", ""),
                "published": src.get("published", ""),
                "summary": summary_uk,
                "source": src.get("source", ""),
                "action": act,
                "action_uk": action_uk[act],
                "lang": "uk",
            }
        )
        if len(out) >= limit:
            break
    return out or fallback
