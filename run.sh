#!/usr/bin/env bash
# Wrapper: zieht .env.local automatisch wenn vorhanden, sonst local-only (kein Sync).
# Nutzung:
#   ./run.sh                 -> flutter run (auto device)
#   ./run.sh -d linux        -> flutter run linux
#   ./run.sh build apk       -> flutter build apk --target-platform android-arm64
#   ./run.sh build linux     -> flutter build linux
# Alle Extra-Args werden an flutter durchgereicht.
set -e

DEFINES=()
if [ -f .env.local ]; then
  # shellcheck disable=SC1091
  source .env.local
  echo ">> .env.local geladen -> Cloud-Sync AN"
  [ -n "$SUPABASE_URL" ]       && DEFINES+=(--dart-define=SUPABASE_URL="$SUPABASE_URL")
  [ -n "$SUPABASE_ANON_KEY" ]  && DEFINES+=(--dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY")
  [ -n "$REVENUECAT_API_KEY" ] && DEFINES+=(--dart-define=REVENUECAT_API_KEY="$REVENUECAT_API_KEY")
else
  echo ">> keine .env.local -> local-only (kein Sync)"
  DEFINES+=(--dart-define=SUPABASE_ENABLED=false)
fi

if [ "$1" = "build" ] && [ "$2" = "apk" ]; then
  shift 2
  exec flutter build apk --target-platform android-arm64 "${DEFINES[@]}" "$@"
elif [ "$1" = "build" ]; then
  CMD="$2"; shift 2
  exec flutter build "$CMD" "${DEFINES[@]}" "$@"
else
  exec flutter run "${DEFINES[@]}" "$@"
fi
