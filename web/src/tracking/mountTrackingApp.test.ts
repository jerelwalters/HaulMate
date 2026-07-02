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
    expect(root.innerHTML).toContain('This secure tracking link is unavailable.')
    expect(fetcher).not.toHaveBeenCalled()
  })

  it.each([401, 403, 404, 410])(
    'renders a non-retryable generic unavailable-link state for status %s',
    async (status) => {
      const root = makeRoot()
      const fetcher = vi.fn(async () => new Response(null, { status }))

      mountTrackingApp({
        env: makeEnv({
          VITE_HAULMATE_TRACKING_FUNCTION_URL:
            'https://example.supabase.co/functions/v1/public-tracking',
        }),
        fetcher,
        location: makeLocation('https://tracking.example/?token=expired-token'),
        root,
      })

      await vi.waitFor(() => {
        expect(root.innerHTML).toContain('Tracking link unavailable')
      })

      expect(root.innerHTML).toContain('This secure tracking link is unavailable.')
      expect(root.innerHTML).not.toMatch(/invalid|expired|revoked|NSF-/i)
      expect(root.innerHTML).not.toContain('data-action="retry-tracking"')
    },
  )

  it('renders a retry state for temporary service failures', async () => {
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

  it('does not let an older tracking response overwrite a newer load', async () => {
    const root = makeRoot()
    let resolveFirstLoad: (response: Response) => void = () => {}
    const firstResponse = new Promise<Response>((resolve) => {
      resolveFirstLoad = resolve
    })
    const fetcher = vi
      .fn()
      .mockReturnValueOnce(firstResponse)
      .mockResolvedValueOnce(Response.json(trackingResponseFixtures.delayedLoad))

    mountTrackingApp({
      env: makeEnv({
        VITE_HAULMATE_TRACKING_FUNCTION_URL:
          'https://example.supabase.co/functions/v1/public-tracking',
      }),
      fetcher,
      location: makeLocation('https://tracking.example/track/old-token'),
      root,
    })

    mountTrackingApp({
      env: makeEnv({
        VITE_HAULMATE_TRACKING_FUNCTION_URL:
          'https://example.supabase.co/functions/v1/public-tracking',
      }),
      fetcher,
      location: makeLocation('https://tracking.example/track/new-token'),
      root,
    })

    await vi.waitFor(() => {
      expect(root.innerHTML).toContain('Load NSF-2051')
    })

    resolveFirstLoad(Response.json(trackingResponseFixtures.activeLoad))
    await new Promise((resolve) => setTimeout(resolve, 0))

    expect(root.innerHTML).toContain('Load NSF-2051')
    expect(root.innerHTML).not.toContain('Load NSF-2048')
    expect(fetcher).toHaveBeenCalledTimes(2)
  })
})
