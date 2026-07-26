import { FLIGHT_SECONDS } from './data'
import type {
  CabinEntity,
  FlightResult,
  FlightStats,
  Loadout,
  Role,
  TouchState,
} from './types'

const clamp = (v: number, min: number, max: number) => Math.max(min, Math.min(max, v))
const rand = (a: number, b: number) => a + Math.random() * (b - a)
const pick = <T>(arr: T[]) => arr[Math.floor(Math.random() * arr.length)]!

export class FlightEngine {
  readonly width = 390
  readonly height = 720
  stats: FlightStats
  entities: CabinEntity[] = []
  role: Role = 'pilot'
  loadout: Loadout
  touch: TouchState = {
    active: false,
    x: 0,
    y: 0,
    startX: 0,
    startY: 0,
    id: null,
  }
  stick = { x: 0, y: 0 }
  private eventTimer = 0
  private serviceCooldown = 0
  private served = 0
  private securedCount = 0
  private finished = false
  private result: FlightResult | null = null
  private chaosBudget: number
  private messageTimer = 0

  constructor(loadout: Loadout) {
    this.loadout = loadout
    const volatility =
      loadout.cargo.reduce((s, c) => s + c.volatility, 0) / Math.max(1, loadout.cargo.length)
    const passengerChaos =
      loadout.passengers.reduce((s, p) => s + p.chaos, 0) /
      Math.max(1, loadout.passengers.length)
    this.chaosBudget = 0.35 + volatility * 0.4 + passengerChaos * 0.35

    this.stats = {
      altitude: 6200,
      pitch: 0,
      roll: 0,
      speed: 420,
      fuel: 100,
      integrity: 100,
      reputation: 80,
      cashEarned: 0,
      timeLeft: FLIGHT_SECONDS,
      duration: FLIGHT_SECONDS,
      turbulence: 0.15,
      warnings: ['Бюджетна авіація вітає на борту.'],
    }

    this.spawnCabin()
  }

  private spawnCabin() {
    const colors = ['#7ec8c3', '#f0c75e', '#ff8f6b', '#9bb7ff', '#e7a0c8']
    this.entities = []

    this.loadout.passengers.forEach((p, i) => {
      this.entities.push({
        id: `p-${p.id}`,
        kind: 'passenger',
        label: p.name.split(' ')[0] ?? p.name,
        x: 90 + (i % 2) * 170,
        y: 220 + Math.floor(i / 2) * 120,
        vx: 0,
        vy: 0,
        radius: 26,
        mood: 0.75 + p.patience * 0.2,
        secured: true,
        needsService: Math.random() < p.hunger * 0.5,
        color: colors[i % colors.length]!,
      })
    })

    this.loadout.cargo.forEach((c, i) => {
      this.entities.push({
        id: `c-${c.id}`,
        kind: 'cargo',
        label: c.name.split(' ')[0] ?? c.name,
        x: 70 + i * 130,
        y: 560,
        vx: 0,
        vy: 0,
        radius: 30 + c.weight * 10,
        mood: 1 - c.volatility,
        secured: Math.random() > c.volatility * 0.4,
        needsService: false,
        color: c.volatility > 0.7 ? '#ff6b4a' : '#c4a574',
      })
    })

    this.entities.push({
      id: 'cart',
      kind: 'cart',
      label: 'Візок',
      x: 195,
      y: 420,
      vx: 0,
      vy: 0,
      radius: 22,
      mood: 1,
      secured: true,
      needsService: false,
      color: '#d9e2ec',
    })
  }

  setRole(role: Role) {
    this.role = role
  }

  pointerDown(x: number, y: number, id = 1) {
    this.touch = { active: true, x, y, startX: x, startY: y, id }
    if (this.role === 'cabin') this.tryCabinAction(x, y)
  }

  pointerMove(x: number, y: number) {
    if (!this.touch.active) return
    this.touch.x = x
    this.touch.y = y
    if (this.role === 'pilot') {
      const dx = (x - this.width * 0.5) / (this.width * 0.5)
      const dy = (y - this.height * 0.62) / (this.height * 0.25)
      this.stick.x = clamp(dx, -1, 1)
      this.stick.y = clamp(dy, -1, 1)
    }
  }

  pointerUp() {
    this.touch.active = false
    this.touch.id = null
    if (this.role === 'pilot') this.stick = { x: 0, y: 0 }
  }

