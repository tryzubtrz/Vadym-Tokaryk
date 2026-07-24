const { app, BrowserWindow } = require('electron')
const path = require('path')
const { spawn } = require('child_process')

let mainWindow
let serverProc
const PORT = process.env.CRAFTPANEL_PORT || '9090'

function startServer() {
  const serverJs = path.join(__dirname, '..', 'server', 'index.js')
  // Portable Windows: use Electron binary as Node (no system node required)
  serverProc = spawn(process.execPath, [serverJs], {
    cwd: path.join(__dirname, '..'),
    env: {
      ...process.env,
      ELECTRON_RUN_AS_NODE: '1',
      CRAFTPANEL_PORT: String(PORT),
    },
    stdio: 'pipe',
  })
  serverProc.stdout.on('data', (d) => console.log('[server]', d.toString()))
  serverProc.stderr.on('data', (d) => console.error('[server]', d.toString()))
  serverProc.on('exit', (code) => console.log('[server] exit', code))
}

function waitForServer(url, tries = 40) {
  return new Promise((resolve, reject) => {
    const http = require('http')
    let n = 0
    const tick = () => {
      n += 1
      const req = http.get(url, (res) => {
        res.resume()
        resolve()
      })
      req.on('error', () => {
        if (n >= tries) reject(new Error('CraftPanel server failed to start'))
        else setTimeout(tick, 250)
      })
    }
    tick()
  })
}

async function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 840,
    backgroundColor: '#0b0d10',
    title: 'CraftPanel · EclipseMC',
    autoHideMenuBar: true,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
    },
  })
  await waitForServer(`http://127.0.0.1:${PORT}/`)
  await mainWindow.loadURL(`http://127.0.0.1:${PORT}/`)
}

app.whenReady().then(async () => {
  startServer()
  try {
    await createWindow()
  } catch (err) {
    console.error(err)
    app.quit()
  }
})

app.on('window-all-closed', () => {
  if (serverProc) {
    try {
      serverProc.kill()
    } catch {}
  }
  if (process.platform !== 'darwin') app.quit()
})
