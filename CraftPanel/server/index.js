const express = require('express')
const cors = require('cors')
const cookieParser = require('cookie-parser')
const path = require('path')
const fs = require('fs')
const { status } = require('minecraft-server-util')
const mineflayer = require('mineflayer')

const ROOT = path.join(__dirname, '..')
const CONFIG_PATH = path.join(ROOT, 'config.json')
const DATA_PATH = path.join(ROOT, 'data.json')

function loadConfig() {
  return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'))
}
function loadData() {
  try {
    return JSON.parse(fs.readFileSync(DATA_PATH, 'utf8'))
  } catch {
    return {
      admins: [{ name: 'Vadym', role: 'owner', op: true }],
      players: [],
      ranks: [
        { id: 'default', name: 'Гравець', prefix: '&7' },
        { id: 'vip', name: 'VIP', prefix: '&aVIP ' },
        { id: 'admin', name: 'Admin', prefix: '&cAdmin ' },
      ],
      economy: { funnyCoinsName: 'FunnyCoins', rate: 1 },
      announcements: [],
      schedule: [],
      backups: 0,
      aiLog: [],
    }
  }
}
function saveData(d) {
  fs.writeFileSync(DATA_PATH, JSON.stringify(d, null, 2))
}

const app = express()
app.use(cors({ origin: true, credentials: true }))
app.use(express.json({ limit: '2mb' }))
app.use(cookieParser())
app.use(express.static(path.join(ROOT, 'public')))

const SESSIONS = new Map()
let aiBot = null
let aiState = { connected: false, username: null, error: null }

function auth(req, res, next) {
  const tok = req.cookies.cp_token || req.headers['x-cp-token']
  if (tok && SESSIONS.has(tok)) return next()
  return res.status(401).json({ error: 'auth' })
}

app.post('/api/login', (req, res) => {
  const cfg = loadConfig()
  const { user, pass } = req.body || {}
  if (user === cfg.adminUser && pass === cfg.adminPass) {
    const token = require('crypto').randomBytes(24).toString('hex')
    SESSIONS.set(token, { user, at: Date.now() })
    res.cookie('cp_token', token, { httpOnly: true, sameSite: 'lax' })
    return res.json({ ok: true, token, user })
  }
  return res.status(401).json({ ok: false, error: 'Невірний логін або пароль' })
})

app.post('/api/logout', (req, res) => {
  const tok = req.cookies.cp_token
  if (tok) SESSIONS.delete(tok)
  res.clearCookie('cp_token')
  res.json({ ok: true })
})

app.get('/api/me', auth, (req, res) => {
  const tok = req.cookies.cp_token || req.headers['x-cp-token']
  res.json({ ok: true, user: SESSIONS.get(tok)?.user })
})

async function pingHost(host, port) {
  try {
    const r = await status(host, port, { timeout: 2500, enableSRV: false })
    return {
      up: true,
      online: r.players?.online ?? 0,
      max: r.players?.max ?? 0,
      version: r.version?.name || '',
      motd: r.motd?.clean || '',
      latency: r.roundTripLatency ?? null,
    }
  } catch (e) {
    return { up: false, online: 0, max: 0, error: String(e.message || e) }
  }
}

app.get('/api/dashboard', auth, async (req, res) => {
  const cfg = loadConfig()
  const data = loadData()
  const host = cfg.minecraftHost
  const servers = []
  let playersOnline = 0
  let running = 0

  // unique ports to avoid double-count lobby/hg same port
  const seenPorts = new Set()
  for (const s of cfg.servers) {
    const ping = await pingHost(host, s.port)
    if (ping.up) {
      running += 1
      if (!seenPorts.has(s.port)) {
        playersOnline += ping.online
        seenPorts.add(s.port)
      }
    }
    servers.push({
      ...s,
      state: ping.up ? 'RUNNING' : 'OFFLINE',
      ping,
    })
  }

  const live = cfg.servers.find((s) => s.live)

  res.json({
    ok: true,
    network: {
      name: cfg.networkName,
      hostname: cfg.vpsHostname,
      ip: cfg.vpsIp,
      playAddress: `${cfg.minecraftHost}:${cfg.minecraftPort}`,
    },
    stats: {
      totalServers: cfg.servers.length,
      running,
      playersOnline,
      backups: data.backups || 0,
    },
    liveEvent: live
      ? { title: live.name, note: live.note || live.desc, status: 'LIVE' }
      : null,
    servers,
    infrastructure: {
      name: `[VPS] EclipseMC`,
      type: 'Paper / Velocity',
      version: '1.21',
      port: cfg.minecraftPort,
      ramMb: 20480,
      state: 'RUNNING',
      ip: cfg.vpsIp,
    },
    ai: { ...aiState, configuredUser: cfg.ai?.username },
  })
})

app.get('/api/players', auth, (req, res) => {
  res.json({ ok: true, players: loadData().players })
})

