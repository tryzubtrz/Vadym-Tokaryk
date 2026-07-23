const { app, BrowserWindow } = require('electron')
const path = require('path')
const { spawn } = require('child_process')

let mainWindow
let serverProc

function startServer() {
  serverProc = spawn('node', [path.join(__dirname, '..', 'server', 'index.js')], {
    cwd: path.join(__dirname, '..'),
    env: { ...process.env, CRAFTPANEL_PORT: '9090' },
    stdio: 'inherit',
  })
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1280,
    height: 840,
    backgroundColor: '#0b0d10',
    title: 'CraftPanel · EclipseMC',
    autoHideMenuBar: true,
    webPreferences: { nodeIntegration: false, contextIsolation: true },
  })
  setTimeout(() => mainWindow.loadURL('http://127.0.0.1:9090'), 900)
}

app.whenReady().then(() => {
  startServer()
  createWindow()
})

app.on('window-all-closed', () => {
  if (serverProc) try { serverProc.kill() } catch {}
  if (process.platform !== 'darwin') app.quit()
})
