export type ShareTokenResult =
  | { kind: 'found'; token: string }
  | { kind: 'missing' }

const tokenQueryKeys = ['token', 'share', 'shareToken']

export function readShareTokenFromUrl(url: URL): ShareTokenResult {
  for (const key of tokenQueryKeys) {
    const token = normalizeToken(url.searchParams.get(key))

    if (token) {
      return { kind: 'found', token }
    }
  }

  const pathToken = normalizeToken(readPathToken(url.pathname))

  if (pathToken) {
    return { kind: 'found', token: pathToken }
  }

  return { kind: 'missing' }
}

function readPathToken(pathname: string) {
  const parts = pathname.split('/').filter(Boolean)
  const trackingIndex = parts.findIndex((part) => part === 'track')

  if (trackingIndex < 0) {
    return null
  }

  return parts[trackingIndex + 1] ?? null
}

function normalizeToken(value: string | null) {
  const token = value?.trim()

  return token && token.length > 0 ? token : null
}
