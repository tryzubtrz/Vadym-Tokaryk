# 07 — Custom modules API (минимум для FunnyMC-класса)

Публичные плагины закрывают ~60%. Ниже — контракты кастомных модулей.

## FunnyCore API (Paper service)

```java
public interface FunnyProfileService {
  CompletableFuture<FunnyProfile> load(UUID uuid);
  CompletableFuture<Void> save(FunnyProfile profile);
  void invalidate(UUID uuid); // redis pub
}

public interface FunnyCoinsService {
  long get(UUID uuid);
  /** Atomic; writes eco_ledger with txnId (idempotent). */
  CompletableFuture<Boolean> mutate(UUID uuid, long delta, String reason, String txnId);
}

public interface FunnyTransferService {
  void transfer(Player player, String group); // hub|surv|bw|...
}
```

## FunnySync

```java
public interface SyncService {
  /** group from FUNNY_SYNC_GROUP; no-op if "none" */
  CompletableFuture<Void> save(Player player);
  CompletableFuture<Void> load(Player player);
}
```

Lock key: `sync-lock:{group}:{uuid}` SET NX EX 15.

## FunnyProxy (Velocity)

- Subscribe Redis `funny:transfer`
- Maintain `online:{server}` heartbeats
- Queue FIFO per group
- Register dynamic arena servers

## FunnyBW hooks

```text
onMatchCountdown(map) -> cancel if players < map.min
onMatchEnd(result) -> FunnyCoinsService.mutate + stats_bedwars upsert
onShopBuy -> charge match_coins only
```

## Placeholder expansion `funny`

| Placeholder | Source |
|-------------|--------|
| `%funny_online_<mode>%` | Redis sum |
| `%funny_clan%` | clan tag |
| `%funny_title%` | active title |
| `%funny_server%` | server-id |
| `%funny_wipe_days%` | wipe.next-date |

## Event bus (Redis JSON)

```json
{ "type": "coins", "uuid": "...", "delta": 25, "reason": "bw_win", "txn": "..." }
{ "type": "transfer", "uuid": "...", "group": "bw", "target": null }
{ "type": "clan_update", "clanId": 1 }
```

## Build order for custom suite

1. FunnyCore (profile + coins + placeholders)
2. FunnyProxy (transfer + queue)
3. FunnySync
4. FunnyCosmetics + Titles
5. FunnyQuests + Clans + Party
6. FunnyBW/SW/HG (or premium forks + reward bridge)
7. FunnyReports
