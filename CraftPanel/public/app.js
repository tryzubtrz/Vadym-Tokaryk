const $ = (id) => document.getElementById(id)
let token = localStorage.getItem('cp_token') || ''
let dash = null

async function api(path, opts = {}) {
  const headers = Object.assign({ 'Content-Type': 'application/json' }, opts.headers || {})
  if (token) headers['x-cp-token'] = token
  const res = await fetch(path, { ...opts, headers, credentials: 'include' })
  const data = await res.json().catch(() => ({}))
  if (res.status === 401) {
    const msg = data.error || data.message || 'Невірний логін або пароль'
    if (path !== '/api/login') {
      showLogin()
      throw new Error('Потрібен вхід')
    }
    throw new Error(msg)
  }
  if (!res.ok) throw new Error(data.error || data.message || ('HTTP ' + res.status))
  return data
}

function showLogin() {
  $('loginScreen').classList.remove('hidden')
  $('app').classList.add('hidden')
}
function showApp() {
  $('loginScreen').classList.add('hidden')
  $('app').classList.remove('hidden')
}

function setView(name) {
  document.querySelectorAll('.view').forEach((v) => v.classList.add('hidden'))
  const el = $('view-' + name)
  if (el) el.classList.remove('hidden')
  document.querySelectorAll('.nav-item').forEach((b) => b.classList.toggle('active', b.dataset.view === name))
  const titles = {
    dashboard: 'Dashboard',
    hosting: 'Хостинг',
    players: 'Гравці',
    admins: 'Адміністратори',
    ai: 'Eclipse AI',
    ranks: 'Ранги',
    economy: 'Економіка',
    announce: 'Оголошення',
    schedule: 'Планувальник',
    stats: 'Статистика',
    newserver: 'Новий сервер',
  }
  $('pageTitle').textContent = titles[name] || name
  if (name === 'dashboard') renderDashboard()
  if (name === 'hosting') renderHosting()
  if (name === 'players') renderPlayers()
  if (name === 'admins') renderAdmins()
  if (name === 'ai') renderAI()
  if (name === 'ranks') renderRanks()
  if (name === 'economy') renderEconomy()
  if (name === 'announce') renderAnnounce()
  if (name === 'schedule') renderSchedule()
  if (name === 'stats') renderStats()
  if (name === 'newserver') renderNewServer()
}

async function refreshDash() {
  dash = await api('/api/dashboard')
  $('networkLine').textContent = `${dash.network.name} · ${dash.network.hostname}`
  return dash
}

function renderDashboard() {
  const root = $('view-dashboard')
  if (!dash) {
    root.innerHTML = '<p class="muted">Завантаження…</p>'
    return
  }
  const s = dash.stats
  const live = dash.liveEvent
  root.innerHTML = `
    <div class="stats">
      <div class="stat-card"><div class="k">Всього серверів</div><div class="v">${s.totalServers}</div></div>
      <div class="stat-card"><div class="k">Запущено</div><div class="v"><span class="pulse"></span>${s.running}</div></div>
      <div class="stat-card"><div class="k">Гравців онлайн</div><div class="v">${s.playersOnline}</div></div>
      <div class="stat-card"><div class="k">Бекапів</div><div class="v">${s.backups}</div></div>
    </div>
    ${live ? `<div class="live-box"><div class="tag">LIVE</div><b>${live.title}</b><div class="meta" style="margin-top:6px">${live.note || ''}</div></div>` : ''}
    <h3 style="margin:8px 0 12px">Сервери EclipseMC</h3>
    <div class="grid" id="srvGrid"></div>
    <div class="infra">
      <b>Інфраструктура</b>
      <div class="meta" style="margin-top:8px">
        ${dash.infrastructure.name} · ${dash.infrastructure.type} ${dash.infrastructure.version}
        · Port ${dash.infrastructure.port} · RAM ${dash.infrastructure.ramMb}MB
        · IP <code>${dash.infrastructure.ip}</code>
        · Play <code>${dash.network.playAddress}</code>
      </div>
    </div>
  `
  const grid = $('srvGrid')
  dash.servers.forEach((srv) => {
    const card = document.createElement('article')
    card.className = 'server-card'
    const run = srv.state === 'RUNNING'
    const pingTxt = srv.ping?.up
      ? `${srv.ping.online}/${srv.ping.max} · ${srv.ping.latency != null ? Math.round(srv.ping.latency) + 'ms' : 'ok'}`
      : (srv.ping?.error || 'offline')
    card.innerHTML = `
      <div class="row">
        <h3>${srv.name}</h3>
        <span class="badge ${run ? 'run' : 'off'}">${srv.state}</span>
      </div>
      <div class="meta">${srv.type} ${srv.version}</div>
      <div class="meta">${pingTxt}</div>
      <div class="meta">Port ${srv.port} · ${srv.ramMb}MB</div>
      <div class="meta">${srv.desc || ''}</div>
    `
    grid.appendChild(card)
  })
}

