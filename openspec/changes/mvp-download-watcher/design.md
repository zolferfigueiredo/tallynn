# Design

## Context

Greenfield. See proposal.md for why. Two existing assets shape the approach:

- **The author's shell script** defines what is counted (`gh repo list --visibility public --source`, then `gh api repos/<owner>/<repo>/releases --paginate` summing `.dmg|.exe|.zip` asset `download_count`). Tallynn must produce the same numbers.
- **`~/www/claudiostat`** is a menu bar app by the same author with the behavior Tallynn copies (LSUIElement, Keep in Dock, Dock click pops the menu, launch at login, notifications) and the build setup (SwiftPM, `run.sh`, `build.sh`, ad hoc signing, `Icon/make-icon.swift`). Deploydz behaves the same way.

The machine has Xcode 26.6 / Swift 6.3 and `gh` at `/opt/homebrew/bin/gh`, logged in.

## Goals / Non-Goals

**Goals:**
- Same numbers as the script, every time.
- Look, feel and build exactly like the author's other menu bar apps.
- Small: a handful of Swift files, no packages.

**Non-Goals:**
- DMG, notarization, Sparkle or any auto-update, localization (English only).
- Settings window, per-repo include/exclude, other GitHub accounts or organizations.
- Charts or history beyond the last-seen counts.

## Decisions

### 1. SwiftPM + AppKit `NSStatusItem`, mirroring ClaudioStat
`Package.swift` with one executable target and one test target, `swift-tools-version: 6.2`, `.defaultIsolation(MainActor.self)`, platform `.macOS(.v26)`. `main.swift` holds `AppDelegate` (owns the status item, timer and state) and the single-copy check, as in ClaudioStat.
- *Why not SwiftUI `MenuBarExtra`:* the Dock click must pop the menu at the pointer (`item.menu?.popUp(positioning:at:in:)` in `applicationShouldHandleReopen`), which needs an `NSMenu`. `MenuBarExtra` can't be opened programmatically.
- *Why not an Xcode project:* the author's apps all build with SwiftPM + shell scripts; reusing `run.sh`/`build.sh` costs nothing.

### 2. All GitHub access goes through the `gh` executable
Per refresh, run off the main actor (`fetchReleases()`):
1. `gh repo list --visibility public --source --limit 1000 --json nameWithOwner,name`. `gh` lists the logged-in user's repos, so no username is needed.
2. For each repo, `gh api repos/<nameWithOwner>/releases --paginate --jq '.[] | .tag_name as $tag | .assets[] | "\($tag)\t\(.name)\t\(.download_count)"'`, one line per asset, newest release first. `releaseDownloads(_:)` filters the installers and sums them per release in Swift, where the filter is unit-tested. With `--paginate`, `--jq` runs once per page, so emitting one line per asset and summing afterwards is correct. Summing inside jq would give one number per page.

`gh` is found by checking `/opt/homebrew/bin/gh` then `/usr/local/bin/gh`, following ClaudioStat's `claudePath()`. When a `gh` call exits non-zero, `gh auth token` (local only, so being offline isn't mistaken for it) decides between "logged out" (non-zero) and a general failure. Any failure fails the whole refresh, so a missing repo never looks like a drop.
- *Alternative:* `gh auth token` + `URLSession` + `Link`-header pagination + JSON decoding. That's more code, with no gain for a personal tool that already depends on `gh`, and it diverges from the script it must match.

### 3. State in `UserDefaults`
- `releases`: JSON of `[String: [Release]]` by repo name (tag and installer downloads, newest first), replaced after each successful refresh, for the per-version submenus.
- `counts`: `[String: Int]` by repo name, `repoCounts(releases)`, saved with `releases`. A missing key means no baseline yet. Change detection and notifications stay per repository.
- `lastRefresh`: `Date` of the last success. `interval`: minutes, registered default 10.
- Pure functions (no AppKit) hold the logic the specs test: `releaseDownloads(_:)` for gh output, `repoCounts(_:)`, `total(_:)`, `changes(old:new:) -> [Change]` (applies the baseline / absent-is-0 / dropped-silently rules), `notificationBody(_:)` (`"theej +3 (364)"`, one line per change, sorted by name) and `menuRows(_:)` (count > 0, alphabetical with `localizedStandardCompare`).

