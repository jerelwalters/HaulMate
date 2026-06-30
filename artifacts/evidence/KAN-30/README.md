# KAN-30 CORE-07 Evidence

Story: [P0-CORE-07] Implement location-backed trip events

Jira: https://haulmatework.atlassian.net/browse/KAN-30

Evidence captured: June 30, 2026 at 11:45 AM America/Detroit

## Verification

Command:

```sh
xcodebuild test -project HaulMate.xcodeproj -scheme HaulMate -destination 'platform=iOS Simulator,id=2622ECAD-BA74-4A1F-94D9-0DF82F8F7B42' -only-testing:HaulMateTests/LoadStateMachineTests
```

Result:

- `LoadStateMachineTests` passed.
- Executed 11 tests.
- 0 failures.
- Evidence validates UTC/timezone capture, device-verified location, poor accuracy, permission denied, unavailable, manual events, and manual correction labeling.

## Files

- `core07-load-state-machine-tests.typescript`: terminal recording of the validation run.
- `core07-load-state-machine-tests.log`: readable console output from the same run.
- `core07-load-state-machine-tests-summary.txt`: screenshot source summary.
- `core07-load-state-machine-tests-summary.html`: styled screenshot source summary.
- `core07-load-state-machine-tests-summary.html.png`: screenshot evidence generated from the styled summary.
