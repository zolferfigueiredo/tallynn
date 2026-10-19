#!/bin/bash
# Builds a debug Tallynn.app in /tmp/tallynn-run and opens it, quitting any running copy first.
set -euo pipefail
cd "$(dirname "$0")"

WORK=/tmp/tallynn-run
export TMPDIR="$WORK/tmp" SWIFTPM_MODULECACHE_OVERRIDE="$WORK/modules" CLANG_MODULE_CACHE_PATH="$WORK/modules"
mkdir -p "$TMPDIR"
SWIFT_OPTS=(--scratch-path "$WORK/build" --cache-path "$WORK/cache" --config-path "$WORK/config"
            --security-path "$WORK/security" --manifest-cache none)

swift build "${SWIFT_OPTS[@]}"
BIN=$(swift build "${SWIFT_OPTS[@]}" --show-bin-path)

APP="$WORK/Tallynn.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Tallynn" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
if [ -f Icon/make-icon.swift ]; then
    swift -module-cache-path "$WORK/modules" Icon/make-icon.swift "$WORK/art"
    iconutil -c icns "$WORK/art/AppIcon.iconset" -o "$APP/Contents/Resources/AppIcon.icns"
    tiffutil -cathidpicheck "$WORK/art/menubar.png" "$WORK/art/menubar@2x.png" -out "$APP/Contents/Resources/MenuBar.tiff"
fi
codesign --force --sign - "$APP"

# Same bundle id as an installed copy: while it runs, open would just bring that one forward.
pkill -ix -U "$(id -u)" tallynn || true
while pgrep -ix -U "$(id -u)" tallynn >/dev/null; do sleep 0.2; done
open "$APP" --args "$@"
echo "Running $APP"
