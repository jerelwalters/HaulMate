# KAN-62 Evidence

Public tracking Edge Function integration was verified locally on 2026-07-01.

Commands:

```sh
cd web
npm run typecheck
npm test
npm run build
```

Results:

- `npm run typecheck`: passed.
- `npm test`: 6 files passed, 17 tests passed.
- `npm run build`: passed and produced `dist/`.

Acceptance coverage:

- Share tokens are read from `?token=`, `?share=`, `?shareToken=`, and `/track/<token>`.
- The configured `VITE_HAULMATE_TRACKING_FUNCTION_URL` is called with native `fetch`.
- Invalid, expired, revoked, missing, and unavailable links use generic UI copy.
- The app does not log share tokens or response payloads.
