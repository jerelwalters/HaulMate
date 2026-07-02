import { describe, expect, it } from 'vitest'

import { renderTrackingState } from './renderTrackingState'

describe('renderTrackingState', () => {
  it('labels the loading state as an update check, not live GPS', () => {
    const html = renderTrackingState('loading')

    expect(html).toContain('Loading tracking update')
    expect(html).toContain('Checking the most recent load update.')
    expect(html).toContain('role="status"')
    expect(html).toContain('aria-live="polite"')
    expect(html).not.toMatch(/continuous live GPS|real-time GPS|live location/i)
  })

  it('renders a generic unavailable-link state without revealing why access failed', () => {
    const html = renderTrackingState('unavailable-link')

    expect(html).toContain('Tracking link unavailable')
    expect(html).toContain('This secure tracking link is unavailable.')
    expect(html).toContain('role="alert"')
    expect(html).toContain('aria-live="assertive"')
    expect(html).not.toMatch(/invalid|expired|revoked|deleted|load found/i)
  })

  it('keeps temporary service failures separate from access-denied links', () => {
    const html = renderTrackingState('service-unavailable', { canRetry: true })

    expect(html).toContain('Tracking temporarily unavailable')
    expect(html).toContain('Tracking updates cannot be checked right now.')
    expect(html).toContain('data-action="retry-tracking"')
  })
})
