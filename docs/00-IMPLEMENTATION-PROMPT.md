# MASTER IMPLEMENTATION PROMPT — FunnyNetwork (FunnyMC-class)

> Скопируй этот файл целиком в ТЗ для команды (билдеры, плагин-девы, DevOps, конфиг-админы).
> Цель: собрать **работающую** сеть уровня FunnyMC на 3000–8000+ онлайна с донатом.

---

## 0. Продуктовая цель

Собрать Minecraft-сеть **FunnyNetwork** — функциональный аналог FunnyMC:

| Параметр | Значение |
|----------|----------|
| IP (пример) | `play.funnynetwork.net` |
| Версии клиента | ViaVersion: `1.20.4–1.21.x` (опц. ViaBackwards до 1.16.5) |
| Core backends | Purpur `1.21.4` (или Paper той же линии) |
| Proxy | Velocity `3.4.x` |
| Целевой онлайн | 3000 steady / 5000 peak / design for 8000 |
| Язык UI | RU primary, EN secondary |
| Монетизация | Tebex + кейсы + косметика + ранги (не P2W на PvP-баланс) |

**Жёсткие инварианты (нельзя нарушать):**

1. **Глобально** между всеми режимами: ранг, престиж, косметика, титулы, достижения, донат-статус, баланс **FunnyCoins**, клан, квесты, ключи кейсов.
2. **Локально на режим**: инвентарь, эндер-сундук, XP/уровень, деньги режима, острова, прогресс режима, рейтинг матчей.
3. Экономики режимов **никогда** не конвертируются друг в друга напрямую.
4. Мини-игра **не стартует**, пока не набран минимум игроков для карты.
5. Каждый режим имеет **своё уникальное лобби** (не копия главного).

---

## 1. Архитектура сети (обязательная топология)

```
                    [Internet]
                         |
              ┌──────────┴──────────┐
              │  Velocity Proxy x2  │  (HA: primary + standby / LB)
              │  Queue + Limbo      │
              └──────────┬──────────┘
                         |
         Redis Cluster (pub/sub, cache, queue, locks)
                         |
         MariaDB Primary + 1 Replica (global) + mode DBs
                         |
    ┌─────────┬──────────┼──────────┬──────────┬─────────┐
    │         │          │          │          │         │
 Lobby-01  Surv-01    Anarchy   SkyBlock   MiniHub   Prison
 Lobby-02  Surv-02    Ana-02    SB-02      BW-01..N  Farm
 Creative  Surv-03             SB-03      SW/SP/HG   ...
```

### Backend servers (минимум для прода)

| Server ID | Role | Instances | Max players / instance | Notes |
|-----------|------|-----------|------------------------|-------|
| `proxy-01/02` | Velocity | 2 | 8000 total | Only proxy plugins |
| `limbo-01` | Queue/Limbo | 1–2 | 2000 | LimboAPI / NanoLimbo |
| `lobby-01..03` | Main lobby | 3 | 400 each | Sticky less critical |
| `lb-surv` | Survival lobby | 1–2 | 300 | Transfer to Surv |
| `lb-bw` | BedWars lobby | 1–2 | 400 | Matchmaking hub |
| `lb-sw` | SkyWars lobby | 1 | 300 | |
| `lb-sp` | SkyPvP lobby | 1 | 300 | |
| `lb-hg` | HG lobby | 1 | 200 | |
| `lb-sb` | SkyBlock lobby | 1 | 300 | |
| `lb-ana` | Anarchy lobby | 1 | 200 | |
| `surv-01..04` | Survival | 4 | 200 | World split / load balance |
| `ana-01..02` | Anarchy | 2 | 150 | Soft wipe cycle |
| `sb-01..03` | SkyBlock | 3 | 180 | Island worlds / Slime |
| `bw-arena-01..N` | BedWars games | autoscale | 16–32 | Dynamic arenas |
| `sw-arena-01..N` | SkyWars | autoscale | 12–24 | |
| `spvp-01..02` | SkyPvP | 2 | 100 | Persistent PvP islands |
| `hg-arena-01..N` | HungerGames | autoscale | 24 | |
| `creative-01` | Creative | 1–2 | 120 | Plots |
| `prison-01..02` | Prison | 2 | 150 | Mines |
| `farm-01` | Farm | 1–2 | 150 | AFK-farm mode |

**Naming convention:** `role-region-index` → `bw-eu-03`.  
**Velocity forwarding:** modern (player info forwarding secret shared).

Полная схема и data-flow: [`01-architecture.md`](01-architecture.md).

---

## 2. Модель данных (кросс-сейв)

### Global profile (Redis cache + MySQL persist)

