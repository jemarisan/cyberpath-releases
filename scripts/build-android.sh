#!/bin/bash
#
# CyberPath Android Build Script
# 
# Usage: ./build-android.sh [version]
# Example: ./build-android.sh 2.0.0
#
# Prerequisites:
# - Flutter SDK installed and in PATH
# - Android SDK installed
# - Java 17+ installed
#

set -e

# Configuration
VERSION="${1:-2.0.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
FRONTEND_DIR="$PROJECT_ROOT/frontend"
RELEASE_DIR="$PROJECT_ROOT/release/packages"
APP_NAME="CyberPath"

echo "🚀 Building CyberPath v$VERSION for Android..."
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

# Build Android APK (release)
echo "🔨 Building Android APK..."
flutter build apk --release

# Copy APK to release directory
APK_NAME="$APP_NAME-$VERSION.apk"
APK_SOURCE="$FRONTEND_DIR/build/app/outputs/flutter-apk/app-release.apk"
APK_PATH="$RELEASE_DIR/$APK_NAME"

cp "$APK_SOURCE" "$APK_PATH"

# Calculate checksum
echo "🔐 Calculating checksum..."
CHECKSUM=$(shasum -a 256 "$APK_PATH" | awk '{print $1}')
echo "$CHECKSUM  $APK_NAME" > "$RELEASE_DIR/$APK_NAME.sha256"

echo ""
echo "✅ Build complete!"
echo "📦 APK: $APK_PATH"
echo "📝 Size: $(du -h "$APK_PATH" | cut -f1)"
echo "🔐 SHA256: $CHECKSUM"
echo ""

# Optional: Build App Bundle for Play Store
read -p "Build App Bundle for Play Store? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔨 Building Android App Bundle..."
    flutter build appbundle --release
    
    AAB_NAME="$APP_NAME-$VERSION.aab"
    AAB_SOURCE="$FRONTEND_DIR/build/app/outputs/bundle/release/app-release.aab"
    AAB_PATH="$RELEASE_DIR/$AAB_NAME"
    
    cp "$AAB_SOURCE" "$AAB_PATH"
    
    AAB_CHECKSUM=$(shasum -a 256 "$AAB_PATH" | awk '{print $1}')
    echo "$AAB_CHECKSUM  $AAB_NAME" > "$RELEASE_DIR/$AAB_NAME.sha256"
    
    echo "📦 AAB: $AAB_PATH"
    echo "🔐 SHA256: $AAB_CHECKSUM"
fi

echo ""
echo "Next steps:"
echo "1. Test the APK on a physical device"
echo "2. Upload to GitHub Releases"
echo "3. Update CHANGELOG.md"
