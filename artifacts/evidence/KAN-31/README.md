# KAN-31 CORE-08 Evidence

Story: [P0-CORE-08] Implement the local document pipeline

Jira: https://haulmatework.atlassian.net/browse/KAN-31

Evidence captured: July 2, 2026 at 12:55 PM EDT

## Verification

Focused simulator validation:

```sh
xcodebuild test -project HaulMate.xcodeproj -scheme HaulMate -destination 'platform=iOS Simulator,id=2622ECAD-BA74-4A1F-94D9-0DF82F8F7B42' -only-testing:HaulMateTests/SyncOutboxTests
xcodebuild test -project HaulMate.xcodeproj -scheme HaulMate -destination 'platform=iOS Simulator,id=2622ECAD-BA74-4A1F-94D9-0DF82F8F7B42' -only-testing:HaulMateTests/DocumentPipelineTests -only-testing:HaulMateTests/HaulMateLocalStorageRepositoryTests
```

Result:

- `SyncOutboxTests` passed: 8 tests, 0 failures.
- `DocumentPipelineTests` passed: 3 tests, 0 failures.
- `HaulMateLocalStorageRepositoryTests` passed: 9 tests, 0 failures.

Storage module validation:

```sh
swift test
```

Result:

- `StorageModule` package tests passed: 23 tests, 0 failures.

Additional checks:

- `ios/Scripts/check_architecture.sh` passed.
- `plutil -lint ios/HaulMate.xcodeproj/project.pbxproj` passed.
- `git diff --check` passed.
- New-file whitespace scan passed.

## Acceptance Coverage

- Supported local documents are copied into protected app storage.
- Document imports validate supported type and max byte count before persisting metadata or queueing upload work.
- Stored file bytes are hashed with SHA-256 and represented as metadata only.
- Recent document metadata stores filename, content type, byte count, hash, local URL, and remote object key without document contents.
- Document uploads enqueue durable `document.upload` sync operations with idempotency keys and retry-safe metadata.
- Account-scoped cleanup clears local repository state and raw document files.
- Existing load-only sync remotes reject unsupported document uploads safely until the upload transport is implemented.