```
player_uuid
├── rank_id, prestige, donor_tier, donor_until
├── funny_coins (BIGINT)
├── cosmetics[] (unlocked + selected: hat, cloak, trail, kill_effect, join_msg)
├── titles[] + active_title
├── achievements[]
├── clan_id + clan_role
├── keys{} (crate_type → count)
├── quest_progress (daily/weekly global)
└── settings (lang, toggle_scoreboard, pm, party)
```

### Mode-local (НЕ синкать между режимами)

```
mode_id + player_uuid
├── inventory_blob, ender_blob
├── balance_local (DECIMAL)
├── xp, level, stats_json
├── island_id / plot_id / prison_rank (mode-specific)
└── last_location
```

**Синк-движок:**

- Global: custom `FunnyCore` + LuckPerms (MySQL) + CoinsEngine/PlayerPoints-style FunnyCoins.
- Inventory: **только внутри группы серверов одного режима** (HuskSync *isolated groups* ИЛИ свой `FunnySync` с `sync_group`).
- Messaging: Redis pub/sub channels `funny:transfer`, `funny:party`, `funny:clan`, `funny:announce`.

Схема SQL: [`sql/schema.sql`](sql/schema.sql).  
Экономика: [`04-economy-crates.md`](04-economy-crates.md).

---

## 3. Режимы — что ОБЯЗАНО работать

Детали: [`03-modes.md`](03-modes.md). Краткий чеклист:

### 3.1 Main Lobby + Mode Lobbies
- NPC + голограммы + звук + particle idle.
- DeluxeMenus selector → 1 клик = transfer в режим (с очередью).
- Уникальный стиль каждого mode-lobby (см. [`05-lobbies.md`](05-lobbies.md)).
- Scoreboard: онлайн сети, FunnyCoins, ранг, квесты.
- Запрет PvP/block break (кроме паркура).

### 3.2 Survival
- Claims (GriefPrevention / Lands), economy local, jobs, auction, shops, RTP, homes, warps.
- Clans overlay (глобальный клан, локальные wars опционально).
- Soft wipe every ~90 days + donor no-wipe world.

### 3.3 Anarchy
- No claims / limited protection, full PvP, raids.
- Local economy light or barter + kits on cooldown.
- Totems limits, elytra combat rules, anti-dupe strict.

### 3.4 SkyBlock
- Single-island classic + FunnyMC-style: island levels, missions, generators, custom items.
- **Отдельная** экономика, shop, auction, bank.
- Cases buyable for **local SB coins** AND **FunnyCoins** (разные кейсы/цены).

### 3.5 BedWars
- Wait until min players (map: 6/8/12/16).
- Generators, upgrades, shop, teams, bed respawn, final battle / sudden death.
- Match coins reset after game; rewards → FunnyCoins + cosmetics + rating.

### 3.6 SkyWars / SkyPvP / HungerGames
- Same wait-gate; SW chests tiers; SkyPvP persistent arenas; HG shrink zone + loot.
- Seasonal leaderboards.

### 3.7 Creative / Prison / Farm
- Plots (Creative), mine ladders + prestiges (Prison), crop/mob AFK farms with anti-bot (Farm).

---

## 4. Плагины

Полный матричный список: [`02-plugins.md`](02-plugins.md).

**Обязательный каркас на каждом Paper backend:**

```
FunnyCore (custom), LuckPerms, PlaceholderAPI, ProtocolLib,
packetevents, Vault, CoinsEngine (или FunnyCoins),
FancyHolograms / DecentHolograms, DeluxeMenus, Citizens,
TAB, FancyNpcs (or Citizens), WorldGuard, CoreProtect,
Vulcan/Matrix, floodgate? (optional), ViaVersion (prefer proxy),
spark, Pluto/Chunky as needed
```

**Proxy:** Velocity, LuckPerms-Velocity, ViaVersion, Maintenance, Queue, Geyser(optional), RedisBungee-like (Velocity Redis), FunnyProxy.

---

## 5. Экономика и кейсы (жёсткие правила)

| Currency | Scope | Earn | Spend |
|----------|-------|------|-------|
| **FunnyCoins** | Global | Tebex, quests, match rewards, vote | Crates, keys, cosmetics, ranks, titles |
| **SurvCoins** | Survival only | Jobs, sell, kill | Local shop/ah |
| **SBCoins** | SkyBlock only | Minions/gens/sell | SB shop/ah/bank/upgrades |
| **MatchCoins** | Single match | Generators/kills | In-match shop only; wipe at end |
| **PrisonTokens** | Prison only | Mining | Prestige/upgrades |
| **FarmPoints** | Farm only | Harvest | Farm shop |

**Crates (ExcellentCrates / CrazyCrates):** COMMON → RARE → EPIC → LEGENDARY.  
Drops: cosmetics, titles, keys, FunnyCoins, temp boosts (XP/coins %), **no** raw PvP gear that breaks modes.

