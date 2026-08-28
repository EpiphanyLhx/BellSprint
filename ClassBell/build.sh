#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="上下课铃声"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"

if command -v xcode-select >/dev/null 2>&1; then
    ACTIVE_DEV="$(xcode-select -p 2>/dev/null || true)"
    if [ -n "$ACTIVE_DEV" ] && [ "$ACTIVE_DEV" != "/Library/Developer/CommandLineTools" ]; then
        export DEVELOPER_DIR="$ACTIVE_DEV"
    else
        export DEVELOPER_DIR=/Library/Developer/CommandLineTools
    fi
else
    export DEVELOPER_DIR=/Library/Developer/CommandLineTools
fi

echo "Building macOS target..."
cd "$PROJECT_DIR"
swift build --target ClassBell -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp "$BUILD_DIR/arm64-apple-macosx/release/ClassBell" "$APP_BUNDLE/Contents/MacOS/ClassBell"
cp "$PROJECT_DIR/Sources/ClassBell/Info.plist" "$APP_BUNDLE/Contents/"

if [ -f "$PROJECT_DIR/Sources/ClassBell/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Sources/ClassBell/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

# Copy resources
cp -R "$BUILD_DIR/arm64-apple-macosx/release/ClassBell_ClassBellCore.bundle" "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
cp -R "$BUILD_DIR/arm64-apple-macosx/release/ClassBell_ClassBell.bundle" "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true
cp "$PROJECT_DIR/Sources/ClassBell/Resources/"*.wav "$APP_BUNDLE/Contents/Resources/" 2>/dev/null || true

echo "✅ App bundle created: $APP_BUNDLE"
