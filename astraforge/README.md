# AstraForge AI

Автономный ИИ-агент для торговли криптовалютными **perpetual futures**.  
После разовой настройки вы кладёте API-ключи в `.env`, запускаете Docker — и дальше управляете ботом обычными сообщениями в **Telegram**.

> Основной интерфейс — Telegram. Веб-дашборд нужен только для мониторинга.

---

## ⚠️ КРИТИЧЕСКОЕ ПРЕДУПРЕЖДЕНИЕ О РИСКАХ

**Торговля деривативами связана с высоким риском потери капитала. Вы можете потерять часть или все средства на счёте.**

Даже при жёстких лимитах (daily loss, drawdown, leverage) **AstraForge AI не гарантирует прибыль**.  
ИИ может ошибаться. Рынок может двигаться против позиции. API биржи может сбоить.

**Это не финансовый совет.** Используйте только те средства, потерю которых вы можете себе позволить.  
По умолчанию бот работает в **paper mode (testnet)**. Не включайте live, пока не понимаете риски.

### Правила создания API-ключей (ОБЯЗАТЕЛЬНО)

1. Создайте **отдельный** API-ключ только для бота.
2. Права ключа:
   - ✅ **Read**
   - ✅ **Futures / Derivatives Trading**
   - ❌ **Withdrawal / Transfer / Universal Transfer — ВЫКЛЮЧИТЬ**
3. По возможности включите **IP whitelist**.
4. Никогда не публикуйте ключи и не коммитьте `.env` в git.
5. Начните с **testnet / paper mode**.

---

## Возможности

- Подключение к **Binance Futures** и **Bybit** через CCXT (async)
- Работа в **paper mode** по умолчанию
- Цели на естественном языке (RU/EN): «сделай сегодня 200$», «цель +3%»
- Неотключаемые риск-лимиты в Python-коде (LLM не может их обойти)
- Circuit breaker при ошибках API / margin / аномалиях
- Лог reasoning ИИ, дневные отчёты в Telegram
- Минимальный веб-дашборд на FastAPI
- Состояние в SQLite (цель, equity, сделки) — переживает рестарт

### Жёсткие лимиты безопасности (по умолчанию)

| Лимит | Значение | Потолок в коде |
|--------|----------|----------------|
| Daily loss limit | 2.5% депозита | ≤ 2.5% |
| Max drawdown от пика | 6% | ≤ 7% |
| Max leverage | 5x | ≤ 5x |
| Max размер позиции | 3.5% equity | ≤ 4% |
| Max открытых позиций | 3 | ≤ 3 |

При достижении daily loss бот **останавливает торговлю до следующего UTC-дня**.

---

## Що потрібно від тебе

Повний список + посилання де взяти ключі: **[WHAT_YOU_NEED.md](./WHAT_YOU_NEED.md)**

Коротко: ключ біржі + ключ LLM (OpenAI/Claude/Grok) + (бажано) Telegram. Код і AI-логіку я вже зробив.

AI-мозок читає **свічки + order book (стакан)** і сам вирішує long/short/hold.

---

## Самый простой запуск — ОДИН ФАЙЛ

Не нужен Docker и не нужна вся папка модулей. Достаточно файла `astraforge_one.py`.

```bash
cd astraforge
pip install ccxt pandas httpx aiosqlite pydantic
# опционально для Telegram:
# pip install aiogram

python astraforge_one.py
```

Скрипт спросит:
1. **Exchange API KEY + SECRET** (обязательно) — права только Read + Futures, без Withdrawal
2. Telegram-токен (можно пропустить → управление в консоли)
3. LLM-ключ (можно пропустить → встроенная heuristic-логика)

После этого бот стартует в **paper mode** и ждёт цель, например:
```text
make 100 dollars today
```
или в консоли/Telegram:
```text
сделай сегодня 100 долларов
```

Можно заранее положить ключи в `.env` — тогда спрашивать почти ничего не будет.

---

## Быстрый старт (Docker, полный проект)

### 1. Получите ключи

