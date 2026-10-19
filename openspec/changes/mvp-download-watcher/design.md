# Design

## Context

Greenfield. See proposal.md for why. Two existing assets shape the approach:

- **The author's shell script** defines what is counted (`gh repo list --visibility public --source`, then `gh api repos/<owner>/<repo>/releases --paginate` summing `.dmg|.exe|.zip` asset `download_count`). Tallynn must produce the same numbers.
- **`~/www/claudiostat`** is a menu bar app by the same author with the behavior Tallynn copies (LSUIElement, Keep in Dock, Dock click pops the menu, launch at login, notifications, a SwiftUI setup window) and the build setup (SwiftPM, `run.sh`, `build.sh`, `Icon/make-icon.swift`). Deploydz behaves the same way.

The machine has Xcode 26.6 / Swift 6.3 and a Developer ID Application signing identity. The first version used the `gh` CLI; it was replaced by signing in with GitHub so repositories can be chosen, private ones included.

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

### 2. GitHub REST over `URLSession`, signed in with the device flow
Requests run off the main actor (`@concurrent` functions in `GitHub.swift`) on an ephemeral `URLSession` with `urlCache = nil`: GitHub allows 60 seconds of caching, which would make Refresh show old counts and write private repositories' data to disk.
1. `GET /user/repos?affiliation=owner&visibility=all&per_page=100`: the user's own public and private repositories; `sourceRepos(_:)` drops forks and sorts them like Finder.
2. For each ticked repository, `GET /repos/{full_name}/releases?per_page=100`; `releaseDownloads(_:)` sums each release's `.dmg`/`.exe`/`.zip` assets, unit-tested on decoded JSON.
Both lists follow the `Link` header's `rel="next"` (`nextPage(_:)`, unit-tested). A 401 means signed out; any other failure fails the whole refresh, so a repository that couldn't be read never looks like a drop. `GET /user` gives the login once, at sign-in.

Sign-in is GitHub's OAuth device flow: `POST github.com/login/device/code` with the client ID and `scope=repo`, show the user code, then poll `POST github.com/login/oauth/access_token` (grant type `urn:ietf:params:oauth:grant-type:device_code`) every `interval` seconds, adding 5 on `slow_down`, until a token, `access_denied`, `expired_token` or `device_flow_disabled`. Both requests send `Accept: application/json`, or GitHub answers form-encoded. No client secret is involved; the client ID is public and lives in Info.plist as `GitHubClientID`.
- *Alternatives:* keep `gh` (no private-repo choice without its own login, an extra install); a personal access token field (manual, expires, pasted secrets); a GitHub App (read-only permissions, but expiring tokens need refreshing, which needs a secret). `repo` is the only OAuth scope that reaches private repositories and it allows writing; Tallynn only sends GETs.

### 2a. Token in the login Keychain
One generic password (service `com.zolfer.tallynn`, account `github`) in `Keychain.swift`; read once at launch into memory, never in UserDefaults, never logged. The data protection keychain would need restricted entitlements a SwiftPM app can't have, so it is the legacy login keychain, whose access is tied to the code signature. `run.sh` and `build.sh` therefore sign with the first Developer ID Application identity (`security find-identity`), falling back to ad hoc; with ad hoc builds the Keychain asks again after every rebuild.

### 3. State in `UserDefaults`
- `shownRepos`: the ticked repository names. When unset at launch it is migrated from `counts` (`migratedShownRepos`: those above 0), so upgrading keeps the menu.
- `login`: the account last signed in. A different login clears `shownRepos` and the counts.
- `releases`: JSON of `[String: [Release]]` by repo name (tag and installer downloads, newest first), for the per-version submenus.
- `counts`: `[String: Int]` by repo name, `repoCounts(releases)`, saved with `releases` and filtered by `shownRepos` at save time. A repository without a saved count is a silent baseline (`changes(old:new:)`), so ticking one, or the first refresh after signing in, never notifies its history.
- `lastRefresh`: `Date` of the last success. `interval`: minutes, default 10. `totalInMenuBar` (default on) and `totalInList` (default off), read through `totalPlaces`, which keeps the bar total if both are off.
- Sign Out or a 401 deletes the token and clears `counts`, `releases` and `lastRefresh`, keeping the picks. A refresh that comes back after the token changed is dropped, and an `again` flag runs one more refresh when repositories were ticked during one.
- Pure functions (no AppKit) hold the logic the specs test: `releaseDownloads`, `repoCounts`, `total`, `changes`, `notificationBody`, `menuRows`, `sourceRepos`, `migratedShownRepos`, `totalPlaces`.

### 4. Scheduling
Copy ClaudioStat's `reschedule()`: invalidate, `tick()` now, then a repeating `Timer` on `RunLoop.main` in `.common` mode with a few seconds' tolerance. A `busy` flag makes `tick()` a no-op while a refresh runs. Changing the interval calls `reschedule()`.

