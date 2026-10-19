# Tasks

## 1. Scaffold

- [x] 1.1 Create `Package.swift` (tools 6.2, macOS 26, executable target `Tallynn` with `.defaultIsolation(MainActor.self)`, test target `TallynnTests`), `Info.plist` (`com.zolfer.tallynn`, Tallynn, 0.1.0, `LSUIElement` true, `LSMinimumSystemVersion` 26.0) and `.gitignore` (`.build/`, `dist/`); verify `swift build` succeeds
- [x] 1.2 Add `Sources/Tallynn/main.swift` with an `AppDelegate` that shows an `NSStatusItem` (SF Symbol `arrow.down.circle`) and the single-copy check copied from ClaudioStat; verify that a second launch quits the first
- [x] 1.3 Add `run.sh` adapted from `~/www/claudiostat/run.sh` (debug build into `/tmp/tallynn-run/Tallynn.app`, ad hoc sign, quit the running copy, open; no icon step yet); verify `./run.sh` shows the menu bar item with no window and no Dock indicator
- [x] 1.4 Add `README.md` with what Tallynn does, the requirements (macOS 26, `gh` installed and logged in) and how to run it with `./run.sh`; verify the documented command works as written

## 2. Counting logic

- [x] 2.1 Add `Sources/Tallynn/Counts.swift` with pure functions `installerDownloads` (filters gh's `name<TAB>downloads` lines to installers), `total`, `menuRows`, `changes(old:new:)` (absent counts as 0, dropped repos ignored, nil `old` means baseline and no changes) and `notificationBody` (`"theej +3 (364)"`, `"claudiostat -30 (400)"`, one line per change, sorted by name)
- [x] 2.2 Add `Tests/TallynnTests/CountsTests.swift` covering the spec scenarios: installer-only asset sum (360), total 411, single change, multiple changes in one body, decrease, baseline produces nothing, new repo `+2 (2)`, dropped repo produces nothing; verify `swift test` passes

## 3. GitHub through gh

- [x] 3.1 Add `Sources/Tallynn/GitHub.swift`: `ghPath()` (`/opt/homebrew/bin/gh`, `/usr/local/bin/gh`), a nonisolated async `run(_ args:)` built on `Process`, `listRepos()` (`gh repo list --visibility public --source --limit 1000 --json nameWithOwner,name`) and `count(_ repo:)` (`gh api ... --paginate --jq` emitting `name<TAB>downloads` per asset, summed with `installerDownloads`)
- [x] 3.2 Add `fetchCounts() async -> Result` returning all counts or a problem (`.notFound`, `.loggedOut` via `gh auth status`, `.failed`), with any single failure failing the whole refresh; log the counts with `Logger` and verify they match the author's shell script exactly (`log stream --predicate 'subsystem == "com.zolfer.tallynn"'`)

## 4. Refresh loop and remembered counts

- [x] 4.1 In `AppDelegate`, register the default `interval` of 10, load `counts`/`lastRefresh` from `UserDefaults`, and add `reschedule()` / `tick()` with a `busy` guard copied from ClaudioStat; verify the log shows a refresh at launch and at each interval (use a temporary 1-minute interval for the check, then remove it)
- [ ] 4.2 On success, save `counts` and `lastRefresh`. On failure, keep both and store the problem. Verify that relaunching shows the previous total before the first refresh, and that with Wi-Fi off the counts stay unchanged and a failure is logged

## 5. Notifications

- [x] 5.1 Add `Sources/Tallynn/Notifications.swift` modeled on ClaudioStat's `post()`: request alert+sound permission on first use, title "Tallynn", body from `notificationBody`, default sound, unique id per refresh; call it from `tick()` only when `changes` is non-empty
- [ ] 5.2 Verify end to end: a fresh install (`defaults delete com.zolfer.tallynn`) posts nothing; `defaults write com.zolfer.tallynn counts -dict theej -int 358` followed by Refresh now posts "theej +3 (361)" with a sound; with notifications denied in System Settings, counts still update

## 6. Menu and Dock

- [ ] 6.1 Show the Tallynn icon plus `total.formatted()` in the menu bar (icon alone before any counts); verify against the spec's "Menu bar item" scenarios
- [ ] 6.2 Build the menu in `menuNeedsUpdate(_:)`: problem line, repo rows with count > 0 (highest first, counts right-aligned by tab stop), TOTAL, "Updated HH:mm", Refresh now, Every submenu (5/10/30/60, current one checked, calls `reschedule()`), Launch at login (`SMAppService.mainApp`, as in ClaudioStat), Quit; verify the script's example data shows five repos, "TOTAL 1,111" and no zolferfigueiredo row
- [ ] 6.3 Show the problem texts from the spec for gh missing (temporarily point `ghPath()` at a bad path), logged out (`gh auth logout` on a test account, or a stubbed result) and network failure; verify each message and that the menu bar keeps the last total
- [ ] 6.4 Copy `~/www/claudiostat/Sources/ClaudioStat/Dock.swift`, add the Keep in Dock item and `applicationShouldHandleReopen` popping the menu at `NSEvent.mouseLocation`; verify pinning, unpinning, the checkmark state, and that a Dock click and opening from Spotlight both show the menu at the pointer

## 7. Icons

- [x] 7.1 Add `Icon/make-icon.swift` drawing the Viru Gate app icon (twin cone-roofed towers, download arrow through the arch) into an iconset, and have `run.sh` build `AppIcon.icns` from it as ClaudioStat does; verify the pinned Dock icon and notifications show the art
- [x] 7.2 Replace the `arrow.down.circle` placeholder with an 18 pt template silhouette of the same motif; verify it is legible in light and dark menu bars and next to the notch

## 8. Release build

- [x] 8.1 Add `build.sh` adapted from ClaudioStat's (run `swift test`, universal release build, assemble `dist/Tallynn.app` with the icon, ad hoc sign or `SIGN_ID`, `codesign --verify`; no DMG); verify `./build.sh` succeeds and the app runs from `/Applications`
- [x] 8.2 Extend `README.md` with `./build.sh` and installing to `/Applications`; verify the steps work as written

## 9. Integration check

- [ ] 9.1 Run the installed app alongside the author's shell script for a day at a 5-minute interval: totals always match, every real download produces exactly one notification, and relaunching or waking from sleep never sends a spurious one

## Workflow follow-up

- Archive with `/opsx:archive` once the integration check passes, so the three capabilities become main specs under `openspec/specs/`.
