# Proposal

## Why

Releases now publish a notarized `Tallynn-<version>.dmg` (see self-hosted-releases), but the installed app never learns about them: updating means downloading and replacing it by hand. ClaudioStat has **Check for updates…** and **Check automatically**. Tallynn should too, adapted to a private repository, where release files can't be downloaded anonymously.

## What Changes

- New menu items above Quit, as in ClaudioStat: **Check for updates…**, and a **Check automatically** submenu (Daily, Weekly by default, Never).
- A check asks GitHub's API for the latest release with the GitHub CLI login Tallynn already uses. Signed out, a check explains that it needs the sign-in.
- **Update now** downloads the release's DMG through the API, checks that the app inside is signed by the author's Developer ID team, has Tallynn's bundle identifier and the expected version, and replaces the copy in Applications. A progress window ends with **Reopen**.
- An automatic check that finds a new version says so once, in a notification; clicking it offers **Update now**. The menu item then reads "Update available!".

## Capabilities

### New Capabilities
- `app-updates`: checking for, announcing and installing new Tallynn releases.

### Modified Capabilities
<!-- none: menu-bar-ui and the other capabilities are still in the unarchived mvp-download-watcher change; the new items are specified in app-updates -->

## Impact

- New `Sources/Tallynn/Updates.swift`, adapted from ClaudioStat's. `Menu.swift`, `main.swift` and `Notifications.swift` change, plus tests and the README.
- GitHub API: one `GET /repos/zolferfigueiredo/tallynn/releases/latest` per check, and the asset download for an update.
- No change to `release.sh`: it already uploads `Tallynn-<version>.dmg` to release `v<version>`.
