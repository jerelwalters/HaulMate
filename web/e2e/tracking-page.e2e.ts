import { expect, type Locator, type Page, test } from '@playwright/test'

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
      page.getByText('This secure tracking link is unavailable.'),
    ).toBeVisible()
    await expectNoHorizontalOverflow(page)

    expect(requests).toEqual([])
  })

  test('renders invalid, expired, and revoked links as the same secure state', async ({
    page,
  }) => {
    const consoleMessages = recordConsole(page)
    const statusByToken = new Map([
      ['invalid-token', 404],
      ['expired-token', 410],
      ['revoked-token', 403],
    ])
    const unavailableCopies: string[] = []

    await page.route(trackingFunctionPattern, async (route) => {
      const requestUrl = new URL(route.request().url())
      const token = requestUrl.searchParams.get('token') ?? ''

      if (token === shareToken) {
        await route.fulfill({
          body: JSON.stringify(trackingResponseFixtures.activeLoad),
          contentType: 'application/json',
        })
        return
      }

      await route.fulfill({
        body: '',
        status: statusByToken.get(token) ?? 404,
      })
    })

    await page.goto(`/track/${shareToken}`)
    await expect(
      page.getByRole('heading', { name: 'Load NSF-2048' }),
    ).toBeVisible()

    for (const token of statusByToken.keys()) {
      await page.goto(`/track/${token}`)

      const statePanel = page.locator('[data-tracking-state="unavailable-link"]')
      await expect(
        page.getByRole('heading', { name: 'Tracking link unavailable' }),
      ).toBeVisible()
      await expect(statePanel).toContainText(
        'This secure tracking link is unavailable.',
      )
      await expect(statePanel).not.toContainText(/invalid|expired|revoked/i)
      await expect(page.getByRole('button', { name: 'Retry' })).toHaveCount(0)
      await expect(page.getByText('Load NSF-2048')).toHaveCount(0)

      await page.addStyleTag({ content: ':root { font-size: 200%; }' })
      await expectNoHorizontalOverflow(page)
      await expectContrastAtLeast(statePanel.locator('h1'), 4.5)

      unavailableCopies.push(normalizeWhitespace(await statePanel.innerText()))
    }

    expect(new Set(unavailableCopies).size).toBe(1)
    expect(consoleMessages.join('\n')).not.toMatch(
      /invalid-token|expired-token|revoked-token|NSF-2048/,
    )
  })

  test('keeps temporary failures keyboard-retryable without exposing tokens', async ({
    page,
  }) => {
    const consoleMessages = recordConsole(page)
    let requestCount = 0

    await page.route(trackingFunctionPattern, async (route) => {
      requestCount += 1

      if (requestCount === 1) {
        await route.fulfill({ body: '', status: 503 })
        return
      }

      await route.fulfill({
        body: JSON.stringify(trackingResponseFixtures.activeLoad),
        contentType: 'application/json',
      })
    })

    await page.goto(`/track/${shareToken}`)

    const retryButton = page.getByRole('button', { name: 'Retry' })
    await expect(
      page.getByRole('heading', { name: 'Tracking temporarily unavailable' }),
    ).toBeVisible()
    await expect(retryButton).toBeVisible()

    await expect(retryButton).toHaveJSProperty('tabIndex', 0)
    await retryButton.focus()
    await expect(retryButton).toBeFocused()
    await page.keyboard.press('Enter')

    await expect(
      page.getByRole('heading', { name: 'Load NSF-2048' }),
    ).toBeVisible()
    await expectNoHorizontalOverflow(page)

    expect(requestCount).toBe(2)
    expect(consoleMessages.join('\n')).not.toContain(shareToken)
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

async function expectContrastAtLeast(
  locator: Locator,
  minimumRatio: number,
) {
  const colors = await locator.evaluate((element) => {
    const foreground = window.getComputedStyle(element).color
    let background = 'rgb(255, 255, 255)'
    let current: Element | null = element

    while (current) {
      const candidate = window.getComputedStyle(current).backgroundColor

      if (!candidate.endsWith(', 0)') && candidate !== 'transparent') {
        background = candidate
        break
      }

      current = current.parentElement
    }

    return { background, foreground }
  })

  expect(contrastRatio(colors.foreground, colors.background)).toBeGreaterThanOrEqual(
    minimumRatio,
  )
}

function normalizeWhitespace(value: string) {
  return value.replace(/\s+/g, ' ').trim()
}

function contrastRatio(foreground: string, background: string) {
  const foregroundLuminance = relativeLuminance(parseRgb(foreground))
  const backgroundLuminance = relativeLuminance(parseRgb(background))
  const lighter = Math.max(foregroundLuminance, backgroundLuminance)
  const darker = Math.min(foregroundLuminance, backgroundLuminance)

  return (lighter + 0.05) / (darker + 0.05)
}

function relativeLuminance([red, green, blue]: [number, number, number]) {
  const [linearRed, linearGreen, linearBlue] = [red, green, blue].map((value) => {
    const normalized = value / 255

    return normalized <= 0.03928
      ? normalized / 12.92
      : ((normalized + 0.055) / 1.055) ** 2.4
  })

  return 0.2126 * linearRed + 0.7152 * linearGreen + 0.0722 * linearBlue
}

function parseRgb(value: string): [number, number, number] {
  const channels = value.match(/\d+(\.\d+)?/g)?.map(Number) ?? []

  if (channels.length < 3) {
    throw new Error(`Could not parse RGB color: ${value}`)
  }

  return [channels[0], channels[1], channels[2]]
}
