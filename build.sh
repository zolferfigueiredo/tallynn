#!/bin/bash
# Runs the tests, builds a universal dist/dmg/Tallynn.app and writes dist/Tallynn-<version>.dmg.
# Every intermediate (SwiftPM build, caches, module cache, TMPDIR) lives in one /tmp dir deleted on exit.
set -euo pipefail
cd "$(dirname "$0")"

VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
DMG="dist/Tallynn-$VERSION.dmg"
WORK=$(mktemp -d /tmp/tallynn.XXXXXX)
trap 'rm -rf "$WORK"' EXIT
trap 'exit 130' INT TERM
export TMPDIR="$WORK/tmp" SWIFTPM_MODULECACHE_OVERRIDE="$WORK/modules" CLANG_MODULE_CACHE_PATH="$WORK/modules"
mkdir -p "$TMPDIR"
SWIFT_OPTS=(--scratch-path "$WORK/build" --cache-path "$WORK/cache" --config-path "$WORK/config"
            --security-path "$WORK/security" --manifest-cache none)
RELEASE_OPTS=(-c release --arch arm64 --arch x86_64)
APP=dist/dmg/Tallynn.app

swift test "${SWIFT_OPTS[@]}"
swift build "${RELEASE_OPTS[@]}" "${SWIFT_OPTS[@]}"
BIN=$(swift build "${RELEASE_OPTS[@]}" "${SWIFT_OPTS[@]}" --show-bin-path)

rm -rf dist/dmg
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Tallynn" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
swift -module-cache-path "$WORK/modules" Icon/make-icon.swift "$WORK/art"
iconutil -c icns "$WORK/art/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
tiffutil -cathidpicheck "$WORK/art/menubar.png" "$WORK/art/menubar@2x.png" -out "$APP/Contents/Resources/MenuBar.tiff"
# The DMG window's background lives inside the app, so the DMG shows nothing but the app and Applications.
swift -module-cache-path "$WORK/modules" Icon/make-dmg-background.swift "$WORK/bg"
tiffutil -cathidpicheck "$WORK/bg/background.png" "$WORK/bg/background@2x.png" \
    -out "$APP/Contents/Resources/dmg-background.tiff"

# Notarization requires the hardened runtime and a secure timestamp. Without SIGN_ID the app is signed ad hoc.
codesign --force --options runtime ${SIGN_ID:+--timestamp} --sign "${SIGN_ID:--}" "$APP"
codesign --verify --strict "$APP"
ln -sfn /Applications dist/dmg/Applications

# The window's layout (background, icon spots) as Finder saved it, so no Finder window opens while a release builds.
# dmg/layout.sh makes it again when the background or the icon spots change.
cp dmg/layout.DS_Store dist/dmg/.DS_Store
hdiutil create -quiet -volname Tallynn -srcfolder dist/dmg -format UDZO -ov "$DMG"
echo "Built $(pwd)/$DMG"
