import type { TrackingResponse } from './types'

export interface TrackingClientConfig {
  functionUrl: string
}

export type TrackingClientErrorKind =
  | 'access_denied'
  | 'network'
  | 'unexpected_response'

export class TrackingClientError extends Error {
  readonly kind: TrackingClientErrorKind

  constructor(kind: TrackingClientErrorKind, message: string) {
    super(message)
    this.name = 'TrackingClientError'
    this.kind = kind
  }
}

export interface FetchTrackingResponseOptions {
  config: TrackingClientConfig
  fetcher: typeof fetch
  shareToken: string
}

export async function fetchTrackingResponse({
  config,
  fetcher,
  shareToken,
}: FetchTrackingResponseOptions): Promise<TrackingResponse> {
  const requestUrl = new URL(config.functionUrl)
  requestUrl.searchParams.set('token', shareToken)

  let response: Response

  try {
    response = await fetcher(requestUrl, {
      cache: 'no-store',
      headers: {
        Accept: 'application/json',
      },
      method: 'GET',
    })
  } catch {
    throw new TrackingClientError(
      'network',
      'Tracking updates are temporarily unavailable.',
    )
  }

  if (response.status === 401 || response.status === 403 || response.status === 404) {
    throw new TrackingClientError(
      'access_denied',
      'This tracking link is unavailable.',
    )
  }

  if (!response.ok) {
    throw new TrackingClientError(
      'network',
      'Tracking updates are temporarily unavailable.',
    )
  }

  try {
    return (await response.json()) as TrackingResponse
  } catch {
    throw new TrackingClientError(
      'unexpected_response',
      'Tracking updates could not be read.',
    )
  }
}

export function readTrackingClientConfig(env: ImportMetaEnv): TrackingClientConfig | null {
  const functionUrl = env.VITE_HAULMATE_TRACKING_FUNCTION_URL?.trim()

  return functionUrl ? { functionUrl } : null
}
