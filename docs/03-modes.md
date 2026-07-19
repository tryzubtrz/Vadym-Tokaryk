# 03 — Детальное описание каждого режима

## 3.0 Общие правила для всех режимов

- Join: apply resource pack, TAB, scoreboard, active cosmetics.
- Chat: global clan tag visible; cross-server chat **off** by default (party/clan channels optional).
- `/spawn` → mode lobby spawn; `/hub` → main lobby (FunnyProxy).
- AFK kick: lobby 15m, games configurable, farm longer with checks.
- Permissions via LuckPerms tracks: `default < vip < premium < elite < legend < media < helper < mod < admin < owner`.

---

## 3.1 Main Lobby (`lobby-*`)

**Цель:** витрина сети, селектор режимов, социал, кейсы/донат NPC.

### Must work
- Compass / hotbar: `Режимы`, `Профиль`, `Косметика`, `Кланы`, `Донат`.
- NPC ряда режимов с голограммами: название, онлайн режима, статус (ONLINE/FULL/UPDATE), анимация (rotate/bob), idle sound radius 3.
- `/menu` DeluxeMenus = полный селектор.
- Parkour + rewards (FunnyCoins small, daily).
- Leaderboards: top FunnyCoins, top clan, top BW rating (hologram refresh 30s).
- Crate room (preview only or open with keys).
- No PvP, no drop, no block break except parkour regions.

### Scoreboard (пример)
```
§b§lFunnyNetwork
§7Онлайн: §f%velocity_total%
§7Ранг: %luckperms_prefix%
§7FunnyCoins: §e%coinsengine_balance_funny_coins%
§7Клан: §f%funny_clan%
§7Титул: §f%funny_title%
```

---

## 3.2 Mode Lobbies (уникальные)

Каждый режим имеет `lb-<mode>` с отдельным миром и стилем (см. `05-lobbies.md`).

### Shared mode-lobby logic
- Button/NPC `Играть` → queue / direct connect game server.
- Rules book, kit preview, map voting (where applicable).
- Stats NPC for that mode only.
- Return to hub NPC.

---

## 3.3 Survival (`surv-*`)

### Gameplay
- Vanilla+ survival: mining, farming, building, PvP in wild.
- Claims: Lands/GP — protect builds; trust members.
- Economy: `surv_coins` — Jobs, shop sell, mob drops sell, AH.
- Homes: rank-based limits (default 2 … legend 15).
- Warps: spawn, pvp, shop, crates, event.
- RTP with cooldown; safer first-join kit.
- Skills (optional mcMMO): mining/combat bonuses **cosmetic+QoL**, not raw P2W weapons.
- Auction + chest shops.
- Events: weekend double jobs, boss arena weekly.

### Wipe policy
- Soft wipe every ~90 days (map reset).
- Donor world `world_donor` no wipe (rank ≥ elite).
- Keep: global FunnyCoins, ranks, cosmetics. Wipe: claims, local coins (or convert 5% to FunnyCoins as goodwill — product decision).

### Forbidden
- Sync inv to other modes.
- Spending FunnyCoins on PvP gear that invalidates balance.

---

## 3.4 Anarchy (`ana-*`)

### Gameplay
- Nearly unrestricted grief/PvP outside spawn.
- Spawn: 100×100 protected; kit NPC with cooldowns.
- Local economy light: `ana_coins` from kills/sell OR barter-only (choose one; FunnyMC-like = kits + stash).
- Totem use limits / crystal PvP rules documented.
- World border e.g. 15k; Elytra OK.
- Anti-dupe highest priority; illegal enchants stripped.

### Wipe
- More frequent than survival OR same global wipe schedule.
- Stash ender sizes limited.

---

## 3.5 SkyBlock (`sb-*`)

### Core loop
1. Create/join island (team up to N).
2. Expand via generator cobble + custom gens (ores).
3. Island level from block values.
4. Missions/challenges → SBCoins + FunnyCoins drip.
5. Shop / AH / Bank (island shared account).
6. Prestige / challenges reset optional seasonal.

### Economy isolation
- Currency: `sb_coins` only on SB servers.
- Bank: withdraw/deposit SBCoins.
- Cases:
  - `sb_case` buy for SBCoins
  - `global_case` buy for FunnyCoins
  - Rewards never grant SurvCoins

### Custom Funny-style features (implement)
- Unique generators tiers.
- Custom tools (telepipe, sellwand limited).
- Island upgrades: members, size, generators speed, flight (donor or level gate).
- Top islands hologram.
- Coop invite cross-server via Redis.

### Technical
- SuperiorSkyblock2 / BentoBox + FunnySkyblock addon.
- Island worlds: one world + schematics OR one world per island (SWM) — prefer one world + stacked islands for scale.
- Purpur hopper limits critical.

---

## 3.6 BedWars (`lb-bw` + `bw-arena-*`)

### Match flow
```
Queue in lb-bw → Map select/vote → Waiting state
→ Start ONLY if players >= map.min (6/8/12/16)
→ Cage/team assign → Generators start
→ Bed alive? respawn : spectator/elim
→ Last team → Victory → Rewards → Return lobby
```