### 5. Notifications
Same as ClaudioStat's `post()`: `UNUserNotificationCenter.requestAuthorization([.alert, .sound])` on first use, title "Tallynn", body from `notificationBody`, `sound = .default`, a unique identifier per refresh so earlier notices stay in Notification Center. Notifications need a real bundle, so development runs go through `run.sh`, not `swift run`.

### 6. Menu
Rebuilt in `menuNeedsUpdate(_:)` with `autoenablesItems = false`, as in ClaudioStat. The order is: optional problem line ("Sign in to GitHub…" opening Settings, or "Couldn’t refresh") or, signed in with nothing ticked, "Choose Repositories…"; repo rows (count > 0, alphabetical); the bold TOTAL row when the List placement is on; separator; "Updated HH:mm", Refresh (disabled while signed out), Refresh rate (5/10/30/60 minutes); separator; Settings… (⌘,), Total (Menu bar, List; the last one on is disabled); separator; Launch at Login (`SMAppService.mainApp`), Keep in Dock; separator; About Tallynn (`info.circle`), Quit Tallynn. Each count is an `NSMenuItemBadge`, so it sits at the menu's right edge in the column the shortcuts and submenu arrows use. Each repo row has a submenu of its releases with downloads (newest first, counts as badges). About opens an AppKit window laid out like BeeHan Brightness's. The menu bar text is `total.formatted()` next to an 18 pt template icon while the Menu bar placement is on.

### 6a. Settings window
`Settings.swift`, modeled on ClaudioStat's `Setup.swift`: a SwiftUI view in an `NSHostingController` inside an `NSWindow` (titled, closable, sized to fit, centred), with an `@Observable` `SettingsModel` that is the window's delegate. Its `Step` is signed out, starting, waiting (the device code), or signed in. Closing the window cancels the sign-in task; after approval the window comes back in front of the browser. Signed in, it lists `fetchRepos` as checkboxes (lock on private, reload button, scrolling after 12 rows), and each tick calls `AppDelegate.show(_:_:)`. It opens at launch while signed out, from "Sign in to GitHub…", from Settings…, and when the app is opened again while signed out.

### 7. Dock behavior
`Info.plist` sets `LSUIElement = true`. `Dock.swift` is copied from ClaudioStat as is: `inDock()` / `toggleDockTile()` edit `com.apple.dock persistent-apps` and restart the Dock. `applicationShouldHandleReopen` pops the menu at `NSEvent.mouseLocation`, or opens Settings while signed out, and returns `false`.

### 8. Icons
`Icon/make-icon.swift` draws the app icon from code, as ClaudioStat does, and `run.sh`/`build.sh` turn it into `AppIcon.icns`. The motif is Tallinn's Viru Gate as a flat white silhouette (two round towers with cone roofs and the crenellated gateway between them) at 1.08 of full size and 0.95 of that width, standing on the bottom edge, its door solid black, on a gradient from Estonian blue (#0072CE) through #003E73 to near-black. The gate stays flat white on purpose: in the Dock, macOS 26 shades it from white to grey and lights the rim, which is the look the author picked; drawing that shading in as well doubles it. Earlier sketches (limestone and red roofs, a download arrow, Old Thomas, wall towers) were dropped. The same silhouette in black, with the door cut out, becomes the 18 pt menu bar template `MenuBar.tiff`: 14 pt tall from 3.5 pt up, so its base sits on the total's baseline. Without a bundle (`swift run`) the app falls back to the SF Symbol `arrow.down.circle`.

### 9. Bundle
`com.zolfer.tallynn`, `CFBundleName` Tallynn, version 0.1.0, `LSMinimumSystemVersion` 26.0, `GitHubClientID`, no entitlements and no sandbox, signed by the scripts with the Developer ID identity (hardened runtime in `build.sh`) or ad hoc without one.

## Risks / Trade-offs

- [The `repo` scope can write to every repository the user owns] → the token is only in the Keychain and Tallynn only sends GETs; a GitHub App with read-only permissions is the upgrade path if that matters, at the cost of token refreshing.
- [Ad hoc builds make the Keychain ask again after every rebuild] → the scripts sign with the Developer ID identity; documented in the README.
- [Enable Device Flow not ticked on the OAuth app] → `device_flow_disabled` gets its own message; with no client ID at all, Sign in is disabled and says so.
- [A ticked repository renamed or deleted] → it is no longer listed and drops out silently; ticking the new name sets a fresh baseline.
- [Asset names in upper case (`.DMG`)] → not counted, exactly like the script. Parity matters more than catching these.
- [Keep in Dock restarts the Dock] → a brief Dock flicker, the same as in ClaudioStat. No API exists to avoid it.
- [Timers don't fire during sleep] → the overdue refresh runs on wake, which is fine for download counts.
- [Notification banners hidden while the screen is shared] → a macOS setting (allow notifications when mirroring or sharing), not something Tallynn can change.
