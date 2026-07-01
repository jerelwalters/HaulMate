import { trackingResponseFixtures } from './tracking/fixtures'
import { renderTrackingPage } from './tracking/renderTrackingPage'
import './style.css'

const app = document.querySelector<HTMLDivElement>('#app')

if (!app) {
  throw new Error('App root not found')
}

app.innerHTML = renderTrackingPage(trackingResponseFixtures.activeLoad)
