# KAN-45 Evidence

Evidence for `[P0-WEB-03] Handle secure failure states accessibly`.

## Screenshots

- `desktop-valid.png`: valid tracking page rendered from the public tracking contract.
- `desktop-unavailable-link.png`: revoked tracking link rendered as the generic unavailable-link state with no prior load data.
- `desktop-retry-success.png`: temporary tracking failure recovered through the retry flow.

## Verification

Run from `web/` on July 2, 2026:

```text
npm run typecheck
npm test
npm run test:e2e
npm run build
```

Results:

- TypeScript passed.
- Vitest passed: 7 files, 31 tests.
- Playwright passed: 20 tests across Chromium/WebKit desktop and mobile projects.
- Production build passed.
- In-app browser smoke passed against local mock tracking responses for valid, revoked, and retry states.
