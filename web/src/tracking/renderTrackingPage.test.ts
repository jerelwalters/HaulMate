import { describe, expect, it } from 'vitest'

import { trackingResponseFixtures } from './fixtures'
import { renderTrackingPage } from './renderTrackingPage'

describe('renderTrackingPage', () => {
  it('renders the approved broker-visible tracking fields', () => {
    const html = renderTrackingPage(trackingResponseFixtures.activeLoad)

    expect(html).toContain('Northstar Freight LLC')
    expect(html).toContain('Load NSF-2048')
    expect(html).toContain('En route to delivery')
    expect(html).toContain('Detroit, MI')
    expect(html).toContain('Columbus, OH')
    expect(html).toContain('Jul 1, 4:00-6:00 PM EDT')
    expect(html).toContain('ETA updated')
    expect(html).toContain('POD')
  })

  it('renders delay and delivered states from representative fixtures', () => {
    const delayedHtml = renderTrackingPage(trackingResponseFixtures.delayedLoad)
    const deliveredHtml = renderTrackingPage(
      trackingResponseFixtures.deliveredLoad,
    )

    expect(delayedHtml).toContain('Waiting for dock assignment.')
    expect(delayedHtml).toContain('Manual estimate')
    expect(deliveredHtml).toContain('Delivered')
    expect(deliveredHtml).toContain('Ready')
  })

  it('does not expose private field labels in the rendered public page', () => {
    const html = renderTrackingPage(trackingResponseFixtures.activeLoad)

    expect(html).not.toMatch(/rate|profit|expense|invoice|payment/i)
    expect(html).not.toMatch(/latitude|longitude|coordinates|accuracy/i)
    expect(html).not.toMatch(/token|auth|session|accountId|userId/i)
  })
})
