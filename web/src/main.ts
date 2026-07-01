import { mountTrackingApp } from './tracking/mountTrackingApp'
import './style.css'

const app = document.querySelector<HTMLDivElement>('#app')

if (!app) {
  throw new Error('App root not found')
}

mountTrackingApp({
  env: import.meta.env,
  fetcher: window.fetch.bind(window),
  location: window.location,
  root: app,
})
