# KAN-29 CORE-06 Evidence

Story: [P0-CORE-06] Implement secure auth session handling

Jira: https://haulmatework.atlassian.net/browse/KAN-29

Evidence captured: June 30, 2026 at 5:39 PM America/Detroit

## Verification

Focused validation:

```sh
xcodebuild test -project HaulMate.xcodeproj -scheme HaulMate -destination 'platform=iOS Simulator,id=2622ECAD-BA74-4A1F-94D9-0DF82F8F7B42' -only-testing:HaulMateTests/AppRootManagerTests -only-testing:HaulMateTests/HaulMateLocalStorageRepositoryTests
```

Result:

- `AppRootManagerTests` and `HaulMateLocalStorageRepositoryTests` passed.
- Executed 14 focused tests.
- 0 failures.

Full regression validation:

```sh
xcodebuild test -project HaulMate.xcodeproj -scheme HaulMate -destination 'platform=iOS Simulator,id=2622ECAD-BA74-4A1F-94D9-0DF82F8F7B42'
```

Result:

- Full `HaulMateTests` suite passed.
- Executed 85 tests.
- 0 failures.

Additional checks:

- `ios/Scripts/check_architecture.sh` passed.
- `git diff --check` passed.

## Acceptance Coverage

- Session material is stored through the secure Keychain-backed storage boundary.
- Authenticated sessions restore without UI/network coupling.
- Expired sessions use an injectable refresh boundary and clear stale session material when refresh fails.
- Sign-out deletes session material and clears account-scoped local data.
- Account switch protection clears local data when the stored account differs from the new authenticated user.

## Files

- `core06-secure-session-tests-summary.txt`: concise command and result summary.