### Map minimums (config-driven)
| Map type | Teams × size | Min start | Max |
|----------|--------------|-----------|-----|
| Solo 8 | 8×1 | 6 | 8 |
| Duo 8 | 8×2 | 8 | 16 |
| Trio 4 | 4×3 | 6 | 12 |
| Quad 4 | 4×4 | 8 | 16 |

If below min after 60s: expand wait or requeue. **Never** force-start at 2 players.

### Mechanics (parity checklist)
- [ ] Iron/gold/diamond/emerald generators with tier times
- [ ] Team upgrades (sharpness, protection, forge, heal pool, traps)
- [ ] Item shop (blocks, melee, ranged, tools, utils, potions)
- [ ] Soft/hard blocks rules
- [ ] Bed break message + sound + tab update
- [ ] Final battle / sudden death (beds destroy all after T)
- [ ] Fireball jump, TNT jump balancing
- [ ] Map boundaries / void death
- [ ] Rejoin within match if disconnect < 5m (optional)

### Economy
- `match_coins` ephemeral — shop only.
- End: convert performance → FunnyCoins + XP rating; match_coins deleted.
- Season reset rating every 90 days; rewards titles.

### Stats
`wins, losses, kills, final_kills, beds, winstreak, rating, season_id`

---

## 3.7 SkyWars (`lb-sw` + arenas)

### Rules
- Min players: **8** (configurable per map; solos 8–12, teams higher).
- Cages → countdown → loot chests (tier 1/2/mid/center).
- Refill at T+2m; border shrink optional.
- No persistent inventory.
- Rewards: FunnyCoins + cosmetics chance + rating.

### Kits
- Unlock with FunnyCoins or achievements; select before start.
- Donor kits = cosmetics/skins first; power kits carefully balanced.

---

## 3.8 SkyPvP (`spvp-*`)

### Rules
- Persistent floating islands / arenas.
- Kit PvP or gear grind with **local** `spvp_coins` (optional) for kits.
- Global rating + seasons.
- Death: keep inventory? **No** for competitive arenas; yes for casual — split worlds `spvp-ranked` / `spvp-casual`.
- Clan fights scheduled.

---

## 3.9 HungerGames (`hg-arena-*`)

### Rules
- Min players: **12** (24 max typical).
- Cornucopia loot + random chests.
- Grace period 30–60s.
- World border shrink stages.
- Deathmatch when ≤ N players or border min.
- Teams optional (duo HG).
- Rewards FunnyCoins + titles.

---

## 3.10 Creative (`creative-*`)

- PlotSquared: claim plot, build, clear, biome, music.
- WorldEdit per-plot limits by rank.
- No economy required; FunnyCoins cosmetics still work.
- Showcase warps for best plots (staff vote).

---

## 3.11 Prison (`prison-*`)

- Mine ladder A→Z + prestiges.
- Autosell / sell wand.
- `prison_tokens` local.
- Gangs optional (link to FunnyClans or separate).
- Enchantments private (custom CE) with careful balance.
- PvP mine optional zone.

---

## 3.12 Farm (`farm-*`)

- Dedicated AFK-friendly crop/mob farms.
- `farm_points` local; exchange **only** to FunnyCoins at bad rate OR shop cosmetics — **never** to SurvCoins.
- Anti-bot: action verification hourly, pitch checks, max farms/player.
- Stackers + hopper caps.

---

## 3.13 Cross-mode systems

### Clans (global)
- Create/invite/kick, roles, bank in FunnyCoins (not mode coins).
- Clan tag in TAB all servers.
- Clan wars on SkyPvP/Anarchy arenas.
- Top clans season rewards.

### Quests
- Daily: login, play 30m on any mode, win 1 BW, etc. → FunnyCoins.
- Weekly: harder → keys + cosmetics.
- Anti-alt: IP/UUID limits.

### Parties
- Cross-server party; warp-to-leader for lobbies; queue together for BW/SW.

### Prestige (global meta)
- Cosmetic progression from total playtime / achievements — separate from Prison prestige.

---

## 3.14 Command map (player-facing)

| Command | Action |
|---------|--------|
| `/hub` | Main lobby |
| `/spawn` | Mode spawn |
| `/menu` | Mode selector |
| `/profile` | Stats GUI |
| `/cosmetics` | Equip |
| `/clan` | Clan GUI |
| `/party` | Party |
| `/quests` | Quests |
| `/report` | Report |
| `/msg` `/r` | Private |
| `/tpa` | Survival/SB only |
| `/is` | SkyBlock |
| `/bw` `/sw` | Queue aliases |
| `/ah` `/shop` | Mode local |
| `/balance` `/bal` | Shows **local** + tip for FunnyCoins `/coins` |
| `/coins` | FunnyCoins |
| `/crates` | Warp crates |
| `/donate` | Store link |

Staff: standard LiteBans + Staff++ + CoreProtect cmds.
