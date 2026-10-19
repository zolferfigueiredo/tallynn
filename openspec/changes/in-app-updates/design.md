# Design

## Context

See proposal.md for why. ClaudioStat's `Updates.swift` reads the version from `releases/latest/download/latest.json` and downloads `releases/download/v<version>/ClaudioStat-<version>.dmg`, both anonymously, which works only for a public repository.

## Goals / Non-Goals

**Goals:**
- ClaudioStat's update experience, menu items, notification, progress window and safety checks, for a private repository.

**Non-Goals:**
- Delta updates, Sparkle, a Homebrew cask, localization.

## Decisions

- **The latest release comes from the API.** `GET /repos/zolferfigueiredo/tallynn/releases/latest`, using the existing `get(_:token:)` and the GitHub CLI token Tallynn already keeps in memory. The version is the tag without its `v`, and the DMG is the asset named `Tallynn-<version>.dmg`. No `latest.json`, so `release.sh` doesn't change.
- **The DMG downloads through the asset's API URL** with `Accept: application/octet-stream` and the token. GitHub redirects to a pre-signed storage URL, which rejects a second credential, so a task delegate drops `Authorization` on any redirect away from api.github.com. The token never leaves GitHub's API host.
- **Safety checks are ClaudioStat's, unchanged:**
  - `codesign --verify --strict` against the team requirement (`certificate leaf[subject.OU] = "497V6MCDS8"`);
  - the bundle identifier and version;
  - only into /Applications;
  - `FileManager.replaceItemAt`, and a relaunch that waits for this process to quit.
- **Signed out:** a manual check explains that the sign-in is needed, and automatic checks skip quietly. Being signed in is the only way to read a private repository's releases.
- **Process runs reuse `exitStatus(_:)`** from GitHub.swift instead of ClaudioStat's separate `run`.
- **English strings inline,** since Tallynn isn't localized.

## Risks / Trade-offs

- [The user signs the GitHub CLI into an account without access to the repository] → the check fails like an offline one; the alert says to check the connection and sign-in.
- [GitHub changes how asset downloads redirect] → the update fails safely (nothing replaced), and the alert's Download opens the release page.
