"""Parse natural-language user messages into structured trading goals.

Supports Russian and English. Uses regex heuristics first; optionally
falls back to LLM for ambiguous phrases.
"""

from __future__ import annotations

import re
from typing import Literal

from astraforge.core.config import Settings
from astraforge.core.models import (
    GoalType,
    InterpretedGoal,
    RiskProfile,
    TradingGoal,
)
from astraforge.core.risk_manager import RiskManager
from astraforge.utils.logging import get_logger

logger = get_logger(__name__)


def detect_language(text: str) -> Literal["ru", "en"]:
    """Very light language detection based on Cyrillic ratio."""
    cyr = sum(1 for ch in text if "а" <= ch.lower() <= "я" or ch.lower() == "ё")
    latin = sum(1 for ch in text if "a" <= ch.lower() <= "z")
    if cyr > latin:
        return "ru"
    return "en"


class GoalInterpreter:
    """Turn free-form Telegram text into a TradingGoal."""

    # Patterns (ru + en)
    RE_USD = re.compile(
        r"(?:"
        r"(?:заработай|сделай|хочу|цель|нужно|дай|получить|заработать|today|make|earn|target|goal)"
        r".{0,40}?)?"
        r"([+]?\d+(?:[.,]\d+)?)\s*"
        r"(?:\$|usd|usdt|доллар(?:ов|а)?|баксов|бакса)?"
        r"|(?:\$|usd)\s*([+]?\d+(?:[.,]\d+)?)",
        re.IGNORECASE,
    )
    RE_PCT = re.compile(
        r"([+]?\d+(?:[.,]\d+)?)\s*%|"
        r"(?:плюс|plus|\+)\s*([+]?\d+(?:[.,]\d+)?)\s*(?:процент(?:ов|а)?|percent|pct)?",
        re.IGNORECASE,
    )
    RE_CLOSE = re.compile(
        r"(закрой\s*(все|всё)?|close\s*all|flatten|выйди\s*из\s*позиц)",
        re.IGNORECASE,
    )
    RE_STOP = re.compile(
        r"^(стоп|stop|остановись|halt|pause|пауза|emergency|аварийная\s*остановка)$",
        re.IGNORECASE,
    )
    RE_STATUS = re.compile(
        r"^(статус|status|как\s*дела|pnl|баланс|equity|состояние)$",
        re.IGNORECASE,
    )
    RE_REPORT = re.compile(
        r"(отчёт|отчет|report|reasoning|почему|лог\s*решени)",
        re.IGNORECASE,
    )
    RE_CONSERVATIVE = re.compile(
        r"(консервативн|conservative|осторожн|аккуратн)",
        re.IGNORECASE,
    )
    RE_AGGRESSIVE = re.compile(
        r"(агрессивн|aggressive|рискн|risky)",
        re.IGNORECASE,
    )
    RE_BALANCED = re.compile(
        r"(сбалансир|balanced|нормальн|обычн)",
        re.IGNORECASE,
    )

    def __init__(self, settings: Settings, risk_manager: RiskManager) -> None:
        self.settings = settings
        self.risk = risk_manager

    def interpret(
        self,
        text: str,
        *,
        equity: float,
    ) -> InterpretedGoal:
        raw = (text or "").strip()
        lang = detect_language(raw)
        lower = raw.lower()

        # Profile only
        profile = self._extract_profile(lower)

        if self.RE_STOP.search(lower.strip()):
            goal = TradingGoal(
                goal_type=GoalType.STOP_TRADING,
                raw_text=raw,
                language=lang,
                risk_profile=profile or self.risk.profile,
            )
            reply = (
                "Останавливаю торговлю. Новые сделки не открываются."
                if lang == "ru"
                else "Stopping trading. No new positions will be opened."
            )
            return InterpretedGoal(understood=True, goal=goal, reply_text=reply, language=lang)

        if self.RE_CLOSE.search(lower):
            goal = TradingGoal(
                goal_type=GoalType.CLOSE_ALL,
                raw_text=raw,
                language=lang,
                risk_profile=profile or self.risk.profile,
            )
            reply = (
                "Закрываю все позиции."
                if lang == "ru"
                else "Closing all positions."
            )
            return InterpretedGoal(understood=True, goal=goal, reply_text=reply, language=lang)

        if self.RE_STATUS.search(lower.strip()):
            goal = TradingGoal(
                goal_type=GoalType.STATUS,
                raw_text=raw,
                language=lang,
                risk_profile=profile or self.risk.profile,
            )
            return InterpretedGoal(
                understood=True,
                goal=goal,
                reply_text="",  # bot fills status
                language=lang,
            )

        if self.RE_REPORT.search(lower) and not self._has_numeric_target(raw):
            goal = TradingGoal(
                goal_type=GoalType.REPORT,
                raw_text=raw,
                language=lang,
                risk_profile=profile or self.risk.profile,
            )
            return InterpretedGoal(understood=True, goal=goal, reply_text="", language=lang)

        # Profit targets
        usd = self._extract_usd(raw)
        pct = self._extract_pct(raw)

        if usd is None and pct is None:
            # Profile-only message
            if profile is not None:
                goal = TradingGoal(
                    goal_type=GoalType.SET_PROFILE,
                    risk_profile=profile,
                    raw_text=raw,
                    language=lang,
                )
                name = profile.value
                reply = (
                    f"Риск-профиль установлен: {name}."
                    if lang == "ru"
                    else f"Risk profile set to: {name}."
                )
                return InterpretedGoal(
                    understood=True, goal=goal, reply_text=reply, language=lang
                )

            reply = (
                "Не понял цель. Примеры:\n"
                "• «сделай мне сегодня 200 долларов»\n"
                "• «цель на сегодня +3%»\n"
                "• «работай консервативно, цель 150$»\n"
                "• «закрой все позиции» / «стоп»"
                if lang == "ru"
                else "I didn't understand the goal. Examples:\n"
                "• «make me 200 dollars today»\n"
                "• «target +3% today»\n"
                "• «work conservatively, goal $150»\n"
                "• «close all» / «stop»"
            )
            return InterpretedGoal(
                understood=False,
                goal=None,
                reply_text=reply,
                language=lang,
            )

        risk_profile = profile or self.risk.profile
        goal = TradingGoal(
            goal_type=GoalType.PROFIT_PCT if pct is not None and usd is None else GoalType.PROFIT_USD,
            target_profit_usd=usd,
            target_profit_pct=pct,
            risk_profile=risk_profile,
            period="day",
            raw_text=raw,
            language=lang,
            active=True,
        )

        # If only pct — also compute usd estimate for messaging
        target_usd = usd
        if target_usd is None and pct is not None and equity > 0:
            target_usd = equity * (pct / 100.0)

        too_agg, suggested_max = self.risk.is_goal_too_aggressive(
            equity=equity,
            target_usd=target_usd,
            target_pct=pct if usd is None else None,
        )

        if too_agg:
            suggested = TradingGoal(
                goal_type=GoalType.PROFIT_USD,
                target_profit_usd=suggested_max,
                risk_profile=RiskProfile.CONSERVATIVE
                if risk_profile == RiskProfile.AGGRESSIVE
                else risk_profile,
                period="day",
                raw_text=raw,
                language=lang,
                active=False,
                notes="suggested_safer_alternative",
            )
            if lang == "ru":
                reply = (
                    f"⚠️ Цель выглядит слишком агрессивной для текущих риск-лимитов "
                    f"(daily loss ≤ {self.risk.limits['daily_loss_limit_pct']}%, "
                    f"leverage ≤ {self.risk.limits['max_leverage']}x).\n\n"
                    f"Я не могу нарушать правила безопасности.\n"
                    f"Реалистичнее: около ${suggested_max:.0f} сегодня.\n"
                    f"Напиши «цель {suggested_max:.0f}$» чтобы подтвердить, "
                    f"или снизь цель / выбери консервативный режим."
                )
            else:
                reply = (
                    f"⚠️ That target looks too aggressive for current risk limits "
                    f"(daily loss ≤ {self.risk.limits['daily_loss_limit_pct']}%, "
                    f"leverage ≤ {self.risk.limits['max_leverage']}x).\n\n"
                    f"I cannot violate safety rules.\n"
                    f"More realistic: about ${suggested_max:.0f} today.\n"
                    f"Reply with «goal {suggested_max:.0f}$» to confirm, "
                    f"or lower the target / switch to conservative mode."
                )
            return InterpretedGoal(
                understood=True,
                goal=None,
                reply_text=reply,
                is_aggressive=True,
                suggested_goal=suggested,
                language=lang,
            )

        # Accept goal
        parts = []
        if usd is not None:
            parts.append(f"${usd:g}")
        if pct is not None:
            parts.append(f"{pct:g}%")
        target_str = " / ".join(parts)
        if lang == "ru":
            reply = (
                f"✅ Цель принята: {target_str} за день.\n"
                f"Риск-профиль: {risk_profile.value}.\n"
                f"Лимиты безопасности активны (daily loss "
                f"{self.risk.limits['daily_loss_limit_pct']}%, "
                f"max DD {self.risk.limits['max_drawdown_pct']}%, "
                f"leverage ≤ {self.risk.limits['max_leverage']}x).\n"
                f"Начинаю работу."
            )
        else:
            reply = (
                f"✅ Goal accepted: {target_str} for today.\n"
                f"Risk profile: {risk_profile.value}.\n"
                f"Safety limits active (daily loss "
                f"{self.risk.limits['daily_loss_limit_pct']}%, "
                f"max DD {self.risk.limits['max_drawdown_pct']}%, "
                f"leverage ≤ {self.risk.limits['max_leverage']}x).\n"
                f"Starting work."
            )

        logger.info(
            "goal_interpreted",
            usd=usd,
            pct=pct,
            profile=risk_profile.value,
            lang=lang,
        )
        return InterpretedGoal(
            understood=True,
            goal=goal,
            reply_text=reply,
            language=lang,
        )

    def _extract_profile(self, lower: str) -> RiskProfile | None:
        if self.RE_CONSERVATIVE.search(lower):
            return RiskProfile.CONSERVATIVE
        if self.RE_AGGRESSIVE.search(lower):
            return RiskProfile.AGGRESSIVE
        if self.RE_BALANCED.search(lower):
            return RiskProfile.BALANCED
        return None

    def _extract_usd(self, text: str) -> float | None:
        # Prefer explicit $ / usd / доллар
        m = re.search(
            r"([+]?\d+(?:[.,]\d+)?)\s*(?:\$|usd|usdt|доллар(?:ов|а)?|баксов|бакса)",
            text,
            re.IGNORECASE,
        )
        if m:
            return float(m.group(1).replace(",", "."))
        m = re.search(r"(?:\$|usd)\s*([+]?\d+(?:[.,]\d+)?)", text, re.IGNORECASE)
        if m:
            return float(m.group(1).replace(",", "."))
        # «сделай 200» without unit — treat as USD if no %
        if "%" not in text and "процент" not in text.lower():
            m = re.search(
                r"(?:сделай|заработай|цель|хочу|make|earn|goal|target)\s+"
                r"(?:мне\s+)?(?:сегодня\s+)?([+]?\d+(?:[.,]\d+)?)",
                text,
                re.IGNORECASE,
            )
            if m:
                return float(m.group(1).replace(",", "."))
        return None

    def _extract_pct(self, text: str) -> float | None:
        m = re.search(r"([+]?\d+(?:[.,]\d+)?)\s*%", text)
        if m:
            return float(m.group(1).replace(",", "."))
        m = re.search(
            r"(?:\+|плюс|plus)\s*([+]?\d+(?:[.,]\d+)?)\s*(?:%|процент)",
            text,
            re.IGNORECASE,
        )
        if m:
            return float(m.group(1).replace(",", "."))
        return None

    def _has_numeric_target(self, text: str) -> bool:
        return self._extract_usd(text) is not None or self._extract_pct(text) is not None
