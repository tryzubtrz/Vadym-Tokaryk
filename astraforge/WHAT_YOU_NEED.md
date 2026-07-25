# Що потрібно від тебе (і де взяти)

Я (код AstraForge) уже вміє:
- читати **свічки**
- читати **стакан (order book / “книгу”)**
- віддавати це в **ШІ (LLM)**
- виконувати buy/sell на ф’ючерсах
- тримати жорсткі ліміти ризику

Від тебе потрібні лише ключі + запуск на своєму ПК/VPS.

---

## 1) Ключ біржі (обов’язково)

**Навіщо:** підключення до futures (Binance або Bybit).

**Де взяти (спочатку TESTNET):**
- Binance Futures Testnet: https://testnet.binancefuture.com/  
  → API Management → Create API
- Bybit Testnet: https://testnet.bybit.com/  
  → API → Create New Key

**Права ключа:**
- ✅ Read
- ✅ Futures / Derivatives Trading
- ❌ Withdrawal / Transfer — **ВИМКНУТИ**

Потім у `.env`:
```env
EXCHANGE_ID=binance
EXCHANGE_API_KEY=...
EXCHANGE_API_SECRET=...
TRADING_MODE=paper
LIVE_CONFIRMED=false
```

---

## 2) Ключ штучного інтелекту / LLM (обов’язково для “справжнього ШІ”)

**Навіщо:** щоб рішення приймав саме AI (читає свічки + стакан), а не простий код-правил.

**Де взяти (будь-який один варіант):**
- OpenAI: https://platform.openai.com/api-keys  
  модель наприклад `gpt-4o-mini`
- Anthropic Claude: https://console.anthropic.com/  
  `LLM_PROVIDER=anthropic`
- xAI Grok: https://console.x.ai/  
  `LLM_PROVIDER=xai`
- Безкоштовніше локально: [Ollama](https://ollama.com/)  
  `LLM_PROVIDER=ollama`, `LLM_MODEL=llama3.1`

```env
LLM_PROVIDER=openai
LLM_MODEL=gpt-4o-mini
LLM_API_KEY=sk-...
```

Без цього ключа бот працює в слабому heuristic-режимі (це вже **не** той AI, який ти хочеш).

---

## 3) Telegram-бот (рекомендовано)

**Навіщо:** писати цілі звичайною мовою: «зроби сьогодні 50$».

**Де взяти:**
1. [@BotFather](https://t.me/BotFather) → `/newbot` → токен
2. [@userinfobot](https://t.me/userinfobot) → твій numeric ID

```env
TELEGRAM_BOT_TOKEN=123456:ABC...
TELEGRAM_ALLOWED_USER_IDS=123456789
```

Якщо пропустиш — керування буде в консолі.

---

## 4) Де запускати

**Варіант А — один файл (найпростіше):**
```bash
cd astraforge
pip install -r requirements-one.txt
# опційно для Telegram: pip install aiogram
cp .env.example .env   # встав ключі
python astraforge_one.py
```

**Варіант B — Docker:**
```bash
cd astraforge
cp .env.example .env
docker compose up --build -d
```

Комп’ютер/VPS має бути увімкнений, поки бот працює.

---

## Мінімальний чеклист

| Що | Обов’язково? | Де |
|----|--------------|-----|
| Exchange API key+secret | Так | Binance/Bybit testnet |
| LLM API key | Так (для AI-мозку) | OpenAI / Anthropic / xAI / Ollama |
| Telegram token + user id | Бажано | BotFather + userinfobot |
| Запуск на ПК/VPS | Так | `python astraforge_one.py` або Docker |

---

## Чого від тебе НЕ потрібно

- писати код
- вигадувати стратегію
- вручну клікати long/short кожні 2 хвилини

Ти даєш ключі → пишеш ціль у Telegram → AI читає ринок і торгує в межах лімітів.
