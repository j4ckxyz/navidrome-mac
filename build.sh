#!/usr/bin/env bash
#
# build.sh — compile NavidromeMac with Swift Package Manager and bundle the
# resulting executable into a double-clickable `NavidromeMac.app`.
#
# Run this on a Mac with Xcode (or the Xcode command line tools) installed.
# It cannot run inside the Linux authoring environment.
#
# Usage:
#   ./build.sh            # release build + bundle into ./dist/NavidromeMac.app
#   ./build.sh --debug    # debug build
#   ./build.sh --run      # build, bundle, then launch the app
#   ./build.sh --open     # build, bundle, then reveal the .app in Finder
#
set -euo pipefail

# --- Resolve paths -----------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="NavidromeMac"
BUNDLE_ID="com.navidromemac.app"
CONFIG="release"
DO_RUN=0
DO_OPEN=0

for arg in "$@"; do
  case "$arg" in
    --debug) CONFIG="debug" ;;
    --release) CONFIG="release" ;;
    --run) DO_RUN=1 ;;
    --open) DO_OPEN=1 ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

# --- Sanity checks -----------------------------------------------------------
if [[ "$(uname)" != "Darwin" ]]; then
  echo "❌ This script must be run on macOS (it builds a native .app bundle)."
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "❌ 'swift' not found. Install Xcode or the Command Line Tools:"
  echo "     xcode-select --install"
  exit 1
fi

echo "▶︎ Building $APP_NAME ($CONFIG) with Swift Package Manager…"
swift build -c "$CONFIG"

BIN_PATH="$(swift build -c "$CONFIG" --show-bin-path)/$APP_NAME"
if [[ ! -f "$BIN_PATH" ]]; then
  echo "❌ Build succeeded but executable not found at: $BIN_PATH"
  exit 1
fi

# --- Assemble the .app bundle ------------------------------------------------
DIST_DIR="$SCRIPT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

echo "▶︎ Assembling bundle at: $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"

# Optional app icon: drop an AppIcon.icns in Resources/ to have it bundled.
if [[ -f "$SCRIPT_DIR/Resources/AppIcon.icns" ]]; then
  cp "$SCRIPT_DIR/Resources/AppIcon.icns" "$RES_DIR/AppIcon.icns"
fi

# --- Code signing ------------------------------------------------------------
# Ad-hoc signature ("-") is enough to run locally. The MediaPlayer Now Playing
# integration and Keychain access work without the App Sandbox. To distribute,
# replace "-" with your Developer ID identity and add --entitlements.
echo "▶︎ Ad-hoc code signing…"
codesign --force --deep --sign - \
  --identifier "$BUNDLE_ID" \
  "$APP_DIR" 2>/dev/null || {
    echo "⚠️  codesign failed (non-fatal). The app may still run locally."
  }

echo "✅ Done: $APP_DIR"

# --- Post actions ------------------------------------------------------------
if [[ "$DO_RUN" -eq 1 ]]; then
  echo "▶︎ Launching…"
  open "$APP_DIR"
elif [[ "$DO_OPEN" -eq 1 ]]; then
  open -R "$APP_DIR"
fi
