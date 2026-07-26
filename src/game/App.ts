import { CARGO, MAX_CARGO, MAX_PASSENGERS, PASSENGERS } from './data'
import { FlightGame } from './FlightGame'
import type { CargoCard, FlightResult, HudState, Loadout, PassengerCard, ScreenId } from './types'

export class App {
  private root: HTMLElement
  private screen: ScreenId = 'menu'
  private selectedPassengers: PassengerCard[] = []
  private selectedCargo: CargoCard[] = []
  private game: FlightGame | null = null
  private result: FlightResult | null = null
  private bestCash = Number(localStorage.getItem('ti-best-cash') || 0)
  private hudEl: HTMLElement | null = null

  constructor(root: HTMLElement) {
    this.root = root
    this.render()
  }

  private setScreen(screen: ScreenId) {
    this.game?.dispose()
    this.game = null
    this.screen = screen
    this.render()
  }

  private render() {
    switch (this.screen) {
      case 'menu':
        this.renderMenu()
        break
      case 'loadout':
        this.renderLoadout()
        break
      case 'flight':
        this.renderFlight()
        break
      case 'results':
        this.renderResults()
        break
    }
  }

  private renderMenu() {
    this.root.innerHTML = `
      <main class="screen menu">
        <div class="atmosphere" aria-hidden="true"></div>
        <div class="menu-visual" aria-hidden="true">
          <div class="plane-silhouette"></div>
        </div>
        <header class="hero">
          <p class="eyebrow">BUDGET AIRLINE CO-OP</p>
          <h1>Turbulence<br/>Inc.</h1>
          <p class="tagline">3D салон, кабіна пілота, фізика вантажу й пасажири в хаосі. На телефоні.</p>
          <div class="cta-row">
            <button class="btn primary" data-action="start">У рейс</button>
            <button class="btn ghost" data-action="how">Як грати</button>
          </div>
          <p class="meta">Рекорд каси: $${this.bestCash}</p>
        </header>
        <section class="how hidden" id="how">
          <h2>Екіпаж</h2>
          <ol>
            <li>Обери пасажирів і вантаж — більше $ = більше хаосу.</li>
            <li><b>Пілот</b> — тримай горизонт стіком.</li>
            <li><b>Салон</b> — ходи, дивись, обслуговуй і кріпи вантаж.</li>
            <li>Червоні крапки = треба сервіс. Жовті = вантаж зірвався.</li>
          </ol>
          <p class="note">Оригінальна гра. Не афілійована з Dear Passengers / FLEXUS.</p>
        </section>
      </main>
    `
    this.root.querySelector('[data-action="start"]')?.addEventListener('click', () => {
      this.selectedPassengers = PASSENGERS.slice(0, 3)
      this.selectedCargo = CARGO.slice(0, 2)
      this.setScreen('loadout')
    })
    this.root.querySelector('[data-action="how"]')?.addEventListener('click', () => {
      this.root.querySelector('#how')?.classList.toggle('hidden')
    })
  }

