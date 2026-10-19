# Tallynn

A macOS menu bar app that keeps a tally of your GitHub release downloads and plays a sound when they change.

Every 5, 10, 30 or 60 minutes it counts the downloads of `.dmg`, `.exe` and `.zip` release assets across the repositories you pick, public or private. The total sits in the menu bar, each repository's count is in the menu with a submenu of downloads per release, and every change arrives as one notification, such as "theej +3 (364)".

The art comes from Tallinn's Old Town.

## Requirements

- macOS 26
- [GitHub CLI](https://cli.github.com) (`brew install gh`). Tallynn signs in through it, the way ClaudioStat signs in through Claude Code, and never keeps a token itself.

## Sign in with GitHub

Open **Settings…** and click **Sign in with GitHub**. Tallynn runs the GitHub CLI's browser sign-in: github.com opens with a one-time code already on your clipboard, you paste it and approve, and Tallynn is signed in. If the GitHub CLI is already signed in, Tallynn uses that login straight away, and it follows the CLI when you sign in or switch accounts in Terminal.

In Settings, tick the repositories to show, public or private; new ones stay hidden until you tick them. The **Total** menu puts the total in the menu bar, in the list, or both. Sign Out in Settings also signs the GitHub CLI out on this Mac, so it asks first.

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
