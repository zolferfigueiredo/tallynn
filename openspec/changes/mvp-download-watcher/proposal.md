# Proposal

## Why

Release download counts are checked today with a shell script that is run by hand (`gh repo list` + `gh api .../releases`, summing `.dmg`/`.exe`/`.zip` assets). New downloads go unnoticed until someone remembers to run it. Tallynn, a menu bar app that runs the same check on a timer and announces changes, makes them visible the moment they happen.

## What Changes

- New macOS menu bar app, **Tallynn**: no running Dock indicator; behaves like ClaudioStat and Deploydz. Its only windows are Settings and About, opened on request.
- Signs in with GitHub through the OAuth device flow (a short code entered on github.com); the token lives only in the login Keychain. No gh CLI, no password, no client secret.
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
- `menu-bar-ui`: the menu bar item, its menu, the Total placement, the Settings and About windows, the Dock pin and Dock click behavior, and how problems are shown.

### Modified Capabilities
<!-- none: greenfield project -->

## Impact

- New SwiftPM package (Swift 6, macOS 26) with AppKit, SwiftUI, Security, UserNotifications and ServiceManagement only; `run.sh`/`build.sh` produce `Tallynn.app` signed with the Developer ID identity when there is one, following `~/www/claudiostat`.
- A GitHub OAuth app, registered once by the author with Enable Device Flow ticked; its client ID goes in Info.plist. The `repo` scope it asks for is the only one that reaches private repositories and also allows writing; Tallynn only reads.
- About 1 + N GitHub API requests per refresh for N shown repositories, well within the 5,000/hour authenticated limit.
- Personal, locally built app: DMG packaging, notarization, auto-update and localization are out of scope.
