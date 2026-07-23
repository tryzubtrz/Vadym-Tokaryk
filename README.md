# FunnyNetwork

Minecraft network blueprint + turnkey stack + **Windows launcher**.

## Download launcher (Windows)

Artifact: `FunnyNetwork-win-unpacked.zip`  
Unpack → run `FunnyNetwork.exe` → set VPS IP in **Настройки**.

Source: [`FunnyLauncher/`](FunnyLauncher/)

## VPS Status API (player counts per mode)

```bash
cd FunnyLauncher/status-api && npm install && npm start
# http://VPS:8787/api/status
```

## Server stack

See [`FunnyNetwork/`](FunnyNetwork/) and [`docs/`](docs/).
