import { describe, expect, it, vi } from 'vitest'

import { trackingResponseFixtures } from './fixtures'
import { mountTrackingApp } from './mountTrackingApp'

class TestRetryButton {
  private listener: (() => void) | null = null

  addEventListener(_type: string, listener: () => void) {
    this.listener = listener
  }

  click() {
    this.listener?.()
  }
}

class TestRoot {
  innerHTML = ''

  private retryButton = new TestRetryButton()

  querySelector(selector: string) {
    if (
      selector === '[data-action="retry-tracking"]' &&
      this.innerHTML.includes('data-action="retry-tracking"')
    ) {
      return this.retryButton
    }

    return null
  }
}

function makeRoot() {
  return new TestRoot() as unknown as HTMLElement
}

function makeEnv(
  overrides: Partial<Record<string, string>> = {},
): ImportMetaEnv {
  return {
    BASE_URL: '/',
    DEV: true,
    MODE: 'test',
    PROD: false,
    SSR: false,
    ...overrides,
  } as ImportMetaEnv
}

function makeLocation(url: string) {
  return new URL(url) as unknown as Location
}

describe('mountTrackingApp', () => {
  it('renders tracking data returned by the configured function', async () => {
    const root = makeRoot()
    const fetcher = vi.fn(async () =>
      Response.json(trackingResponseFixtures.delayedLoad),
    )

    mountTrackingApp({
      env: makeEnv({
        VITE_HAULMATE_TRACKING_FUNCTION_URL:
          'https://example.supabase.co/functions/v1/public-tracking',
      }),
      fetcher,
      location: makeLocation('https://tracking.example/track/link-token'),
      root,
    })

    await vi.waitFor(() => {
      expect(root.innerHTML).toContain('Load NSF-2051')
    })
    expect(root.innerHTML).toContain('Waiting for dock assignment.')
    expect(fetcher).toHaveBeenCalledOnce()
  })

  it('renders a secure missing-link state when no share token is present', async () => {
    const root = makeRoot()
    const fetcher = vi.fn()

    mountTrackingApp({
      env: makeEnv({
        VITE_HAULMATE_TRACKING_FUNCTION_URL:
          'https://example.supabase.co/functions/v1/public-tracking',
      }),
      fetcher,
      location: makeLocation('https://tracking.example/'),
      root,
    })

    expect(root.innerHTML).toContain('Tracking link unavailable')
    expect(fetcher).not.toHaveBeenCalled()
  })

  it('renders a retry state without logging private response details', async () => {
    const root = makeRoot()
    const fetcher = vi
      .fn()
      .mockResolvedValueOnce(new Response(null, { status: 500 }))
      .mockResolvedValueOnce(Response.json(trackingResponseFixtures.activeLoad))

    mountTrackingApp({
      env: makeEnv({
        VITE_HAULMATE_TRACKING_FUNCTION_URL:
          'https://example.supabase.co/functions/v1/public-tracking',
      }),
      fetcher,
      location: makeLocation('https://tracking.example/?token=retry-token'),
      root,
    })

    await vi.waitFor(() => {
      expect(root.innerHTML).toContain('Tracking temporarily unavailable')
    })

    root.querySelector<HTMLButtonElement>('[data-action="retry-tracking"]')?.click()

    await vi.waitFor(() => {
      expect(root.innerHTML).toContain('Load NSF-2048')
    })
    expect(fetcher).toHaveBeenCalledTimes(2)
  })
})
