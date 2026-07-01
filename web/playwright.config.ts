import { defineConfig } from '@playwright/test'

const appPort = 5178
const trackingFunctionUrl = 'http://127.0.0.1:5179/public-tracking'

export default defineConfig({
  testDir: './e2e',
  testMatch: /.*\.e2e\.ts/,
  outputDir: './test-results',
  reporter: [['list']],
  use: {
    baseURL: `http://127.0.0.1:${appPort}`,
    trace: 'on-first-retry',
  },
  webServer: {
    command: `VITE_HAULMATE_TRACKING_FUNCTION_URL=${trackingFunctionUrl} npm run dev -- --host 127.0.0.1 --port ${appPort}`,
    url: `http://127.0.0.1:${appPort}`,
    reuseExistingServer: false,
    timeout: 120_000,
  },
  projects: [
    {
      name: 'chromium-desktop',
      use: {
        browserName: 'chromium',
        viewport: { width: 1280, height: 720 },
      },
    },
    {
      name: 'chromium-mobile',
      use: {
        browserName: 'chromium',
        viewport: { width: 390, height: 844 },
      },
    },
    {
      name: 'webkit-desktop',
      use: {
        browserName: 'webkit',
        viewport: { width: 1280, height: 720 },
      },
    },
    {
      name: 'webkit-mobile',
      use: {
        browserName: 'webkit',
        viewport: { width: 390, height: 844 },
      },
    },
  ],
})
