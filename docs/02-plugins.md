# 02 — Полный список плагинов

> Версии указаны как **целевые линии** на момент сборки под Purpur/Paper `1.21.4` + Velocity `3.4.x`.
> Перед деплоем сверяй совместимость на Modrinth/Hangar/SpigotMC.
> `custom` = пишется командой; без них FunnyMC-класс не собрать.

Легенда колонки **Where**:
`P` = Proxy · `A` = All backends · `L` = Lobby · `S` = Survival · `N` = Anarchy ·
`B` = SkyBlock · `M` = Minigame lobbies/arenas · `C` = Creative · `R` = Prison · `F` = Farm

---

## 2.1 Velocity (Proxy)

| Plugin | Version line | Purpose |
|--------|--------------|---------|
| Velocity | 3.4.x | Proxy core |
| LuckPerms | 5.4.x | Cross-network permissions |
| ViaVersion | 5.x | Protocol translate |
| ViaBackwards | 5.x | Older clients (optional) |
| ViaRewind | 4.x | 1.8 clients (optional, FunnyMC-like) |
| Maintenance | 4.x | Maintenance mode |
| MiniMOTD | 2.x | Fancy MOTD |
| FlameCord/VelocityAntiBot or BotSentry | latest | Anti-bot |
| SignedVelocity | latest | Chat signing bridge |
| Geyser-Velocity | 2.x | Bedrock (optional) |
| Floodgate | 2.x | Bedrock auth (optional) |
| **FunnyProxy** | custom | Queue, transfer, server groups, branding |
| RedisBungee (Velocity fork) / Plan Velocity | latest | Proxy Redis sync / analytics |
| LibertyBans or LiteBans | 1.x / 2.x | Network punishments |
| PremiumVanish / SuperVanish bridge | — | Staff vanish (if used) |

---

## 2.2 Core на КАЖДОМ Paper/Purpur backend

| Plugin | Version | Where | Purpose |
|--------|---------|-------|---------|
| Purpur | 1.21.4 build latest | A | Server fork (optimizations) |
| LuckPerms | 5.4.x | A | Permissions |
| PlaceholderAPI | 2.11.x | A | Placeholders |
| ProtocolLib | 5.3.x | A | Packets (legacy deps) |
| packetevents | 2.7.x | A | Modern packets |
| Vault | 1.7.x | A | Eco/perm bridge |
| **FunnyCore** | custom | A | Profile, FunnyCoins API, settings |
| **FunnySync** | custom | A | Grouped inv sync (or HuskSync Pro licensed) |
| HuskSync | 3.8.x | A | Alternative to FunnySync if licensed |
| CoinsEngine | 2.x | A | Multi-currency engine (FunnyCoins + local) |
| TAB | 5.x | A | Tablist, scoreboard, nametags |
| FancyHolograms | 2.x | A | Holograms (or DecentHolograms 2.x) |
| DecentHolograms | 2.8.x | A | Alt holograms |
| DeluxeMenus | 1.14.x | A | GUI menus |
| Citizens | 2.0.35+ | L,M,S,B | NPCs |
| FancyNpcs | 2.x | L,M | Lightweight NPCs alt |
| WorldGuard | 7.0.x | A | Regions |
| WorldEdit | 7.3.x | A | Building tools (staff) |
| CoreProtect | 22.x | S,N,B,C,R,F | Block logs |
| spark | 1.10.x | A | Profiler |
| PlugManX | 2.x | A | Hot manage (stage only) |
| Vulcan **or** Matrix | latest licensed | A | Anticheat |
| Negativity / Grim (extra) | optional | M | Extra PvP checks |
| InventoryRollbackPlus | 1.x | S,B | Staff restore |
| LiteBans | 2.x | A | Punishments client |
| DiscordSRV | 1.28.x | L,S | Discord bridge (1–2 servers only) |
| Plan | 5.6.x | A | Analytics |
| **FunnyCosmetics** | custom | A | Cosmetics runtime |
| **FunnyClans** | custom | A | Global clans |
| **FunnyQuests** | custom | A | Daily/weekly |
| **FunnyParty** | custom | A | Parties |
| LumpTech Voice / PlasmoVoice | optional | — | Voice chat |

