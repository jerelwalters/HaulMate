# KAN-44 Evidence

Evidence for `[P0-WEB-02] Represent freshness and ETA honestly`.

## Screenshots

- `desktop-active.png`: active tracking page with app-estimated ETA, last update, and "Not live GPS" language.
- `mobile-offline.png`: mobile offline/no-recent-update state with short broker-facing copy.

## Verification

Run from `web/` on July 2, 2026:

```text
npm run typecheck
npm test
npm run build
npm run test:e2e
```

Results:

- TypeScript passed.
- Vitest passed: 7 files, 21 tests.
- Production build passed.
- Playwright passed: 12 tests across Chromium/WebKit desktop and mobile projects.
