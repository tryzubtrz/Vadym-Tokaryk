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

SYSTEM_PROMPT = """You are AstraForge AI — a real trading brain for crypto perpetual futures.

You are NOT a fixed rule script. You READ the market data and DECIDE yourself:
- Candles (OHLCV + indicators + recent bars)
- Order book / "the book" (bids, asks, imbalance, walls, spread, pressure)
- Open positions, equity, and the user's profit goal

Think like a discretionary trader:
1. Read trend + momentum from candles
2. Confirm or fade using order-book pressure (bid_heavy / ask_heavy, walls)
3. Choose open_long / open_short / close / reduce / hold
4. Explain WHY in reasoning (mention candle + book signals)

HARD RULES (enforced outside you — do not violate):
1. Max leverage: {max_leverage}x
2. Max position size: {max_position_pct}% of equity
3. Max open positions: {max_open_positions}
4. Never blow risk limits to chase the daily goal
5. Prefer HOLD when confidence < 0.45 or book+candles disagree
6. Protect profits when the goal is already reached

Respond with ONLY valid JSON:
{{
  "decisions": [
    {{
      "action": "open_long" | "open_short" | "close" | "hold" | "reduce",
      "symbol": "BTC/USDT:USDT" or null,
      "side": "long" | "short" | null,
      "size_pct_of_equity": 0.0-{max_position_pct},
      "leverage": 1.0-{max_leverage},
      "confidence": 0.0-1.0,
      "reasoning": "short explanation citing candles + order book",
      "stop_loss_pct": number or null,
      "take_profit_pct": number or null
    }}
  ],
  "goal_progress_note": "string",
  "risk_note": "string"
}}

Do not invent symbols outside the provided universe.
Output JSON only — no markdown fences.
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
        snapshots: list[MarketSnapshot] = []
        for symbol in symbols:
            ohlcv = await exchange.fetch_ohlcv(symbol, timeframe="15m", limit=100)
            if not ohlcv:
                continue
            df = ohlcv_to_dataframe(ohlcv)
            indicators = compute_indicators(df)
            book = await exchange.fetch_order_book(symbol, limit=20)
            recent = []
            for row in ohlcv[-8:]:
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
        system = SYSTEM_PROMPT.format(
            max_leverage=risk_limits.get("max_leverage", self.settings.max_leverage),
            max_position_pct=risk_limits.get(
                "max_position_pct", self.settings.max_position_pct
            ),
            max_open_positions=self.settings.max_open_positions,
        )
        user_payload = self._build_context(account, markets, goal, risk_limits, pnl_today)

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
        try:
            return AgentDecisionBatch.model_validate(data)
        except ValidationError:
            # Soft coerce decisions list
            decisions = []
            for item in data.get("decisions", []):
                try:
                    decisions.append(TradeDecision.model_validate(item))
                except ValidationError as ve:
                    logger.debug("skip_invalid_decision", error=str(ve))
            return AgentDecisionBatch(
                decisions=decisions,
                goal_progress_note=str(data.get("goal_progress_note", "")),
                risk_note=str(data.get("risk_note", "")),
            )

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
            # Manage open: close if RSI extreme against position
            decisions: list[TradeDecision] = []
            for p in account.positions:
                m = next((x for x in markets if x.symbol == p.symbol), None)
                rsi = (m.indicators or {}).get("rsi") if m else None
                if rsi is not None:
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
                    risk_note="Heuristic RSI exit",
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
                elif trend == "bearish" and rsi is not None and 40 <= rsi <= 60:
                    score = 0.55 + (0.1 if ind.get("macd_hist", 0) and ind["macd_hist"] < 0 else 0)
                    action = ActionType.OPEN_SHORT
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
                            take_profit_pct=2.5,
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
