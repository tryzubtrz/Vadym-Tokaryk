import { CARGO, MAX_CARGO, MAX_PASSENGERS, PASSENGERS, ROUTES } from './data'
import { FlightEngine } from './FlightEngine'
import { drawFlight } from './render'
import type { CargoCard, Loadout, PassengerCard, ScreenId } from './types'

export class App {
  private root: HTMLElement
  private screen: ScreenId = 'menu'
  private selectedPassengers: PassengerCard[] = []
  private selectedCargo: CargoCard[] = []
  private route = ROUTES[0]!
  private engine: FlightEngine | null = null
  private raf = 0
  private last = 0
  private canvas: HTMLCanvasElement | null = null
  private ctx: CanvasRenderingContext2D | null = null
  private bestCash = Number(localStorage.getItem('ti-best-cash') || 0)

  constructor(root: HTMLElement) {
    this.root = root
    this.render()
  }

  private setScreen(screen: ScreenId) {
    this.screen = screen
    cancelAnimationFrame(this.raf)
    this.engine = null
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
        <header class="hero">
          <p class="eyebrow">WORLD'S WORST AIRLINE</p>
          <h1>Turbulence<br/>Inc.</h1>
          <p class="tagline">Пілотуй розвалину, рятуй салон, вези сумнівний вантаж. На телефоні.</p>
          <div class="cta-row">
            <button class="btn primary" data-action="start">У рейс</button>
            <button class="btn ghost" data-action="how">Як грати</button>
          </div>
          <p class="meta">Рекорд каси: $${this.bestCash}</p>
        </header>
        <section class="how hidden" id="how">
          <h2>Коротко</h2>
          <ol>
            <li>Обери пасажирів і вантаж — більше грошей = більше хаосу.</li>
            <li>У польоті перемикай <b>Пілот</b> / <b>Салон</b>.</li>
            <li>Пілот тримає горизонт. Салон гасить кризи тапами.</li>
            <li>Долети з цілим бортом — забери виплату.</li>
          </ol>
          <p class="note">Оригінальна мобільна гра в жанрі хаотичного авіа-co-op. Не повʼязана з Dear Passengers / FLEXUS.</p>
        </section>
      </main>
    `

    this.root.querySelector('[data-action="start"]')?.addEventListener('click', () => {
      this.selectedPassengers = []
      this.selectedCargo = []
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
          <div class="card-top">
            <strong>${p.name}</strong>
            <span>$${p.payout}</span>
          </div>
          <p>${p.blurb}</p>
          <div class="bars">
            <span>Хаос ${Math.round(p.chaos * 100)}%</span>
            <span>Голод ${Math.round(p.hunger * 100)}%</span>
          </div>
        </button>
      `
    }).join('')

    const cCards = CARGO.map((c) => {
      const on = this.selectedCargo.some((x) => x.id === c.id)
      return `
        <button class="card ${on ? 'on' : ''}" data-c="${c.id}">
          <div class="card-top">
            <strong>${c.name}</strong>
            <span>$${c.payout}</span>
          </div>
          <p>${c.blurb}</p>
          <div class="bars">
            <span>Ризик ${Math.round(c.volatility * 100)}%</span>
            <span>Вага ${Math.round(c.weight * 100)}%</span>
          </div>
        </button>
      `
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
          <div>
            <h2>Перед вильотом</h2>
            <p>${this.route.name}</p>
          </div>
          <div class="payout">$${payout}</div>
        </header>

        <section>
          <div class="section-head">
            <h3>Пасажири</h3>
            <span>${this.selectedPassengers.length}/${MAX_PASSENGERS}</span>
          </div>
          <div class="grid">${pCards}</div>
        </section>

        <section>
          <div class="section-head">
            <h3>Вантаж</h3>
            <span>${this.selectedCargo.length}/${MAX_CARGO}</span>
          </div>
          <div class="grid">${cCards}</div>
        </section>

        <footer class="sticky-cta">
          <button class="btn primary" data-action="fly" ${canFly ? '' : 'disabled'}>
            Зліт
          </button>
        </footer>
      </main>
    `

    this.root.querySelector('[data-action="back"]')?.addEventListener('click', () => {
      this.setScreen('menu')
    })
    this.root.querySelector('[data-action="fly"]')?.addEventListener('click', () => {
      if (!canFly) return
      this.setScreen('flight')
    })

    this.root.querySelectorAll<HTMLButtonElement>('[data-p]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const id = btn.dataset.p!
        const card = PASSENGERS.find((p) => p.id === id)!
        const exists = this.selectedPassengers.find((p) => p.id === id)
        if (exists) {
          this.selectedPassengers = this.selectedPassengers.filter((p) => p.id !== id)
        } else if (this.selectedPassengers.length < MAX_PASSENGERS) {
          this.selectedPassengers = [...this.selectedPassengers, card]
        }
        this.renderLoadout()
      })
    })

    this.root.querySelectorAll<HTMLButtonElement>('[data-c]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const id = btn.dataset.c!
        const card = CARGO.find((c) => c.id === id)!
        const exists = this.selectedCargo.find((c) => c.id === id)
        if (exists) {
          this.selectedCargo = this.selectedCargo.filter((c) => c.id !== id)
        } else if (this.selectedCargo.length < MAX_CARGO) {
          this.selectedCargo = [...this.selectedCargo, card]
        }
        this.renderLoadout()
      })
    })
  }

  private renderFlight() {
    const loadout: Loadout = {
      passengers: this.selectedPassengers,
      cargo: this.selectedCargo,
    }
    this.engine = new FlightEngine(loadout)

    this.root.innerHTML = `
      <main class="screen flight">
        <canvas id="game" width="390" height="720"></canvas>
        <div class="flight-controls">
          <button class="btn role on" data-role="pilot">Пілот</button>
          <button class="btn role" data-role="cabin">Салон</button>
        </div>
      </main>
    `

    this.canvas = this.root.querySelector('#game')
    this.ctx = this.canvas?.getContext('2d') ?? null
    this.bindCanvas()
    this.bindRoles()
    this.last = performance.now()
    this.loop(this.last)
  }

  private bindRoles() {
    this.root.querySelectorAll<HTMLButtonElement>('[data-role]').forEach((btn) => {
      btn.addEventListener('click', () => {
        const role = btn.dataset.role === 'cabin' ? 'cabin' : 'pilot'
        this.engine?.setRole(role)
        this.root.querySelectorAll('.role').forEach((el) => el.classList.remove('on'))
        btn.classList.add('on')
      })
    })
  }

  private bindCanvas() {
    const canvas = this.canvas
    const engine = this.engine
    if (!canvas || !engine) return

    const toLocal = (clientX: number, clientY: number) => {
      const rect = canvas.getBoundingClientRect()
      return {
        x: ((clientX - rect.left) / rect.width) * engine.width,
        y: ((clientY - rect.top) / rect.height) * engine.height,
      }
    }

    const onDown = (e: PointerEvent) => {
      e.preventDefault()
      canvas.setPointerCapture(e.pointerId)
      const { x, y } = toLocal(e.clientX, e.clientY)
      engine.pointerDown(x, y, e.pointerId)
    }
    const onMove = (e: PointerEvent) => {
      if (!engine.touch.active) return
      const { x, y } = toLocal(e.clientX, e.clientY)
      engine.pointerMove(x, y)
    }
    const onUp = () => engine.pointerUp()

    canvas.addEventListener('pointerdown', onDown)
    canvas.addEventListener('pointermove', onMove)
    canvas.addEventListener('pointerup', onUp)
    canvas.addEventListener('pointercancel', onUp)
  }

  private loop = (now: number) => {
    const engine = this.engine
    const ctx = this.ctx
    if (!engine || !ctx) return

    const dt = Math.min(0.033, (now - this.last) / 1000)
    this.last = now
    engine.update(dt)
    drawFlight(ctx, engine, now)

    if (engine.isFinished()) {
      const result = engine.getResult()
      if (result && result.cash > this.bestCash) {
        this.bestCash = result.cash
        localStorage.setItem('ti-best-cash', String(this.bestCash))
      }
      // stash result on window-like field
      ;(this as unknown as { _result: typeof result })._result = result
      setTimeout(() => this.setScreen('results'), 350)
      return
    }

    this.raf = requestAnimationFrame(this.loop)
  }

  private renderResults() {
    const result = (this as unknown as { _result?: ReturnType<FlightEngine['getResult']> })._result
    if (!result) {
      this.setScreen('menu')
      return
    }

    this.root.innerHTML = `
      <main class="screen results">
        <div class="atmosphere" aria-hidden="true"></div>
        <section class="result-panel">
          <p class="eyebrow">${result.crashed ? 'INCIDENT REPORT' : 'ARRIVAL'}</p>
          <h1>Оцінка ${result.grade}</h1>
          <p class="tagline">${result.summary}</p>
          <ul class="stats">
            <li><span>Каса</span><strong>$${result.cash}</strong></li>
            <li><span>Репутація</span><strong>${result.reputation}</strong></li>
            <li><span>Цілісність</span><strong>${result.integrity}</strong></li>
            <li><span>Сервіс</span><strong>${result.served}</strong></li>
            <li><span>Закріплено</span><strong>${result.secured}</strong></li>
          </ul>
          <div class="cta-row">
            <button class="btn primary" data-action="again">Ще рейс</button>
            <button class="btn ghost" data-action="menu">Меню</button>
          </div>
        </section>
      </main>
    `

    this.root.querySelector('[data-action="again"]')?.addEventListener('click', () => {
      this.setScreen('loadout')
    })
    this.root.querySelector('[data-action="menu"]')?.addEventListener('click', () => {
      this.setScreen('menu')
    })
  }
}
