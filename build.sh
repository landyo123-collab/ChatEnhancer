#!/bin/bash
# ChatEnhancer build script
# Builds ChatEnhancer.app from the Swift sources in Sources/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/ChatEnhancer.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

echo "Building ChatEnhancer.app..."

# Create app bundle structure
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

# Copy resources
cp "$SCRIPT_DIR/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$SCRIPT_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

# Compile
xcrun swiftc -O -framework Cocoa -framework WebKit \
  "$SCRIPT_DIR/Sources/"*.swift \
  -o "$MACOS_DIR/launch"

echo "Build succeeded: $APP_DIR ($(wc -c < "$MACOS_DIR/launch" | tr -d ' ') bytes)"
echo "Run with: open $APP_DIR"
