# FunnyNetwork

Turnkey Minecraft network (FunnyMC-class blueprint + runnable stack).

## Play now (this environment)

See `FunnyNetwork/CONNECT.txt` — currently:

```
bore.pub:42211
```

Offline, any nick. In-game: `/menu`, `/server list`.

## Launch package

```bash
cd FunnyNetwork
./bin/setup-download.sh      # jars + plugins
./bin/assemble-runtime.sh    # servers + configs
./bin/prepare-first-boot.sh  # generate worlds (once)
./bin/start-all.sh           # start network + public tunnel
cat runtime/CONNECT_ADDR
```

## Architecture docs

See [`docs/00-IMPLEMENTATION-PROMPT.md`](docs/00-IMPLEMENTATION-PROMPT.md).
