# MyMasyaAI

Кросплатформенний Flutter-компаньйон з вирощуванням персонажа (Сирик / Мася) від **4 до 60+** років, локальним інтелектом, двома валютами, кімнатами догляду, міні-іграми, друзями, фото та кодом.

## Стек

- Flutter + Riverpod
- GoRouter
- Hive + Flutter Secure Storage
- CustomPainter-анімація персонажа (Rive-ready слоти в `assets/rive/`)
- Offline-first базовий догляд

## Запуск

```bash
flutter pub get
flutter run
```

## Архітектура

```
lib/
  core/           # константи, тема, роутер, мови
  data/           # моделі, Hive, secure store
  domain/         # сервіси (auth, character, growth, AI, chat, friends…)
  features/       # onboarding, home, rooms, games, settings…
  shared/         # провайдери та віджети
```

## Ключові системи

| Система | Де |
|--------|----|
| Онбординг (мова, auth, вік, Сирик/Мася) | `features/onboarding`, `features/auth` |
| Потреби + тіло + вікові стадії | `domain/services/character_service.dart` |
| Ріст XP / моделі ШІ (кеш ≤2) | `growth_service.dart`, `ai_model_service.dart` |
| Кухня drag&drop / пакети їжі | `features/kitchen` |
| Ванна / спальня | `features/bathroom`, `features/bedroom` |
| 9 міні-ігор | `features/games/presentation/games/` |
| Чат + життєві підказки | `features/chat` |
| Фото (з 10) / Код (з 20) | `features/photo`, `features/code` |
| Друзі / сховище / економіка | `features/friends`, `settings`, `economy` |

## Баланс росту

Крива XP у `lib/core/constants/growth_balance.dart`:

- 4→5 ≈ 2–3 дні активної гри
- з кожним роком складність росте (~1.28× + буст після 20)
- очки за ранок/день/вечір, питання дня (1 год), ігри, чат

## Примітки

- Apple/Google login і завантаження LLM — клієнтські потоки зі stub/симуляцією до підключення ключів і сервера.
- Донат-кнопка навмисно неактивна; розвиток персонажа безкоштовний.
- Захист від переведення часу: `TimeGuardService`.
