#!/bin/bash
# Bump both versions in Info.plist first. Builds dist/Tallynn-<version>.dmg, signs and notarizes it with Developer ID,
# then publishes it as a GitHub release of the current commit, which must be pushed.
# .github/workflows/release.yml runs it on every push to main, on the self-hosted runner on z's Mac; by hand it does
# the same. It stops early when this version is already released.
# One-time setup (shared with ClaudioStat): xcrun notarytool store-credentials bihan --key <AuthKey.p8> --key-id <id> --issuer <issuer-id>
set -euo pipefail
cd "$(dirname "$0")"

export SIGN_ID="Developer ID Application: Zolfer Figueiredo (497V6MCDS8)"
NAME=Tallynn
REPO=zolferfigueiredo/tallynn
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
DMG="dist/$NAME-$VERSION.dmg"
if gh release view "v$VERSION" -R "$REPO" >/dev/null 2>&1; then
  echo "v$VERSION is already released."
  exit 0
fi

./build.sh
codesign --timestamp --sign "$SIGN_ID" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile bihan --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature -vv "$DMG"
gh release create "v$VERSION" "$DMG" -R "$REPO" --target "$(git rev-parse HEAD)" --title "$NAME $VERSION" --generate-notes
