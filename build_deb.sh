#!/bin/bash
set -e

# Chukdoo .deb Package Builder
# Usage: ./build_deb.sh [--with-supabase]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Chukdoo .deb Package Builder ==="
echo ""

# Check for required tools
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "Error: $1 is not installed. Please install it first."
        echo "  sudo apt install $2"
        exit 1
    fi
}

check_command flutter flutter
check_command dpkg-buildpackage dpkg-dev

# Load environment variables if available
if [ -f .env.local ]; then
    echo "Loading environment from .env.local..."
    source .env.local
fi

# Build Flutter for Linux
echo ""
echo "=== Building Flutter for Linux ==="
echo ""

# Build with or without Supabase
if [ -n "$SUPABASE_URL" ] && [ -n "$SUPABASE_ANON_KEY" ]; then
    echo "Building with Supabase support..."
    flutter build linux --release \
        --dart-define=SUPABASE_URL="$SUPABASE_URL" \
        --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
else
    echo "Building without Supabase (local-only mode)..."
    flutter build linux --release \
        --dart-define=SUPABASE_ENABLED=false
fi

# Clean previous debian build artifacts
echo ""
echo "=== Cleaning previous build ==="
rm -rf debian/chukdoo debian/.debhelper debian/files debian/*.debhelper* debian/*.substvars

# Build the .deb package
echo ""
echo "=== Building .deb package ==="
echo ""

dpkg-buildpackage -b -us -uc

# Move the package to a more convenient location
echo ""
echo "=== Package built successfully ==="
echo ""

DEB_FILE=$(ls -1 ../chukdoo_*.deb 2>/dev/null | head -1)
if [ -n "$DEB_FILE" ]; then
    echo "Package: $DEB_FILE"
    echo ""
    echo "To install:"
    echo "  sudo dpkg -i $DEB_FILE"
    echo ""
    echo "To uninstall:"
    echo "  sudo apt remove chukdoo"
else
    echo "Warning: .deb file not found in parent directory"
fi