  private tryCabinAction(x: number, y: number) {
    const target = [...this.entities]
      .sort((a, b) => {
        const da = (a.x - x) ** 2 + (a.y - y) ** 2
        const db = (b.x - x) ** 2 + (b.y - y) ** 2
        return da - db
      })
      .find((e) => Math.hypot(e.x - x, e.y - y) < e.radius + 28)

    if (!target) return

    if (target.kind === 'passenger' && target.needsService && this.serviceCooldown <= 0) {
      target.needsService = false
      target.mood = clamp(target.mood + 0.25, 0, 1)
      this.served += 1
      this.stats.reputation = clamp(this.stats.reputation + 4, 0, 100)
      this.stats.cashEarned += 18
      this.pushWarning('Сервіс прийнято. Настрій +')
      this.serviceCooldown = 0.35
      return
    }

    if (target.kind === 'cargo' && !target.secured) {
      target.secured = true
      target.vx *= 0.2
      target.vy *= 0.2
      this.securedCount += 1
      this.stats.integrity = clamp(this.stats.integrity + 3, 0, 100)
      this.pushWarning('Вантаж закріплено.')
      return
    }

    if (target.kind === 'hazard') {
      this.entities = this.entities.filter((e) => e.id !== target.id)
      this.stats.integrity = clamp(this.stats.integrity + 5, 0, 100)
      this.pushWarning('Загрозу прибрано.')
      return
    }

    if (target.kind === 'passenger' && target.mood < 0.35) {
      target.mood = clamp(target.mood + 0.15, 0, 1)
      this.stats.reputation = clamp(this.stats.reputation + 2, 0, 100)
      this.pushWarning('Пасажира заспокоїли.')
    }
  }

  private pushWarning(text: string) {
    this.stats.warnings = [text, ...this.stats.warnings].slice(0, 3)
    this.messageTimer = 2.2
  }

  update(dt: number) {
    if (this.finished) return

    this.stats.timeLeft = Math.max(0, this.stats.timeLeft - dt)
    this.eventTimer -= dt
    this.serviceCooldown = Math.max(0, this.serviceCooldown - dt)
    this.messageTimer = Math.max(0, this.messageTimer - dt)

    this.updatePilot(dt)
    this.updateCabin(dt)
    this.maybeSpawnEvent()

    if (this.stats.integrity <= 0 || this.stats.altitude < 400) {
      this.finish(false, true)
      return
    }

    if (this.stats.timeLeft <= 0) {
      const ok =
        this.stats.altitude > 1800 &&
        Math.abs(this.stats.pitch) < 18 &&
        Math.abs(this.stats.roll) < 22 &&
        this.stats.integrity > 25
      this.finish(ok, !ok)
    }
  }

  private updatePilot(dt: number) {
    const inputX = this.role === 'pilot' ? this.stick.x : Math.sin(performance.now() / 900) * 0.15
    const inputY = this.role === 'pilot' ? this.stick.y : Math.cos(performance.now() / 1100) * 0.1

    const turb = this.stats.turbulence
    this.stats.roll = clamp(
      this.stats.roll + inputX * 55 * dt + rand(-1, 1) * turb * 28 * dt,
      -42,
      42,
    )
    this.stats.pitch = clamp(
      this.stats.pitch + inputY * 48 * dt + rand(-1, 1) * turb * 22 * dt,
      -30,
      30,
    )

    // Autostabilize a bit when not touching
    if (this.role !== 'pilot' || !this.touch.active) {
      this.stats.roll *= 1 - 0.55 * dt
      this.stats.pitch *= 1 - 0.5 * dt
    }

    this.stats.altitude += (-this.stats.pitch * 18 - Math.abs(this.stats.roll) * 4) * dt
    this.stats.altitude = clamp(this.stats.altitude, 200, 9800)
    this.stats.speed = clamp(420 - this.stats.pitch * 2.2 - this.chaosBudget * 20, 280, 520)
    this.stats.fuel = Math.max(0, this.stats.fuel - dt * 0.55)

    const stress =
      (Math.abs(this.stats.roll) + Math.abs(this.stats.pitch)) / 50 + this.stats.turbulence
    if (stress > 0.85) {
      this.stats.integrity -= (stress - 0.85) * 18 * dt
    }

    // Natural turbulence wave
    const t = 1 - this.stats.timeLeft / this.stats.duration
    this.stats.turbulence = clamp(
      0.12 + this.chaosBudget * 0.5 + Math.sin(t * Math.PI * 3) * 0.18 + (t > 0.7 ? 0.15 : 0),
      0.08,
      1,
    )
  }

