const forbiddenPublicFieldPatterns = [
  /(^|\.)(lat|latitude|lng|longitude|coordinates?|accuracy)$/i,
  /(^|\.)(street|streetAddress|addressLine|postalCode|zipCode)$/i,
  /rate|profit|expense|cost|price|amount|financial/i,
  /invoice|payment|receivable/i,
  /privateDocument|documentUrl|signedUrl|storagePath/i,
  /token|tokenHash|auth|session|credential/i,
  /otherLoads|accountId|userId|driverId|vehicleId/i,
]

export function listForbiddenPublicFieldPaths(value: unknown): string[] {
  return collectForbiddenPaths(value, '$')
}

function collectForbiddenPaths(value: unknown, path: string): string[] {
  if (Array.isArray(value)) {
    return value.flatMap((item, index) =>
      collectForbiddenPaths(item, `${path}[${index}]`),
    )
  }

  if (!isRecord(value)) {
    return []
  }

  return Object.entries(value).flatMap(([key, child]) => {
    const nextPath = `${path}.${key}`
    const keyViolations = isForbiddenPublicFieldPath(nextPath) ? [nextPath] : []

    return [...keyViolations, ...collectForbiddenPaths(child, nextPath)]
  })
}

function isForbiddenPublicFieldPath(path: string) {
  return forbiddenPublicFieldPatterns.some((pattern) => pattern.test(path))
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null
}