  private renderLoadout() {
    const pCards = PASSENGERS.map((p) => {
      const on = this.selectedPassengers.some((x) => x.id === p.id)
      return `
        <button class="card ${on ? 'on' : ''}" data-p="${p.id}">
          <div class="swatch" style="background:${p.color}"></div>
          <div class="card-body">
            <div class="card-top"><strong>${p.name}</strong><span>$${p.payout}</span></div>
            <p>${p.blurb}</p>
            <div class="bars"><span>Хаос ${Math.round(p.chaos * 100)}%</span><span>Голод ${Math.round(p.hunger * 100)}%</span></div>
          </div>
        </button>`
    }).join('')

    const cCards = CARGO.map((c) => {
      const on = this.selectedCargo.some((x) => x.id === c.id)
      return `
        <button class="card ${on ? 'on' : ''}" data-c="${c.id}">
          <div class="swatch" style="background:${c.color}"></div>
          <div class="card-body">
            <div class="card-top"><strong>${c.name}</strong><span>$${c.payout}</span></div>
            <p>${c.blurb}</p>
            <div class="bars"><span>Ризик ${Math.round(c.volatility * 100)}%</span><span>Вага ${Math.round(c.weight * 100)}%</span></div>
          </div>
        </button>`
    }).join('')

    const payout =
      this.selectedPassengers.reduce((s, p) => s + p.payout, 0) +
      this.selectedCargo.reduce((s, c) => s + c.payout, 0)
    const canFly =
      this.selectedPassengers.length > 0 &&
      this.selectedPassengers.length <= MAX_PASSENGERS &&
      this.selectedCargo.length > 0 &&
      this.selectedCargo.length <= MAX_CARGO

    this.root.innerHTML = `
      <main class="screen loadout">
        <header class="bar">
          <button class="btn tiny ghost" data-action="back">←</button>
          <div><h2>Перед вильотом</h2><p>Нічний борт · фізика увімкнена</p></div>
          <div class="payout">$${payout}</div>
        </header>
        <section>
          <div class="section-head"><h3>Пасажири</h3><span>${this.selectedPassengers.length}/${MAX_PASSENGERS}</span></div>
          <div class="grid">${pCards}</div>
        </section>
        <section>
          <div class="section-head"><h3>Вантаж</h3><span>${this.selectedCargo.length}/${MAX_CARGO}</span></div>
          <div class="grid">${cCards}</div>
        </section>
        <footer class="sticky-cta">
          <button class="btn primary" data-action="fly" ${canFly ? '' : 'disabled'}>Зліт у 3D</button>
        </footer>
      </main>`

    this.root.querySelector('[data-action="back"]')?.addEventListener('click', () => this.setScreen('menu'))
    this.root.querySelector('[data-action="fly"]')?.addEventListener('click', () => {
      if (canFly) this.setScreen('flight')
    })
    this.root.querySelectorAll<HTMLButtonElement>('[data-p]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const card = PASSENGERS.find((p) => p.id === btn.dataset.p)!
        const exists = this.selectedPassengers.some((p) => p.id === card.id)
        this.selectedPassengers = exists
          ? this.selectedPassengers.filter((p) => p.id !== card.id)
          : this.selectedPassengers.length < MAX_PASSENGERS
            ? [...this.selectedPassengers, card]
            : this.selectedPassengers
        this.renderLoadout()
      })
    })
    this.root.querySelectorAll<HTMLButtonElement>('[data-c]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const card = CARGO.find((c) => c.id === btn.dataset.c)!
        const exists = this.selectedCargo.some((c) => c.id === card.id)
        this.selectedCargo = exists
          ? this.selectedCargo.filter((c) => c.id !== card.id)
          : this.selectedCargo.length < MAX_CARGO
            ? [...this.selectedCargo, card]
            : this.selectedCargo
        this.renderLoadout()
      })
    })
  }

  private renderFlight() {
    const loadout: Loadout = {
      passengers: this.selectedPassengers,
      cargo: this.selectedCargo,
    }

    this.root.innerHTML = `
      <main class="screen flight">
        <div id="viewport"></div>
        <div class="hud" id="hud"></div>
        <div class="touch">
          <div class="stick" id="stick"><div class="knob" id="knob"></div></div>
          <div class="touch-right">
            <button class="btn action" id="action">Дія</button>
            <div class="lookpad" id="lookpad"><span>огляд</span></div>
          </div>
        </div>
        <div class="flight-controls">
          <button class="btn role" data-role="pilot">Пілот</button>
          <button class="btn role on" data-role="cabin">Салон</button>
        </div>
      </main>`

    const viewport = this.root.querySelector('#viewport') as HTMLElement
    this.hudEl = this.root.querySelector('#hud')
    this.game = new FlightGame(viewport, loadout)
    this.game.setRole('cabin')
    this.game.setCallbacks(
      (hud) => this.paintHud(hud),
      (result) => {
        this.result = result
        if (result.cash > this.bestCash) {
          this.bestCash = result.cash
          localStorage.setItem('ti-best-cash', String(this.bestCash))
        }
        setTimeout(() => this.setScreen('results'), 500)
      },
    )

    this.root.querySelectorAll<HTMLButtonElement>('[data-role]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const role = btn.dataset.role === 'pilot' ? 'pilot' : 'cabin'
        this.game?.setRole(role)
        this.root.querySelectorAll('.role').forEach((el) => el.classList.remove('on'))
        btn.classList.add('on')
      })
    })

    this.root.querySelector('#action')?.addEventListener('click', () => this.game?.interact())
    this.bindStick()
    this.bindLookPad()
  }

  private paintHud(h: HudState) {
    if (!this.hudEl) return
    const t = Math.max(0, h.timeLeft / h.duration)
    this.hudEl.innerHTML = `
      <div class="hud-card">
        <div class="hud-row">
          <span>ALT ${Math.round(h.altitude)}</span>
          <span class="${h.integrity < 40 ? 'bad' : 'ok'}">HP ${Math.round(h.integrity)}</span>
          <span>$${Math.round(h.cash)}</span>
        </div>
        <div class="hud-row dim">
          <span>SPD ${Math.round(h.speed)}</span>
          <span>REP ${Math.round(h.reputation)}</span>
          <span>FUEL ${Math.round(h.fuel)}%</span>
        </div>
        <div class="bar-track"><div class="bar-fill" style="width:${t * 100}%"></div></div>
        <div class="turb" style="width:${h.turbulence * 100}%"></div>
        <p class="warn">${h.warning}</p>
        <p class="prompt">${h.prompt}</p>
      </div>`
  }

  private bindStick() {
    const stick = this.root.querySelector('#stick') as HTMLElement
    const knob = this.root.querySelector('#knob') as HTMLElement
    let active = false
    let origin = { x: 0, y: 0 }

    const set = (clientX: number, clientY: number) => {
      const dx = clientX - origin.x
      const dy = clientY - origin.y
      const max = 48
      const len = Math.hypot(dx, dy) || 1
      const nx = (dx / len) * Math.min(len, max)
      const ny = (dy / len) * Math.min(len, max)
      knob.style.transform = `translate(${nx}px, ${ny}px)`
      this.game?.setMove(nx / max, -ny / max)
    }

    const end = () => {
      active = false
      knob.style.transform = 'translate(0px, 0px)'
      this.game?.setMove(0, 0)
    }

    stick.addEventListener('pointerdown', (e) => {
      active = true
      stick.setPointerCapture(e.pointerId)
      const r = stick.getBoundingClientRect()
      origin = { x: r.left + r.width / 2, y: r.top + r.height / 2 }
      set(e.clientX, e.clientY)
    })
    stick.addEventListener('pointermove', (e) => {
      if (active) set(e.clientX, e.clientY)
    })
    stick.addEventListener('pointerup', end)
    stick.addEventListener('pointercancel', end)
  }

  private bindLookPad() {
    const pad = this.root.querySelector('#lookpad') as HTMLElement
    let last: { x: number; y: number } | null = null
    pad.addEventListener('pointerdown', (e) => {
      last = { x: e.clientX, y: e.clientY }
      pad.setPointerCapture(e.pointerId)
    })
    pad.addEventListener('pointermove', (e) => {
      if (!last) return
      const dx = e.clientX - last.x
      const dy = e.clientY - last.y
      last = { x: e.clientX, y: e.clientY }
      this.game?.setLook(dx * 0.08, dy * 0.08)
    })
    pad.addEventListener('pointerup', () => {
      last = null
      this.game?.setLook(0, 0)
    })
  }

  private renderResults() {
    if (!this.result) {
      this.setScreen('menu')
      return
    }
    const r = this.result
    this.root.innerHTML = `
      <main class="screen results">
        <div class="atmosphere" aria-hidden="true"></div>
        <section class="result-panel">
          <p class="eyebrow">${r.crashed ? 'INCIDENT REPORT' : 'ARRIVAL BOARD'}</p>
          <h1>Оцінка ${r.grade}</h1>
          <p class="tagline">${r.summary}</p>
          <ul class="stats">
            <li><span>Каса</span><strong>$${r.cash}</strong></li>
            <li><span>Репутація</span><strong>${r.reputation}</strong></li>
            <li><span>Цілісність</span><strong>${r.integrity}</strong></li>
            <li><span>Сервіс</span><strong>${r.served}</strong></li>
            <li><span>Закріплено</span><strong>${r.secured}</strong></li>
          </ul>
          <div class="cta-row">
            <button class="btn primary" data-action="again">Ще рейс</button>
            <button class="btn ghost" data-action="menu">Меню</button>
          </div>
        </section>
      </main>`
    this.root.querySelector('[data-action="again"]')?.addEventListener('click', () => this.setScreen('loadout'))
    this.root.querySelector('[data-action="menu"]')?.addEventListener('click', () => this.setScreen('menu'))
  }
}
