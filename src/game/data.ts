import type { CargoCard, PassengerCard } from './types'

export const PASSENGERS: PassengerCard[] = [
  {
    id: 'grandma',
    name: 'Бабуся Оля',
    payout: 80,
    patience: 0.85,
    hunger: 0.4,
    chaos: 0.15,
    blurb: 'Тиха, але чай має бути гарячим.',
  },
  {
    id: 'influencer',
    name: 'Інфлюенсер',
    payout: 140,
    patience: 0.35,
    hunger: 0.7,
    chaos: 0.55,
    blurb: 'Знімає Stories під час турбулентності.',
  },
  {
    id: 'business',
    name: 'Бізнес-клас?',
    payout: 160,
    patience: 0.25,
    hunger: 0.55,
    chaos: 0.4,
    blurb: 'Купив економ, вимагає шампанське.',
  },
  {
    id: 'kids',
    name: 'Діти + барабан',
    payout: 110,
    patience: 0.3,
    hunger: 0.85,
    chaos: 0.75,
    blurb: 'Енергія нескінченна. Барабан теж.',
  },
  {
    id: 'sleepy',
    name: 'Сонний студент',
    payout: 70,
    patience: 0.9,
    hunger: 0.25,
    chaos: 0.1,
    blurb: 'Майже ідеальний пасажир. Майже.',
  },
  {
    id: 'karate',
    name: 'Каратист у відпустці',
    payout: 150,
    patience: 0.45,
    hunger: 0.5,
    chaos: 0.65,
    blurb: 'Розминається в проході. Сильно.',
  },
]

export const CARGO: CargoCard[] = [
  {
    id: 'mail',
    name: 'Мішки з поштою',
    payout: 90,
    weight: 0.3,
    volatility: 0.1,
    blurb: 'Нудно, але стабільно.',
  },
  {
    id: 'fish',
    name: 'Жива риба',
    payout: 170,
    weight: 0.45,
    volatility: 0.55,
    blurb: 'Акваріум любить турбулентність.',
  },
  {
    id: 'piano',
    name: 'Рояль «трохи»',
    payout: 220,
    weight: 0.85,
    volatility: 0.5,
    blurb: 'Важкий. І скрипить пісню смерті.',
  },
  {
    id: 'bees',
    name: 'Вулики',
    payout: 200,
    weight: 0.4,
    volatility: 0.8,
    blurb: 'Не відкривай. Серйозно.',
  },
  {
    id: 'cake',
    name: 'Весільний торт',
    payout: 130,
    weight: 0.35,
    volatility: 0.6,
    blurb: 'Один крен — і кінець романтики.',
  },
  {
    id: 'mystery',
    name: '«Не питайте»',
    payout: 280,
    weight: 0.55,
    volatility: 0.95,
    blurb: 'Максимальний кеш. Мінімум пояснень.',
  },
]

export const ROUTES = [
  { id: 'kyiv-odesa', name: 'Київ → Одеса', minutes: 90, difficulty: 0.45 },
  { id: 'lviv-kharkiv', name: 'Львів → Харків', minutes: 100, difficulty: 0.6 },
  { id: 'night-hop', name: 'Нічний хоп', minutes: 75, difficulty: 0.75 },
]

export const MAX_PASSENGERS = 3
export const MAX_CARGO = 2
export const FLIGHT_SECONDS = 78