app.post('/api/players', auth, (req, res) => {
  const data = loadData()
  const { name, rank } = req.body || {}
  if (!name) return res.status(400).json({ error: 'name required' })
  data.players = data.players.filter((p) => p.name.toLowerCase() !== String(name).toLowerCase())
  data.players.push({ name, rank: rank || 'default', lastSeen: new Date().toISOString() })
  saveData(data)
  res.json({ ok: true, players: data.players })
})

app.get('/api/admins', auth, (req, res) => {
  res.json({ ok: true, admins: loadData().admins })
})

app.post('/api/admins/op', auth, (req, res) => {
  const data = loadData()
  const { name, op = true, role = 'admin' } = req.body || {}
  if (!name) return res.status(400).json({ error: 'name required' })
  data.admins = data.admins.filter((a) => a.name.toLowerCase() !== String(name).toLowerCase())
  if (op) data.admins.push({ name, role, op: true, at: new Date().toISOString() })
  saveData(data)
  // Try tell AI bot to run /op if connected
  let game = null
  if (aiBot && aiState.connected) {
    try {
      aiBot.chat(op ? `/op ${name}` : `/deop ${name}`)
      game = 'command_sent'
    } catch (e) {
      game = String(e.message || e)
    }
  }
  res.json({ ok: true, admins: data.admins, game })
})

app.get('/api/ranks', auth, (req, res) => res.json({ ok: true, ranks: loadData().ranks }))
app.get('/api/economy', auth, (req, res) => res.json({ ok: true, economy: loadData().economy }))
app.get('/api/announcements', auth, (req, res) => res.json({ ok: true, items: loadData().announcements }))
app.post('/api/announcements', auth, (req, res) => {
  const data = loadData()
  const { text } = req.body || {}
  if (!text) return res.status(400).json({ error: 'text required' })
  data.announcements.unshift({ text, at: new Date().toISOString() })
  data.announcements = data.announcements.slice(0, 50)
  saveData(data)
  if (aiBot && aiState.connected) {
    try { aiBot.chat(text) } catch {}
  }
  res.json({ ok: true, items: data.announcements })
})

app.get('/api/schedule', auth, (req, res) => res.json({ ok: true, items: loadData().schedule }))
app.post('/api/schedule', auth, (req, res) => {
  const data = loadData()
  const { title, when } = req.body || {}
  data.schedule.push({ title, when, id: Date.now() })
  saveData(data)
  res.json({ ok: true, items: data.schedule })
})

app.get('/api/stats', auth, async (req, res) => {
  const cfg = loadConfig()
  const dash = await pingHost(cfg.minecraftHost, cfg.minecraftPort)
  res.json({
    ok: true,
    proxy: dash,
    historyNote: 'Live ping from CraftPanel · VPS ' + cfg.vpsIp,
  })
})

app.post('/api/servers', auth, (req, res) => {
  const cfg = loadConfig()
  const { name, type, version, port, ramMb, desc } = req.body || {}
  if (!name || !port) return res.status(400).json({ error: 'name and port required' })
  const id = String(name).toLowerCase().replace(/[^a-z0-9]+/g, '-')
  cfg.servers.push({
    id,
    name,
    type: type || 'Paper',
    version: version || '1.21.4',
    port: Number(port),
    ramMb: Number(ramMb) || 2048,
    desc: desc || 'Новий сервер / міні-гра',
  })
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(cfg, null, 2))
  res.json({ ok: true, servers: cfg.servers })
})

// ——— Eclipse AI ———
app.get('/api/ai/status', auth, (req, res) => {
  res.json({ ok: true, ...aiState, log: loadData().aiLog.slice(0, 40) })
})

app.post('/api/ai/connect', auth, async (req, res) => {
  const cfg = loadConfig()
  if (aiBot) {
    try { aiBot.quit('reconnect') } catch {}
    aiBot = null
  }
  const username = (req.body && req.body.username) || cfg.ai.username || 'EclipseAI'
  try {
    aiBot = mineflayer.createBot({
      host: cfg.minecraftHost,
      port: cfg.minecraftPort,
      username,
      auth: 'offline',
      version: false,
      hideErrors: true,
    })
    aiState = { connected: false, username, error: null, connecting: true }

    aiBot.once('spawn', () => {
      aiState = { connected: true, username, error: null, connecting: false }
      pushAiLog(`AI зайшов на сервер як ${username}`)
    })
    aiBot.on('chat', (user, message) => {
      if (user === username) return
      pushAiLog(`<${user}> ${message}`)
      // simple auto-reply helper
      const m = message.toLowerCase()
      let reply = null
      if (m.includes('hg') || m.includes('голодн')) reply = 'Голодні ігри: NPC в лобі або /hg join'
      else if (m.includes('help') || m.includes('допомог')) reply = 'Питай адмінів у CraftPanel · Eclipse AI онлайн'
      else if (m.includes('ip')) reply = `IP: ${cfg.minecraftHost}`
      if (reply) {
        setTimeout(() => {
          try { aiBot.chat(reply) } catch {}
        }, 400)
      }
    })
    aiBot.on('end', () => {
      aiState = { connected: false, username, error: 'disconnected', connecting: false }
      pushAiLog('AI відключився')
    })
    aiBot.on('error', (err) => {
      aiState.error = String(err.message || err)
      pushAiLog('AI error: ' + aiState.error)
    })

    res.json({ ok: true, message: 'Підключення AI…', username })
  } catch (e) {
    aiState = { connected: false, username, error: String(e.message || e), connecting: false }
    res.status(500).json({ ok: false, error: aiState.error })
  }
})

