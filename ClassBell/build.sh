#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="上下课铃声"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"

export DEVELOPER_DIR=/Library/Developer/CommandLineTools

echo "Building macOS target..."
cd "$PROJECT_DIR"
swift build --target ClassBell-macOS -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/arm64-apple-macosx/release/ClassBell-macOS" "$APP_BUNDLE/Contents/MacOS/ClassBell"
cp "$PROJECT_DIR/Sources/ClassBell/Info.plist" "$APP_BUNDLE/Contents/"

# Copy resources
cp -R "$BUILD_DIR/arm64-apple-macosx/release/ClassBell_ClassBellCore.bundle" "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
cp -R "$BUILD_DIR/arm64-apple-macosx/release/ClassBell-macOS.bundle" "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
cp "$PROJECT_DIR/Sources/ClassBellCore/Resources/"*.wav "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true

echo "✅ App bundle created: $APP_BUNDLE"
