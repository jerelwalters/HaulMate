# HaulMate

HaulMate is a load-to-cash assistant for independent box-truck and semi-truck
owner-operators. This repository contains every pilot artifact so contracts and
changes can evolve together.

## Repository layout

| Path | Purpose |
|---|---|
| `ios/` | Native SwiftUI application and tests |
| `supabase/` | Database migrations, row-level security, seed data, and Edge Functions |
| `web/` | Account-free broker tracking page |
| `shared/` | Cross-platform contracts, fixtures, and design tokens |
| `docs/` | Product, architecture, design, and delivery documentation |
| `.github/workflows/` | Continuous integration workflows |

## Local checks

Run the iOS architecture guard:

```sh
ios/Scripts/check_architecture.sh
```

Run the iOS test suite:

```sh
xcodebuild test \
  -project ios/HaulMate.xcodeproj \
  -scheme HaulMate \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

Start the local backend:

```sh
supabase start
supabase db reset
```

See the README in each top-level directory for component-specific guidance.
