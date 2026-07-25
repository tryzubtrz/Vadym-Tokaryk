"""aiogram Telegram bot — primary user interface (RU/EN natural language)."""

from __future__ import annotations

import asyncio
from typing import TYPE_CHECKING

from aiogram import Bot, Dispatcher, F
from aiogram.enums import ParseMode
from aiogram.filters import Command, CommandStart
from aiogram.types import Message
from aiogram.client.default import DefaultBotProperties

from astraforge.core.goal_interpreter import detect_language
from astraforge.utils.logging import get_logger

if TYPE_CHECKING:
    from astraforge.core.engine import TradingEngine

logger = get_logger(__name__)


class TelegramBotApp:
    """Thin wrapper around aiogram that talks to TradingEngine."""

    def __init__(self, token: str, allowed_ids: set[int], engine: TradingEngine) -> None:
        self.engine = engine
        self.allowed_ids = allowed_ids
        self.bot = Bot(
            token=token,
            default=DefaultBotProperties(parse_mode=ParseMode.MARKDOWN),
        )
        self.dp = Dispatcher()
        self._chat_ids: set[int] = set()
        self._register()

    def _authorized(self, message: Message) -> bool:
        uid = message.from_user.id if message.from_user else None
        if uid is None:
            return False
        if not self.allowed_ids:
            # If no whitelist configured, allow first user and lock to them
            logger.warning("telegram_no_whitelist_configured", user_id=uid)
            return True
        return uid in self.allowed_ids

    def _register(self) -> None:
        @self.dp.message(CommandStart())
        async def cmd_start(message: Message) -> None:
            if not self._authorized(message):
                await message.answer("Access denied.")
                return
            if message.chat:
                self._chat_ids.add(message.chat.id)
            text = await self.engine.startup_message()
            await message.answer(text)

        @self.dp.message(Command("status"))
        async def cmd_status(message: Message) -> None:
            if not self._authorized(message):
                return
            lang = detect_language(message.text or "")
            await message.answer(await self.engine.format_status(lang=lang))

        @self.dp.message(Command("report"))
        async def cmd_report(message: Message) -> None:
            if not self._authorized(message):
                return
            lang = detect_language(message.text or "ru")
            await message.answer(await self.engine.format_report(lang=lang))

        @self.dp.message(Command("emergency_stop"))
        async def cmd_emergency(message: Message) -> None:
            if not self._authorized(message):
                return
            reply = await self.engine.emergency_stop()
            await message.answer(reply)

        @self.dp.message(Command("resume"))
        async def cmd_resume(message: Message) -> None:
            if not self._authorized(message):
                return
            reply = await self.engine.resume_trading()
            await message.answer(reply)

        @self.dp.message(Command("help"))
        async def cmd_help(message: Message) -> None:
            if not self._authorized(message):
                return
            await message.answer(
                "AstraForge AI — команды / examples:\n"
                "• «сделай мне сегодня 200 долларов»\n"
                "• «цель на сегодня +3%»\n"
                "• «работай консервативно, цель 150$»\n"
                "• «закрой все позиции» / «стоп»\n"
                "• /status /report /emergency_stop /resume\n\n"
                "⚠️ Даже с лимитами риск потери капитала остаётся."
            )

        @self.dp.message(F.text)
        async def on_text(message: Message) -> None:
            if not self._authorized(message):
                await message.answer("Access denied.")
                return
            if message.chat:
                self._chat_ids.add(message.chat.id)
            text = (message.text or "").strip()
            if not text:
                return

            # Natural-language emergency shortcuts
            lower = text.lower().strip()
            if lower in {"стоп", "stop", "emergency", "аварийная остановка"}:
                await message.answer(await self.engine.emergency_stop())
                return

            try:
                reply = await self.engine.handle_user_text(text)
            except Exception as exc:  # noqa: BLE001
                logger.exception("handle_user_text_failed", error=str(exc))
                reply = f"Error: {exc}"
            if reply:
                await message.answer(reply)

    async def broadcast(self, text: str) -> None:
        """Send a message to all known chats (and allowed users as fallback)."""
        targets = set(self._chat_ids)
        # Also try direct user ids if no chats yet
        if not targets:
            targets = set(self.allowed_ids)
        for chat_id in list(targets):
            try:
                await self.bot.send_message(chat_id, text)
            except Exception as exc:  # noqa: BLE001
                logger.warning("broadcast_failed", chat_id=chat_id, error=str(exc))

    async def announce_startup(self) -> None:
        msg = await self.engine.startup_message()
        # Prefer configured user ids
        for uid in self.allowed_ids:
            try:
                await self.bot.send_message(uid, msg)
                self._chat_ids.add(uid)
            except Exception as exc:  # noqa: BLE001
                logger.warning("startup_announce_failed", user_id=uid, error=str(exc))

    async def run(self) -> None:
        logger.info("telegram_bot_starting")
        # Small delay so engine is ready
        await asyncio.sleep(1)
        await self.announce_startup()
        await self.dp.start_polling(self.bot, allowed_updates=["message"])

    async def close(self) -> None:
        await self.bot.session.close()


def main() -> None:
    """Standalone entry (usually started via astraforge.main)."""
    import asyncio
    from astraforge.core.config import get_settings
    from astraforge.core.engine import TradingEngine
    from astraforge.utils.logging import setup_logging

    settings = get_settings()
    setup_logging(settings.log_level)
    engine = TradingEngine(settings)

    async def _run() -> None:
        await engine.start()
        app = TelegramBotApp(
            settings.telegram_bot_token,
            settings.allowed_user_ids,
            engine,
        )
        engine.set_notify(app.broadcast)
        try:
            await app.run()
        finally:
            await app.close()
            await engine.stop()

    asyncio.run(_run())


if __name__ == "__main__":
    main()