app.post('/api/ai/disconnect', auth, (req, res) => {
  if (aiBot) {
    try { aiBot.quit('panel') } catch {}
    aiBot = null
  }
  aiState = { connected: false, username: null, error: null }
  pushAiLog('AI вимкнено з панелі')
  res.json({ ok: true })
})

app.post('/api/ai/chat', auth, (req, res) => {
  const { message } = req.body || {}
  if (!message) return res.status(400).json({ error: 'message required' })
  pushAiLog(`[panel] ${message}`)
  if (!aiBot || !aiState.connected) {
    // offline AI helper replies
    const tip = aiHelp(message)
    pushAiLog(`[Eclipse AI] ${tip}`)
    return res.json({ ok: true, mode: 'assistant', reply: tip })
  }
  try {
    aiBot.chat(message)
    return res.json({ ok: true, mode: 'ingame', sent: message })
  } catch (e) {
    return res.status(500).json({ ok: false, error: String(e.message || e) })
  }
})

app.post('/api/ai/setup-minigame', auth, (req, res) => {
  const { type } = req.body || {}
  const plan = buildMinigamePlan(type || 'hungergames')
  pushAiLog(`[setup] ${plan.title}`)
  if (aiBot && aiState.connected) {
    try {
      for (const line of plan.chatCommands) aiBot.chat(line)
    } catch {}
  }
  res.json({ ok: true, plan })
})

function pushAiLog(line) {
  const data = loadData()
  data.aiLog.unshift({ at: new Date().toISOString(), line })
  data.aiLog = data.aiLog.slice(0, 200)
  saveData(data)
}

function aiHelp(msg) {
  const m = String(msg).toLowerCase()
  if (m.includes('npc')) return 'NPC: Citizens/FancyNpcs у Lobby · /npc create · голограма · /server <mode>. Для HG — слот 20 у селекторі.'
  if (m.includes('hg') || m.includes('голодн')) return 'HG: карта hgarena, /hg join, мін. гравців у конфігу, NPC в хабі. Якщо плагін генерує flat — міняй на SurvivalGames з кастом-картою.'
  if (m.includes('op')) return 'Видача OP: розділ Адміністратори → нік → Видати OP. Якщо AI в грі — виконає /op.'
  if (m.includes('сервер') || m.includes('server')) return 'Новий сервер: + Новий сервер → імʼя, порт, RAM. Потім у VPS створи інстанс Paper/Spigot і пропиши в Velocity.'
  return 'Я Eclipse AI. Можу: зайти в гру, відповідати гравцям, підказати NPC/HG/OP/економіку. Напиши задачу.'
}

function buildMinigamePlan(type) {
  const plans = {
    hungergames: {
      title: 'Голодні ігри',
      steps: [
        'Перевір світ hgarena / карту Creative_Node HG',
        'NPC в Lobby на лінії ігрових NPC (y як у Skyblock/BedWars)',
        'Server Selector slot 20 → HG',
        'Мін. гравців /hg, спавни по арені',
        'Анонс у чат мережі',
      ],
      chatCommands: [
        '/broadcast §6Голодні ігри готові! §e/hg join або NPC у лобі',
      ],
    },
    bedwars: {
      title: 'BedWars',
      steps: ['Арена шаблон', 'Мін. гравців', 'Генератори', 'NPC лобі'],
      chatCommands: ['/broadcast §cBedWars скоро!'],
    },
  }
  return plans[type] || plans.hungergames
}

app.use((req, res, next) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') return next()
  if (req.path.startsWith('/api/')) return next()
  res.sendFile(path.join(ROOT, 'public', 'index.html'))
})

const PORT = Number(process.env.CRAFTPANEL_PORT || 9090)
app.listen(PORT, '0.0.0.0', () => {
  const cfg = loadConfig()
  console.log(`[CraftPanel] http://127.0.0.1:${PORT}`)
  console.log(`[CraftPanel] VPS ${cfg.vpsIp} · play ${cfg.minecraftHost}:${cfg.minecraftPort}`)
  console.log(`[CraftPanel] login: ${cfg.adminUser} / (see config.json)`)
})
