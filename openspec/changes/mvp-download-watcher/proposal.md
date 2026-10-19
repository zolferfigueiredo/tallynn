# Proposal

## Why

Release download counts are checked today with a shell script that is run by hand (`gh repo list` + `gh api .../releases`, summing `.dmg`/`.exe`/`.zip` assets). New downloads go unnoticed until someone remembers to run it. Tallynn, a menu bar app that runs the same check on a timer and announces changes, makes them visible the moment they happen.

## What Changes

- New macOS menu bar app, **Tallynn**: no running Dock indicator; behaves like ClaudioStat and Deploydz. Its only window is Settings, with General and About tabs, opened on request.
- Signs in with GitHub through the GitHub CLI's browser sign-in (`gh auth login --web`), as ClaudioStat signs in through Claude Code: Tallynn never stores a token, and follows the CLI's login.
- Settings lists the user's own public and private repositories (no forks, no organization repositories) to tick; new ones stay hidden until ticked, and an upgrade starts with the repositories that had downloads.
- Counts downloads like the author's script: per repository and per release, summing release assets whose names end in `.dmg`, `.exe` or `.zip`.
- Refreshes every 5, 10, 30 or 60 minutes (user's choice) and on Refresh.
- Remembers last-seen counts; when a shown repository's count changes, posts one notification with sound listing each change and its delta. A newly shown repository is a silent baseline.
- Menu bar shows the Tallynn icon and, by default, the total. The menu lists the shown repositories A to Z with per-release submenus, an optional TOTAL row, the last update time, Refresh, Refresh rate, Total (Menu bar, List), Settings, Launch at Login, Keep in Dock, About and Quit.
- "Keep in Dock" pins the app to the Dock; clicking the Dock icon opens the menu at the pointer, or Settings while signed out.

## Capabilities

### New Capabilities
- `download-tracking`: signing in with GitHub, discovering and selecting repositories, counting release asset downloads, the refresh schedule, and remembering last-seen counts.
- `change-notifications`: deciding when a notification is due and posting it with sound, including baselines and combining several changes.
- `menu-bar-ui`: the menu bar item, its menu, the Total placement, the Settings window with its General and About tabs, the Dock pin and Dock click behavior, and how problems are shown.

### Modified Capabilities
<!-- none: greenfield project -->

## Impact

- New SwiftPM package (Swift 6, macOS 26) with AppKit, SwiftUI, UserNotifications and ServiceManagement only; `run.sh`/`build.sh` produce an ad hoc signed `Tallynn.app`, following `~/www/claudiostat`.
- Runtime dependency on the GitHub CLI (`gh`), installed with Homebrew. Its default login scopes include `repo`, which reaches private repositories; Tallynn only reads.
- About 1 + N GitHub API requests per refresh for N shown repositories, well within the 5,000/hour authenticated limit.
- Personal, locally built app: DMG packaging, notarization, auto-update and localization are out of scope.
