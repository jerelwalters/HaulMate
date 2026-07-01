import { expect, type Page, test } from '@playwright/test'

import { trackingResponseFixtures } from '../src/tracking/fixtures'

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
    await expect(page.getByText('ETA published for delivery.')).toBeVisible()
    await expectNoHorizontalOverflow(page)

    expect(requests).toHaveLength(1)
    expect(consoleMessages.join('\n')).not.toContain(shareToken)
    expect(consoleMessages.join('\n')).not.toContain('NSF-2048')
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

async function mockTrackingFunction(page: Page, expectedToken: string) {
  const requests: string[] = []

  await page.route(trackingFunctionPattern, async (route) => {
    const requestUrl = new URL(route.request().url())
    requests.push(route.request().url())

    expect(requestUrl.searchParams.get('token')).toBe(expectedToken)

    await route.fulfill({
      body: JSON.stringify(trackingResponseFixtures.activeLoad),
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
