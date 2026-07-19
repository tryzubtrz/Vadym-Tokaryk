# MineLegacy — готова копія мережі (стиль play.MLegacy.net)

Повноцінний сервер «під ключ»: красиве лобі, міні-ігри (BedWars), Survival, Skyblock, Prison, Factions, Anarchy, система донатів.

> Це самостійна збірка в стилі MineLegacy (режими + хаб + донат), а не копія їхніх платних карт/плагінів.

## Запуск

```bash
chmod +x scripts/*.sh tools/tryzub-setup/build.sh
./scripts/make-ready.sh   # повна підготовка
./scripts/ip.sh           # адреса для гравців
```

Повторний старт: `./scripts/start.sh` · стоп: `./scripts/stop.sh`

## Підключення (TLauncher)

- Адреса: `./scripts/ip.sh` (зараз тунель **bore.pub**)
- Версія: **1.21.x** (ViaVersion)
- Офлайн-режим увімкнено
- Власник: нік **Vadym** (`config/owners.txt`)

## Режими

| Режим | Як зайти | Що робити |
|--------|----------|-----------|
| Лобі | авто / `/server lobby` | Компас `/menu`, платформи, голограми |
| Міні-ігри | платформа / `/server minigames` | `/bw join TryzubDuo` |
| Survival | `/server survival` | `/sethome`, `/claim` |
| Skyblock | `/server skyblock` | `/is create` |
| Prison | `/server prison` | `/ranks` |
| Factions | `/server factions` | `/f create` |
| Anarchy | `/server anarchy` | PvP без правил |

## Донати

У грі: **`/donate`** або смарагд у лобі.

Пакети (донат-монети):
- **VIP** — 500
- **Premium** — 1500
- **Legend** — 4000
- **Sponsor** — 10000

Після реальної оплати адмін видає монети:

```text
/coins give <нік> 5000
```

Гравцеві вже видано тест: `Vadym` = 5000 монет.

## Команди гравця

- `/menu` — вибір режиму
- `/donate` — магазин рангів
- `/coins` — баланс
- `/server <режим>` — перехід (Velocity)

## Що всередині

- Velocity + 7× Paper
- Преміум-лобі (неон, маяк, платформи режимів, голограми)
- ScreamingBedWars арена **TryzubDuo**
- EssentialsX, LuckPerms, WorldGuard/Edit, TAB, Vault
- IridiumSkyblock, Prison, ImprovedFactions
- Плагін **TryzubSetup** (лобі + донати + арени)

## Для свого VPS

1. Скопіюй репозиторій
2. Java 21+, ~12 ГБ RAM
3. `./scripts/make-ready.sh`
4. Відкрий порт **25565**
5. Дай друзям свій IP:25565
