import './style.css'
import { App } from './game/App'
import { registerSW } from 'virtual:pwa-register'

const root = document.querySelector<HTMLElement>('#app')
if (!root) {
  throw new Error('Missing #app root')
}

new App(root)

registerSW({ immediate: true })
