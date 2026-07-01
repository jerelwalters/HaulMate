import { renderTrackingPage } from './renderTrackingPage'
import { renderTrackingState } from './renderTrackingState'
import { readShareTokenFromUrl } from './shareToken'
import {
  TrackingClientError,
  fetchTrackingResponse,
  readTrackingClientConfig,
} from './trackingClient'

export interface MountTrackingAppOptions {
  env: ImportMetaEnv
  fetcher: typeof fetch
  location: Location
  root: HTMLElement
}

export function mountTrackingApp(options: MountTrackingAppOptions) {
  void loadTrackingPage(options)
}

async function loadTrackingPage(options: MountTrackingAppOptions) {
  const url = new URL(options.location.href)
  const tokenResult = readShareTokenFromUrl(url)

  if (tokenResult.kind === 'missing') {
    options.root.innerHTML = renderTrackingState('missing-token')
    return
  }

  const config = readTrackingClientConfig(options.env)

  if (!config) {
    options.root.innerHTML = renderTrackingState('unavailable')
    return
  }

  options.root.innerHTML = renderTrackingState('loading')

  try {
    const tracking = await fetchTrackingResponse({
      config,
      fetcher: options.fetcher,
      shareToken: tokenResult.token,
    })

    options.root.innerHTML = renderTrackingPage(tracking)
  } catch (error) {
    options.root.innerHTML = renderTrackingState(
      error instanceof TrackingClientError && error.kind === 'access_denied'
        ? 'missing-token'
        : 'unavailable',
      { canRetry: true },
    )
    options.root
      .querySelector('[data-action="retry-tracking"]')
      ?.addEventListener('click', () => {
        void loadTrackingPage(options)
      })
  }
}
