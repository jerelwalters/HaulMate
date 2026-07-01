import { trackingResponseFixtures } from './tracking/fixtures'
import { renderTrackingPage } from './tracking/renderTrackingPage'

export function renderScaffold() {
  return renderTrackingPage(trackingResponseFixtures.activeLoad)
}
