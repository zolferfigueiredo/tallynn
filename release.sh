#!/bin/bash
# Bump both versions in Info.plist first. Builds dist/Tallynn-<version>.dmg, signs and notarizes it with Developer ID,
# then publishes it as a GitHub release of the current commit, which must be pushed.
# .github/workflows/release.yml runs it in two halves on every push to main, and to a beta branch (<feature>-beta):
#   ./release.sh build  the tests and the unsigned dist/dmg/Tallynn.app, on GitHub's Mac
#   ./release.sh sign   Developer ID, the DMG, notarization and the release, on the self-hosted runner on z's Mac
# With neither it does both, by hand. Both stop early when this version is already released.
# One-time setup (shared with ClaudioStat): xcrun notarytool store-credentials bihan --key <AuthKey.p8> --key-id <id> --issuer <issuer-id>
set -euo pipefail
cd "$(dirname "$0")"
MODE=all
case "${1:-}" in build | sign) MODE=$1; shift ;; esac

export SIGN_ID="Developer ID Application: Zolfer Figueiredo (497V6MCDS8)"
NAME=Tallynn
REPO=zolferfigueiredo/tallynn
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)
DMG="dist/$NAME-$VERSION.dmg"
if gh release view "v$VERSION" -R "$REPO" >/dev/null 2>&1; then
  echo "v$VERSION is already released."
  exit 0
fi
# A version with a "-", 0.7.0-widgets-beta.1, is a beta: a pre-release, which GitHub never calls latest, so neither the
# app's update check (unless it runs a beta) nor the website or the cask offer it. A beta branch publishes betas only.
PRERELEASE=false
case $VERSION in *-*) PRERELEASE=true ;; esac
case "${GITHUB_REF_NAME:-}" in *-beta)
  [ "$PRERELEASE" = true ] || { echo "$GITHUB_REF_NAME publishes betas only, and $VERSION isn't one."; exit 0; } ;;
esac

case $MODE in
  build) exec ./build.sh app ;;
  sign) ./build.sh dmg ;;
  *) ./build.sh ;;
esac
codesign --timestamp --sign "$SIGN_ID" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile bihan --wait
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature -vv "$DMG"
# The app learns the newest version from releases/latest/download/latest.json, the same file the website serves.
printf '{"version": "%s"}\n' "$VERSION" > dist/latest.json
gh release create "v$VERSION" "$DMG" dist/latest.json -R "$REPO" --target "$(git rev-parse HEAD)" --title "$NAME $VERSION" --generate-notes --prerelease="$PRERELEASE"
