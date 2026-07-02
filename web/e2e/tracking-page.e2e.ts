import { expect, type Page, test } from '@playwright/test'

import { trackingResponseFixtures } from '../src/tracking/fixtures'
import type { TrackingResponse } from '../src/tracking/types'

const trackingFunctionPattern = 'http://127.0.0.1:5179/public-tracking*'
const shareToken = 'playwright-share-token'

test.describe('public tracking page', () => {
  test('renders tracking data from the configured Edge Function', async ({ page }) => {
    const consoleMessages = recordConsole(page)
    const requests = await mockTrackingFunction(page, shareToken)

    await page.goto(`/track/${shareToken}`)

    await expect(
      page.getByRole('heading', { name: 'Load NSF-2048' }),
    ).toBeVisible()
    await expect(page.locator('[aria-label="Load status"]')).toContainText(
      'En route to delivery',
    )
    await expect(page.locator('[aria-label="Tracking summary"]')).toContainText(
      'Delivery ETA',
    )
    await expect(page.locator('[aria-label="Tracking summary"]')).toContainText(
      'App-estimated ETA',
    )
    await expect(page.locator('[aria-label="Tracking summary"]')).toContainText(
      'Last update',
    )
    await expect(page.locator('[aria-label="Tracking summary"]')).toContainText(
      'Not live GPS.',
    )
    await expect(page.getByText('ETA updated for delivery.')).toBeVisible()
    await expectNoHorizontalOverflow(page)

    expect(requests).toHaveLength(1)
    expect(consoleMessages.join('\n')).not.toContain(shareToken)
    expect(consoleMessages.join('\n')).not.toContain('NSF-2048')
  })

  test('renders an offline/no-update tracking state honestly', async ({ page }) => {
    await mockTrackingFunction(
      page,
      shareToken,
      trackingResponseFixtures.offlineNoUpdateLoad,
    )

    await page.goto(`/track/${shareToken}`)

    await expect(page.getByText('No recent update')).toBeVisible()
    await expect(
      page.getByText('No new update has come in.'),
    ).toBeVisible()
    await expect(page.getByText('Not live GPS.')).toBeVisible()
    await expectNoHorizontalOverflow(page)
  })

  test('shows a generic unavailable-link state when the URL has no token', async ({
    page,
  }) => {
    const requests: string[] = []
    await page.route(trackingFunctionPattern, async (route) => {
      requests.push(route.request().url())
      await route.abort()
    })

    await page.goto('/')

    await expect(
      page.getByRole('heading', { name: 'Tracking link unavailable' }),
    ).toBeVisible()
    await expect(
      page.getByText('Open the secure tracking link sent by the carrier.'),
    ).toBeVisible()
    await expectNoHorizontalOverflow(page)

    expect(requests).toEqual([])
  })
})

async function mockTrackingFunction(
  page: Page,
  expectedToken: string,
  responseFixture: TrackingResponse = trackingResponseFixtures.activeLoad,
) {
  const requests: string[] = []

  await page.route(trackingFunctionPattern, async (route) => {
    const requestUrl = new URL(route.request().url())
    requests.push(route.request().url())

    expect(requestUrl.searchParams.get('token')).toBe(expectedToken)

    await route.fulfill({
      body: JSON.stringify(responseFixture),
      contentType: 'application/json',
      headers: {
        'access-control-allow-origin': '*',
      },
    })
  })

  return requests
}

function recordConsole(page: Page) {
  const messages: string[] = []

  page.on('console', (message) => {
    messages.push(message.text())
  })

  return messages
}

async function expectNoHorizontalOverflow(page: Page) {
  const metrics = await page.evaluate(() => ({
    clientWidth: document.documentElement.clientWidth,
    scrollWidth: document.documentElement.scrollWidth,
  }))

  expect(metrics.scrollWidth).toBeLessThanOrEqual(metrics.clientWidth + 1)
}
