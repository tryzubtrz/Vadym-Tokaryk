import * as THREE from 'three'
import * as CANNON from 'cannon-es'
import { FLIGHT_SECONDS } from './data'
import type { FlightResult, HudState, Loadout, Role } from './types'

type InteractKind = 'passenger' | 'cargo' | 'hazard'

interface SimPassenger {
  id: string
  name: string
  mesh: THREE.Group
  body: CANNON.Body
  mood: number
  needsService: boolean
  seat: THREE.Vector3
  marker: THREE.Mesh
}

interface SimCargo {
  id: string
  name: string
  mesh: THREE.Mesh
  body: CANNON.Body
  secured: boolean
  volatility: number
  marker: THREE.Mesh
}

interface SimHazard {
  id: string
  mesh: THREE.Mesh
  body: CANNON.Body
}

const clamp = (v: number, a: number, b: number) => Math.max(a, Math.min(b, v))
const rand = (a: number, b: number) => a + Math.random() * (b - a)

export class FlightGame {
  readonly dom: HTMLDivElement
  private renderer: THREE.WebGLRenderer
  private scene: THREE.Scene
  private camera: THREE.PerspectiveCamera
  private world: CANNON.World
  private clock = new THREE.Clock()
  private raf = 0
  private role: Role = 'cabin'
  private loadout: Loadout

  private planeRoot = new THREE.Group()
  private passengers: SimPassenger[] = []
  private cargo: SimCargo[] = []
  private hazards: SimHazard[] = []
  private cartMesh!: THREE.Mesh
  private cartBody!: CANNON.Body

  private playerPos = new THREE.Vector3(0, 1.6, 4)
  private playerYaw = Math.PI
  private playerPitch = 0
  private move = { x: 0, y: 0 }
  private look = { x: 0, y: 0 }
  private stick = { x: 0, y: 0 }

  private altitude = 6400
  private pitch = 0
  private roll = 0
  private speed = 430
  private fuel = 100
  private integrity = 100
  private reputation = 82
  private cash = 0
  private timeLeft = FLIGHT_SECONDS
  private turbulence = 0.15
  private warning = 'Доброї ночі. Бюджетна авіація вітає на борту.'
  private prompt = ''
  private warningTimer = 0
  private eventTimer = 5
  private served = 0
  private securedCount = 0
  private chaos = 0.4
  private finished = false
  private result: FlightResult | null = null
  private onHud: ((h: HudState) => void) | null = null
  private onDone: ((r: FlightResult) => void) | null = null
  private keys = new Set<string>()
  private pointerLookActive = false
  private lastPointer = { x: 0, y: 0 }
  private sky!: THREE.Mesh
  private cabinLights: THREE.PointLight[] = []

  constructor(host: HTMLElement, loadout: Loadout) {
    this.loadout = loadout
    this.chaos =
      0.28 +
      loadout.passengers.reduce((s, p) => s + p.chaos, 0) / Math.max(1, loadout.passengers.length) * 0.35 +
      loadout.cargo.reduce((s, c) => s + c.volatility, 0) / Math.max(1, loadout.cargo.length) * 0.37

    this.dom = document.createElement('div')
    this.dom.className = 'game-host'
    host.appendChild(this.dom)

    this.scene = new THREE.Scene()
    this.scene.fog = new THREE.FogExp2(0x07141c, 0.012)
    this.camera = new THREE.PerspectiveCamera(70, 1, 0.08, 400)
    this.renderer = new THREE.WebGLRenderer({ antialias: true, powerPreference: 'high-performance' })
    this.renderer.setPixelRatio(Math.min(window.devicePixelRatio, 2))
    this.renderer.setSize(host.clientWidth, host.clientHeight)
    this.renderer.shadowMap.enabled = true
    this.renderer.outputColorSpace = THREE.SRGBColorSpace
    this.dom.appendChild(this.renderer.domElement)

    this.world = new CANNON.World({ gravity: new CANNON.Vec3(0, -9.8, 0) })
    this.world.broadphase = new CANNON.SAPBroadphase(this.world)
    this.world.allowSleep = true

    this.buildWorld()
    this.bindInput()
    this.onResize()
    window.addEventListener('resize', this.onResize)
    this.raf = requestAnimationFrame(this.tick)
  }

  setCallbacks(onHud: (h: HudState) => void, onDone: (r: FlightResult) => void) {
    this.onHud = onHud
    this.onDone = onDone
  }

  setRole(role: Role) {
    this.role = role
    if (role === 'pilot') {
      this.playerYaw = 0
      this.playerPitch = -0.08
    } else {
      this.playerYaw = Math.PI
      this.playerPitch = 0
      this.playerPos.set(0, 1.6, 3.5)
    }
  }

  setMove(x: number, y: number) {
    this.move.x = clamp(x, -1, 1)
    this.move.y = clamp(y, -1, 1)
    if (this.role === 'pilot') {
      this.stick.x = this.move.x
      this.stick.y = this.move.y
    }
  }

