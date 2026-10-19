# Proposal

## Why

Release download counts are checked today with a shell script that is run by hand (`gh repo list` + `gh api .../releases`, summing `.dmg`/`.exe`/`.zip` assets). New downloads go unnoticed until someone remembers to run it. Tallynn, a menu bar app that runs the same check on a timer and announces changes, makes them visible the moment they happen.

## What Changes

- New macOS menu bar app, **Tallynn**: no windows, no running Dock indicator; behaves like ClaudioStat and Deploydz.
- Counts downloads exactly like the existing script: the logged-in GitHub user's public, non-fork repositories, summing release assets whose names end in `.dmg`, `.exe` or `.zip`, per repository and in total.
- Uses the GitHub CLI login; no token entry or account settings.
- Refreshes every 5, 10, 30 or 60 minutes (user's choice) and on "Refresh now".
- Remembers last-seen counts; when any repository's count changes, posts one notification with sound listing each change and its delta.
- Menu bar shows the Tallynn icon and the total. The menu lists per-repository counts, the total, last update time, the interval choice, Refresh now, Launch at login, Keep in Dock and Quit.
- "Keep in Dock" pins the app to the Dock; clicking the Dock icon opens the menu at the pointer.

## Capabilities

### New Capabilities
- `download-tracking`: using the GitHub CLI login, discovering repositories, counting release asset downloads, the refresh schedule, and remembering last-seen counts.
- `change-notifications`: deciding when a notification is due and posting it with sound, including the first-run baseline and combining several changes.
- `menu-bar-ui`: the menu bar item, its menu, the Dock pin and Dock click behavior, and how errors are shown.

### Modified Capabilities
<!-- none: greenfield project -->

## Impact

- New SwiftPM package (Swift 6, macOS 26) with AppKit, UserNotifications and ServiceManagement only; `run.sh`/`build.sh` produce an ad hoc signed `Tallynn.app`, following `~/www/claudiostat`.
- Runtime dependency on the GitHub CLI (`gh`) being installed and logged in.
- About 1 + N GitHub API requests per refresh for N repositories, well within the 5,000/hour authenticated limit.
- Personal, locally built app: DMG packaging, notarization, auto-update and localization are out of scope.
