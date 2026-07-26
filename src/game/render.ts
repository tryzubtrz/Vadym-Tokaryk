import type { FlightEngine } from './FlightEngine'

export function drawFlight(ctx: CanvasRenderingContext2D, engine: FlightEngine, now: number) {
  const { width: w, height: h, stats, entities, role, stick } = engine
  ctx.clearRect(0, 0, w, h)

  // Sky atmosphere
  const sky = ctx.createLinearGradient(0, 0, 0, h)
  sky.addColorStop(0, '#081820')
  sky.addColorStop(0.45, '#123247')
  sky.addColorStop(1, '#1b4338')
  ctx.fillStyle = sky
  ctx.fillRect(0, 0, w, h)

  // Stars / clouds
  ctx.globalAlpha = 0.35
  for (let i = 0; i < 28; i++) {
    const x = ((i * 73 + now * 0.01 * (i % 5)) % w)
    const y = (i * 47) % (h * 0.45)
    ctx.fillStyle = i % 3 === 0 ? '#f0c75e' : '#d7e8ef'
    ctx.beginPath()
    ctx.arc(x, y, i % 4 === 0 ? 1.8 : 1.1, 0, Math.PI * 2)
    ctx.fill()
  }
  ctx.globalAlpha = 1

  // Horizon influenced by pitch/roll
  ctx.save()
  ctx.translate(w / 2, h * 0.34)
  ctx.rotate((stats.roll * Math.PI) / 180)
  const horizonY = stats.pitch * 2.4
  const ground = ctx.createLinearGradient(0, horizonY, 0, h)
  ground.addColorStop(0, '#2d6a4f')
  ground.addColorStop(1, '#081c15')
  ctx.fillStyle = ground
  ctx.fillRect(-w, horizonY, w * 2, h)
  ctx.fillStyle = 'rgba(240,199,94,0.35)'
  ctx.fillRect(-w, horizonY - 2, w * 2, 4)
  ctx.restore()

  // Cabin fuselage
  roundRect(ctx, 28, 150, w - 56, h - 190, 28)
  const cabinGrad = ctx.createLinearGradient(0, 150, 0, h)
  cabinGrad.addColorStop(0, '#243b4a')
  cabinGrad.addColorStop(1, '#152530')
  ctx.fillStyle = cabinGrad
  ctx.fill()
  ctx.strokeStyle = 'rgba(126,200,195,0.35)'
  ctx.lineWidth = 2
  ctx.stroke()

  // Windows
  for (let i = 0; i < 6; i++) {
    const x = 48
    const y = 190 + i * 78
    roundRect(ctx, x, y, 22, 40, 8)
    ctx.fillStyle = `rgba(126,200,195,${0.25 + Math.sin(now / 400 + i) * 0.08})`
    ctx.fill()
    roundRect(ctx, w - 70, y, 22, 40, 8)
    ctx.fill()
  }

  // Aisle
  ctx.fillStyle = 'rgba(255,255,255,0.04)'
  ctx.fillRect(w / 2 - 18, 170, 36, h - 220)

  // Entities
  for (const e of entities) {
    ctx.save()
    ctx.translate(e.x, e.y)
    if (e.kind === 'passenger') {
      ctx.beginPath()
      ctx.arc(0, 0, e.radius, 0, Math.PI * 2)
      ctx.fillStyle = e.color
      ctx.fill()
      ctx.fillStyle = '#0b1f2a'
      ctx.font = '700 12px Figtree, sans-serif'
      ctx.textAlign = 'center'
      ctx.fillText(e.label.slice(0, 6), 0, 4)
      if (e.needsService) {
        pulseBadge(ctx, 16, -22, '!', '#ff6b4a', now)
      }
      // mood bar
      ctx.fillStyle = 'rgba(0,0,0,0.35)'
      ctx.fillRect(-20, 30, 40, 5)
      ctx.fillStyle = e.mood > 0.45 ? '#7ec8c3' : '#ff6b4a'
      ctx.fillRect(-20, 30, 40 * e.mood, 5)
    } else if (e.kind === 'cargo') {
      roundRect(ctx, -e.radius, -e.radius * 0.75, e.radius * 2, e.radius * 1.5, 8)
      ctx.fillStyle = e.color
      ctx.fill()
      ctx.strokeStyle = e.secured ? '#7ec8c3' : '#ff6b4a'
      ctx.lineWidth = 3
      ctx.stroke()
      ctx.fillStyle = '#0b1f2a'
      ctx.font = '700 11px Figtree, sans-serif'
      ctx.textAlign = 'center'
      ctx.fillText(e.secured ? 'OK' : '!!!', 0, 4)
      if (!e.secured) pulseBadge(ctx, e.radius - 4, -e.radius, '?', '#f0c75e', now)
    } else if (e.kind === 'cart') {
      roundRect(ctx, -18, -14, 36, 28, 6)
      ctx.fillStyle = e.color
      ctx.fill()
      ctx.fillStyle = '#0b1f2a'
      ctx.font = '700 10px Figtree, sans-serif'
      ctx.textAlign = 'center'
      ctx.fillText('CART', 0, 3)
    } else {
      ctx.beginPath()
      ctx.arc(0, 0, e.radius, 0, Math.PI * 2)
      ctx.fillStyle = e.color
      ctx.fill()
      ctx.fillStyle = '#0b1f2a'
      ctx.font = '700 11px Figtree, sans-serif'
      ctx.textAlign = 'center'
      ctx.fillText(e.label.slice(0, 4), 0, 3)
    }
    ctx.restore()
  }

  // HUD top
  drawHud(ctx, engine)

  // Role helper / stick
  if (role === 'pilot') {
    drawStick(ctx, w * 0.5, h * 0.78, stick.x, stick.y)
    ctx.fillStyle = 'rgba(240,199,94,0.9)'
    ctx.font = '700 13px Figtree, sans-serif'
    ctx.textAlign = 'center'
    ctx.fillText('Пілот: тягни стік, тримай горизонт', w / 2, h - 28)
  } else {
    ctx.fillStyle = 'rgba(126,200,195,0.95)'
    ctx.font = '700 13px Figtree, sans-serif'
    ctx.textAlign = 'center'
    ctx.fillText('Салон: тапай ! пасажирів і червоний вантаж', w / 2, h - 28)
  }
}