  setLook(dx: number, dy: number) {
    this.look.x = dx
    this.look.y = dy
  }

  interact() {
    if (this.finished || this.role !== 'cabin') return
    const target = this.pickInteract()
    if (!target) {
      this.pushWarn('Поруч немає з ким працювати.')
      return
    }
    if (target.kind === 'passenger') {
      const p = target.ref as SimPassenger
      if (p.needsService) {
        p.needsService = false
        p.mood = clamp(p.mood + 0.28, 0, 1)
        p.marker.visible = false
        this.served += 1
        this.cash += 22
        this.reputation = clamp(this.reputation + 5, 0, 100)
        this.pushWarn(`${p.name}: «Дякую… напевно.»`)
      } else if (p.mood < 0.4) {
        p.mood = clamp(p.mood + 0.18, 0, 1)
        this.reputation = clamp(this.reputation + 2, 0, 100)
        this.pushWarn(`${p.name} трохи заспокоївся.`)
      } else {
        this.pushWarn(`${p.name} поки ок.`)
      }
    } else if (target.kind === 'cargo') {
      const c = target.ref as SimCargo
      if (!c.secured) {
        c.secured = true
        c.body.velocity.set(0, 0, 0)
        c.body.angularVelocity.set(0, 0, 0)
        c.body.type = CANNON.Body.KINEMATIC
        c.marker.visible = false
        this.securedCount += 1
        this.integrity = clamp(this.integrity + 4, 0, 100)
        this.cash += 15
        this.pushWarn(`${c.name} закріплено ременями.`)
      }
    } else {
      const h = target.ref as SimHazard
      this.world.removeBody(h.body)
      this.scene.remove(h.mesh)
      this.hazards = this.hazards.filter((x) => x.id !== h.id)
      this.integrity = clamp(this.integrity + 3, 0, 100)
      this.pushWarn('Прибрано з проходу.')
    }
  }

  dispose() {
    cancelAnimationFrame(this.raf)
    window.removeEventListener('resize', this.onResize)
    window.removeEventListener('keydown', this.onKeyDown)
    window.removeEventListener('keyup', this.onKeyUp)
    this.renderer.dispose()
    this.dom.remove()
  }

  private onResize = () => {
    const w = this.dom.clientWidth || window.innerWidth
    const h = this.dom.clientHeight || window.innerHeight
    this.camera.aspect = w / h
    this.camera.updateProjectionMatrix()
    this.renderer.setSize(w, h, false)
  }

  private pushWarn(text: string) {
    this.warning = text
    this.warningTimer = 2.4
  }

  private buildWorld() {
    // Sky dome
    const skyGeo = new THREE.SphereGeometry(180, 32, 24)
    const skyMat = new THREE.ShaderMaterial({
      side: THREE.BackSide,
      uniforms: {
        top: { value: new THREE.Color('#020b14') },
        mid: { value: new THREE.Color('#123047') },
        bot: { value: new THREE.Color('#1d3b2d') },
      },
      vertexShader: `
        varying vec3 vPos;
        void main(){
          vPos = position;
          gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0);
        }
      `,
      fragmentShader: `
        uniform vec3 top; uniform vec3 mid; uniform vec3 bot;
        varying vec3 vPos;
        void main(){
          float h = normalize(vPos).y * 0.5 + 0.5;
          vec3 col = mix(bot, mid, smoothstep(0.0,0.55,h));
          col = mix(col, top, smoothstep(0.45,1.0,h));
          gl_FragColor = vec4(col,1.0);
        }
      `,
    })
    this.sky = new THREE.Mesh(skyGeo, skyMat)
    this.scene.add(this.sky)

    // Stars
    const starGeo = new THREE.BufferGeometry()
    const starPos = new Float32Array(900)
    for (let i = 0; i < 300; i++) {
      const v = new THREE.Vector3().randomDirection().multiplyScalar(rand(60, 160))
      starPos[i * 3] = v.x
      starPos[i * 3 + 1] = Math.abs(v.y) + 10
      starPos[i * 3 + 2] = v.z
    }
    starGeo.setAttribute('position', new THREE.BufferAttribute(starPos, 3))
    this.scene.add(new THREE.Points(starGeo, new THREE.PointsMaterial({ color: 0xf0c75e, size: 0.45 })))

    const hemi = new THREE.HemisphereLight(0xb8d4ff, 0x2a1a10, 0.55)
    this.scene.add(hemi)
    const dir = new THREE.DirectionalLight(0xffe2b0, 0.65)
    dir.position.set(8, 18, 4)
    dir.castShadow = true
    this.scene.add(dir)

    this.scene.add(this.planeRoot)
    this.planeRoot.add(this.camera)
    this.buildFuselage()
    this.spawnPassengers()
    this.spawnCargo()
    this.spawnCart()
  }

