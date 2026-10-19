# Tallynn

A macOS menu bar app that keeps a tally of your GitHub release downloads and plays a sound when they change.

Every 5, 10, 30 or 60 minutes it counts the downloads of `.dmg`, `.exe` and `.zip` release assets across your public, non-fork repositories. The total sits in the menu bar, each repository's count is in the menu with a submenu of downloads per release, and every change arrives as one notification, such as "theej +3 (364)".

The art comes from Tallinn's Old Town.

## Requirements

- macOS 26
- [GitHub CLI](https://cli.github.com) installed (`brew install gh`) and logged in (`gh auth login`). Tallynn uses its login and never asks for a token.

## Run

```bash
./run.sh
```

This builds a debug `Tallynn.app` in `/tmp/tallynn-run`, quits any running copy, and opens it. Run the tests with `swift test`.

## Build and install

```bash
./build.sh
```

This runs the tests and writes a universal `dist/Tallynn.app`, signed ad hoc. Set `SIGN_ID` to your signing identity to sign it with your certificate instead. Then install it:

```bash
ditto dist/Tallynn.app /Applications/Tallynn.app
```

Open it from /Applications. A newly opened copy quits any other running copy. Launch at Login is available only for the copy in /Applications.

The plan lives in `openspec/`: see `openspec/changes/mvp-download-watcher/` for the proposal, specs, design and tasks.
