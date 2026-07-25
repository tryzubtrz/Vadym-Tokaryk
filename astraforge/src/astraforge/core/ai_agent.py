"""LLM-powered trading agent with strict JSON decisions.

The agent receives structured market + account + goal context and must
return AgentDecisionBatch. Risk limits are enforced OUTSIDE the LLM —
this module never bypasses RiskManager / CircuitBreaker.
"""

from __future__ import annotations

import json
from typing import Any

import httpx
from pydantic import ValidationError

from astraforge.core.config import Settings
from astraforge.core.models import (
    AccountSnapshot,
    ActionType,
    AgentDecisionBatch,
    MarketSnapshot,
    Side,
    TradeDecision,
    TradingGoal,
)
from astraforge.utils.indicators import compute_indicators, ohlcv_to_dataframe
from astraforge.utils.logging import get_logger

logger = get_logger(__name__)

SYSTEM_PROMPT = """You are AstraForge AI — a momentum scalping brain for crypto markets.

Style: FREQUENT small trades. Many small wins > one big bet.
IMPORTANT FEE MODE: {fee_mode}
{fee_note}

You READ 5-minute candles + order book across many coins and DECIDE yourself.

How to trade:
1. Scan for coins already moving UP over the last ~5 minutes (momentum_5m_pct > 0.10 and rising).
2. Confirm with order-book pressure (prefer bid_heavy) and RSI not extremely overbought (<78).
3. BUY (open_long) with part of equity — aim size_pct_of_equity around {typical_size}-{max_position_pct}.
4. While in a position: if you have ANY small green profit and momentum cools, RSI rolls over, or book flips ask_heavy → CLOSE/SELL quickly.
5. Take quick profits often ({tp_hint}). Do NOT hold forever hoping for a moonshot.
6. Prefer several rotations per day over one giant swing.
7. Spot mode: NO shorts. Only open_long / close / hold / reduce.
8. If nothing is clearly moving — HOLD. Do not force garbage trades.
9. If daily goal already reached → close open positions and protect profits.

HARD RULES (enforced in code):
1. Leverage max: {max_leverage}x
2. Position size max: {max_position_pct}% of equity
3. Max open positions: {max_open_positions}
4. Never violate daily loss / drawdown limits
5. Confidence < 0.45 → HOLD

Respond with ONLY valid JSON:
{{
  "decisions": [
    {{
      "action": "open_long" | "open_short" | "close" | "hold" | "reduce",
      "symbol": "BTC/USD" or null,
      "side": "long" | "short" | null,
      "size_pct_of_equity": 0.0-{max_position_pct},
      "leverage": 1.0-{max_leverage},
      "confidence": 0.0-1.0,
      "reasoning": "cite 5m momentum + order book",
      "stop_loss_pct": number or null,
      "take_profit_pct": number or null
    }}
  ],
  "goal_progress_note": "string",
  "risk_note": "string"
}}

Only use symbols from the provided universe. JSON only — no markdown.
"""


