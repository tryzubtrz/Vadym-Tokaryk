const { app, BrowserWindow, ipcMain, shell, clipboard, nativeTheme } = require('electron')
const path = require('path')
const fs = require('fs')
const { status } = require('minecraft-server-util')

const CONFIG_PATH = path.join(__dirname, '..', 'config.json')

function loadConfig() {
  try {
    return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'))
  } catch {
    return {
      serverHost: '127.0.0.1',
      serverPort: 25565,
      statusApiUrl: 'http://127.0.0.1:8787/api/status',
      refreshSeconds: 8,
      brand: 'FunnyNetwork',
      tagline: '',
      modes: [],
    }
  }
}

function saveConfig(cfg) {
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(cfg, null, 2), 'utf8')
}

let mainWindow

function createWindow() {
  nativeTheme.themeSource = 'dark'
  mainWindow = new BrowserWindow({
    width: 1100,
    height: 720,
    minWidth: 900,
    minHeight: 600,
    backgroundColor: '#071218',
    title: 'FunnyNetwork Launcher',
    autoHideMenuBar: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  })
  mainWindow.loadFile(path.join(__dirname, '..', 'renderer', 'index.html'))
}

app.whenReady().then(() => {
  createWindow()
  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow()
  })
})

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit()
})

ipcMain.handle('get-config', () => loadConfig())

ipcMain.handle('save-config', (_e, cfg) => {
  const current = loadConfig()
  const next = { ...current, ...cfg }
  saveConfig(next)
  return next
})

ipcMain.handle('copy-text', (_e, text) => {
  clipboard.writeText(String(text || ''))
  return true
})

ipcMain.handle('open-external', (_e, url) => {
  shell.openExternal(String(url))
  return true
})

/** Direct Minecraft server list ping (proxy total online). */
ipcMain.handle('ping-minecraft', async () => {
  const cfg = loadConfig()
  try {
    const res = await status(cfg.serverHost, Number(cfg.serverPort) || 25565, {
      timeout: 5000,
      enableSRV: true,
    })
    return {
      ok: true,
      online: res.players?.online ?? 0,
      max: res.players?.max ?? 0,
      version: res.version?.name || '',
      motd: res.motd?.clean || res.motd?.raw || '',
      latency: res.roundTripLatency ?? null,
      fetchedAt: Date.now(),
    }
  } catch (err) {
    return { ok: false, error: String(err.message || err), fetchedAt: Date.now() }
  }
})

/** VPS status API — per-mode online. */
ipcMain.handle('fetch-status-api', async () => {
  const cfg = loadConfig()
  const url = cfg.statusApiUrl
  if (!url) return { ok: false, error: 'statusApiUrl not set' }
  try {
    const ctrl = new AbortController()
    const t = setTimeout(() => ctrl.abort(), 6000)
    const res = await fetch(url, { signal: ctrl.signal })
    clearTimeout(t)
    if (!res.ok) return { ok: false, error: `HTTP ${res.status}` }
    const data = await res.json()
    return { ok: true, data, fetchedAt: Date.now() }
  } catch (err) {
    return { ok: false, error: String(err.message || err), fetchedAt: Date.now() }
  }
})
