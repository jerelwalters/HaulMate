# KAN-63 Evidence

Public tracking test and browser verification was run locally on 2026-07-01.

Commands:

```sh
cd web
npm run typecheck
npm test
npm run test:e2e
npm run build
git diff --check
```

Results:

- `npm run typecheck`: passed.
- `npm test`: 6 files passed, 17 tests passed.
- `npm run test:e2e`: 8 tests passed across Chromium desktop, Chromium mobile, WebKit desktop, and WebKit mobile.
- `npm run build`: passed and produced `dist/`.
- `git diff --check`: passed.

Acceptance coverage:

- Unit tests cover token parsing, response fetching, generic error handling, and mounted app states.
- Browser tests cover desktop and mobile layout in Chromium and WebKit.
- Browser tests confirm the page renders mapped tracking data, missing-token links do not call the function, no horizontal overflow is present, and share tokens/payload values are not written to console output.