class AIAgent:
    """Stateful decision engine wrapping OpenAI-compatible / Anthropic APIs."""

    def __init__(self, settings: Settings) -> None:
        self.settings = settings
        self._last_reasoning: str = ""

    @property
    def last_reasoning(self) -> str:
        return self._last_reasoning

    async def analyze_markets(
        self,
        exchange: Any,
        symbols: list[str] | None = None,
    ) -> list[MarketSnapshot]:
        """Fetch candles + order book for the trade universe (AI brain input)."""
        symbols = symbols or self.settings.symbols
        timeframe = self.settings.candle_timeframe or "5m"
        snapshots: list[MarketSnapshot] = []
        for symbol in symbols:
            ohlcv = await exchange.fetch_ohlcv(symbol, timeframe=timeframe, limit=100)
            if not ohlcv:
                continue
            df = ohlcv_to_dataframe(ohlcv)
            indicators = compute_indicators(df)
            # 5-minute momentum helpers for scalping
            if len(df) >= 3:
                c0 = float(df.iloc[-1]["close"])
                c1 = float(df.iloc[-2]["close"])
                c3 = float(df.iloc[-3]["close"])
                indicators["momentum_1bar_pct"] = ((c0 - c1) / c1) * 100 if c1 else 0.0
                indicators["momentum_5m_pct"] = ((c0 - c3) / c3) * 100 if c3 else 0.0
            book = await exchange.fetch_order_book(symbol, limit=20)
            recent = []
            for row in ohlcv[-12:]:
                recent.append(
                    {
                        "o": float(row[1]),
                        "h": float(row[2]),
                        "l": float(row[3]),
                        "c": float(row[4]),
                        "v": float(row[5]),
                    }
                )
            snapshots.append(
                MarketSnapshot(
                    symbol=symbol,
                    indicators=indicators,
                    order_book=book,
                    recent_candles=recent,
                )
            )
        # Rank hottest movers first for the LLM
        snapshots.sort(
            key=lambda s: float((s.indicators or {}).get("momentum_5m_pct") or -999),
            reverse=True,
        )
        return snapshots

    @property
    def llm_configured(self) -> bool:
        if self.settings.llm_provider == "ollama":
            return True
        return bool(self.settings.llm_api_key)

    async def decide(
        self,
        *,
        account: AccountSnapshot,
        markets: list[MarketSnapshot],
        goal: TradingGoal | None,
        risk_limits: dict[str, float],
        pnl_today: float,
    ) -> AgentDecisionBatch:
        """Ask the LLM brain first; heuristic only if LLM is missing/fails."""
        max_pos = self.settings.effective_max_position_pct(account.equity)
        typical = max(8.0, min(max_pos, 20.0)) if self.settings.is_spot else min(max_pos, 3.0)
        zero_fee = bool(getattr(self.settings, "zero_fee_mode", True))
        min_tp = float(getattr(self.settings, "min_take_profit_pct", 0.12))
        fee_mode = "ZERO / very low fees" if zero_fee else "normal fees"
        fee_note = (
            f"Fees are negligible. It is GOOD to close on tiny profits "
            f"(even +{min_tp:.2f}% to +0.4%) when momentum cools. "
            "Do not wait for large moves just to cover fees."
            if zero_fee
            else "Account for fees: prefer +0.4% to +1.5% targets before closing."
        )
        system = SYSTEM_PROMPT.format(
            max_leverage=1.0 if self.settings.is_spot else risk_limits.get("max_leverage", self.settings.max_leverage),
            max_position_pct=max_pos,
            max_open_positions=self.settings.max_open_positions,
            typical_size=typical,
            fee_mode=fee_mode,
            fee_note=fee_note,
            tp_hint=(
                f"even +{min_tp:.2f}%…+0.5% is fine"
                if zero_fee
                else "often +0.4% to +1.5%"
            ),
        )
        user_payload = self._build_context(account, markets, goal, risk_limits, pnl_today)
        user_payload["style"] = self.settings.trading_style
        user_payload["timeframe"] = self.settings.candle_timeframe
        user_payload["zero_fee_mode"] = zero_fee
        user_payload["min_take_profit_pct"] = min_tp
        user_payload["instruction"] = (
            "Scalp momentum: buy strength on 5m, sell when momentum fades. "
            "Prefer frequent small trades. Spot: no shorts. "
            + (
                f"ZERO FEE: close winners quickly even at +{min_tp:.2f}%."
                if zero_fee
                else "Include fees in profit targets."
            )
        )

        if not self.llm_configured:
            logger.warning("llm_not_configured_using_heuristic")
            batch = self._heuristic_decide(account, markets, goal, pnl_today, risk_limits)
            self._last_reasoning = (
                f"[no LLM key — heuristic] {self._summarize(batch)}"
            )
            return batch

        try:
            raw = await self._call_llm(system, json.dumps(user_payload, ensure_ascii=False))
            batch = self._parse_batch(raw)
            self._last_reasoning = f"[AI brain] {self._summarize(batch)}"
            return batch
        except Exception as exc:  # noqa: BLE001
            logger.warning("llm_decide_failed", error=str(exc))
            batch = self._heuristic_decide(account, markets, goal, pnl_today, risk_limits)
            self._last_reasoning = (
                f"[heuristic fallback] {self._summarize(batch)} | llm_error={exc}"
            )
            return batch

    def _build_context(
        self,
        account: AccountSnapshot,
        markets: list[MarketSnapshot],
        goal: TradingGoal | None,
        risk_limits: dict[str, float],
        pnl_today: float,
    ) -> dict[str, Any]:
        goal_block: dict[str, Any] | None = None
        progress = 0.0
        if goal:
            goal_block = {
                "type": goal.goal_type.value,
                "target_usd": goal.target_profit_usd,
                "target_pct": goal.target_profit_pct,
                "profile": goal.risk_profile.value,
                "raw": goal.raw_text,
            }
            if goal.target_profit_usd and goal.target_profit_usd > 0:
                progress = (pnl_today / goal.target_profit_usd) * 100.0
            elif goal.target_profit_pct and account.equity > 0:
                progress = ((pnl_today / account.equity) * 100.0 / goal.target_profit_pct) * 100.0

        return {
            "account": {
                "equity": account.equity,
                "available": account.available_balance,
                "unrealized_pnl": account.unrealized_pnl,
                "pnl_today": pnl_today,
                "drawdown_pct": account.drawdown_pct,
                "mode": account.mode.value,
                "positions": [p.model_dump() for p in account.positions],
            },
            "goal": goal_block,
            "goal_progress_pct": round(progress, 2),
            "risk_limits": risk_limits,
            "markets": [
                {
                    "symbol": m.symbol,
                    "indicators": m.indicators,
                    "order_book": m.order_book,
                    "recent_candles": m.recent_candles,
                }
                for m in markets
            ],
            "universe": self.settings.symbols,
            "instruction": (
                "Read candles + order_book for each symbol. "
                "Decide like a trader. Cite both in reasoning."
            ),
        }

    async def _call_llm(self, system: str, user: str) -> str:
        provider = self.settings.llm_provider
        if provider == "anthropic":
            return await self._call_anthropic(system, user)
        # openai / ollama / xai — OpenAI-compatible chat completions
        return await self._call_openai_compatible(system, user)

    async def _call_openai_compatible(self, system: str, user: str) -> str:
        base = self.settings.effective_llm_base_url or "https://api.openai.com/v1"
        url = f"{base.rstrip('/')}/chat/completions"
        headers = {"Content-Type": "application/json"}
        if self.settings.llm_api_key:
            headers["Authorization"] = f"Bearer {self.settings.llm_api_key}"

        body = {
            "model": self.settings.llm_model,
            "temperature": 0.2,
            "messages": [
                {"role": "system", "content": system},
                {"role": "user", "content": user},
            ],
            "response_format": {"type": "json_object"},
        }
        # Some local models don't support response_format
        if self.settings.llm_provider == "ollama":
            body.pop("response_format", None)

        async with httpx.AsyncClient(timeout=60.0) as client:
            resp = await client.post(url, headers=headers, json=body)
            resp.raise_for_status()
            data = resp.json()
        content = data["choices"][0]["message"]["content"]
        return str(content)

    async def _call_anthropic(self, system: str, user: str) -> str:
        try:
            import anthropic
        except ImportError as exc:  # pragma: no cover
            raise RuntimeError("anthropic package not installed") from exc

        client = anthropic.AsyncAnthropic(api_key=self.settings.llm_api_key)
        msg = await client.messages.create(
            model=self.settings.llm_model,
            max_tokens=2048,
            system=system,
            messages=[{"role": "user", "content": user}],
        )
        parts = []
        for block in msg.content:
            if hasattr(block, "text"):
                parts.append(block.text)
        return "\n".join(parts)

    def _parse_batch(self, raw: str) -> AgentDecisionBatch:
        text = raw.strip()
        if text.startswith("```"):
            text = text.strip("`")
            if text.startswith("json"):
                text = text[4:].strip()
        data = json.loads(text)
        # Always soft-coerce — LLMs often send CLOSE/SELL/aliases
        decisions: list[TradeDecision] = []
        for item in data.get("decisions", []) or []:
            coerced = self._coerce_decision(item)
            if coerced is None:
                continue
            decisions.append(coerced)
        if not decisions:
            # Fallback: try strict whole-batch parse
            try:
                return AgentDecisionBatch.model_validate(data)
            except ValidationError:
                pass
        return AgentDecisionBatch(
            decisions=decisions
            or [
                TradeDecision(
                    action=ActionType.HOLD,
                    confidence=0.4,
                    reasoning="No valid decisions parsed — holding",
                )
            ],
            goal_progress_note=str(data.get("goal_progress_note", "")),
            risk_note=str(data.get("risk_note", "")),
        )

    def _coerce_decision(self, item: Any) -> TradeDecision | None:
        if not isinstance(item, dict):
            return None
        raw = dict(item)
        action = str(raw.get("action") or "hold").strip().lower()
        aliases = {
            "buy": "open_long",
            "long": "open_long",
            "open": "open_long",
            "enter_long": "open_long",
            "sell": "close",
            "exit": "close",
            "close_long": "close",
            "flat": "close",
            "take_profit": "close",
            "tp": "close",
            "short": "open_short",
            "open_short": "open_short",
            "sell_short": "open_short",
        }
        action = aliases.get(action, action)
        if action not in {a.value for a in ActionType}:
            logger.debug("skip_unknown_action", action=action)
            return None
        raw["action"] = action
        if raw.get("side"):
            side = str(raw["side"]).strip().lower()
            if side in {"buy", "long"}:
                raw["side"] = "long"
            elif side in {"sell", "short"}:
                raw["side"] = "short"
        # Spot: never open shorts
        if self.settings.is_spot and action == "open_short":
            return None
        # Clamp tiny TPs for zero-fee mode
        for key in ("take_profit_pct", "stop_loss_pct"):
            if raw.get(key) is None:
                continue
            try:
                val = float(raw[key])
            except (TypeError, ValueError):
                raw[key] = None
                continue
            if key == "take_profit_pct" and 0 < val < 0.05:
                raw[key] = 0.05
            if key == "stop_loss_pct" and 0 < val < 0.1:
                raw[key] = 0.1
        try:
            return TradeDecision.model_validate(raw)
        except ValidationError as ve:
            logger.warning("skip_invalid_decision", error=str(ve), item=raw)
            return None

    def _heuristic_decide(
        self,
        account: AccountSnapshot,
        markets: list[MarketSnapshot],
        goal: TradingGoal | None,
        pnl_today: float,
        risk_limits: dict[str, float],
    ) -> AgentDecisionBatch:
        """Rule-based fallback when LLM is unavailable."""
        # Goal reached → protect
        if goal and goal.target_profit_usd and pnl_today >= goal.target_profit_usd:
            decisions = []
            for p in account.positions:
                decisions.append(
                    TradeDecision(
                        action=ActionType.CLOSE,
                        symbol=p.symbol,
                        side=p.side,
                        confidence=0.9,
                        reasoning="Daily goal reached — closing to lock profit",
                    )
                )
            if not decisions:
                decisions.append(
                    TradeDecision(
                        action=ActionType.HOLD,
                        confidence=0.8,
                        reasoning="Goal reached, flat — holding",
                    )
                )
            return AgentDecisionBatch(
                decisions=decisions,
                goal_progress_note="Goal reached",
                risk_note="Protecting profits",
            )

        if account.positions:
            # Manage open: tiny green (zero-fee) or RSI extreme against position
            decisions: list[TradeDecision] = []
            zero_fee = bool(getattr(self.settings, "zero_fee_mode", True))
            min_tp = float(getattr(self.settings, "min_take_profit_pct", 0.12))
            for p in account.positions:
                m = next((x for x in markets if x.symbol == p.symbol), None)
                ind = (m.indicators if m else None) or {}
                book = (m.order_book if m else None) or {}
                rsi = ind.get("rsi")
                mom = float(ind.get("momentum_5m_pct") or 0.0)
                pressure = str(book.get("pressure") or "neutral")
                pnl_pct = 0.0
                if p.entry_price > 0 and p.mark_price > 0:
                    sign = 1.0 if p.side == Side.LONG else -1.0
                    pnl_pct = ((p.mark_price - p.entry_price) / p.entry_price) * 100.0 * sign
                if (
                    zero_fee
                    and p.side == Side.LONG
                    and pnl_pct >= min_tp
                    and (mom < 0.08 or pressure == "ask_heavy" or (rsi is not None and rsi >= 65))
                ):
                    decisions.append(
                        TradeDecision(
                            action=ActionType.CLOSE,
                            symbol=p.symbol,
                            side=p.side,
                            confidence=0.75,
                            reasoning=(
                                f"Zero-fee tiny TP +{pnl_pct:.3f}% "
                                f"mom5m={mom:.3f} rsi={rsi} book={pressure}"
                            ),
                            take_profit_pct=round(max(pnl_pct, min_tp), 3),
                        )
                    )
                elif rsi is not None:
                    if p.side == Side.LONG and rsi > 75:
                        decisions.append(
                            TradeDecision(
                                action=ActionType.CLOSE,
                                symbol=p.symbol,
                                side=p.side,
                                confidence=0.7,
                                reasoning=f"RSI {rsi:.1f} overbought — close long",
                            )
                        )
                    elif p.side == Side.SHORT and rsi < 25:
                        decisions.append(
                            TradeDecision(
                                action=ActionType.CLOSE,
                                symbol=p.symbol,
                                side=p.side,
                                confidence=0.7,
                                reasoning=f"RSI {rsi:.1f} oversold — close short",
                            )
                        )
            if decisions:
                return AgentDecisionBatch(
                    decisions=decisions,
                    goal_progress_note="Managing open risk",
                    risk_note="Heuristic scalp / RSI exit",
                )

        # Look for a single setup if we have a goal and room for positions
        if goal and len(account.positions) < self.settings.max_open_positions:
            best: MarketSnapshot | None = None
            best_score = 0.0
            direction: ActionType | None = None
            for m in markets:
                ind = m.indicators or {}
                if ind.get("error"):
                    continue
                rsi = ind.get("rsi")
                trend = ind.get("trend")
                score = 0.0
                action = None
                if trend == "bullish" and rsi is not None and 40 <= rsi <= 60:
                    score = 0.55 + (0.1 if ind.get("macd_hist", 0) and ind["macd_hist"] > 0 else 0)
                    action = ActionType.OPEN_LONG
                elif (
                    not self.settings.is_spot
                    and trend == "bearish"
                    and rsi is not None
                    and 40 <= rsi <= 60
                ):
                    score = 0.55 + (0.1 if ind.get("macd_hist", 0) and ind["macd_hist"] < 0 else 0)
                    action = ActionType.OPEN_SHORT
                # Spot: allow cautious dip-buy when oversold in non-crash conditions
                elif self.settings.is_spot and rsi is not None and 30 <= rsi <= 45 and trend != "bearish":
                    score = 0.55
                    action = ActionType.OPEN_LONG
                if action and score > best_score:
                    best_score = score
                    best = m
                    direction = action

            if best and direction and best_score >= 0.55:
                size = min(
                    risk_limits.get("max_position_pct", 3.0) * 0.7,
                    self.settings.max_position_pct,
                )
                lev = min(risk_limits.get("max_leverage", 3.0), 3.0)
                return AgentDecisionBatch(
                    decisions=[
                        TradeDecision(
                            action=direction,
                            symbol=best.symbol,
                            side=Side.LONG
                            if direction == ActionType.OPEN_LONG
                            else Side.SHORT,
                            size_pct_of_equity=size,
                            leverage=lev,
                            confidence=best_score,
                            reasoning=(
                                f"Heuristic {direction.value} on {best.symbol}: "
                                f"trend={best.indicators.get('trend')}, "
                                f"rsi={best.indicators.get('rsi')}"
                            ),
                            stop_loss_pct=1.5,
                            take_profit_pct=(
                                0.35
                                if getattr(self.settings, "zero_fee_mode", True)
                                else 2.5
                            ),
                        )
                    ],
                    goal_progress_note=f"pnl_today={pnl_today:.2f}",
                    risk_note="Heuristic entry within limits",
                )

        return AgentDecisionBatch(
            decisions=[
                TradeDecision(
                    action=ActionType.HOLD,
                    confidence=0.5,
                    reasoning="No clear setup — holding",
                )
            ],
            goal_progress_note=f"pnl_today={pnl_today:.2f}",
            risk_note="Waiting for setup",
        )

    @staticmethod
    def _summarize(batch: AgentDecisionBatch) -> str:
        parts = [f"{d.action.value}:{d.symbol or '-'}({d.confidence:.2f})" for d in batch.decisions]
        note = batch.goal_progress_note or batch.risk_note
        return "; ".join(parts) + (f" | {note}" if note else "")
