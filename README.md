# Тризуб — Minecraft-мережа з міні-іграми

Українська мережа серверів на **Velocity + Paper**, щоб грати з друзями:

| Режим | Команда | Опис |
|--------|---------|------|
| Лобі | `/server lobby` | Хаб мережі |
| Міні-ігри | `/server minigames` | BedWars (ScreamingBedWars) |
| Survival | `/server survival` | Класичне виживання |
| Skyblock | `/server skyblock` | Острови (IridiumSkyblock) |
| Prison | `/server prison` | В'язниця / майнинг |
| Factions | `/server factions` | Фракції (Improved Factions) |

## Вимоги

- Linux / macOS / WSL
- **Java 21+**
- ~10 ГБ вільної RAM
- `curl`, `jq`, `openssl`

## Швидкий старт

```bash
chmod +x scripts/*.sh
./scripts/setup.sh    # завантажити Paper, Velocity і плагіни
./scripts/start.sh    # запустити всю мережу
./scripts/status.sh   # перевірити статус
./scripts/stop.sh     # зупинити
```

Гравці підключаються до **IP:25565** (порт Velocity).

Поточну публічну IP можна дізнатись командою `curl ifconfig.me` (на хмарних машинах IP може змінюватись після перезапуску).

Приклад: `123.45.67.89:25565`

Зараз **online-mode вимкнено** — можна заходити з **TLauncher** (офлайн).

## Структура

```
velocity/           — проксі (єдиний вхід :25565)
servers/lobby/      — лобі
servers/minigames/  — міні-ігри
servers/survival/   — виживання
servers/skyblock/   — скайблок
servers/prison/     — в'язниця
servers/factions/   — фракції
scripts/            — setup / start / stop / status
config/             — forwarding.secret (не комітити)
logs/               — логи процесів
```

## Команди в грі

- `/server <назва>` — перейти на інший режим
- `/server` — список серверів (Velocity)

На міні-іграх (BedWars) після першого запуску налаштуйте арену командами плагіна ScreamingBedWars (див. логи `logs/minigames.log`).

## Безпека

- Бекенди слухають лише `127.0.0.1` — з інтернету видно тільки Velocity.
- Між проксі та Paper використовується **modern forwarding** (`config/forwarding.secret`).
- Не відкривайте порти 25566–25571 у фаєрволі.

## Примітки

- Перший запуск завантажує світ і залежності — може зайняти кілька хвилин.
- ViaVersion / ViaBackwards дозволяють заходити з близьких версій клієнта.
- Плагіни режимів можуть потребувати додаткового налаштування після першого входу (арени BedWars, острови Skyblock тощо).
