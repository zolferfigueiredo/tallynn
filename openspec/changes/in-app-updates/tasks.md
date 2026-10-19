# Tasks

## 1. Updater

- [x] 1.1 Add `Sources/Tallynn/Updates.swift` adapted from ClaudioStat's: the latest release from the API, the asset download that drops the token on redirect, install with the team, bundle and version checks, the progress window, relaunch, and the once-per-version notification. Verify `swift build` passes with no warnings
- [ ] 1.2 Add Check for updates… (or "Update available!") and the Check automatically submenu above Quit, the hourly and launch checks, and the notification click. Verify the menu shows them in the installed app
- [x] 1.3 Add tests for version comparison, when a check is due, and reading the latest release (tag without `v`, the matching DMG, none without it). Verify `swift test` passes

## 2. Docs

- [x] 2.1 Describe updates in README.md (Features, How it works, Every setting) and verify the labels match the menu

## 3. End to end

- [ ] 3.1 Release this change as 0.3.0 and install it in /Applications (0.2.0 has no updater). With the next release, 0.3.1, verify Check for updates… offers it, Update Now installs it, Reopen starts it and the alert says 0.3.1
