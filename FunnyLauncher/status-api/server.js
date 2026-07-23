#!/usr/bin/env node
/**
 * FunnyNetwork Status API — run on the VPS next to Velocity/backends.
 * GET /api/status  → JSON with total + per-mode online
 * GET /health
 */
const http = require('http')
const { status } = require('minecraft-server-util')
const fs = require('fs')
const path = require('path')

const PORT = Number(process.env.FN_STATUS_PORT || 8787)
const HOST = process.env.FN_STATUS_BIND || '0.0.0.0'
const CONFIG_PATH = process.env.FN_STATUS_CONFIG || path.join(__dirname, 'servers.json')

function loadServers() {
  try {
    return JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'))
  } catch {
    return {
      proxy: { host: '127.0.0.1', port: 25565 },
      modes: {
        lobby: { host: '127.0.0.1', port: 25566 },
        survival: { host: '127.0.0.1', port: 25570 },
        skyblock: { host: '127.0.0.1', port: 25571 },
        anarchy: { host: '127.0.0.1', port: 25572 },
        bedwars: { host: '127.0.0.1', port: 25573 },
        creative: { host: '127.0.0.1', port: 25574 },
      },
    }
  }
}

async function pingOne(host, port) {
  try {
    const res = await status(host, port, { timeout: 2500, enableSRV: false })
    return {
      up: true,
      online: res.players?.online ?? 0,
      max: res.players?.max ?? 0,
      version: res.version?.name || '',
      motd: res.motd?.clean || '',
      latency: res.roundTripLatency ?? null,
    }
  } catch (err) {
    return { up: false, online: 0, max: 0, error: String(err.message || err) }
  }
}

async function collect() {
  const cfg = loadServers()
  const proxy = await pingOne(cfg.proxy.host, cfg.proxy.port)
  const modes = {}
  const entries = Object.entries(cfg.modes || {})
  await Promise.all(entries.map(async ([id, s]) => {
    modes[id] = await pingOne(s.host, s.port)
  }))
  const sumOnline = Object.values(modes).reduce((a, m) => a + (m.online || 0), 0)
  return {
    online: !!proxy.up,
    brand: 'FunnyNetwork',
    proxy,
    totalOnline: proxy.up ? proxy.online : sumOnline,
    totalMax: proxy.max || 5000,
    modes,
    fetchedAt: new Date().toISOString(),
  }
}

let cache = null
let cacheAt = 0
const CACHE_MS = 4000

const server = http.createServer(async (req, res) => {
  res.setHeader('Access-Control-Allow-Origin', '*')
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS')
  if (req.method === 'OPTIONS') {
    res.writeHead(204)
    res.end()
    return
  }

  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' })
    res.end(JSON.stringify({ ok: true }))
    return
  }

  if (req.url === '/api/status' || req.url === '/status') {
    try {
      const now = Date.now()
      if (!cache || now - cacheAt > CACHE_MS) {
        cache = await collect()
        cacheAt = now
      }
      res.writeHead(200, { 'Content-Type': 'application/json; charset=utf-8' })
      res.end(JSON.stringify(cache, null, 2))
    } catch (err) {
      res.writeHead(500, { 'Content-Type': 'application/json' })
      res.end(JSON.stringify({ ok: false, error: String(err.message || err) }))
    }
    return
  }

  res.writeHead(404, { 'Content-Type': 'application/json' })
  res.end(JSON.stringify({ error: 'not found', routes: ['/api/status', '/health'] }))
})

server.listen(PORT, HOST, () => {
  console.log(`[FunnyNetwork Status API] http://${HOST}:${PORT}/api/status`)
  console.log(`config: ${CONFIG_PATH}`)
})