function drawHud(ctx: CanvasRenderingContext2D, engine: FlightEngine) {
  const { width: w, stats } = engine
  roundRect(ctx, 16, 16, w - 32, 118, 18)
  ctx.fillStyle = 'rgba(7,20,28,0.82)'
  ctx.fill()
  ctx.strokeStyle = 'rgba(126,200,195,0.25)'
  ctx.stroke()

  ctx.fillStyle = '#f3f7f4'
  ctx.font = '700 15px Figtree, sans-serif'
  ctx.textAlign = 'left'
  ctx.fillText(`ALT ${Math.round(stats.altitude)} м`, 30, 42)
  ctx.fillText(`SPD ${Math.round(stats.speed)}`, 30, 64)
  ctx.fillText(`FUEL ${Math.round(stats.fuel)}%`, 30, 86)

  ctx.textAlign = 'right'
  ctx.fillStyle = '#f0c75e'
  ctx.fillText(`$ ${Math.round(stats.cashEarned)}`, w - 30, 42)
  ctx.fillStyle = stats.integrity > 40 ? '#7ec8c3' : '#ff6b4a'
  ctx.fillText(`HP ${Math.round(stats.integrity)}`, w - 30, 64)
  ctx.fillStyle = '#d7e8ef'
  ctx.fillText(`REP ${Math.round(stats.reputation)}`, w - 30, 86)

  // Timer bar
  const t = stats.timeLeft / stats.duration
  ctx.fillStyle = 'rgba(255,255,255,0.08)'
  ctx.fillRect(30, 102, w - 60, 10)
  ctx.fillStyle = '#f0c75e'
  ctx.fillRect(30, 102, (w - 60) * t, 10)

  // Turbulence
  ctx.fillStyle = 'rgba(255,107,74,0.15)'
  ctx.fillRect(30, 116, (w - 60) * stats.turbulence, 4)

  if (stats.warnings[0]) {
    ctx.fillStyle = 'rgba(240,199,94,0.95)'
    ctx.font = '600 12px Figtree, sans-serif'
    ctx.textAlign = 'center'
    ctx.fillText(stats.warnings[0], w / 2, 145)
  }
}

function drawStick(
  ctx: CanvasRenderingContext2D,
  cx: number,
  cy: number,
  x: number,
  y: number,
) {
  ctx.beginPath()
  ctx.arc(cx, cy, 54, 0, Math.PI * 2)
  ctx.fillStyle = 'rgba(7,20,28,0.55)'
  ctx.fill()
  ctx.strokeStyle = 'rgba(126,200,195,0.4)'
  ctx.lineWidth = 2
  ctx.stroke()
  ctx.beginPath()
  ctx.arc(cx + x * 34, cy + y * 34, 22, 0, Math.PI * 2)
  ctx.fillStyle = '#f0c75e'
  ctx.fill()
}

function pulseBadge(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  text: string,
  color: string,
  now: number,
) {
  const s = 1 + Math.sin(now / 120) * 0.12
  ctx.save()
  ctx.translate(x, y)
  ctx.scale(s, s)
  ctx.beginPath()
  ctx.arc(0, 0, 12, 0, Math.PI * 2)
  ctx.fillStyle = color
  ctx.fill()
  ctx.fillStyle = '#0b1f2a'
  ctx.font = '800 12px Figtree, sans-serif'
  ctx.textAlign = 'center'
  ctx.textBaseline = 'middle'
  ctx.fillText(text, 0, 1)
  ctx.restore()
}

function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  w: number,
  h: number,
  r: number,
) {
  const rr = Math.min(r, w / 2, h / 2)
  ctx.beginPath()
  ctx.moveTo(x + rr, y)
  ctx.arcTo(x + w, y, x + w, y + h, rr)
  ctx.arcTo(x + w, y + h, x, y + h, rr)
  ctx.arcTo(x, y + h, x, y, rr)
  ctx.arcTo(x, y, x + w, y, rr)
  ctx.closePath()
}
