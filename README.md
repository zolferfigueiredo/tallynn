# Tallynn

A macOS menu bar app that keeps a tally of your GitHub release downloads and plays a sound when they change.

Every 5, 10, 30 or 60 minutes it counts the downloads of `.dmg`, `.exe` and `.zip` release assets across the repositories you pick, public or private. The total sits in the menu bar, each repository's count is in the menu with a submenu of downloads per release, and every change arrives as one notification, such as "theej +3 (364)".

The art comes from Tallinn's Old Town.

## Requirements

- macOS 26
- A GitHub OAuth app for signing in, registered once (below).

## Sign in with GitHub

Tallynn signs in with GitHub's device flow: Settings shows a short code, you enter it on github.com, and the token is kept in your login Keychain. It never asks for a password and needs no client secret. Before the first build, register an OAuth app:

1. On GitHub, open Settings, Developer settings, OAuth Apps, New OAuth App.
2. Name it Tallynn, set the homepage to this repository, and give any https URL as the callback (the device flow doesn't use it).
3. Register it, tick **Enable Device Flow**, and save.
4. Put its Client ID in `Info.plist`: `<key>GitHubClientID</key><string>YOUR_CLIENT_ID</string>`. A client ID is public, not a secret.

Tallynn asks for the `repo` scope because it is the only one that reaches private repositories. That scope also allows writing, but Tallynn only reads. You can revoke its access at any time under GitHub Settings, Applications, Authorized OAuth Apps.

In Settings, tick the repositories to show; new ones stay hidden until you tick them. The **Total** menu puts the total in the menu bar, in the list, or both.

## Run

```bash
./run.sh
```

This builds a debug `Tallynn.app` in `/tmp/tallynn-run`, quits any running copy, and opens it. Run the tests with `swift test`.

## Build and install

```bash
./build.sh
```

This runs the tests and writes a universal `dist/Tallynn.app`, signed with your first Developer ID Application identity, or ad hoc without one. Set `SIGN_ID` to pick another identity. A stable signature matters: an ad hoc build makes the Keychain ask again for the saved sign-in after every rebuild. Then install it:

```bash
ditto dist/Tallynn.app /Applications/Tallynn.app
```

Open it from /Applications. A newly opened copy quits any other running copy. Launch at Login is available only for the copy in /Applications.

The plan lives in `openspec/`: see `openspec/changes/mvp-download-watcher/` for the proposal, specs, design and tasks.
