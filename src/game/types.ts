export type ScreenId = 'menu' | 'loadout' | 'flight' | 'results'

export type Role = 'pilot' | 'cabin'

export interface PassengerCard {
  id: string
  name: string
  payout: number
  patience: number
  hunger: number
  chaos: number
  blurb: string
}

export interface CargoCard {
  id: string
  name: string
  payout: number
  weight: number
  volatility: number
  blurb: string
}

export interface Loadout {
  passengers: PassengerCard[]
  cargo: CargoCard[]
}

export interface CabinEntity {
  id: string
  kind: 'passenger' | 'cargo' | 'cart' | 'hazard'
  label: string
  x: number
  y: number
  vx: number
  vy: number
  radius: number
  mood: number
  secured: boolean
  needsService: boolean
  color: string
}

export interface FlightStats {
  altitude: number
  pitch: number
  roll: number
  speed: number
  fuel: number
  integrity: number
  reputation: number
  cashEarned: number
  timeLeft: number
  duration: number
  turbulence: number
  warnings: string[]
}

export interface FlightResult {
  landed: boolean
  crashed: boolean
  cash: number
  reputation: number
  integrity: number
  served: number
  secured: number
  grade: string
  summary: string
}

export interface TouchState {
  active: boolean
  x: number
  y: number
  startX: number
  startY: number
  id: number | null
}
