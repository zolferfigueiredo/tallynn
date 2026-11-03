<p align="center">
  <img src="Icon/icon.png" width="128" height="128" alt="Tallynn icon">
</p>

<h1 align="center">Tallynn</h1>

<h3 align="center">Every download, tallied.</h3>

<p align="center">
  Your GitHub release downloads, live in the macOS menu bar.<br>
  A notification and a sound the moment any of them changes.
</p>

<p align="center">
  <a href="https://www.swift.org"><img src="https://img.shields.io/badge/Swift-6.2-orange" alt="Swift 6.2"></a>
  <img src="https://img.shields.io/badge/Platform-macOS%2026%2B-blue" alt="macOS 26 or later">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-yellow" alt="MIT license"></a>
  <img src="https://img.shields.io/badge/GitHub_Actions-%240-brightgreen" alt="GitHub Actions: $0">
</p>

<p align="center">
  <a href="https://github.com/zolferfigueiredo/tallynn/releases/latest"><b>Download for macOS</b></a>
</p>

## Install

1. [Download the DMG](https://github.com/zolferfigueiredo/tallynn/releases/latest), open it and drag Tallynn to Applications.
2. Open Tallynn. It's signed and notarized by Apple, so macOS only asks you to confirm the first time.
3. Settings opens on General. Click **Sign in with GitHub**: github.com opens with a one-time code already on your clipboard, you paste it and approve. If the GitHub CLI is already signed in, Tallynn uses that login straight away. To count only other people's public repositories, skip signing in and add them under Repositories.
4. Tick the repositories to count. The total appears in the menu bar, and each repository in the menu with its most downloaded and newest release.

You need:

- macOS 26 or later, on Apple silicon or Intel
- The [GitHub CLI](https://cli.github.com) (`brew install gh`), which Tallynn signs in through, to count your own repositories
- Tallynn in Applications, for launch at login

## Features

- **Counts what people download.** Every project file of each repository's 50 newest releases: installers, packages, archives and binaries (`.dmg`, `.pkg`, `.exe`, `.msi`, `.zip`, `.tar.gz`, `.deb`, `.rpm`, `.AppImage`, `.bin`, plain binaries and the like). Checksums, signatures, the metadata updaters fetch (`latest-mac.yml`, `.blockmap`, appcasts) and GitHub's source code archives don't count.
- **Tells you right away.** One notification with a sound for each refresh that finds a change: `theej +3 (364)`, a line per repository. A drop, say after you delete a release, says `-30`. A release pushed out of the newest 50 by a new one is no drop. **Notifications** in Settings turns them off, along with the one about a new version.
- **No surprises.** The first refresh after signing in, and a repository you've just ticked, set a quiet baseline. Only the downloads after that are announced, and a relaunch never repeats them.
- **Most downloaded and newest.** Each repository's row shows its most downloaded release's downloads in a badge, and its newest release's in grey beside it, unless they're the same number.
- **Per version.** Each repository opens a submenu with its releases that have downloads, newest first, and the downloads of each. Clicking one opens its release page on GitHub, with its files, in your browser.
- **Public and private.** Pick any of your own repositories in Settings, with a lock on the private ones. New ones stay hidden until you tick them. Add anyone else's public repository by `owner/repo` or its GitHub link, signed in or not. Switched off, it stays in the list; its trash button removes it, after asking.
- **The total where you want it.** Each repository's most downloaded release, added up: in the menu bar, as a TOTAL row in the menu, both, or neither.
- **Never keeps a token.** It reads the GitHub CLI's login on each refresh and keeps it only in memory. It never stores, logs or shows a credential.
- **Updates itself.** **Check for updates…** finds a new release and installs it in one click, only if it's signed by the same developer. It can check daily or weekly on its own, and tells you once with a notification.
- **Native and tiny.** A small Swift app in the menu bar, with no Dock icon unless you choose **Keep in Dock**, and then clicking it opens the menu. It can launch at login.
- **In your language.** English, Deutsch, Español, Français, Italiano, Polski, Português, Русский, Українська, 中文, 日本語 and 한국어. It starts in your Mac's language, and **Language** on the General tab switches it.
- **From Tallinn.** The icon is Viru Gate, the two towers that open Tallinn's Old Town.

## How it works

Every 5, 10, 30 or 60 minutes, and when you choose **Refresh**, Tallynn asks GitHub for your repositories and their releases, and adds up the downloads.

- It asks the GitHub CLI for its token (`gh auth token`) on each refresh, so signing in, out or switching accounts in Terminal is followed straight away. **Sign in with GitHub** runs the CLI's own browser sign-in, and **Sign out** signs the CLI out on this Mac, after asking.
- It calls GitHub's REST API: `GET /user`, `GET /user/repos` (your own repositories, forks left out), `GET /repos/{owner}/{repo}` when you add one, and each ticked repository's 50 newest releases, in one request. Nothing is cached on disk. An added repository that's deleted or made private just isn't listed any more. Signed out, it asks about the added public repositories without a login, which GitHub allows 60 times an hour from your Mac: one request per repository each refresh, so with many of them pick a slower refresh rate.
- It keeps only the last counts and releases, to compare with the next refresh. A refresh that fails keeps them as they were, so a repository that couldn't be read never looks like a drop, and the menu says **Couldn't refresh**.
- **Check for updates…** asks GitHub for this repository's latest release with the same sign-in, since the repository is private, and downloads its DMG the same way. The token goes only to GitHub's API, not to the download's storage link. An update installs only if the app inside is signed by the same developer, has Tallynn's identifier and the expected version, and only into the copy in Applications. A window shows each step, and **Reopen** starts the new version.
- Only one copy runs at a time: opening another one, say from the DMG, quits the copy already running.

<details>
<summary><b>Every setting</b></summary>

- **Settings…** (⌘,), first in the menu, above the repositories:
  - **General**: **App** first, with the language, the **Refresh rate** (5, 10 (default) or 30 minutes, or 1 hour) and **Notifications** (on), then the **Total** (**Menu bar** on, **List** off), your GitHub account, and the repositories to count (yours, and any public ones you add).
  - **About**: the version with Check for updates, and links to the author, the website and Buy me a coffee.
- **Refresh** (⌘R), shown once there's a repository to count.
- **Launch at login** (from the Applications folder) and **Keep in Dock**, which asks first because macOS restarts the Dock to change it.
- **About Tallynn** opens Settings on About.
- **Check for updates…**, which reads **Update available!** once a check finds a new version, and **Check automatically** daily, weekly (default) or never.
- **Quit Tallynn** (⌘Q).

While signed out with nothing to count, the menu says **Sign in to GitHub…** and clicking the Dock icon opens Settings. Public repositories you added count without signing in. Without the GitHub CLI, it says **Install the GitHub CLI…**.

</details>

## Build from source

```bash
./build.sh
```

It runs the tests, builds a universal `dist/dmg/Tallynn.app` and writes `dist/Tallynn-<version>.dmg`, laid out by Finder with the app and an Applications shortcut. It needs Xcode 26 (Swift 6.2 or later). It signs ad hoc unless `SIGN_ID` names your signing identity. Every intermediate goes to a folder in `/tmp` that is deleted when the script ends.

To try a change, run `./run.sh`. It builds a debug copy in `/tmp/tallynn-run`, quits any running Tallynn and opens the new one. `swift test` runs the tests alone.

## Release

Raise both versions in `Info.plist` and merge to main. Every pull request runs `.github/workflows/ci.yml` on the same runner: shellcheck, the tests and the release build with warnings as errors, and a check that a change to the app raises its version, since merging one that doesn't releases nothing. `.github/workflows/release.yml` then runs `./release.sh` on the self-hosted runner on this Mac: it builds the DMG, signs it with Developer ID, notarizes it, and publishes it as a GitHub release. A version that's already released is skipped. A pull request that changes `release.sh`, `build.sh`, `Icon/` or `release.yml` runs `release.yml` as a trial: `./build.sh` only, the tests and the DMG signed ad hoc, with nothing signed with Developer ID, notarized or published.

The repository is private, so nothing runs on GitHub's own machines, which bill minutes there. Self-hosted runs are free, and so are releases and their downloads. Keep the GitHub Actions budget at $0 in Settings > Billing, so a job that ever lands on GitHub's machines fails instead of billing. `./release.sh` by hand does the same without Actions.

One-time setup: a runner for this repository labelled `release` (see "Add a runner" in `~/www/actions-runner`), and the `bihan` notary profile ClaudioStat already uses.

The plan lives in `openspec/`: see `openspec/changes/` for the proposals, specs, designs and tasks.

## Disclaimer

Unofficial. Not affiliated with or endorsed by GitHub. It uses the GitHub CLI and GitHub's public REST API.

## License

[MIT](LICENSE)

---

<p align="center">
  Made with ❤️ by <a href="https://zolfer.com">zolfer.com</a>
</p>
