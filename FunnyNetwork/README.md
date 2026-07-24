# FunnyNetwork — turnkey (запустил и играешь)

## Быстрый старт на этой машине

```bash
cd FunnyNetwork
./bin/prepare-first-boot.sh   # один раз (генерация миров)
./bin/start-all.sh            # запуск всей сети + туннель
cat runtime/CONNECT_ADDR      # IP для лаунчера
```

Стоп: `./bin/stop-all.sh`

## Что поднимается

| Сервер | Порт | Назначение |
|--------|------|------------|
| Velocity proxy | 25565 | Вход |
| lobby | 25566 | Главное лобби |
| survival | 25570 | Выживание |
| skyblock | 25571 | SkyBlock |
| anarchy | 25572 | Анархия |
| bedwars | 25573 | BedWars лобби |
| creative | 25574 | Creative |

Плагины: LuckPerms, EssentialsX, DeluxeMenus (`/menu`), TAB, FancyHolograms, FancyNpcs, PlayerPoints (`/points` = FunnyCoins), ViaVersion (на proxy).

## В игре

- Offline — любой ник  
- `/menu` или `/modes` — выбор режима  
- `/server list` — список серверов  
- `/server survival` и т.д.

## Важно

Это **готовый запускаемый каркас сети** (proxy + режимы + меню + права + экономика-поинты).  
Полный FunnyMC (генераторы BW, острова SB с миссиями, кейсы Tebex) — по docs/ в корне репо; сюда ставятся доп. плагины в `runtime/servers/<mode>/plugins/`.
