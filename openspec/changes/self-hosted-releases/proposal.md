# Proposal

## Why

Tallynn is installed by hand from `build.sh`, with no versioned downloads. Its repository is private, where GitHub bills Actions minutes on its own machines, macOS minutes most of all, so ClaudioStat's release setup, which builds on GitHub's Mac, would cost money here.

## What Changes

- `build.sh` writes a Finder-styled `dist/Tallynn-<version>.dmg` (the app, an Applications shortcut and a blue-to-black background with an arrow), like ClaudioStat's. This supersedes mvp-download-watcher's "DMG packaging and notarization are out of scope".
- New `release.sh`: builds, signs with Developer ID, notarizes, staples and publishes the DMG as a GitHub release of the current commit, skipping a version that's already released.
- New `.github/workflows/release.yml`: on every push to main, runs `release.sh` on the self-hosted runner on z's Mac only. No job uses GitHub's machines, and no artifacts are stored.
- A runner for the repository labelled `release`, and Tallynn added to Deploydz's Apps list.
- Version 0.2.0, the first release.

## Capabilities

### New Capabilities
<!-- none: tooling only, so .openspec.yaml sets skip_specs -->

### Modified Capabilities
<!-- none -->

## Impact

- New files: `release.sh`, `.github/workflows/release.yml`, `Icon/make-dmg-background.swift`. `build.sh`, `Info.plist` and `README.md` change.
- Outside the repository: `~/www/actions-runner/tallynn` (an ignored runner folder) and Deploydz's `releases` setting.
- Cost: $0. Releases, their storage and downloads are free; self-hosted runs are free and use none of the included minutes.
