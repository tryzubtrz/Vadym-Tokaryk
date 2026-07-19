# FunnyNetwork — Technical Blueprint (FunnyMC-class)

Production-ready architecture and implementation prompt for a Minecraft network
modeled after **FunnyMC** (`play.FunnyMC.net` / `fl.FunnyMC.net`).

**Stack:** Velocity proxy · Paper/Purpur `1.20.4–1.21.x` · Redis · MySQL/MariaDB · Tebex

## Documents

| File | Content |
|------|---------|
| [`docs/00-IMPLEMENTATION-PROMPT.md`](docs/00-IMPLEMENTATION-PROMPT.md) | Master prompt — give this to builders/devs |
| [`docs/01-architecture.md`](docs/01-architecture.md) | Network topology, data flow, folder layout |
| [`docs/02-plugins.md`](docs/02-plugins.md) | Full plugin matrix with versions & roles |
| [`docs/03-modes.md`](docs/03-modes.md) | Per-mode functional specs |
| [`docs/04-economy-crates.md`](docs/04-economy-crates.md) | Dual currency, crates, Tebex |
| [`docs/05-lobbies.md`](docs/05-lobbies.md) | Unique lobby design system |
| [`docs/06-scale-5000.md`](docs/06-scale-5000.md) | Hardware, JVM, anti-lag for 5k–8k online |
| [`docs/07-custom-modules-api.md`](docs/07-custom-modules-api.md) | FunnyCore/Sync/Proxy/BW API contracts |
| [`docs/sql/schema.sql`](docs/sql/schema.sql) | MySQL schema (global + per-mode) |
| [`docs/configs/`](docs/configs/) | Skeleton configs (LuckPerms, Velocity, menus…) |
| [`docs/scripts/`](docs/scripts/) | Start scripts & systemd examples |
| [`infra/examples/`](infra/examples/) | Docker Compose / Redis / MariaDB sketches |

## Quick start (ops)

1. Read `docs/00-IMPLEMENTATION-PROMPT.md` end-to-end.
2. Provision infra from `docs/06-scale-5000.md`.
3. Apply `docs/sql/schema.sql`.
4. Deploy Velocity + backends using folder layout in `docs/01-architecture.md`.
5. Install plugins from `docs/02-plugins.md` per server role.
6. Paste skeletons from `docs/configs/`, then fill secrets.
7. Build unique lobbies per `docs/05-lobbies.md`.
8. Soft-launch → load-test → open to public.

## License / disclaimer

This repository is an **architecture and ops blueprint**, not FunnyMC's proprietary plugins or assets.
Custom mode logic must be developed or licensed separately. Do not copy closed-source FunnyMC jars.