**Telegram**
1. Откройте [@BotFather](https://t.me/BotFather) → `/newbot` → скопируйте токен.
2. Узнайте свой user id через [@userinfobot](https://t.me/userinfobot).

**Биржа (testnet сначала!)**
- Binance Futures Testnet: https://testnet.binancefuture.com/
- Bybit Testnet: https://testnet.bybit.com/

**LLM**
- OpenAI / Anthropic / xAI API key, либо локальный Ollama.

### 2. Настройте `.env`

```bash
cd astraforge
cp .env.example .env
nano .env   # или любой редактор
```

Минимум:

```env
TELEGRAM_BOT_TOKEN=123456:ABC...
TELEGRAM_ALLOWED_USER_IDS=123456789

EXCHANGE_ID=binance
EXCHANGE_API_KEY=...
EXCHANGE_API_SECRET=...

TRADING_MODE=paper
LIVE_CONFIRMED=false

LLM_PROVIDER=openai
LLM_MODEL=gpt-4o-mini
LLM_API_KEY=sk-...
```

### 3. Запуск

```bash
docker compose up --build -d
```

Дашборд: http://localhost:8080  

При старте бот напишет в Telegram:

> Бот запущен в paper mode. Готов принимать цели. Напиши, сколько хочешь заработать сегодня.

Логи:

```bash
docker compose logs -f astraforge
```

Остановка:

```bash
docker compose down
```

### Локальный запуск без Docker

```bash
cd astraforge
python3.11 -m venv .venv
source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env
python -m astraforge.main
```

---

## Переключение paper → live

Live **не включится**, пока вы явно не подтвердите:

```env
TRADING_MODE=live
LIVE_CONFIRMED=true
```

Без `LIVE_CONFIRMED=true` конфиг принудительно остаётся в `paper`.  
После смены режима перезапустите контейнер:

```bash
docker compose up -d --force-recreate
```

Рекомендуется: сначала недели paper/testnet → маленькое live equity → мониторинг Telegram.

---

## Примеры сообщений в Telegram

| Сообщение | Действие |
|-----------|----------|
| `сделай мне сегодня 200 долларов` | Цель +$200 за день |
| `цель на сегодня +3%` | Цель +3% к equity |
| `работай консервативно, цель 150$` | Профиль conservative + цель |
| `закрой все позиции` | Закрыть все позиции |
| `стоп` / `/emergency_stop` | Аварийная остановка + flatten |
| `/status` или `статус` | PnL, позиции, прогресс цели |
| `/report` или `отчёт` | Отчёт + reasoning |
| `/resume` | Возобновить (если не daily halt) |
| `make me $100 today` | English goal |

Если цель слишком агрессивная для риск-лимитов, бот **откажется** и предложит реалистичную альтернативу.

---

## Архитектура

```
astraforge/
├── src/astraforge/
│   ├── core/
│   │   ├── config.py            # настройки + hard ceilings
│   │   ├── exchange.py          # CCXT async (Binance/Bybit)
│   │   ├── ai_agent.py          # LLM решения (JSON / Pydantic)
│   │   ├── risk_manager.py      # неотключаемые лимиты
│   │   ├── goal_interpreter.py  # парсинг целей RU/EN
│   │   ├── order_executor.py
│   │   ├── state_manager.py     # SQLite
│   │   ├── circuit_breaker.py
│   │   └── engine.py            # главный цикл
│   ├── telegram/bot.py          # aiogram
│   ├── dashboard/               # FastAPI монитор
│   ├── backtest/
│   └── utils/
├── config/default.yaml
├── docker/
├── tests/
├── .env.example
├── docker-compose.yml
└── pyproject.toml
```

Поток: **Telegram цель → Goal Interpreter → AI Agent → Risk Manager → Order Executor → Exchange**.  
Risk Manager и Circuit Breaker стоят после LLM и режут/клампят любые опасные решения.

---

## Команды Telegram

- `/start` — приветствие
- `/status` — статус
- `/report` — отчёт и reasoning
- `/emergency_stop` — стоп + закрытие всех позиций
- `/resume` — возобновление (не снимает daily loss halt в тот же UTC-день)
- `/help` — справка

---

## Тесты

```bash
cd astraforge
pip install -e ".[dev]"
pytest -q
```

---

## Дисклеймер (ещё раз)

AstraForge AI — экспериментальный инструмент.  
**Даже при соблюдении всех лимитов возможна полная или частичная потеря капитала.**  
Авторы не несут ответственности за торговые убытки. Используйте на свой страх и риск.