### 4. Scheduling
Copy ClaudioStat's `reschedule()`: invalidate, `tick()` now, then a repeating `Timer` on `RunLoop.main` in `.common` mode with a few seconds' tolerance. A `busy` flag makes `tick()` a no-op while a refresh runs. Changing the interval calls `reschedule()`.

### 5. Notifications
Same as ClaudioStat's `post()`: `UNUserNotificationCenter.requestAuthorization([.alert, .sound])` on first use, title "Tallynn", body from `notificationBody`, `sound = .default`, a unique identifier per refresh so earlier notices stay in Notification Center. Notifications need a real bundle, so development runs go through `run.sh`, not `swift run`.

### 6. Menu
Rebuilt in `menuNeedsUpdate(_:)` with `autoenablesItems = false`, as in ClaudioStat. The order is: optional problem line, repo rows (count > 0, alphabetical), separator, "Updated HH:mm", Refresh, Refresh rate (submenu of 5/10/30/60 minutes), separator, Launch at Login (`SMAppService.mainApp`), Keep in Dock, separator, About Tallynn (`info.circle`), Quit Tallynn. There is no TOTAL row: the total is in the menu bar. Each count is an `NSMenuItemBadge`, so it sits at the menu's right edge in the column the shortcuts and submenu arrows use (a fixed tab stop left a gap before that column). Each repo row has a submenu of its releases with downloads (newest first, counts as badges). About opens an AppKit window laid out like BeeHan Brightness's (icon, name, Made by, version, separator, GitHub, Buy me a coffee), without its update check or website, which Tallynn doesn't have. The menu bar text is `total.formatted()` next to an 18 pt template icon.

### 7. Dock behavior
`Info.plist` sets `LSUIElement = true`. `Dock.swift` is copied from ClaudioStat as is: `inDock()` / `toggleDockTile()` edit `com.apple.dock persistent-apps` and restart the Dock. `applicationShouldHandleReopen` pops the menu at `NSEvent.mouseLocation` and returns `false`.

### 8. Icons
`Icon/make-icon.swift` draws the app icon from code, as ClaudioStat does, and `run.sh`/`build.sh` turn it into `AppIcon.icns`. The motif is Tallinn's Viru Gate as a flat white silhouette (two round towers with cone roofs and the crenellated gateway between them) at 0.92 of full size, standing on the bottom edge, its door solid black, on a gradient from Estonian blue (#0072CE) at the top to near-black at the bottom. Earlier sketches (limestone and red roofs, a download arrow, Old Thomas, wall towers) were dropped. The same silhouette in black, with the door cut out, becomes the 18 pt menu bar template `MenuBar.tiff`: 14 pt tall from 3.5 pt up, so its base sits on the total's baseline. Without a bundle (`swift run`) the app falls back to the SF Symbol `arrow.down.circle`.

### 9. Bundle
`com.zolfer.tallynn`, `CFBundleName` Tallynn, version 0.1.0, `LSMinimumSystemVersion` 26.0, no entitlements and no sandbox (it runs `gh`), signed ad hoc by the scripts.

## Risks / Trade-offs

- [`gh` installed somewhere other than the two Homebrew paths] → shown as "GitHub CLI not found". `ponytail:` fixed path list; resolve via the login shell's `PATH` if it ever matters.
- [Switching `gh` to another account] → every old repo drops silently and every new one is notified as `+N`, which means one large notification. Accepted for a single-account personal tool.
- [Asset names in upper case (`.DMG`)] → not counted, exactly like the script. Parity matters more than catching these.
- [Keep in Dock restarts the Dock] → a brief Dock flicker, the same as in ClaudioStat. No API exists to avoid it.
- [Timers don't fire during sleep] → the overdue refresh runs on wake, which is fine for download counts.
- [About 1 + N process launches per refresh] → negligible at 6 repos every 5 minutes or more.