---

## 2.3 Lobby / Mode Lobby

| Plugin | Version | Purpose |
|--------|---------|---------|
| ItemsAdder **or** Oraxen | 4.x / 2.x | Custom models, furniture, HUD |
| ModelEngine | 4.x | Animated NPC/boss models (optional premium) |
| MythicMobs | 5.x | Showcase mobs in lobby |
| NoteBlockAPI + custom | — | Lobby music zones |
| Parkour | 7.x | Parkour courses |
| DeluxeMenus + chat games | — | Hub activities |
| PlayerPoints (only if not CoinsEngine) | — | Avoid double currency plugins |
| GadgetsMenu / **FunnyCosmetics** | — | Lobby gadgets |
| ImageFrame / MapMenu | — | Map art boards |
| InteractiveChat | 4.x | Hover/click chat (careful with perf) |

---

## 2.4 Survival

| Plugin | Version | Purpose |
|--------|---------|---------|
| Lands **or** GriefPrevention | 7.x / 16.x | Claims |
| EconomyShopGUI **or** ShopGUIPlus | latest | Player/server shop |
| AuctionHouse **or** zAuctionHouse | latest | AH |
| Jobs Reborn | 5.x | Jobs → SurvCoins |
| mcMMO **or** AureliumSkills | 2.x / 2.x | Skills |
| ExcellentCrates | 5.x | Crates (global keys) |
| CMI **or** EssentialsX | 9.x / 2.21.x | Homes, kits, warps, moderation utils |
| EssentialsX Chat/Spawn/Protect | matching | |
| RoseStacker / UltimateStacker | latest | Mob/item stack |
| Chunky | 1.4.x | Pregen |
| Sleep-most | latest | Night skip |
| Dynmap **or** BlueMap | latest | Map (1 node) |
| CombatLogX | 11.x | Combat tag |
| GSit | latest | Sit/lay |
| BetterRTP | 3.x | RTP |
| WildInspect | — | Claim inspect |
| **FunnyWipe** | custom | Wipe cycle + donor world |

---

## 2.5 Anarchy

| Plugin | Purpose |
|--------|---------|
| CoreProtect (short retention) | Rollback staff only |
| AntiDupe suite / DupeFix | Strict |
| IllegalStack | Nuke illegals |
| OldCombatMechanics (optional) | 1.8 PvP feel |
| FreedomChat / NoChatReports | Depending on policy |
| Custom kits plugin | Cooldown kits |
| WorldBorder | Map limit |
| Spark + Purpur entity caps | Perf |

No Lands/GP claims (or only spawn).

---

## 2.6 SkyBlock

| Plugin | Version | Purpose |
|--------|---------|---------|
| IridiumSkyblock **or** SuperiorSkyblock2 **or** BentoBox | latest 1.21 | Islands core |
| **FunnySkyblock** addon | custom | Levels, missions, gens Funny-style |
| CoinsEngine currency `sb_coins` | — | Local eco |
| ShopGUIPlus (SB config) | — | Separate shop |
| zAuctionHouse (SB group) | — | Separate AH |
| ExcellentCrates (SB + global pools) | — | Dual purchase |
| CustomItems / ItemsAdder | — | Custom gear |
| EpicFarming / Generators plugin | — | Ore gens |
| Bank plugin (local) | — | Island bank |
| Challenges / **FunnyQuests** SB pack | — | Missions |

---

## 2.7 Minigames

### BedWars
| Option | Note |
|--------|------|
| **MBedwars** (premium) + addons | Closest public quality |
| **FunnyBW** custom | Full FunnyMC parity |
| SlimeWorldManager / AdvancedSlimePaper | Arena templates |
| FastAsyncWorldEdit | Map paste |

Features required: generators, team upgrades, shop, beds, sudden death, map pool min-players, ratings.

