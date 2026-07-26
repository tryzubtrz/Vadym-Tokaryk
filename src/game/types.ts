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
  color: string
}

export interface CargoCard {
  id: string
  name: string
  payout: number
  weight: number
  volatility: number
  blurb: string
  color: string
}

export interface Loadout {
  passengers: PassengerCard[]
  cargo: CargoCard[]
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

export interface HudState {
  altitude: number
  speed: number
  fuel: number
  integrity: number
  reputation: number
  cash: number
  timeLeft: number
  duration: number
  turbulence: number
  pitch: number
  roll: number
  role: Role
  warning: string
  prompt: string
}
