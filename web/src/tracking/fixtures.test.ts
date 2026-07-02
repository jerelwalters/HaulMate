import { describe, expect, it } from 'vitest'

import { trackingResponseFixtures } from './fixtures'
import { listForbiddenPublicFieldPaths } from './publicFieldPolicy'
import type { TrackingResponse } from './types'

describe('tracking API contract fixtures', () => {
  it('provides representative tracking states', () => {
    const fixtures = Object.values(
      trackingResponseFixtures,
    ) satisfies TrackingResponse[]

    expect(fixtures).toHaveLength(4)
    expect(trackingResponseFixtures.activeLoad.freshness.status).toBe('current')
    expect(trackingResponseFixtures.delayedLoad.latestDelay?.reason).toBe(
      'Waiting for dock assignment.',
    )
    expect(trackingResponseFixtures.deliveredLoad.pod.available).toBe(true)
    expect(trackingResponseFixtures.offlineNoUpdateLoad.freshness.status).toBe(
      'offline_no_update',
    )
  })

  it('exposes only approved public fields', () => {
    for (const [name, fixture] of Object.entries(trackingResponseFixtures)) {
      expect(listForbiddenPublicFieldPaths(fixture), name).toEqual([])
    }
  })

  it('flags private tracking fields before they reach the page contract', () => {
    expect(
      listForbiddenPublicFieldPaths({
        load: {
          referenceNumber: 'NSF-2048',
          rate: 1800,
        },
        coordinates: {
          latitude: 42.3314,
          longitude: -83.0458,
        },
        shareToken: 'do-not-render',
      }),
    ).toEqual([
      '$.load.rate',
      '$.coordinates',
      '$.coordinates.latitude',
      '$.coordinates.longitude',
      '$.shareToken',
    ])
  })
})
