import { describe, expect, it, vi } from 'vitest'

import { trackingResponseFixtures } from './fixtures'
import {
  TrackingClientError,
  fetchTrackingResponse,
  readTrackingClientConfig,
} from './trackingClient'

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

describe('fetchTrackingResponse', () => {
  it('calls the configured Edge Function with a token query parameter', async () => {
    let requestCount = 0
    let requestedUrl: RequestInfo | URL | null = null
    let requestedInit: RequestInit | undefined
    const fetcher: typeof fetch = async (input, init) => {
      requestCount += 1
      requestedUrl = input
      requestedInit = init

      return Response.json(trackingResponseFixtures.activeLoad)
    }

    const response = await fetchTrackingResponse({
      config: {
        functionUrl: 'https://example.supabase.co/functions/v1/public-tracking',
      },
      fetcher,
      shareToken: 'share-token-123',
    })

    expect(response.load.referenceNumber).toBe('NSF-2048')
    expect(requestCount).toBe(1)

    expect(requestedUrl).toBeInstanceOf(URL)
    expect(String(requestedUrl)).toBe(
      'https://example.supabase.co/functions/v1/public-tracking?token=share-token-123',
    )
    expect(requestedInit).toEqual({
      cache: 'no-store',
      credentials: 'omit',
      headers: {
        Accept: 'application/json',
      },
      method: 'GET',
      redirect: 'error',
      referrerPolicy: 'no-referrer',
    })
  })

  it.each([401, 403, 404, 410])(
    'uses a generic access-denied error for status %s',
    async (status) => {
      const fetcher = vi.fn(async () => new Response(null, { status }))

      await expect(
        fetchTrackingResponse({
          config: {
            functionUrl:
              'https://example.supabase.co/functions/v1/public-tracking',
          },
          fetcher,
          shareToken: 'expired-token',
        }),
      ).rejects.toMatchObject(
        new TrackingClientError(
          'access_denied',
          'This tracking link is unavailable.',
        ),
      )
    },
  )
})

describe('readTrackingClientConfig', () => {
  it('reads the tracking function URL from Vite env', () => {
    expect(
      readTrackingClientConfig(makeEnv({
        VITE_HAULMATE_TRACKING_FUNCTION_URL:
          'https://example.supabase.co/functions/v1/public-tracking',
      })),
    ).toEqual({
      functionUrl: 'https://example.supabase.co/functions/v1/public-tracking',
    })
  })

  it('returns null when the endpoint is not configured', () => {
    expect(readTrackingClientConfig(makeEnv())).toBeNull()
  })
})
