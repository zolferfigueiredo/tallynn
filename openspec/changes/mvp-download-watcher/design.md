# Design

## Context

Greenfield. See proposal.md for why. Two existing assets shape the approach:

- **The author's shell script** defines what is counted (`gh repo list --visibility public --source`, then `gh api repos/<owner>/<repo>/releases --paginate` summing `.dmg|.exe|.zip` asset `download_count`). Tallynn must produce the same numbers.
- **`~/www/claudiostat`** is a menu bar app by the same author with the behavior Tallynn copies (LSUIElement, Keep in Dock, Dock click pops the menu, launch at login, notifications, a SwiftUI setup window) and the build setup (SwiftPM, `run.sh`, `build.sh`, `Icon/make-icon.swift`). Deploydz behaves the same way.

The machine has Xcode 26.6 / Swift 6.3 and the GitHub CLI (`/opt/homebrew/bin/gh`), signed in. The first version counted through `gh` commands; this one asks GitHub's REST API directly with the CLI's token, so repositories can be chosen, private ones included.

## Goals / Non-Goals

**Goals:**
- Same numbers as the script, every time.
- Look, feel and build exactly like the author's other menu bar apps.
- Small: a handful of Swift files, no packages.

**Non-Goals:**
- DMG, notarization, Sparkle or any auto-update, localization (English only).
- Organization repositories, forks, several accounts at once.
- Charts or history beyond the last-seen counts.

## Decisions

### 1. SwiftPM + AppKit `NSStatusItem`, mirroring ClaudioStat
`Package.swift` with one executable target and one test target, `swift-tools-version: 6.2`, `.defaultIsolation(MainActor.self)`, platform `.macOS(.v26)`. `main.swift` holds `AppDelegate` (owns the status item, timer and state) and the single-copy check, as in ClaudioStat.
- *Why not SwiftUI `MenuBarExtra`:* the Dock click must pop the menu at the pointer (`item.menu?.popUp(positioning:at:in:)` in `applicationShouldHandleReopen`), which needs an `NSMenu`. `MenuBarExtra` can't be opened programmatically.
- *Why not an Xcode project:* the author's apps all build with SwiftPM + shell scripts; reusing `run.sh`/`build.sh` costs nothing.

### 2. GitHub REST over `URLSession`, with the GitHub CLI's login
Requests run off the main actor (`@concurrent` functions in `GitHub.swift`) on an ephemeral `URLSession` with `urlCache = nil`: GitHub allows 60 seconds of caching, which would make Refresh show old counts and write private repositories' data to disk.
1. `GET /user/repos?affiliation=owner&visibility=all&per_page=100`: the user's own public and private repositories; `sourceRepos(_:)` drops forks and sorts them like Finder.
2. For each ticked repository, `GET /repos/{full_name}/releases?per_page=100`; `releaseDownloads(_:)` sums each release's `.dmg`/`.exe`/`.zip` assets, unit-tested on decoded JSON.
Both lists follow the `Link` header's `rel="next"` (`nextPage(_:)`, unit-tested). A 401 means signed out; any other failure fails the whole refresh, so a repository that couldn't be read never looks like a drop. `GET /user` gives the login whenever the token changes.

