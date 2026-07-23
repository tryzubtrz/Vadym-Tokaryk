# FunnyNetwork Launcher (Windows)

Desktop app to connect to your VPS Minecraft network:
- total online / ping / version (Minecraft status)
- per-mode player counts via Status API on the VPS
- copy IP for the Minecraft multiplayer screen

## For players (download)

1. Download `FunnyNetwork-win-unpacked.zip`
2. Unpack anywhere
3. Run `FunnyNetwork.exe`
4. Open **Настройки** and set:
   - Host = your VPS / tunnel host (example `play.example.com` or `bore.pub`)
   - Port = `25565` (or tunnel port)
   - Status API = `http://YOUR_VPS_IP:8787/api/status`

## On the VPS (Status API)

```bash
cd FunnyLauncher/status-api
npm install
# edit servers.json if ports differ
npm start
# listens on 0.0.0.0:8787
```

Open firewall for `8787/tcp` (or put nginx reverse proxy in front).

## Dev

```bash
cd FunnyLauncher
npm install
npm start
```

## Build Windows folder (win-unpacked style)

```bash
cd FunnyLauncher
npm install
npm run pack:dir
# output: dist/FunnyNetwork-win32-x64/
```

Zip that folder and distribute.
