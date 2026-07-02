import { describe, expect, it } from 'vitest'

import { renderTrackingState } from './renderTrackingState'

describe('renderTrackingState', () => {
  it('labels the loading state as an update check, not live GPS', () => {
    const html = renderTrackingState('loading')

    expect(html).toContain('Loading tracking update')
    expect(html).toContain('Checking the most recent load update.')
    expect(html).not.toMatch(/continuous live GPS|real-time GPS|live location/i)
  })
})
