# HaulMate iOS

Native SwiftUI client for the HaulMate load-to-cash pilot.

See [ARCHITECTURE.md](ARCHITECTURE.md) for module boundaries and vendor-integration rules.

## Requirements

- Xcode 16.4+
- iOS 17+

## Build and test

```sh
xcodebuild test \
  -project HaulMate.xcodeproj \
  -scheme HaulMate \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```