function renderHosting() {
  const d = dash
  $('view-hosting').innerHTML = `
    <div class="panel-card">
      <h3>VPS / Hosting-Minecraft.pro</h3>
      <p class="meta">Hostname: <b>${d?.network.hostname}</b></p>
      <p class="meta">IPv4: <b>${d?.network.ip}</b></p>
      <p class="meta">Panel на VPS: <a href="http://${d?.network.ip}:8080" target="_blank">http://${d?.network.ip}:8080</a></p>
      <p class="meta">Minecraft join: <b>${d?.network.playAddress}</b></p>
      <p class="meta">CraftPanel моніторить порти мережі з цього ПК/сервера панелі.</p>
    </div>
  `
}

async function renderPlayers() {
  const root = $('view-players')
  const data = await api('/api/players')
  root.innerHTML = `
    <div class="panel-card">
      <h3>Додати / оновити гравця</h3>
      <div class="form-row">
        <input id="pName" placeholder="Нік" />
        <input id="pRank" placeholder="Ранг (default/vip/admin)" />
        <button class="btn primary" id="pSave">Зберегти</button>
      </div>
    </div>
    <div class="panel-card">
      <table class="table"><thead><tr><th>Нік</th><th>Ранг</th><th>Оновлено</th></tr></thead>
      <tbody id="pBody"></tbody></table>
    </div>`
  const body = document.getElementById('pBody')
  data.players.forEach((p) => {
    body.innerHTML += `<tr><td>${p.name}</td><td>${p.rank}</td><td>${p.lastSeen || ''}</td></tr>`
  })
  document.getElementById('pSave').onclick = async () => {
    await api('/api/players', { method: 'POST', body: JSON.stringify({ name: pName.value, rank: pRank.value }) })
    renderPlayers()
  }
}

async function renderAdmins() {
  const root = $('view-admins')
  const data = await api('/api/admins')
  root.innerHTML = `
    <div class="panel-card">
      <h3>Видати / зняти OP</h3>
      <div class="form-row">
        <input id="aName" placeholder="Нік гравця" />
        <button class="btn primary" id="aOp">Видати OP</button>
        <button class="btn danger" id="aDeop">Зняти OP</button>
      </div>
      <p class="meta">Якщо Eclipse AI в грі — команда /op піде на сервер автоматично.</p>
    </div>
    <div class="panel-card">
      <table class="table"><thead><tr><th>Нік</th><th>Роль</th><th>OP</th><th></th></tr></thead>
      <tbody id="aBody"></tbody></table>
    </div>`
  const body = document.getElementById('aBody')
  data.admins.forEach((a) => {
    body.innerHTML += `<tr><td>${a.name}</td><td>${a.role}</td><td>${a.op ? 'yes' : 'no'}</td><td></td></tr>`
  })
  document.getElementById('aOp').onclick = async () => {
    await api('/api/admins/op', { method: 'POST', body: JSON.stringify({ name: aName.value, op: true }) })
    renderAdmins()
  }
  document.getElementById('aDeop').onclick = async () => {
    await api('/api/admins/op', { method: 'POST', body: JSON.stringify({ name: aName.value, op: false }) })
    renderAdmins()
  }
}

