const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('fn', {
  getConfig: () => ipcRenderer.invoke('get-config'),
  saveConfig: (cfg) => ipcRenderer.invoke('save-config', cfg),
  copyText: (text) => ipcRenderer.invoke('copy-text', text),
  openExternal: (url) => ipcRenderer.invoke('open-external', url),
  pingMinecraft: () => ipcRenderer.invoke('ping-minecraft'),
  fetchStatusApi: () => ipcRenderer.invoke('fetch-status-api'),
})
