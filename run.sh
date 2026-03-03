#!/bin/bash
# Build and run Frame It as a proper .app bundle

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="/tmp/frameit-build"
APP_BUNDLE="$BUILD_DIR/FrameIt.app"

echo "🔨 Building Frame It..."
cd "$SCRIPT_DIR"
swift build --scratch-path "$BUILD_DIR"

echo "📦 Creating .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/debug/FrameIt" "$APP_BUNDLE/Contents/MacOS/FrameIt"

# Copy Info.plist
cp "$SCRIPT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

echo "🚀 Launching Frame It..."
open "$APP_BUNDLE"
