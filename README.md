# Тризуб — готова Minecraft-мережа

Повноцінна мережа для гри з друзями: **головне лобі**, **лобі міні-ігор + BedWars**, Skyblock, Survival, Prison, Factions, адмінка.

## Швидкий старт

```bash
chmod +x scripts/*.sh tools/tryzub-setup/build.sh
./scripts/make-ready.sh   # повна підготовка «з коробки»
./scripts/ip.sh           # адреса для друзів
./scripts/status.sh       # статус
./scripts/stop.sh         # зупинка
```

Мінімальний повторний запуск (якщо вже налаштовано):

```bash
./scripts/start.sh
```

## Підключення (TLauncher)

- Адреса: дивись `./scripts/ip.sh` (зазвичай тунель `bore.pub:ПОРТ`)
- Версія клієнта: **1.21.x**
- Нік: будь-який (офлайн-режим)
- Власник за замовчуванням: нік **Vadym** (повні права) — список у `config/owners.txt`

## Режими

| Режим | Команда | Що робити |
|--------|---------|-----------|
| Головне лобі | `/server lobby` | Папір «Вибір сервера» |
| Міні-ігри | `/server minigames` | `/bw join TryzubDuo` |
| Skyblock | `/server skyblock` | `/is create` (або авто) |
| Survival | `/server survival` | `/sethome`, `/claim` |
| Prison | `/server prison` | `/ranks`, шахти |
| Factions | `/server factions` | `/f create <назва>` |

## Що вже налаштовано

- Velocity-проксі + 6 Paper-серверів
- Українське меню лобі (FluffyLobby)
- Автопобудова головного лобі та арени **BedWars TryzubDuo**
- Лобі міні-ігор на сервері `minigames`
- EssentialsX (економіка, spawn, чат, кіти)
- LuckPerms зі спільними рангами: default → vip → helper → admin → owner
- PlaceholderAPI, TAB, WorldEdit, WorldGuard, GriefPrevention
- Vault + Prison autoConfigure
- IridiumSkyblock з `internalAsync` paster
- RCON для адмін-скриптів

## Адмінка

Ніки з `config/owners.txt` отримують групу **owner** і OP.
Іншим гравцям (консоль / RCON):

```text
lp user <нік> parent set admin
```

## Структура

```
scripts/make-ready.sh   — повний bootstrap
scripts/start|stop|status|ip.sh
tools/tryzub-setup/     — плагін автоналаштування арен/лобі
shared/luckperms/       — спільні права між серверами
velocity/               — проксі
servers/{lobby,minigames,...}
```

## Примітки

- На хмарі Cursor прямий порт часто закритий — використовується тунель **bore.pub**.
- Для стабільної гри з друзями краще запустити `./scripts/make-ready.sh` на своєму VPS/ПК і відкрити порт **25565**.
- Prison-шахти після `autoConfigure` варто прив’язати до зони (`/mines set area`) під своїм ніком адміна в грі.
