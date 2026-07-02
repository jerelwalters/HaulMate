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
    expect(delayedHtml).toContain('Driver-entered ETA')
    expect(delayedHtml).toContain('Delayed, update is old')
    expect(deliveredHtml).toContain('Delivered')
    expect(deliveredHtml).toContain('Ready')
    expect(deliveredHtml).toContain('last tracking update')
  })

  it('labels ETA source, refresh time, and non-GPS scope', () => {
    const activeHtml = renderTrackingPage(trackingResponseFixtures.activeLoad)
    const manualHtml = renderTrackingPage(trackingResponseFixtures.delayedLoad)

    expect(activeHtml).toContain('App-estimated ETA for Delivery')
    expect(activeHtml).toContain('ETA updated')
    expect(activeHtml).toContain('Not live GPS.')
    expect(manualHtml).toContain('Driver-entered ETA for Pickup')
  })

  it('always shows the last successful update for public tracking states', () => {
    for (const [name, fixture] of Object.entries(trackingResponseFixtures)) {
      const html = renderTrackingPage(fixture)

      expect(html, name).toContain('Last update')
      expect(html, name).toContain(fixture.freshness.lastUpdatedAt)
    }
  })

  it('distinguishes current, stale, delayed, delivered, and offline states', () => {
    expect(renderTrackingPage(trackingResponseFixtures.activeLoad)).toContain(
      'Updated recently',
    )
    expect(renderTrackingPage(trackingResponseFixtures.delayedLoad)).toContain(
      'Delayed, update is old',
    )
    expect(renderTrackingPage(trackingResponseFixtures.deliveredLoad)).toContain(
      'Delivered',
    )
    expect(
      renderTrackingPage(trackingResponseFixtures.offlineNoUpdateLoad),
    ).toContain('No recent update')
  })

  it('does not expose private field labels in the rendered public page', () => {
    const html = renderTrackingPage(trackingResponseFixtures.activeLoad)

    expect(html).not.toMatch(/rate|profit|expense|invoice|payment/i)
    expect(html).not.toMatch(/latitude|longitude|coordinates|accuracy/i)
    expect(html).not.toMatch(/token|auth|session|accountId|userId/i)
  })
})