The token comes from the GitHub CLI, the way ClaudioStat leans on Claude Code: `connect()` runs `gh auth token --hostname github.com` before every refresh (local only, so being offline isn't mistaken for being signed out) and keeps it only in memory. Signing in runs `gh auth login --web --hostname github.com --git-protocol https` with no terminal: gh copies its one-time code to the clipboard and prints "One-time code (…)" and the device page URL, which `loginPrompt(_:)` (unit-tested) reads so Settings can show the code and open the page; Tallynn then waits for gh to exit. Sign Out runs `gh auth logout --hostname github.com --user <login>` after asking, like ClaudioStat's profile removal signing Claude Code out. `gh` is found at `/opt/homebrew/bin/gh` or `/usr/local/bin/gh`, following ClaudioStat's `claudePath()`.
- *Alternatives:* an own OAuth app with the device flow (the author registers an app and pastes a client ID, and the token needs the Keychain, which re-prompts on every ad hoc rebuild); the OAuth web flow with a redirect back to the app (needs the client secret inside the app); a personal access token field (manual, pasted secrets). The GitHub CLI's default login scopes include `repo`, which reaches private repositories and allows writing; Tallynn only sends GETs.

### 3. State in `UserDefaults`
- `shownRepos`: the ticked repository names. When unset at launch it is migrated from `counts` (`migratedShownRepos`: those above 0), so upgrading keeps the menu.
- `login`: the account last signed in. A different login clears `shownRepos` and the counts.
- `releases`: JSON of `[String: [Release]]` by repo name (tag and installer downloads, newest first), for the per-version submenus.
- `counts`: `[String: Int]` by repo name, `repoCounts(releases)`, saved with `releases` and filtered by `shownRepos` at save time. A repository without a saved count is a silent baseline (`changes(old:new:)`), so ticking one, or the first refresh after signing in, never notifies its history.
- `lastRefresh`: `Date` of the last success. `interval`: minutes, default 10. `totalInMenuBar` (default on) and `totalInList` (default off), read through `totalPlaces`, which keeps the bar total if both are off.
- Losing the login (Sign Out, a 401, or the CLI signed out in Terminal) clears `counts`, `releases` and `lastRefresh`, keeping the picks. A refresh that comes back after the token changed is dropped, and an `again` flag runs one more refresh when repositories were ticked during one.
- Pure functions (no AppKit) hold the logic the specs test: `releaseDownloads`, `repoCounts`, `total`, `changes`, `notificationBody`, `menuRows`, `sourceRepos`, `migratedShownRepos`, `totalPlaces`, `nextPage`, `loginPrompt`.

### 4. Scheduling
Copy ClaudioStat's `reschedule()`: invalidate, `tick()` now, then a repeating `Timer` on `RunLoop.main` in `.common` mode with a few seconds' tolerance. A `busy` flag makes `tick()` a no-op while a refresh runs. Changing the interval calls `reschedule()`.

### 5. Notifications
Same as ClaudioStat's `post()`: `UNUserNotificationCenter.requestAuthorization([.alert, .sound])` on first use, title "Tallynn", body from `notificationBody`, `sound = .default`, a unique identifier per refresh so earlier notices stay in Notification Center. Notifications need a real bundle, so development runs go through `run.sh`, not `swift run`.

### 6. Menu
Rebuilt in `menuNeedsUpdate(_:)` with `autoenablesItems = false`, as in ClaudioStat. The order is: optional problem line ("Install the GitHub CLI…" or "Sign in to GitHub…", both opening Settings, or "Couldn’t refresh") or, signed in with nothing ticked, "Choose Repositories…"; repo rows (count > 0, alphabetical); the bold TOTAL row when the List placement is on; separator; "Updated HH:mm", Refresh (disabled while signed out), Refresh rate (5/10/30/60 minutes); separator; Settings… (⌘,), Total (Menu bar, List; the last one on is disabled); separator; Launch at Login (`SMAppService.mainApp`), Keep in Dock; separator; About Tallynn (`info.circle`), Quit Tallynn. Each count is an `NSMenuItemBadge`, so it sits at the menu's right edge in the column the shortcuts and submenu arrows use. Each repo row has a submenu of its releases with downloads (newest first, counts as badges). About opens an AppKit window laid out like BeeHan Brightness's. The menu bar text is `total.formatted()` next to an 18 pt template icon while the Menu bar placement is on.

### 6a. Settings window
`Settings.swift`, modeled on ClaudioStat's `Setup.swift`: a SwiftUI view in an `NSHostingController` inside an `NSWindow` (titled, closable, sized to fit, centred), with an `@Observable` `SettingsModel` that is the window's delegate. Its `Step` is GitHub CLI missing (install hint, Try Again, Get GitHub CLI), signed out (Sign in with GitHub), signing in (the copied code, Cancel, Open GitHub Again) or signed in. Closing the window cancels the sign-in, which terminates gh; after approval the window comes back in front of the browser. Signed in, it lists `fetchRepos` as checkboxes (lock on private, reload button, scrolling after 12 rows), and each tick calls `AppDelegate.show(_:_:)`. It opens at launch without a login, from the menu's problem line, from Settings…, and when the app is opened again while signed out.

### 7. Dock behavior
`Info.plist` sets `LSUIElement = true`. `Dock.swift` is copied from ClaudioStat as is: `inDock()` / `toggleDockTile()` edit `com.apple.dock persistent-apps` and restart the Dock. `applicationShouldHandleReopen` pops the menu at `NSEvent.mouseLocation`, or opens Settings while signed out, and returns `false`.

### 8. Icons
`Icon/make-icon.swift` draws the app icon from code, as ClaudioStat does, and `run.sh`/`build.sh` turn it into `AppIcon.icns`. The motif is Tallinn's Viru Gate, built once as `gateOutline`: two round towers with cone roofs and the crenellated gateway between them, five merlons centred so the gaps at both towers match, and the doorway cut through (`CGPath` normalized and subtracting). In the app icon it stands on the bottom edge at 1.08 of full size and 0.95 of that width, on a gradient from Estonian blue (#0072CE) through #003E73 to near-black. The gate is filled with a vertical gray gradient (#8F949B at the base up to #DCDFE3), lit by a bright rim (a white stroke inside the outline and soft inner glows) over a soft drop shadow, and its door is solid black. No arrow. The plate keeps ClaudioStat's soft bevel; its glows move their off-canvas caster by `away / scale`, because shadow offsets ignore the canvas scale and the rim otherwise vanished below 1024 px. The same outline in black, door cut out, becomes the 18 pt menu bar template `MenuBar.tiff`: 14 pt tall from 3.5 pt up, so its base sits on the total's baseline. Without a bundle (`swift run`) the app falls back to the SF Symbol `arrow.down.circle`.

### 9. Bundle
`com.zolfer.tallynn`, `CFBundleName` Tallynn, version 0.1.0, `LSMinimumSystemVersion` 26.0, no entitlements and no sandbox (it runs `gh`), signed ad hoc by the scripts unless `SIGN_ID` is set.

## Risks / Trade-offs

- [The GitHub CLI's token can write to the user's repositories] → Tallynn only sends GETs and keeps the token in memory only; the CLI already holds the same token.
- [`gh` installed somewhere other than the two Homebrew paths] → shown as "Install the GitHub CLI…". `ponytail:` fixed path list; resolve via the login shell's `PATH` if it ever matters.
- [gh changes the wording of its login prompt] → `loginPrompt` finds no code and Settings just waits while the page opens; gh still copies the code, so signing in keeps working.
- [Sign Out also signs the GitHub CLI out] → asked first, and said so in the alert.
- [A ticked repository renamed or deleted] → it is no longer listed and drops out silently; ticking the new name sets a fresh baseline.
- [Asset names in upper case (`.DMG`)] → not counted, exactly like the script. Parity matters more than catching these.
- [Keep in Dock restarts the Dock] → a brief Dock flicker, the same as in ClaudioStat. No API exists to avoid it.
- [Timers don't fire during sleep] → the overdue refresh runs on wake, which is fine for download counts.
- [Notification banners hidden while the screen is shared] → a macOS setting (allow notifications when mirroring or sharing), not something Tallynn can change.