  private mat(color: string | number, opts: { roughness?: number; metalness?: number; emissive?: number } = {}) {
    return new THREE.MeshStandardMaterial({
      color,
      roughness: opts.roughness ?? 0.72,
      metalness: opts.metalness ?? 0.08,
      emissive: opts.emissive ?? 0x000000,
    })
  }

  private addStaticBox(
    size: THREE.Vector3,
    pos: THREE.Vector3,
    color: string | number,
    rotY = 0,
    opts: { roughness?: number; metalness?: number } = {},
  ) {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(size.x, size.y, size.z), this.mat(color, opts))
    mesh.position.copy(pos)
    mesh.rotation.y = rotY
    mesh.castShadow = true
    mesh.receiveShadow = true
    this.planeRoot.add(mesh)
    const body = new CANNON.Body({
      mass: 0,
      shape: new CANNON.Box(new CANNON.Vec3(size.x / 2, size.y / 2, size.z / 2)),
      position: new CANNON.Vec3(pos.x, pos.y, pos.z),
    })
    body.quaternion.setFromEuler(0, rotY, 0)
    this.world.addBody(body)
    return mesh
  }

  private buildFuselage() {
    // Floor / ceiling / walls
    this.addStaticBox(new THREE.Vector3(3.2, 0.18, 18), new THREE.Vector3(0, 0, 2), '#3a4550', 0, {
      roughness: 0.9,
    })
    this.addStaticBox(new THREE.Vector3(3.2, 0.12, 18), new THREE.Vector3(0, 2.55, 2), '#2c3640')
    this.addStaticBox(new THREE.Vector3(0.12, 2.5, 18), new THREE.Vector3(-1.55, 1.25, 2), '#44515c', 0, {
      metalness: 0.25,
    })
    this.addStaticBox(new THREE.Vector3(0.12, 2.5, 18), new THREE.Vector3(1.55, 1.25, 2), '#44515c', 0, {
      metalness: 0.25,
    })
    // Cockpit bulkhead + cargo bulkhead
    this.addStaticBox(new THREE.Vector3(3.1, 2.4, 0.15), new THREE.Vector3(0, 1.2, -6.2), '#1f2a33')
    this.addStaticBox(new THREE.Vector3(3.1, 2.4, 0.15), new THREE.Vector3(0, 1.2, 10.4), '#1f2a33')

    // Aisle carpet
    const carpet = new THREE.Mesh(
      new THREE.BoxGeometry(0.9, 0.02, 15.5),
      this.mat('#5a2d2d', { roughness: 1 }),
    )
    carpet.position.set(0, 0.1, 2)
    carpet.receiveShadow = true
    this.planeRoot.add(carpet)

    // Seats
    for (let row = 0; row < 7; row++) {
      const z = -3.8 + row * 1.7
      for (const x of [-1.05, 1.05]) {
        this.makeSeat(x, z)
      }
    }

    // Windows
    for (let i = 0; i < 8; i++) {
      const z = -4.2 + i * 1.7
      for (const x of [-1.52, 1.52]) {
        const frame = new THREE.Mesh(
          new THREE.BoxGeometry(0.06, 0.55, 0.7),
          this.mat('#9aa7b2', { metalness: 0.4, roughness: 0.35 }),
        )
        frame.position.set(x, 1.45, z)
        this.planeRoot.add(frame)
        const glass = new THREE.Mesh(
          new THREE.PlaneGeometry(0.55, 0.42),
          new THREE.MeshStandardMaterial({
            color: '#7ec8c3',
            emissive: '#12353a',
            emissiveIntensity: 0.5,
            transparent: true,
            opacity: 0.55,
            roughness: 0.15,
            metalness: 0.2,
          }),
        )
        glass.position.set(x + (x > 0 ? -0.04 : 0.04), 1.45, z)
        glass.rotation.y = x > 0 ? -Math.PI / 2 : Math.PI / 2
        this.planeRoot.add(glass)
      }
    }

    // Overhead bins
    this.addStaticBox(new THREE.Vector3(0.7, 0.35, 15), new THREE.Vector3(-1.05, 2.25, 2), '#6a7682', 0, {
      metalness: 0.3,
    })
    this.addStaticBox(new THREE.Vector3(0.7, 0.35, 15), new THREE.Vector3(1.05, 2.25, 2), '#6a7682', 0, {
      metalness: 0.3,
    })

    // Cockpit dashboard
    const dash = new THREE.Mesh(
      new THREE.BoxGeometry(2.4, 0.55, 0.9),
      this.mat('#151b22', { metalness: 0.45, roughness: 0.4 }),
    )
    dash.position.set(0, 0.85, -7.1)
    this.planeRoot.add(dash)
    const panel = new THREE.Mesh(
      new THREE.PlaneGeometry(1.8, 0.35),
      new THREE.MeshStandardMaterial({
        color: '#0b1f2a',
        emissive: '#1f6f5b',
        emissiveIntensity: 0.8,
      }),
    )
    panel.position.set(0, 1.05, -6.7)
    panel.rotation.x = -0.55
    this.planeRoot.add(panel)

    // Cabin lights
    for (let i = 0; i < 5; i++) {
      const light = new THREE.PointLight(0xffd7a0, 0.55, 7, 2)
      light.position.set(0, 2.2, -3 + i * 2.8)
      this.planeRoot.add(light)
      this.cabinLights.push(light)
      const fixture = new THREE.Mesh(
        new THREE.BoxGeometry(0.8, 0.05, 0.2),
        new THREE.MeshStandardMaterial({ color: '#f0e0c0', emissive: '#f0c75e', emissiveIntensity: 0.6 }),
      )
      fixture.position.copy(light.position)
      this.planeRoot.add(fixture)
    }

    // Exterior nose hint
    const nose = new THREE.Mesh(
      new THREE.ConeGeometry(1.4, 2.2, 16),
      this.mat('#7ec8c3', { metalness: 0.35, roughness: 0.4 }),
    )
    nose.rotation.x = -Math.PI / 2
    nose.position.set(0, 1.2, -8.4)
    this.planeRoot.add(nose)
  }

  private makeSeat(x: number, z: number) {
    const base = this.addStaticBox(new THREE.Vector3(0.7, 0.35, 0.7), new THREE.Vector3(x, 0.35, z), '#2f4f4f')
    const back = new THREE.Mesh(new THREE.BoxGeometry(0.7, 0.85, 0.12), this.mat('#244744'))
    back.position.set(x, 0.85, z + (x < 0 ? 0.28 : -0.28) * 0 + 0.28)
    back.position.set(x, 0.9, z + 0.28)
    back.castShadow = true
    this.planeRoot.add(back)
    const head = new THREE.Mesh(new THREE.BoxGeometry(0.55, 0.22, 0.1), this.mat('#1d3533'))
    head.position.set(x, 1.35, z + 0.3)
    this.planeRoot.add(head)
    void base
  }

  private spawnPassengers() {
    const seats: THREE.Vector3[] = []
    for (let row = 0; row < 7; row++) {
      const z = -3.8 + row * 1.7
      seats.push(new THREE.Vector3(-1.05, 0.95, z))
      seats.push(new THREE.Vector3(1.05, 0.95, z))
    }

    this.loadout.passengers.forEach((card, i) => {
      const seat = seats[i % seats.length]!.clone()
      const group = new THREE.Group()
      const bodyMesh = new THREE.Mesh(
        new THREE.CapsuleGeometry(0.22, 0.55, 4, 8),
        this.mat(card.color, { roughness: 0.55 }),
      )
      bodyMesh.castShadow = true
      const head = new THREE.Mesh(new THREE.SphereGeometry(0.18, 12, 12), this.mat('#f0d5c0'))
      head.position.y = 0.55
      const phone = new THREE.Mesh(
        new THREE.BoxGeometry(0.08, 0.14, 0.02),
        new THREE.MeshStandardMaterial({ color: '#111', emissive: '#3af', emissiveIntensity: 0.4 }),
      )
      phone.position.set(0.18, 0.15, 0.15)
      group.add(bodyMesh, head, phone)
      group.position.copy(seat)
      this.planeRoot.add(group)

      const body = new CANNON.Body({
        mass: 55,
        shape: new CANNON.Sphere(0.28),
        position: new CANNON.Vec3(seat.x, seat.y, seat.z),
        linearDamping: 0.4,
        angularDamping: 0.8,
      })
      body.sleep()
      this.world.addBody(body)

      const marker = new THREE.Mesh(
        new THREE.SphereGeometry(0.09, 10, 10),
        new THREE.MeshStandardMaterial({ color: '#ff6b4a', emissive: '#ff6b4a', emissiveIntensity: 1 }),
      )
      marker.position.set(0, 0.95, 0)
      marker.visible = Math.random() < card.hunger * 0.45
      group.add(marker)

      this.passengers.push({
        id: card.id,
        name: card.name,
        mesh: group,
        body,
        mood: 0.7 + card.patience * 0.25,
        needsService: marker.visible,
        seat,
        marker,
      })
    })
  }

  private spawnCargo() {
    this.loadout.cargo.forEach((card, i) => {
      const size = 0.35 + card.weight * 0.35
      const mesh = new THREE.Mesh(
        new THREE.BoxGeometry(size, size * 0.85, size * 1.1),
        this.mat(card.color, { roughness: 0.85 }),
      )
      const x = -0.7 + (i % 3) * 0.7
      const z = 8.2 + Math.floor(i / 3) * 0.8
      mesh.position.set(x, 0.45 + size * 0.2, z)
      mesh.castShadow = true
      this.planeRoot.add(mesh)

      const secured = Math.random() > card.volatility * 0.45
      const body = new CANNON.Body({
        mass: secured ? 0 : 20 + card.weight * 40,
        shape: new CANNON.Box(new CANNON.Vec3(size / 2, (size * 0.85) / 2, (size * 1.1) / 2)),
        position: new CANNON.Vec3(mesh.position.x, mesh.position.y, mesh.position.z),
        linearDamping: 0.25,
        angularDamping: 0.25,
      })
      if (secured) body.type = CANNON.Body.KINEMATIC
      this.world.addBody(body)

      const marker = new THREE.Mesh(
        new THREE.SphereGeometry(0.1, 10, 10),
        new THREE.MeshStandardMaterial({ color: '#f0c75e', emissive: '#f0c75e', emissiveIntensity: 1 }),
      )
      marker.position.set(0, size * 0.7, 0)
      marker.visible = !secured
      mesh.add(marker)

      this.cargo.push({
        id: card.id,
        name: card.name,
        mesh,
        body,
        secured,
        volatility: card.volatility,
        marker,
      })
    })
  }

  private spawnCart() {
    this.cartMesh = new THREE.Mesh(
      new THREE.BoxGeometry(0.55, 0.9, 0.7),
      this.mat('#d9e2ec', { metalness: 0.35, roughness: 0.35 }),
    )
    this.cartMesh.position.set(0.15, 0.55, 1.5)
    this.cartMesh.castShadow = true
    this.planeRoot.add(this.cartMesh)
    this.cartBody = new CANNON.Body({
      mass: 35,
      shape: new CANNON.Box(new CANNON.Vec3(0.275, 0.45, 0.35)),
      position: new CANNON.Vec3(0.15, 0.55, 1.5),
      linearDamping: 0.6,
      angularDamping: 0.8,
    })
    this.world.addBody(this.cartBody)
  }

  private bindInput() {
    window.addEventListener('keydown', this.onKeyDown)
    window.addEventListener('keyup', this.onKeyUp)

    const el = this.renderer.domElement
    el.addEventListener('pointerdown', (e) => {
      if (e.clientX > window.innerWidth * 0.45) {
        this.pointerLookActive = true
        this.lastPointer = { x: e.clientX, y: e.clientY }
        el.setPointerCapture(e.pointerId)
      }
    })
    el.addEventListener('pointermove', (e) => {
      if (!this.pointerLookActive) return
      const dx = e.clientX - this.lastPointer.x
      const dy = e.clientY - this.lastPointer.y
      this.lastPointer = { x: e.clientX, y: e.clientY }
      this.playerYaw -= dx * 0.005
      this.playerPitch = clamp(this.playerPitch - dy * 0.004, -1.1, 1.1)
    })
    el.addEventListener('pointerup', () => {
      this.pointerLookActive = false
    })
  }

  private onKeyDown = (e: KeyboardEvent) => {
    this.keys.add(e.key.toLowerCase())
    if (e.key === 'e' || e.key === 'E' || e.key === ' ') this.interact()
    if (e.key === '1') this.setRole('pilot')
    if (e.key === '2') this.setRole('cabin')
  }
  private onKeyUp = (e: KeyboardEvent) => {
    this.keys.delete(e.key.toLowerCase())
  }

  private pickInteract(): { kind: InteractKind; ref: SimPassenger | SimCargo | SimHazard } | null {
    const origin = new THREE.Vector3()
    this.camera.getWorldPosition(origin)
    const dir = new THREE.Vector3()
    this.camera.getWorldDirection(dir)
    let bestDist = Infinity
    let best: { kind: InteractKind; ref: SimPassenger | SimCargo | SimHazard } | null = null

    const consider = (kind: InteractKind, ref: SimPassenger | SimCargo | SimHazard, pos: THREE.Vector3) => {
      const to = pos.clone().sub(origin)
      const dist = to.length()
      if (dist > 2.4 || dist >= bestDist) return
      to.normalize()
      if (to.dot(dir) < 0.55) return
      bestDist = dist
      best = { kind, ref }
    }

    for (const p of this.passengers) {
      consider('passenger', p, p.mesh.getWorldPosition(new THREE.Vector3()).add(new THREE.Vector3(0, 0.4, 0)))
    }
    for (const c of this.cargo) consider('cargo', c, c.mesh.getWorldPosition(new THREE.Vector3()))
    for (const h of this.hazards) consider('hazard', h, h.mesh.getWorldPosition(new THREE.Vector3()))
    return best
  }

  private tick = () => {
    this.raf = requestAnimationFrame(this.tick)
    const dt = Math.min(0.033, this.clock.getDelta())
    if (this.finished) {
      this.renderer.render(this.scene, this.camera)
      return
    }

    this.updateKeyboardMove()
    this.updateFlight(dt)
    this.updatePlayer(dt)
    this.updateCabinChaos(dt)
    this.world.step(1 / 60, dt, 3)
    this.syncMeshes()
    this.updateCamera()
    this.updatePrompt()
    this.emitHud()

    // Visual turbulence shake of cabin lights
    for (const l of this.cabinLights) {
      l.intensity = 0.4 + Math.random() * this.turbulence * 0.5
    }
    this.sky.rotation.y += dt * 0.01
    this.renderer.render(this.scene, this.camera)

    if (this.integrity <= 0 || this.altitude < 350) this.finish(false, true)
    else if (this.timeLeft <= 0) {
      const ok =
        this.altitude > 1600 &&
        Math.abs(this.pitch) < 16 &&
        Math.abs(this.roll) < 20 &&
        this.integrity > 28
      this.finish(ok, !ok)
    }
  }

  private updateKeyboardMove() {
    let x = this.move.x
    let y = this.move.y
    if (this.keys.has('a') || this.keys.has('arrowleft')) x -= 1
    if (this.keys.has('d') || this.keys.has('arrowright')) x += 1
    if (this.keys.has('w') || this.keys.has('arrowup')) y += 1
    if (this.keys.has('s') || this.keys.has('arrowdown')) y -= 1
    x = clamp(x, -1, 1)
    y = clamp(y, -1, 1)
    if (this.role === 'pilot') {
      this.stick.x = x || this.stick.x * 0.9
      this.stick.y = y || this.stick.y * 0.9
      if (!x && !y && !this.keys.size) {
        // keep virtual stick if set via UI
      }
    } else {
      this.move.x = x
      this.move.y = y
    }
  }

  private updateFlight(dt: number) {
    this.timeLeft = Math.max(0, this.timeLeft - dt)
    this.warningTimer = Math.max(0, this.warningTimer - dt)
    this.eventTimer -= dt

    const inputX = this.role === 'pilot' ? this.stick.x : Math.sin(performance.now() / 1200) * 0.12
    const inputY = this.role === 'pilot' ? this.stick.y : Math.cos(performance.now() / 1400) * 0.08

    this.roll = clamp(this.roll + inputX * 50 * dt + rand(-1, 1) * this.turbulence * 26 * dt, -40, 40)
    this.pitch = clamp(this.pitch + inputY * 42 * dt + rand(-1, 1) * this.turbulence * 20 * dt, -28, 28)

    if (this.role !== 'pilot') {
      this.roll *= 1 - 0.45 * dt
      this.pitch *= 1 - 0.4 * dt
    } else if (Math.abs(this.stick.x) < 0.05 && Math.abs(this.stick.y) < 0.05) {
      this.roll *= 1 - 0.25 * dt
      this.pitch *= 1 - 0.22 * dt
    }

    this.altitude += (-this.pitch * 17 - Math.abs(this.roll) * 3.5) * dt
    this.altitude = clamp(this.altitude, 200, 9800)
    this.speed = clamp(430 - this.pitch * 2 - this.chaos * 18, 260, 540)
    this.fuel = Math.max(0, this.fuel - dt * 0.5)

    const t = 1 - this.timeLeft / FLIGHT_SECONDS
    this.turbulence = clamp(
      0.1 + this.chaos * 0.55 + Math.sin(t * Math.PI * 3.2) * 0.2 + (t > 0.72 ? 0.18 : 0),
      0.08,
      1,
    )

    // Apply cabin "gravity tilt"
    const gx = Math.sin((this.roll * Math.PI) / 180) * 9.2 + rand(-1, 1) * this.turbulence * 3
    const gz = Math.sin((this.pitch * Math.PI) / 180) * 8.5 + rand(-1, 1) * this.turbulence * 2.5
    const gy = -9.8 + Math.cos((this.roll * Math.PI) / 180) * 0.2
    this.world.gravity.set(gx, gy, gz)

    const stress = (Math.abs(this.roll) + Math.abs(this.pitch)) / 48 + this.turbulence
    if (stress > 0.9) this.integrity -= (stress - 0.9) * 16 * dt

    if (this.eventTimer <= 0) this.spawnEvent()
  }

  private spawnEvent() {
    this.eventTimer = rand(4, 7.5) * (1.2 - this.chaos * 0.35)
    const roll = Math.random()
    if (roll < 0.34) {
      this.pushWarn(['Повітряна яма!', 'Сильна турбулентність!', 'Тримай ніс!'][Math.floor(Math.random() * 3)]!)
      this.turbulence = clamp(this.turbulence + 0.28, 0, 1)
      this.pitch += rand(-12, 12)
      this.roll += rand(-16, 16)
      // Wake passengers/cargo
      for (const p of this.passengers) {
        if (Math.random() < this.chaos) {
          p.body.wakeUp()
          p.body.velocity.x += rand(-2, 2)
        }
      }
      for (const c of this.cargo) {
        if (!c.secured && Math.random() < c.volatility + 0.2) {
          c.body.wakeUp()
          c.body.velocity.x += rand(-3, 3)
          c.body.velocity.z += rand(-2, 2)
        }
      }
    } else if (roll < 0.7) {
      const p = this.passengers[Math.floor(Math.random() * this.passengers.length)]
      if (p) {
        p.needsService = true
        p.marker.visible = true
        p.mood -= 0.12
        this.pushWarn(`${p.name} кличе бортпровідника!`)
      }
    } else if (roll < 0.88) {
      const c = this.cargo.find((x) => x.secured)
      if (c && Math.random() < this.chaos) {
        c.secured = false
        c.body.type = CANNON.Body.DYNAMIC
        c.body.mass = 25
        c.body.updateMassProperties()
        c.body.wakeUp()
        c.marker.visible = true
        this.pushWarn(`${c.name} зірвався з кріплень!`)
      } else {
        this.spawnHazard()
      }
    } else {
      this.spawnHazard()
    }
  }

  private spawnHazard() {
    const mesh = new THREE.Mesh(
      new THREE.BoxGeometry(0.28, 0.2, 0.35),
      this.mat(['#f0c75e', '#ff8f6b', '#d9e2ec'][Math.floor(Math.random() * 3)]!),
    )
    const x = rand(-0.4, 0.4)
    const z = rand(-2, 6)
    mesh.position.set(x, 1.8, z)
    mesh.castShadow = true
    this.planeRoot.add(mesh)
    const body = new CANNON.Body({
      mass: 8,
      shape: new CANNON.Box(new CANNON.Vec3(0.14, 0.1, 0.175)),
      position: new CANNON.Vec3(x, 1.8, z),
    })
    body.velocity.set(rand(-1, 1), 0, rand(-1, 1))
    this.world.addBody(body)
    const id = `hz-${Math.random().toString(36).slice(2, 7)}`
    this.hazards.push({ id, mesh, body })
    this.pushWarn('У проході летить мотлох!')
  }

  private updatePlayer(dt: number) {
    if (this.role !== 'cabin') return
    // look from UI drag deltas
    this.playerYaw -= this.look.x * dt * 2.2
    this.playerPitch = clamp(this.playerPitch - this.look.y * dt * 1.8, -1.1, 1.1)
    this.look.x *= 1 - 8 * dt
    this.look.y *= 1 - 8 * dt

    const speed = 3.1
    const forward = new THREE.Vector3(Math.sin(this.playerYaw), 0, Math.cos(this.playerYaw))
    const right = new THREE.Vector3(Math.cos(this.playerYaw), 0, -Math.sin(this.playerYaw))
    const wish = forward.multiplyScalar(this.move.y).add(right.multiplyScalar(this.move.x))
    if (wish.lengthSq() > 0) wish.normalize()
    this.playerPos.addScaledVector(wish, speed * dt)
    this.playerPos.x = clamp(this.playerPos.x, -1.05, 1.05)
    this.playerPos.z = clamp(this.playerPos.z, -5.4, 9.6)
    this.playerPos.y = 1.55
  }

  private updateCabinChaos(dt: number) {
    for (const p of this.passengers) {
      if (p.needsService) p.mood -= dt * 0.05
      if (this.turbulence > 0.7) p.mood -= dt * 0.04
      p.mood = clamp(p.mood, 0, 1)
      if (p.mood < 0.22) {
        this.reputation -= 5 * dt
        if (this.warningTimer <= 0) this.pushWarn(`${p.name} у паніці!`)
      }
      // Keep seated unless turbulence wakes them hard
      if (p.body.sleepState === CANNON.Body.SLEEPING || this.turbulence < 0.55) {
        p.body.position.x = THREE.MathUtils.damp(p.body.position.x, p.seat.x, 2, dt)
        p.body.position.z = THREE.MathUtils.damp(p.body.position.z, p.seat.z, 2, dt)
        p.body.position.y = Math.max(p.body.position.y, 0.9)
      }
      if (Math.random() < dt * (0.05 + this.chaos * 0.08)) {
        p.needsService = true
        p.marker.visible = true
      }
    }

    for (const c of this.cargo) {
      if (!c.secured) {
        this.integrity -= 2.2 * dt * (0.4 + this.turbulence)
        if (c.body.velocity.length() > 2.5) this.integrity -= 4 * dt
      }
    }

    // Auto weak help if stuck in pilot
    if (this.role === 'pilot' && Math.random() < dt * 0.2) {
      const needy = this.passengers.find((p) => p.needsService)
      if (needy && Math.random() > this.chaos) {
        needy.needsService = false
        needy.marker.visible = false
        needy.mood = clamp(needy.mood + 0.08, 0, 1)
      }
    }
  }

  private syncMeshes() {
    for (const p of this.passengers) {
      p.mesh.position.set(p.body.position.x, p.body.position.y, p.body.position.z)
      p.mesh.quaternion.set(p.body.quaternion.x, p.body.quaternion.y, p.body.quaternion.z, p.body.quaternion.w)
      p.marker.visible = p.needsService
      const pulse = 1 + Math.sin(performance.now() / 120) * 0.15
      p.marker.scale.setScalar(pulse)
    }
    for (const c of this.cargo) {
      c.mesh.position.set(c.body.position.x, c.body.position.y, c.body.position.z)
      c.mesh.quaternion.set(c.body.quaternion.x, c.body.quaternion.y, c.body.quaternion.z, c.body.quaternion.w)
      c.marker.visible = !c.secured
    }
    for (const h of this.hazards) {
      h.mesh.position.set(h.body.position.x, h.body.position.y, h.body.position.z)
      h.mesh.quaternion.set(h.body.quaternion.x, h.body.quaternion.y, h.body.quaternion.z, h.body.quaternion.w)
      if (h.body.position.y < 0.15) this.integrity -= 0.02
    }
    this.cartMesh.position.set(this.cartBody.position.x, this.cartBody.position.y, this.cartBody.position.z)
    this.cartMesh.quaternion.set(
      this.cartBody.quaternion.x,
      this.cartBody.quaternion.y,
      this.cartBody.quaternion.z,
      this.cartBody.quaternion.w,
    )
  }

  private updateCamera() {
    const shake = this.turbulence * 0.04
    const sx = (Math.random() - 0.5) * shake
    const sy = (Math.random() - 0.5) * shake
    if (this.role === 'pilot') {
      this.camera.position.set(sx, 1.35 + sy, -6.55)
      this.camera.rotation.order = 'YXZ'
      this.camera.rotation.set(
        this.playerPitch - 0.05 + this.pitch * 0.002,
        this.playerYaw,
        (-this.roll * Math.PI) / 180 * 0.25,
      )
    } else {
      this.camera.position.set(this.playerPos.x + sx, this.playerPos.y + sy, this.playerPos.z)
      this.camera.rotation.order = 'YXZ'
      this.camera.rotation.set(
        this.playerPitch,
        this.playerYaw,
        (-this.roll * Math.PI) / 180 * 0.12,
      )
    }
  }

  private updatePrompt() {
    if (this.role === 'pilot') {
      this.prompt = 'Пілот: стік ліворуч. Тримайте горизонт.'
      return
    }
    const t = this.pickInteract()
    if (!t) {
      this.prompt = 'Салон: ходи джойстиком, дивись свайпом, [Дія] поруч з !'
      return
    }
    if (t.kind === 'passenger') {
      const p = t.ref as SimPassenger
      this.prompt = p.needsService ? `Подати сервіс: ${p.name}` : `Заспокоїти: ${p.name}`
    } else if (t.kind === 'cargo') {
      const c = t.ref as SimCargo
      this.prompt = c.secured ? `${c.name} закріплено` : `Закріпити: ${c.name}`
    } else {
      this.prompt = 'Прибрати перешкоду'
    }
  }

  private emitHud() {
    this.onHud?.({
      altitude: this.altitude,
      speed: this.speed,
      fuel: this.fuel,
      integrity: this.integrity,
      reputation: this.reputation,
      cash: this.cash,
      timeLeft: this.timeLeft,
      duration: FLIGHT_SECONDS,
      turbulence: this.turbulence,
      pitch: this.pitch,
      roll: this.roll,
      role: this.role,
      warning: this.warningTimer > 0 ? this.warning : this.warning,
      prompt: this.prompt,
    })
  }

  private finish(landed: boolean, crashed: boolean) {
    if (this.finished) return
    this.finished = true
    const base =
      this.loadout.passengers.reduce((s, p) => s + p.payout, 0) +
      this.loadout.cargo.reduce((s, c) => s + c.payout, 0)
    let cash = this.cash
    if (landed) cash += Math.round(base * (0.6 + this.reputation / 220))
    if (crashed) cash = Math.round(cash * 0.12)

    const score =
      (landed ? 42 : 0) +
      this.integrity * 0.24 +
      this.reputation * 0.2 +
      this.served * 4 +
      this.securedCount * 5

    const grade =
      score > 92 ? 'S' : score > 78 ? 'A' : score > 62 ? 'B' : score > 42 ? 'C' : crashed ? 'F' : 'D'

    this.result = {
      landed,
      crashed,
      cash: Math.max(0, cash),
      reputation: Math.round(clamp(this.reputation, 0, 100)),
      integrity: Math.round(clamp(this.integrity, 0, 100)),
      served: this.served,
      secured: this.securedCount,
      grade,
      summary: crashed
        ? 'Борт не долетів. Страховка в сльозах, пасажири в мемах.'
        : landed
          ? 'Посадка зарахована. Turbulence Inc. пишається… умовно.'
          : 'Долетіли на чесному слові й ізострічці.',
    }
    this.onDone?.(this.result)
  }
}
