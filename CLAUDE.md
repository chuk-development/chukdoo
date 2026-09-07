# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

### Full build with Supabase + RevenueCat (Play Store)
```bash
# Load keys from .env.local (not in git)
source .env.local

flutter build apk \
  --target-platform android-arm64 \
  --no-tree-shake-icons \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY \
  --dart-define=REVENUECAT_API_KEY=$REVENUECAT_API_KEY
```

> **`--no-tree-shake-icons` is required.** Material Design Icons
> (`material_design_icons_flutter`) expose icons as non-const `MdiIcons.*`
> getters the tree-shaker can't track, so without this flag the nav/search
> icons render blank.

### Linux build with Supabase
```bash
source .env.local

flutter build linux \
  --no-tree-shake-icons \
  --dart-define=SUPABASE_URL=$SUPABASE_URL \
  --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

### OSS/Self-hosted build (local only, no cloud)
```bash
flutter build apk \
  --target-platform android-arm64 \
  --no-tree-shake-icons \
  --dart-define=SUPABASE_ENABLED=false
```

### Install via ADB
```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

### Run tests
```bash
flutter test
```

### Run single test file
```bash
flutter test test/widget_test.dart
```

### Analyze code
```bash
flutter analyze
```

## Architecture

### Monetization: free app + donations
The app is **free** and every feature — including cloud sync and E2EE — is
available to everyone. There is no Pro tier, no entitlement and no paywall.

RevenueCat is still used, but only to sell **one-off donations** (consumable
Google Play products) that unlock nothing:
- `lib/features/donations/services/revenuecat_service.dart` — SDK init, login,
  `getDonationPackages()`, `donate(package)`, `donationCount()`
- `lib/features/donations/presentation/donation_page.dart` — "Support Chukdoo"
- Products live in a RevenueCat offering named `donations`
  (`AppConstants.donationOfferingId`); the current offering is the fallback.

Nothing in the sync path checks a subscription. Do not reintroduce
`isPro`/`canSync` gating.

### Shape system (Material 3 Expressive)
`lib/core/theme/app_shapes.dart` is the single source for radii:
- A todo list is one **group**: the first and last row get `groupOuter` (26),
  the corners between two rows `groupInner` (6), separated by `groupGap`.
  `TodoSwipeTile` takes `isFirst`/`isLast` and clips the whole row (including
  the swipe actions) with `AppShapes.row(...)`.
- Bottom sheets and the quick-add input dock use `sheetTop` (28); controls
  inside the dock use `dockField`/`dockChip`.
When adding a new list, pass `isFirst`/`isLast` per group instead of
hardcoding a radius.

### Offline-First Design
The app is designed to work completely offline:
- **Local storage**: Hive boxes for todos, projects, and sync queue
- **Non-blocking network init**: Supabase/RevenueCat initialize in background with 5s timeout
- **Network calls have timeouts**: All auth.getUser() calls timeout after 3s to prevent hanging offline
- App launches instantly regardless of network status

### Project Structure
```
lib/
├── core/                    # Config, constants, theme
│   └── config/env_config.dart  # Compile-time dart-define flags
├── features/                # Feature modules
│   ├── auth/               # Authentication (Supabase Auth)
│   ├── todos/              # Todo CRUD + state
│   ├── projects/           # Project management
│   ├── nlp/parser/         # Natural language date/priority parsing
│   ├── sync/               # Offline queue + background sync
│   ├── donations/          # RevenueCat one-off donations (no gating)
│   └── notifications/      # Local notifications
├── shared/services/
│   ├── encryption_service.dart  # E2EE (AES-256-GCM + PBKDF2)
│   └── supabase_service.dart    # Backend abstraction
├── main.dart               # Entry point (offline-first init)
├── app.dart                # MaterialApp.router
└── router.dart             # GoRouter with auth guards
```

### State Management
- **Riverpod 2.x** with StateNotifier pattern
- Key providers: `authProvider`, `todoProvider`, `projectProvider`
- Router redirects based on `AuthStatus` (initial, authenticated, unauthenticated, needsPassword)

### End-to-End Encryption
- User password → PBKDF2 (600k iterations) → AES-256-GCM key
- Key stored in Flutter Secure Storage
- Sensitive fields (title, description) encrypted before Supabase upload
- Salt stored in Supabase user metadata for cross-device sync

### Natural Language Parser
Bilingual (German/English) with auto-detection:
```
"Milch kaufen mi 15:00 !!2 #einkauf"
→ Title: "Milch kaufen"
→ Due: Wednesday 15:00
→ Priority: P2
→ Project: einkauf
```

Syntax:
- `!!1-4` or `p1-p4` = Priority
- Day shortcuts: `mo`, `di`, `mi`, `do`, `fr`, `sa`, `so` (German) / `mon`, `tue`, `wed`... (English)
- `#projectname` = Project
- `@label` = Labels

### Sync Strategy
- Queue-based with Hive persistence
- Operations queued locally, processed when online
- `SyncService.processQueue()` handles create/update/delete
- Background sync via WorkManager

## Environment Variables

Create a `.env.local` file (gitignored) with your keys:
```bash
# .env.local - DO NOT COMMIT
export SUPABASE_URL="https://your-project.supabase.co"
export SUPABASE_ANON_KEY="your-supabase-anon-key"
export REVENUECAT_API_KEY="your-revenuecat-api-key"
```

Then source it before building: `source .env.local`

## Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | Offline-first initialization |
| `lib/features/auth/providers/auth_provider.dart` | Auth state machine |
| `lib/shared/services/encryption_service.dart` | E2EE implementation |
| `lib/features/nlp/parser/date_parser.dart` | Date/day parsing |
| `lib/features/sync/services/sync_service.dart` | Offline queue |
