# Tasks

## 1. Scaffold

- [x] 1.1 Create `Package.swift` (tools 6.2, macOS 26, executable target `Tallynn` with `.defaultIsolation(MainActor.self)`, test target `TallynnTests`), `Info.plist` (`com.zolfer.tallynn`, Tallynn, 0.1.0, `LSUIElement` true, `LSMinimumSystemVersion` 26.0) and `.gitignore` (`.build/`, `dist/`); verify `swift build` succeeds
- [x] 1.2 Add `Sources/Tallynn/main.swift` with an `AppDelegate` that shows an `NSStatusItem` (SF Symbol `arrow.down.circle`) and the single-copy check copied from ClaudioStat; verify that a second launch quits the first
- [x] 1.3 Add `run.sh` adapted from `~/www/claudiostat/run.sh` (debug build into `/tmp/tallynn-run/Tallynn.app`, ad hoc sign, quit the running copy, open; no icon step yet); verify `./run.sh` shows the menu bar item with no window and no Dock indicator
- [x] 1.4 Add `README.md` with what Tallynn does, the requirements (macOS 26, `gh` installed and logged in) and how to run it with `./run.sh`; verify the documented command works as written

## 2. Counting logic

- [x] 2.1 Add `Sources/Tallynn/Counts.swift` with pure functions `installerDownloads` (filters gh's `name<TAB>downloads` lines to installers), `total`, `menuRows`, `changes(old:new:)` (absent counts as 0, dropped repos ignored, nil `old` means baseline and no changes) and `notificationBody` (`"theej +3 (364)"`, `"claudiostat -30 (400)"`, one line per change, sorted by name)
- [x] 2.2 Add `Tests/TallynnTests/CountsTests.swift` covering the spec scenarios: installer-only asset sum (360), total 411, single change, multiple changes in one body, decrease, baseline produces nothing, new repo `+2 (2)`, dropped repo produces nothing; verify `swift test` passes

## 3. GitHub through gh (replaced by group 10: Tallynn signs in with GitHub instead)

- [x] 3.1 Add `Sources/Tallynn/GitHub.swift`: `ghPath()` (`/opt/homebrew/bin/gh`, `/usr/local/bin/gh`), a nonisolated async `run(_ args:)` built on `Process`, `listRepos()` (`gh repo list --visibility public --source --limit 1000 --json nameWithOwner,name`) and `count(_ repo:)` (`gh api ... --paginate --jq` emitting `name<TAB>downloads` per asset, summed with `installerDownloads`)
- [x] 3.2 Add `fetchCounts() async -> Result` returning all counts or a problem (`.notFound`, `.loggedOut` via `gh auth status`, `.failed`), with any single failure failing the whole refresh; log the counts with `Logger` and verify they match the author's shell script exactly (`log stream --predicate 'subsystem == "com.zolfer.tallynn"'`)

## 4. Refresh loop and remembered counts

- [x] 4.1 In `AppDelegate`, register the default `interval` of 10, load `counts`/`lastRefresh` from `UserDefaults`, and add `reschedule()` / `tick()` with a `busy` guard copied from ClaudioStat; verify the log shows a refresh at launch and at each interval (use a temporary 1-minute interval for the check, then remove it)
- [x] 4.2 On success, save `counts` and `lastRefresh`. On failure, keep both and store the problem. Verify that relaunching shows the previous total before the first refresh, and that with Wi-Fi off the counts stay unchanged and a failure is logged

## 5. Notifications

- [x] 5.1 Add `Sources/Tallynn/Notifications.swift` modeled on ClaudioStat's `post()`: request alert+sound permission on first use, title "Tallynn", body from `notificationBody`, default sound, unique id per refresh; call it from `tick()` only when `changes` is non-empty
- [x] 5.2 Verify end to end: a fresh install (`defaults delete com.zolfer.tallynn`) posts nothing; `defaults write com.zolfer.tallynn counts -dict theej -int 358` followed by Refresh now posts "theej +3 (361)" with a sound; with notifications denied in System Settings, counts still update

## 6. Menu and Dock

- [x] 6.1 Show the Tallynn icon plus `total.formatted()` in the menu bar (icon alone before any counts); verify against the spec's "Menu bar item" scenarios
- [x] 6.2 Build the menu in `menuNeedsUpdate(_:)`: problem line, repo rows with count > 0 (highest first, counts as `NSMenuItemBadge` at the right edge), TOTAL, "Updated HH:mm", Refresh now, Every submenu (5/10/30/60, current one checked, calls `reschedule()`), Launch at login (`SMAppService.mainApp`, as in ClaudioStat), Quit; verify the script's example data shows five repos, "TOTAL 1,111" and no zolferfigueiredo row
- [ ] 6.3 Show the problem lines from the spec: signed out ("Sign in to GitHub…", which opens Settings) and a failed refresh ("Couldn’t refresh", the menu bar keeping the last total); verify each on screen, the failure by relaunching with `open -n --env HTTPS_PROXY=http://127.0.0.1:9 /Applications/Tallynn.app`
- [x] 6.4 Copy `~/www/claudiostat/Sources/ClaudioStat/Dock.swift`, add the Keep in Dock item and `applicationShouldHandleReopen` popping the menu at `NSEvent.mouseLocation`; verify pinning, unpinning, the checkmark state, and that a Dock click and opening from Spotlight both show the menu at the pointer

## 7. Icons

- [x] 7.1 Add `Icon/make-icon.swift` drawing the Viru Gate app icon (white gate silhouette with a black door on Estonian blue fading to black, no arrow) into an iconset, and have `run.sh` build `AppIcon.icns` from it as ClaudioStat does; verify the pinned Dock icon and notifications show the art
- [x] 7.2 Replace the `arrow.down.circle` placeholder with an 18 pt template silhouette of the same motif; verify it is legible in light and dark menu bars and next to the notch

## 8. Release build

- [x] 8.1 Add `build.sh` adapted from ClaudioStat's (run `swift test`, universal release build, assemble `dist/Tallynn.app` with the icon, ad hoc sign or `SIGN_ID`, `codesign --verify`; no DMG); verify `./build.sh` succeeds and the app runs from `/Applications`
- [x] 8.2 Extend `README.md` with `./build.sh` and installing to `/Applications`; verify the steps work as written

## 9. Menu and icon refinements

- [x] 9.1 Sort repository rows alphabetically (`localizedStandardCompare`) and drop the TOTAL row; verify `menuHidesZerosAndSortsAlphabetically` passes and the menu lists bhbrightness to wrecktangle with no TOTAL
- [x] 9.2 Rename Refresh Now to Refresh and Refresh Every to Refresh rate, move "Updated" below the separator just above Refresh, and put About Tallynn directly above Quit with no separator; verify the menu order on screen
- [x] 9.3 Keep per-release downloads: gh's jq emits `tag<TAB>name<TAB>downloads`, `releaseDownloads` sums installers per release, `repoCounts` derives the counts, and `releases` is saved as JSON next to `counts`; verify the new unit tests pass and the saved releases sum to the logged counts
- [x] 9.4 Give each repository row a submenu of its releases with downloads (newest first, counts as `NSMenuItemBadge`, zero releases hidden); verify on screen
- [x] 9.5 Replace the About window with one laid out like BeeHan Brightness's (icon, name, Made by, version, separator, GitHub, Buy me a coffee); verify it opens from About Tallynn and every link works
- [x] 9.6 Redraw the icons: the app icon as a flat white gate (1.08 size, 0.95 width, on the bottom edge, black door) on Estonian blue fading to black, and the menu bar template without the arrow; verify the Dock and menu bar show them

## 10. Sign in with GitHub and repository choice

- [x] 10.1 Add pure functions and tests: `releaseDownloads` on decoded release JSON, `nextPage` for `Link` headers, `sourceRepos` (no forks, Finder order), the silent-baseline `changes`, `migratedShownRepos`, `totalPlaces`, `loginPrompt` for gh's sign-in output; verify `swift test` passes
- [x] 10.2 Rewrite `GitHub.swift` as a REST client on an ephemeral, cache-free `URLSession` (`/user`, `/user/repos`, releases, `Link` pagination, 401 as signed out) using the GitHub CLI's token from `gh auth token`; verify `swift build` succeeds and a refresh logs the same counts as before
- [ ] 10.3 Sign in through `gh auth login --web` like ClaudioStat through Claude Code: show the code gh copied, open the device page, wait for gh, follow the CLI's login on every refresh, and sign out with `gh auth logout` after asking; verify a sign-in from a signed-out CLI, a Terminal `gh auth switch` being followed, and that no token appears in `defaults read com.zolfer.tallynn` or the app's log
- [x] 10.4 Migrate `shownRepos` from the saved counts at launch; verify `defaults read com.zolfer.tallynn shownRepos` lists the repositories that had downloads
- [ ] 10.5 Hold the token in memory and handle losing the login (clears counts, releases, last refresh; keeps picks), another account (clears picks), stale results and ticks during a refresh; verify that the first refresh after signing in notifies nothing and Sign Out clears the keys
- [ ] 10.6 Add the Settings window (`Settings.swift`, like ClaudioStat's setup window): GitHub CLI missing, Sign in with GitHub, the copied code with Cancel and Open GitHub Again, Sign Out, and the repository checkboxes with locks and reload; verify on screen that it shows the signed-in account and that ticking a private repository adds it to the menu without a notification
- [ ] 10.7 Update the menu: Settings… (⌘,) then Total (Menu bar, List; the last one on disabled) with a separator after it, the optional TOTAL row, "Install the GitHub CLI…", "Sign in to GitHub…" and "Choose Repositories…"; verify the order and every Total combination on screen
- [ ] 10.8 Document signing in through the GitHub CLI, the repository picker and the Total menu in the README; verify the steps work as written
- [ ] 10.9 Run the whole flow: sign in, tick a private repository, a real download notifies once, sign out and back in without notifications

## 11. Integration check

- [ ] 11.1 Run the installed app alongside the author's shell script for a day at a 5-minute interval: totals always match, every real download produces exactly one notification, and relaunching or waking from sleep never sends a spurious one

## Workflow follow-up

- Archive with `/opsx:archive` once the integration check passes, so the three capabilities become main specs under `openspec/specs/`.
