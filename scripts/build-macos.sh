#!/bin/bash
#
# CyberPath macOS Build Script
# 
# Usage: ./build-macos.sh [version]
# Example: ./build-macos.sh 2.0.0
#

set -e

# Configuration
VERSION="${1:-2.0.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
RELEASE_DIR="$PROJECT_ROOT/release/packages"
APP_NAME="CyberPath"

echo "🚀 Building CyberPath v$VERSION for macOS..."
echo "📁 Project root: $PROJECT_ROOT"
echo "📁 Frontend dir: $FRONTEND_DIR"
echo "📁 Release dir: $RELEASE_DIR"

# Ensure release directory exists
mkdir -p "$RELEASE_DIR"

# Navigate to frontend
cd "$FRONTEND_DIR"

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Build macOS release
echo "🔨 Building macOS release..."
flutter build macos --release

# Create DMG
echo "📀 Creating DMG..."
DMG_NAME="$APP_NAME-$VERSION-macos.dmg"
APP_PATH="$FRONTEND_DIR/build/macos/Build/Products/Release/cyberpath.app"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"

# Remove old DMG if exists
rm -f "$DMG_PATH"

# Create DMG
hdiutil create \
    -volname "$APP_NAME $VERSION" \
    -srcfolder "$APP_PATH" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

# Calculate checksum
echo "🔐 Calculating checksum..."
CHECKSUM=$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')
echo "$CHECKSUM  $DMG_NAME" > "$RELEASE_DIR/$DMG_NAME.sha256"

echo ""
echo "✅ Build complete!"
echo "📦 DMG: $DMG_PATH"
echo "📝 Size: $(du -h "$DMG_PATH" | cut -f1)"
echo "🔐 SHA256: $CHECKSUM"
echo ""
echo "Next steps:"
echo "1. Test the DMG by mounting and running the app"
echo "2. Upload to GitHub Releases"
echo "3. Update CHANGELOG.md"
