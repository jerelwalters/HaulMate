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

const activeLoadIds = new WeakMap<HTMLElement, number>()

export function mountTrackingApp(options: MountTrackingAppOptions) {
  void loadTrackingPage(options)
}

async function loadTrackingPage(options: MountTrackingAppOptions) {
  const loadId = beginLoad(options.root)
  const url = new URL(options.location.href)
  const tokenResult = readShareTokenFromUrl(url)

  if (tokenResult.kind === 'missing') {
    renderIfCurrent(
      options.root,
      loadId,
      renderTrackingState('unavailable-link'),
    )
    return
  }

  const config = readTrackingClientConfig(options.env)

  if (!config) {
    renderIfCurrent(
      options.root,
      loadId,
      renderTrackingState('service-unavailable'),
    )
    return
  }

  renderIfCurrent(options.root, loadId, renderTrackingState('loading'))

  try {
    const tracking = await fetchTrackingResponse({
      config,
      fetcher: options.fetcher,
      shareToken: tokenResult.token,
    })

    renderIfCurrent(options.root, loadId, renderTrackingPage(tracking))
  } catch (error) {
    if (!isCurrentLoad(options.root, loadId)) {
      return
    }

    const isAccessDenied =
      error instanceof TrackingClientError && error.kind === 'access_denied'
    const canRetry = !isAccessDenied

    renderIfCurrent(
      options.root,
      loadId,
      renderTrackingState(
        isAccessDenied ? 'unavailable-link' : 'service-unavailable',
        { canRetry },
      ),
    )

    if (canRetry) {
      options.root
        .querySelector('[data-action="retry-tracking"]')
        ?.addEventListener('click', () => {
          void loadTrackingPage(options)
        })
    }
  }
}

function beginLoad(root: HTMLElement) {
  const loadId = (activeLoadIds.get(root) ?? 0) + 1
  activeLoadIds.set(root, loadId)
  return loadId
}

function isCurrentLoad(root: HTMLElement, loadId: number) {
  return activeLoadIds.get(root) === loadId
}

function renderIfCurrent(root: HTMLElement, loadId: number, html: string) {
  if (isCurrentLoad(root, loadId)) {
    root.innerHTML = html
  }
}