async function renderAI() {
  const root = $('view-ai')
  const st = await api('/api/ai/status')
  root.innerHTML = `
    <div class="ai-layout">
      <div class="panel-card">
        <h3>Eclipse AI</h3>
        <p class="meta">Статус: <b>${st.connected ? 'В ГРІ' : (st.connecting ? 'підключення…' : 'офлайн')}</b>
          ${st.username ? ' · ' + st.username : ''} ${st.error ? ' · ' + st.error : ''}</p>
        <div class="form-row" style="margin:10px 0">
          <button class="btn primary" id="aiConnect">Зайти в гру</button>
          <button class="btn ghost" id="aiDisconnect">Вийти</button>
          <button class="btn ghost" id="aiHG">Налаштувати Голодні ігри</button>
        </div>
        <div class="form-row">
          <input id="aiMsg" placeholder="Написати в чат / запитати AI…" />
          <button class="btn primary" id="aiSend">Надіслати</button>
        </div>
        <div class="ai-log" id="aiLog"></div>
      </div>
      <div class="panel-card">
        <h3>Що вміє AI</h3>
        <ul class="meta">
          <li>Заходить на Velocity/мережу offline-ботом</li>
          <li>Відповідає гравцям (HG, IP, help)</li>
          <li>Допомагає з NPC, міні-іграми, OP</li>
          <li>Може розіслати broadcast при setup міні-гри</li>
        </ul>
        <p class="meta">Play IP: <code>${dash?.network.playAddress || '202.181.188.222:25565'}</code></p>
      </div>
    </div>`
  const log = document.getElementById('aiLog')
  log.textContent = (st.log || []).map((x) => `${x.at}  ${x.line}`).join('\n') || 'Порожньо'
  document.getElementById('aiConnect').onclick = async () => {
    await api('/api/ai/connect', { method: 'POST', body: '{}' })
    setTimeout(renderAI, 1200)
  }
  document.getElementById('aiDisconnect').onclick = async () => {
    await api('/api/ai/disconnect', { method: 'POST', body: '{}' })
    renderAI()
  }
  document.getElementById('aiHG').onclick = async () => {
    const r = await api('/api/ai/setup-minigame', { method: 'POST', body: JSON.stringify({ type: 'hungergames' }) })
    alert('План:\n' + (r.plan?.steps || []).join('\n'))
    renderAI()
  }
  document.getElementById('aiSend').onclick = async () => {
    const message = aiMsg.value
    const r = await api('/api/ai/chat', { method: 'POST', body: JSON.stringify({ message }) })
    if (r.reply) alert(r.reply)
    aiMsg.value = ''
    renderAI()
  }
}

async function renderRanks() {
  const r = await api('/api/ranks')
  $('view-ranks').innerHTML = `<div class="panel-card"><table class="table"><thead><tr><th>ID</th><th>Назва</th><th>Prefix</th></tr></thead><tbody>
    ${r.ranks.map((x) => `<tr><td>${x.id}</td><td>${x.name}</td><td><code>${x.prefix}</code></td></tr>`).join('')}
  </tbody></table></div>`
}

async function renderEconomy() {
  const r = await api('/api/economy')
  $('view-economy').innerHTML = `<div class="panel-card"><p>Валюта: <b>${r.economy.funnyCoinsName}</b></p>
    <p class="meta">Глобальні монети мережі · локальні економіки режимів окремо (FunnyNetwork model).</p></div>`
}

async function renderAnnounce() {
  const r = await api('/api/announcements')
  $('view-announce').innerHTML = `
    <div class="panel-card">
      <div class="form-row">
        <input id="anText" placeholder="Текст оголошення" />
        <button class="btn primary" id="anSend">Опублікувати</button>
      </div>
    </div>
    <div class="panel-card" id="anList"></div>`
  document.getElementById('anList').innerHTML = (r.items || []).map((i) => `<div class="meta" style="margin:8px 0"><b>${i.at}</b> — ${i.text}</div>`).join('') || '<p class="muted">Порожньо</p>'
  document.getElementById('anSend').onclick = async () => {
    await api('/api/announcements', { method: 'POST', body: JSON.stringify({ text: anText.value }) })
    renderAnnounce()
  }
}

