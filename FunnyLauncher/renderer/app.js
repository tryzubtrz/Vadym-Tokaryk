let config = null
let timer = null

const $ = (id) => document.getElementById(id)

function toast(msg) {
  const el = $('toast')
  el.hidden = false
  el.textContent = msg
  clearTimeout(toast._t)
  toast._t = setTimeout(() => { el.hidden = true }, 2200)
}

function setLive(ok, text) {
  const pill = $('livePill')
  pill.classList.toggle('online', ok)
  pill.classList.toggle('offline', !ok)
  $('liveText').textContent = text
}

function formatIp(cfg) {
  const host = cfg.serverHost || '—'
  const port = Number(cfg.serverPort) || 25565
  return port === 25565 ? host : `${host}:${port}`
}

function renderModes(modes, apiModes = {}) {
  const grid = $('modesGrid')
  grid.innerHTML = ''
  modes.forEach((mode, i) => {
    const info = apiModes[mode.id] || {}
    const online = info.online ?? info.players ?? null
    const max = info.max ?? null
    const up = info.online !== undefined ? true : info.up
    const card = document.createElement('article')
    card.className = 'mode-card'
    card.style.setProperty('--accent', mode.color || '#2aa4c8')
    card.style.animationDelay = `${i * 40}ms`
    const onlineText = online === null || online === undefined ? '—' : (max != null ? `${online}/${max}` : String(online))
    const stateChip = up === false
      ? '<span class="chip down">offline</span>'
      : '<span class="chip up">online</span>'
    card.innerHTML = `
      <div class="mode-top">
        <div class="mode-name">${mode.icon || ''} ${mode.name}</div>
        <div class="mode-online">${onlineText}</div>
      </div>
      <p class="mode-desc">${mode.desc || ''}</p>
      <div class="mode-meta">${stateChip}<span class="chip">id: ${mode.id}</span></div>
    `
    grid.appendChild(card)
  })
}

async function refresh() {
  if (!config) return
  $('serverIp').textContent = formatIp(config)
  $('brandName').textContent = config.brand || 'FunnyNetwork'
  $('tagline').textContent = config.tagline || ''

  const [mc, api] = await Promise.all([
    window.fn.pingMinecraft(),
    window.fn.fetchStatusApi(),
  ])

  if (mc.ok) {
    setLive(true, 'Сервер онлайн')
    $('totalOnline').textContent = mc.online
    $('totalMax').textContent = mc.max
    $('latency').textContent = mc.latency != null ? `${Math.round(mc.latency)} ms` : '—'
    $('version').textContent = mc.version || '—'
    $('motdLine').textContent = mc.motd || config.tagline || ''
  } else {
    setLive(false, 'Нет ответа Minecraft')
    $('totalOnline').textContent = '—'
    $('totalMax').textContent = '—'
    $('latency').textContent = '—'
    $('version').textContent = '—'
    $('motdLine').textContent = mc.error || 'Проверь IP / VPS в настройках'
  }

  let apiModes = {}
  if (api.ok && api.data) {
    const data = api.data
    if (data.modes && typeof data.modes === 'object') apiModes = data.modes
    // Prefer API totals if present
    if (typeof data.totalOnline === 'number') $('totalOnline').textContent = data.totalOnline
    if (typeof data.totalMax === 'number') $('totalMax').textContent = data.totalMax
    if (data.online) setLive(true, 'VPS + сервер онлайн')
  }

  renderModes(config.modes || [], apiModes)
  const ts = new Date()
  $('updatedAt').textContent = `обновлено ${ts.toLocaleTimeString()}`
}

function openSettings() {
  $('inpHost').value = config.serverHost || ''
  $('inpPort').value = config.serverPort || 25565
  $('inpApi').value = config.statusApiUrl || ''
  $('settingsDialog').showModal()
}

async function init() {
  config = await window.fn.getConfig()
  renderModes(config.modes || [], {})
  await refresh()

  $('btnRefresh').onclick = () => refresh()
  $('btnSettings').onclick = openSettings
  $('btnCloseSettings').onclick = () => $('settingsDialog').close()

  $('settingsForm').onsubmit = async (e) => {
    e.preventDefault()
    config = await window.fn.saveConfig({
      serverHost: $('inpHost').value.trim(),
      serverPort: Number($('inpPort').value) || 25565,
      statusApiUrl: $('inpApi').value.trim(),
    })
    $('settingsDialog').close()
    toast('Сохранено')
    await refresh()
  }

  $('btnCopy').onclick = async () => {
    await window.fn.copyText(formatIp(config))
    toast('IP скопирован')
  }
  $('btnCopyPort').onclick = async () => {
    await window.fn.copyText(config.serverHost)
    toast('Хост скопирован')
  }

  const sec = Math.max(5, Number(config.refreshSeconds) || 8) * 1000
  timer = setInterval(refresh, sec)
}

init().catch((err) => {
  console.error(err)
  setLive(false, 'Ошибка лаунчера')
})