Tebex packages map → LuckPerms track + FunnyCoins + keys via Buycraft webhook / Tebex plugin.

---

## 6. UI / UX (обязательный polish)

На каждом режиме:

- TAB (header/footer + sorting by rank)
- Scoreboard (TAB or FunnyBoard)
- ActionBar (tips / combat tag / generator timer)
- BossBar (events / wipe countdown)
- Join titles + sounds
- Chat format: `[Rank] [Clan] [Title] Name » msg` via LPC / Custom

Menus: DeluxeMenus YAML, all placeholders from PlaceholderAPI expansions.

---

## 7. Модерация / античит / логи

- Reports: LiteBans + custom `/report` → Discord webhook + staff GUI.
- Punishments: LiteBans networked (MySQL).
- Anticheat: Vulcan **or** Matrix (+ custom checks for scaffold/timer on mini-games).
- Logs: CoreProtect per survival-like mode; chat logs; command spy; inventory snapshots on death (mini-games off).
- Staff mode: vanish, freeze, spectate match.

---

## 8. Масштаб 5000+

См. [`06-scale-5000.md`](06-scale-5000.md). Минимум:

- Dedicated hosts / bare metal preferred for game nodes.
- Redis Cluster, MariaDB tuned, HikariCP pools capped.
- Proxy queue when backends full.
- Entity/chunk/hopper limits, view-distance 6–8, simulation 4–6.
- Autoscale arena servers via Pterodactyl/Wings or custom orchestrator.
- Monitoring: Prometheus + Grafana + spark profiler weekly.

---

## 9. Структура папок (деплой)

```
/opt/funny/
├── proxy/
│   ├── velocity.jar
│   ├── velocity.toml
│   ├── forwarding.secret
│   └── plugins/
├── servers/
│   ├── lobby-01/
│   ├── surv-01/
│   ├── sb-01/
│   ├── bw-lobby/
│   ├── bw-arena-01/
│   └── ...
├── shared/
│   ├── luckperms/          # synced or DB-only
│   ├── menus/              # DeluxeMenus templates
│   └── resourcepack/
├── data/
│   ├── mysql/
│   └── redis/
└── scripts/
    ├── start-proxy.sh
    ├── start-paper.sh
    └── backup.sh
```

Скрипты: [`scripts/`](scripts/).

---

## 10. Acceptance criteria (DoD)

Сеть считается готовой к публичному запуску когда:

- [ ] Игрок проходит Lobby → любой режим → обратно без потери FunnyCoins/ранга/косметики.
- [ ] Инвентарь Survival **не** появляется в SkyBlock / BedWars.
- [ ] BedWars матч не стартует при 5/8; стартует при достижении min.
- [ ] Локальные монеты SB нельзя потратить в Survival shop.
- [ ] Tebex test package выдаёт ранг + ключи < 30s.
- [ ] `/report` создаёт тикет staff.
- [ ] 500 ботов / load-test: proxy queue работает, нет дупов инвентаря.
- [ ] 5 уникальных mode-lobby визуально различимы на скриншоте без UI.
- [ ] Clans видны на всех режимах.
- [ ] Daily quests выдают FunnyCoins один раз в сутки (анти-абуз).

---

## 11. Порядок реализации (спринты)

1. **Infra** — Velocity, Lobby×1, Redis, MariaDB, LuckPerms, FunnyCoins, transfer.
2. **Identity** — ranks, TAB, menus, holograms, NPC selector.
3. **Survival MVP** — claims, local eco, shop.
4. **SkyBlock MVP** — islands, local eco, missions skeleton.
5. **BedWars MVP** — wait-gate, generators, shop, beds, rewards → FunnyCoins.
6. **Other minigames** — SW, SkyPvP, HG.
7. **Anarchy / Prison / Farm / Creative**.
8. **Crates + Tebex**.
9. **Clans / quests / cosmetics polish**.
10. **Scale** — multi-lobby, arenas autoscale, anti-lag pass, public launch.

---

## 12. Кастомная разработка (обязательна)

Публичными плагинами **нельзя** закрыть FunnyMC 1:1. Нужны модули:

| Module | Responsibility |
|--------|----------------|
| `FunnyCore` | Profile, FunnyCoins API, transfer, settings |
| `FunnySync` | Grouped inventory sync |
| `FunnyParty` | Cross-server party |
| `FunnyClans` | Global clans + wars hook |
| `FunnyQuests` | Daily/weekly |
| `FunnyCosmetics` | Hats/trails/kill effects |
| `FunnyBW` / `FunnySW` / … | Or heavily fork MBedwars / SlimeGame |
| `FunnyProxy` | Queue, server switch, maintenance branding |

API: Redis messages + MySQL; Paper services registered for other plugins.

---

**Конец мастер-промпта.** Дальше — детальные приложения в `docs/`.
