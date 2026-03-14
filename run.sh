#!/bin/bash
# Build frame it. as a .app bundle and optionally install it into /Applications.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="/tmp/frameit-build"
APP_NAME="frame it."
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_PATH="/Applications/$APP_NAME.app"
LEGACY_INSTALL_PATH="/Applications/FrameIt.app"
REPO_BUNDLE_DIR="$SCRIPT_DIR/App"
REPO_BUNDLE_PATH="$REPO_BUNDLE_DIR/$APP_NAME.app"
SDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
SWIFTC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
ICON_FILE="$SCRIPT_DIR/Assets/FrameIt.icns"

BUILD_ONLY=0
INSTALL_APP=0

for arg in "$@"; do
    case "$arg" in
        --build-only)
            BUILD_ONLY=1
            ;;
        --install)
            INSTALL_APP=1
            ;;
        *)
            echo "Unknown option: $arg" >&2
            echo "Usage: $0 [--build-only] [--install]" >&2
            exit 1
            ;;
    esac
done

echo "🔨 Building $APP_NAME..."
cd "$SCRIPT_DIR"
mkdir -p "$BUILD_DIR"
CLANG_MODULE_CACHE_PATH=/tmp/frameit-clang-modules \
    "$SWIFTC" \
    -sdk "$SDK" \
    -target arm64-apple-macosx26.0 \
    -o "$BUILD_DIR/FrameIt" \
    Sources/FrameIt/main.swift \
    Sources/FrameIt/AppDelegate.swift \
    Sources/FrameIt/Controllers/*.swift \
    Sources/FrameIt/Models/*.swift \
    Sources/FrameIt/Views/*.swift \
    Sources/FrameIt/Windows/*.swift

if [[ ! -f "$ICON_FILE" ]]; then
    echo "Missing app icon: $ICON_FILE" >&2
    exit 1
fi

echo "📦 Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/FrameIt" "$APP_BUNDLE/Contents/MacOS/FrameIt"
chmod +x "$APP_BUNDLE/Contents/MacOS/FrameIt"

# Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$ICON_FILE" "$APP_BUNDLE/Contents/Resources/FrameIt.icns"

mkdir -p "$REPO_BUNDLE_DIR"
rm -rf "$REPO_BUNDLE_PATH"
cp -R "$APP_BUNDLE" "$REPO_BUNDLE_PATH"

if [[ "$INSTALL_APP" -eq 1 ]]; then
    echo "📁 Installing to $INSTALL_PATH..."
    if [[ -d "$LEGACY_INSTALL_PATH" && "$LEGACY_INSTALL_PATH" != "$INSTALL_PATH" ]]; then
        rm -rf "$LEGACY_INSTALL_PATH"
    fi
    rm -rf "$INSTALL_PATH"
    cp -R "$APP_BUNDLE" "$INSTALL_PATH"
fi

if [[ "$BUILD_ONLY" -eq 0 ]]; then
    TARGET_APP="$APP_BUNDLE"
    if [[ "$INSTALL_APP" -eq 1 ]]; then
        TARGET_APP="$INSTALL_PATH"
    fi
    echo "🚀 Launching $APP_NAME..."
    open "$TARGET_APP"
fi