  private updateCabin(dt: number) {
    const forceX = this.stats.roll * 4.2
    const forceY = this.stats.pitch * 3.4 + this.stats.turbulence * 20

    for (const e of this.entities) {
      if (e.kind === 'hazard') {
        e.x += e.vx * dt
        e.y += e.vy * dt
        e.vy += 30 * dt
        if (e.y > this.height - 40) {
          this.stats.integrity -= 8 * dt
        }
        continue
      }

      const loose = e.kind === 'cargo' ? !e.secured : e.mood < 0.4 || this.stats.turbulence > 0.55
      if (loose) {
        e.vx += forceX * dt * (e.kind === 'cargo' ? 1.3 : 1)
        e.vy += forceY * dt
        e.vx *= 1 - 1.8 * dt
        e.vy *= 1 - 1.8 * dt
        e.x += e.vx * dt * 10
        e.y += e.vy * dt * 10
      } else {
        e.vx *= 1 - 4 * dt
        e.vy *= 1 - 4 * dt
      }

      // Keep in cabin bounds
      e.x = clamp(e.x, 40, this.width - 40)
      e.y = clamp(e.y, 170, this.height - 36)

      if (e.kind === 'passenger') {
        if (Math.random() < dt * (0.08 + this.chaosBudget * 0.12)) {
          e.needsService = true
        }
        if (e.needsService) e.mood -= dt * 0.06
        if (this.stats.turbulence > 0.65) e.mood -= dt * 0.05
        e.mood = clamp(e.mood, 0, 1)
        if (e.mood < 0.2) {
          this.stats.reputation -= 6 * dt
          if (this.messageTimer <= 0) this.pushWarning(`${e.label} на межі.`)
        }
      }

      if (e.kind === 'cargo' && !e.secured) {
        this.stats.integrity -= 3.5 * dt * this.stats.turbulence
        if (Math.hypot(e.vx, e.vy) > 1.8 && Math.random() < dt * 0.4) {
          this.stats.integrity -= 2
          this.pushWarning('Вантаж бʼється об борт!')
        }
      }
    }

    // Auto cabin help when playing as pilot
    if (this.role === 'pilot' && Math.random() < dt * 0.25) {
      const needy = this.entities.find((e) => e.kind === 'passenger' && e.needsService)
      if (needy && Math.random() > this.chaosBudget) {
        needy.needsService = false
        needy.mood = clamp(needy.mood + 0.1, 0, 1)
      }
    }
  }

  private maybeSpawnEvent() {
    if (this.eventTimer > 0) return
    this.eventTimer = rand(4.5, 8.5) * (1.15 - this.chaosBudget * 0.4)

    const roll = Math.random()
    if (roll < 0.33) {
      this.pushWarning(pick([
        'Повітряна яма!',
        'Бічний вітер підріс.',
        'Капітан, тримай ніс!',
      ]))
      this.stats.turbulence = clamp(this.stats.turbulence + 0.25, 0, 1)
      this.stats.pitch += rand(-10, 10)
      this.stats.roll += rand(-14, 14)
    } else if (roll < 0.66) {
      const p = this.entities.find((e) => e.kind === 'passenger')
      if (p) {
        p.needsService = true
        p.mood -= 0.12
        this.pushWarning(`${p.label} вимагає уваги.`)
      }
    } else {
      const c = this.entities.find((e) => e.kind === 'cargo' && e.secured)
      if (c && Math.random() < this.chaosBudget) {
        c.secured = false
        c.vx = rand(-2, 2)
        this.pushWarning(`${c.label} зірвався з кріплень!`)
      } else {
        this.entities.push({
          id: `hz-${Math.random().toString(36).slice(2, 7)}`,
          kind: 'hazard',
          label: pick(['Візок', 'Кава', 'Багаж']),
          x: rand(60, this.width - 60),
          y: 180,
          vx: rand(-20, 20),
          vy: rand(10, 40),
          radius: 16,
          mood: 0,
          secured: false,
          needsService: false,
          color: '#ffb454',
        })
        this.pushWarning('У салоні летить небезпека!')
      }
    }
  }

  private finish(landed: boolean, crashed: boolean) {
    this.finished = true
    const base =
      this.loadout.passengers.reduce((s, p) => s + p.payout, 0) +
      this.loadout.cargo.reduce((s, c) => s + c.payout, 0)
    let cash = this.stats.cashEarned
    if (landed) cash += Math.round(base * (0.55 + this.stats.reputation / 200))
    if (crashed) cash = Math.round(cash * 0.15)

    const score =
      (landed ? 40 : 0) +
      this.stats.integrity * 0.25 +
      this.stats.reputation * 0.2 +
      this.served * 4 +
      this.securedCount * 5

    const grade =
      score > 90 ? 'S' : score > 75 ? 'A' : score > 60 ? 'B' : score > 40 ? 'C' : crashed ? 'F' : 'D'

    this.result = {
      landed,
      crashed,
      cash: Math.max(0, cash),
      reputation: Math.round(clamp(this.stats.reputation, 0, 100)),
      integrity: Math.round(clamp(this.stats.integrity, 0, 100)),
      served: this.served,
      secured: this.securedCount,
      grade,
      summary: crashed
        ? 'Борт не долетів. Страховка плаче, TikTok радіє.'
        : landed
          ? 'Мʼяка посадка за мірками Turbulence Inc.'
          : 'Долетіли. Технічно.',
    }
  }

  getResult() {
    return this.result
  }

  isFinished() {
    return this.finished
  }
}
