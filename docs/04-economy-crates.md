# 04 — Система экономик и кейсов

## 4.1 Двухуровневая модель (закон сети)

```
┌─────────────────────────────────────────────┐
│ GLOBAL: FunnyCoins                          │
│ Earn: Tebex, quests, match rewards, vote    │
│ Spend: crates, keys, cosmetics, ranks,      │
│        titles, global boosts                │
└─────────────────────────────────────────────┘
           ✗ NO direct conversion ✗
┌──────────┬──────────┬──────────┬────────────┐
│ SurvCoins│ SBCoins  │ Match$   │ PrisonTok  │ ...
│ Survival │ SkyBlock │ per match│ Prison     │
└──────────┴──────────┴──────────┴────────────┘
```

**Запрещено в коде и конфигах:**
- `/pay` FunnyCoins ↔ local
- Shop price accepting wrong currency
- AH cross-listing between modes
- MatchCoins leaving arena server

## 4.2 CoinsEngine currencies (скелет)

```yaml
currencies:
  funny_coins:
    display-name: "FunnyCoins"
    symbol: "⛁"
    sync: true          # Redis+MySQL global
    payable: true       # /pay between players OK
    decimal: false
  surv_coins:
    display-name: "Монеты"
    symbol: "$"
    sync: false
    storage-group: surv
  sb_coins:
    display-name: "SkyCoins"
    symbol: "❂"
    sync: false
    storage-group: sb
  ana_coins:
    display-name: "Anarchy$"
    storage-group: ana
  prison_tokens:
    storage-group: prison
  farm_points:
    storage-group: farm
  match_coins:
    # memory-only / arena plugin internal — do NOT persist in CoinsEngine
```

FunnyCore wraps FunnyCoins for atomic rewards + anti-dupe transaction IDs.

## 4.3 Earn rates (стартовый баланс экономики)

| Source | Reward | Cap |
|--------|--------|-----|
| First join | 100 FunnyCoins | once |
| Daily quest pack | 50–150 FC | /day |
| Weekly quest | 1–3 keys + 300 FC | /week |
| BW win | 15–40 FC + rating | diminishing returns |
| BW final kill | 2–5 FC | /match |
| Vote (minecraft-mp) | 20 FC | /day |
| SB mission | SBCoins primary + 5 FC | |
| Tebex ₽/$ | see packages | |

Tune after 2 weeks of metrics; avoid FC inflation > 5%/week without sinks.

## 4.4 Sinks (обязательны)

- Crates / keys
- Cosmetics shop
- Rank upgrades (Tebex preferred; in-game FC ranks = lower tiers only)
- Nickname color / title slots
- Clan rename / clan cosmetics
- Season battle-pass style track (optional)

## 4.5 Crate tiers (ExcellentCrates)

| Crate | Key | Price FC | Price local | Pity |
|-------|-----|----------|-------------|------|
| Common | `key_common` | 100 | SB: 50k SBCoins | — |
| Rare | `key_rare` | 250 | SB: 150k | — |
| Epic | `key_epic` | 600 | — | soft pity 50 |
| Legendary | `key_legend` | 1500 | — | hard pity 80 |

### Loot tables (принцип)

**Common:** titles gray, trails basic, 10–50 FC, common keys×1, temp 30m job boost.  
**Rare:** better trails, hats, 50–150 FC, rare keys.  
**Epic:** kill effects, join messages, 150–400 FC, epic keys, temporary fly lobby.  
**Legendary:** exclusive cosmetics, 400–1000 FC, legendary duplicate → 300 FC, exclusive title.

**Never in crates:**
- Sharpness VI / Op weapons for Survival
- BedWars permanent P2W gear
- Cross-mode currency piles of local coins

### Hologram + animation
- ItemsAdder crate model + ExcellentCrates animation `wheel`/`csgo`.
- Sound: `ui.toast.challenge_complete` on legend.

## 4.6 Tebex packages (пример)

| Package | Commands (lobby/proxy console) |
|---------|--------------------------------|
| VIP (30d) | `lp user %name% parent addtemp vip 30d` + `funny keys give %name% common 3` |
| Premium | rank + `funnycoins give %name% 500` |
| Elite | rank + FC 1500 + epic keys 2 |
| Legend | rank + FC 4000 + legend key 1 |
| FC 1000 | `funnycoins give %name% 1000` |
| Key pack | `ec givekey %name% rare 5` |

Idempotency: store `tebex_txn_id` in MySQL; ignore duplicates.

## 4.7 Match economy (BedWars example)

```
onKill: match_coins += 8
onBedBreak: match_coins += 20
generator iron: +1 / period
shop: prices in match_coins
onMatchEnd:
  clear match_coins
  funny_coins += f(wins, kills, beds, time)
  rating += g(...)
```

## 4.8 Auction / Shop isolation

| Mode | Shop config path | AH database |
|------|------------------|-------------|
| Survival | `shops/surv.yml` | MySQL schema `ah_surv` |
| SkyBlock | `shops/sb.yml` | `ah_sb` |
| Prison | `shops/prison.yml` | `ah_prison` |
| Lobby | cosmetics only FC | — |

Plugin instances use different MySQL databases or table prefixes.

## 4.9 Anti-abuse

- Transaction ledger table `eco_ledger` (from, to, currency, amount, reason, server, ts).
- Rate-limit `/pay`.
- Duped item detector on sell.
- Alts: max FunnyCoins earn from matches per IP /day.
- Staff `funny eco rollback <txn>`.

## 4.10 Vote party

- Every N votes network-wide: +10% FC rewards 1h (Redis flag `boost:fc:until`).