async function renderSchedule() {
  const r = await api('/api/schedule')
  $('view-schedule').innerHTML = `
    <div class="panel-card form-row">
      <input id="schTitle" placeholder="Подія (напр. HG турнір)" />
      <input id="schWhen" placeholder="Коли (2026-07-24 20:00)" />
      <button class="btn primary" id="schAdd">Додати</button>
    </div>
    <div class="panel-card">${(r.items || []).map((i) => `<div class="meta">${i.when} — <b>${i.title}</b></div>`).join('') || '<p class="muted">Немає подій</p>'}</div>`
  document.getElementById('schAdd').onclick = async () => {
    await api('/api/schedule', { method: 'POST', body: JSON.stringify({ title: schTitle.value, when: schWhen.value }) })
    renderSchedule()
  }
}

async function renderStats() {
  const r = await api('/api/stats')
  $('view-stats').innerHTML = `<div class="panel-card">
    <p>Proxy online: <b>${r.proxy.up ? 'yes' : 'no'}</b></p>
    <p>Гравці: <b>${r.proxy.online}/${r.proxy.max}</b></p>
    <p>Пінґ: <b>${r.proxy.latency != null ? Math.round(r.proxy.latency) + ' ms' : '—'}</b></p>
    <p class="meta">${r.historyNote}</p>
  </div>`
}

function renderNewServer() {
  $('view-newserver').innerHTML = `
    <div class="panel-card">
      <h3>+ Новий сервер / міні-гра</h3>
      <label>Назва<input id="nsName" placeholder="BedWars Duels" /></label>
      <label>Тип<input id="nsType" value="Paper" /></label>
      <label>Версія<input id="nsVer" value="1.21.4" /></label>
      <label>Порт<input id="nsPort" type="number" value="25580" /></label>
      <label>RAM MB<input id="nsRam" type="number" value="2048" /></label>
      <label>Опис<input id="nsDesc" placeholder="Нова міні-гра" /></label>
      <button class="btn primary" id="nsCreate">Створити в CraftPanel</button>
      <p class="meta" style="margin-top:10px">Це додає сервер у моніторинг. На VPS також підніми інстанс і пропиши в Velocity.</p>
    </div>`
  document.getElementById('nsCreate').onclick = async () => {
    await api('/api/servers', {
      method: 'POST',
      body: JSON.stringify({
        name: nsName.value,
        type: nsType.value,
        version: nsVer.value,
        port: Number(nsPort.value),
        ramMb: Number(nsRam.value),
        desc: nsDesc.value,
      }),
    })
    await refreshDash()
    setView('dashboard')
  }
}

$('loginForm').onsubmit = async (e) => {
  e.preventDefault()
  $('loginErr').textContent = ''
  token = ''
  localStorage.removeItem('cp_token')
  try {
    const r = await api('/api/login', {
      method: 'POST',
      body: JSON.stringify({ user: loginUser.value.trim(), pass: loginPass.value }),
    })
    token = r.token
    localStorage.setItem('cp_token', token)
    showApp()
    await refreshDash()
    setView('dashboard')
  } catch (err) {
    $('loginErr').textContent = (err && err.message) || 'Помилка входу'
  }
}

$('btnLogout').onclick = async () => {
  try { await api('/api/logout', { method: 'POST', body: '{}' }) } catch {}
  token = ''
  localStorage.removeItem('cp_token')
  showLogin()
}

$('btnRefresh').onclick = async () => {
  await refreshDash()
  const active = document.querySelector('.nav-item.active')?.dataset.view || 'dashboard'
  setView(active)
}

document.querySelectorAll('.nav-item').forEach((btn) => {
  btn.addEventListener('click', () => setView(btn.dataset.view))
})
document.querySelectorAll('[data-view-jump]').forEach((btn) => {
  btn.addEventListener('click', () => setView(btn.dataset.viewJump))
})

;(async () => {
  if (!token) return showLogin()
  try {
    await api('/api/me')
    showApp()
    await refreshDash()
    setView('dashboard')
  } catch {
    showLogin()
  }
})()
