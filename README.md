# Chukdoo

Offline-first, end-to-end encrypted todo app with natural language parsing.

## Features

- **End-to-End Encryption**: AES-256-GCM encryption with PBKDF2 key derivation
- **Offline-First**: Works without internet, syncs when connected
- **Natural Language Parsing**: German/English date and priority parsing
- **Cross-Platform**: Android, Linux, Windows, macOS
- **Smart Sync**: Realtime updates with adaptive polling (saves battery)
- **System Tray**: Minimize to tray on desktop (Linux/Windows/macOS)

## Natural Language Syntax

```
"Milch kaufen morgen 15:00 !!2 #einkauf"
→ Title: Milch kaufen
→ Due: Tomorrow 15:00
→ Priority: P2
→ Project: einkauf
```

| Syntax | Meaning |
|--------|---------|
| `!!1` - `!!4` | Priority (1=highest) |
| `morgen`, `tomorrow` | Tomorrow |
| `mo`, `di`, `mi`... | Weekdays (German) |
| `mon`, `tue`, `wed`... | Weekdays (English) |
| `15:00` | Time |
| `#project` | Project |
| `@label` | Label |

## Build

### Android (with Supabase sync)

```bash
flutter build apk \
  --target-platform android-arm64 \
  --dart-define=SUPABASE_URL=your_url \
  --dart-define=SUPABASE_ANON_KEY=your_key
```

### Linux .deb Package

```bash
# Set environment variables
export SUPABASE_URL="your_url"
export SUPABASE_ANON_KEY="your_key"

# Build .deb
./build_deb.sh

# Install
sudo dpkg -i ../chukdoo_*.deb
```

### Local-Only Build (no cloud sync)

```bash
flutter build apk --dart-define=SUPABASE_ENABLED=false
flutter build linux --dart-define=SUPABASE_ENABLED=false
```

## Architecture

```
lib/
├── core/                    # Config, constants, theme
├── features/
│   ├── auth/               # Authentication
│   ├── todos/              # Todo CRUD + state
│   ├── projects/           # Project management
│   ├── nlp/parser/         # Natural language parsing
│   ├── sync/               # Offline queue + smart sync
│   ├── notifications/      # Local notifications
│   └── system_tray/        # Desktop tray integration
├── shared/services/
│   ├── encryption_service.dart
│   └── supabase_service.dart
└── main.dart
```

## Smart Sync

Adaptive sync intervals to save battery:

| Condition | Interval |
|-----------|----------|
| Realtime active | 5 min (backup polling) |
| User active | 2 min |
| User idle | 10 min |
| Offline | Paused |

## Desktop Features (Linux/Windows/macOS)

- **System Tray**: App minimizes to tray instead of closing
- **Tray Menu**: Show/Hide, Sync Now, Quit
- **Background Sync**: Continues syncing when minimized

## Requirements

### Linux
- GTK 3
- libsecret
- libayatana-appindicator3 (for system tray)

### Android
- Android 5.0+ (API 21)

## License

Proprietary - All rights reserved