### SkyWars
| Option | Note |
|--------|------|
| SlimeWorld SkyWars / SWM + custom | |
| CrazySkyWars / custom FunnySW | Chests tiers, refill, cages |

### SkyPvP
| Custom FunnySkyPvP | Persistent islands, kits, local coins optional, global rating |

### HungerGames
| Custom / SurvGame fork | Shrink border, loot crates, teams optional |

### Shared minigame libs
- NPCs for join
- TAB arena scoreboard
- Liberum / Parties for team invite
- LeaderboardsPlus / custom SQL boards

---

## 2.8 Creative / Prison / Farm

| Mode | Plugins |
|------|---------|
| Creative | PlotSquared 7.x, BuilderTools, FAWE, WorldEdit |
| Prison | Prison 3.x **or** custom PrisonEVO, autosell, prestiges, mines reset |
| Farm | Custom farm worlds, RoseStacker, AFK zone, anti-macro, sell wands |

---

## 2.9 Crates / Donate / Cosmetics

| Plugin | Purpose |
|--------|---------|
| ExcellentCrates 5.x **or** CrazyCrates | Case opening |
| Tebex | Payments |
| BuycraftX / Tebex plugin | Command execution |
| HeadDatabase | Heads for menus |
| ItemsAdder furniture for crate models | Visual |
| **FunnyCosmetics** | Equip logic |

---

## 2.10 Optimization / Anti-lag

| Plugin / Tool | Purpose |
|---------------|---------|
| Purpur config + paper-global.yml | Core perf |
| FartherViewDistance (careful) | Optional |
| FarmControl | Manage farms |
| LagAssist / HopperOptimizer | Hoppers |
| EntityTrackerFixer | Tracker |
| ClearLag **or** custom | Periodic clear (prefer smarter) |
| Chunky | Pregen |
| Spark | Profiles |
| StackMob / RoseStacker | Entities |

---

## 2.11 Moderation / Reports

| Plugin | Purpose |
|--------|---------|
| LiteBans | Ban/mute/warn network |
| **FunnyReports** custom | `/report` GUI + Discord |
| CoreProtect | Blocks |
| ChatControl Red / VentureChat | Chat filter, channels |
| Staff++ | Staff mode |
| NightVision / vanish suite | Mod tools |

---

## 2.12 PlaceholderAPI expansions (обязательные)

```
%luckperms_prefix%
%coinsengine_balance_funny_coins%
%coinsengine_balance_surv_coins%
%funny_rank%
%funny_prestige%
%funny_title%
%funny_clan%
%server_online%
%bungee_total% / %velocity_total%
%player_name%
%funnystats_bw_wins%
%funnystats_bw_kills%
%funnyquests_daily_progress%
```

Install expansions: `PAPI ecloud download <name>` for Vault, LuckPerms, Player, Server, LocalTime, etc. Custom expansions ship inside FunnyCore.

---

## 2.13 Resource pack stack

- ItemsAdder / Oraxen pack merged
- Custom fonts for logos in menus
- Glyphs for currencies (⚙ FunnyCoins icon)
- Hosted via `resourcepack` CDN + sha1 in FunnyCore join apply

---

## 2.14 Что НЕ ставить вместе (конфликты)

- EssentialsX Eco + CoinsEngine без отключения Ess eco
- DecentHolograms + FancyHolograms на одном тексте (выбери один primary)
- Multiple anticheats full mode
- Via* on both proxy and backend (prefer proxy only)
- Two island plugins
- HuskSync global sync across all modes (breaks isolation)

---

## 2.15 Лицензии / бюджет (ориентир)

| Item | Approx |
|------|--------|
| Vulcan / Matrix | paid |
| MBedwars + addons | paid |
| ItemsAdder / Oraxen | paid |
| ModelEngine | paid |
| Tebex fees | % |
| Custom dev (Funny* suite) | largest cost |
| Dedicated hardware | see 06 |

Open-source-only MVP возможен, но визуал и мини-игры будут слабее FunnyMC.
