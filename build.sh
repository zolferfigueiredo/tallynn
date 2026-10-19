#!/bin/bash
# Runs the tests and builds a universal dist/Tallynn.app.
# Every intermediate (SwiftPM build, caches, module cache, TMPDIR) lives in one /tmp dir deleted on exit.
set -euo pipefail
cd "$(dirname "$0")"

WORK=$(mktemp -d /tmp/tallynn.XXXXXX)
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT TERM
export TMPDIR="$WORK/tmp" SWIFTPM_MODULECACHE_OVERRIDE="$WORK/modules" CLANG_MODULE_CACHE_PATH="$WORK/modules"
mkdir -p "$TMPDIR"
SWIFT_OPTS=(--scratch-path "$WORK/build" --cache-path "$WORK/cache" --config-path "$WORK/config"
            --security-path "$WORK/security" --manifest-cache none)
RELEASE_OPTS=(-c release --arch arm64 --arch x86_64)

swift test "${SWIFT_OPTS[@]}"
swift build "${RELEASE_OPTS[@]}" "${SWIFT_OPTS[@]}"
BIN=$(swift build "${RELEASE_OPTS[@]}" "${SWIFT_OPTS[@]}" --show-bin-path)

APP=dist/Tallynn.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Tallynn" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
swift -module-cache-path "$WORK/modules" Icon/make-icon.swift "$WORK/art"
iconutil -c icns "$WORK/art/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
tiffutil -cathidpicheck "$WORK/art/menubar.png" "$WORK/art/menubar@2x.png" -out "$APP/Contents/Resources/MenuBar.tiff"
# Notarization requires the hardened runtime and a secure timestamp. Without SIGN_ID the app is signed ad hoc.
codesign --force --options runtime ${SIGN_ID:+--timestamp} --sign "${SIGN_ID:--}" "$APP"
codesign --verify --strict "$APP"
echo "Built $(pwd)/$APP"
