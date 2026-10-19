# Design

## Context

See proposal.md for why. ClaudioStat's `release.yml` builds the unsigned app on GitHub's `macos-26` runner and signs, notarizes and publishes on the self-hosted runner. That is free only because ClaudioStat is public.

## Goals / Non-Goals

**Goals:**
- A notarized, Finder-styled DMG on a GitHub release for every new version merged to main.
- No GitHub-hosted minutes, artifacts or caches.

**Non-Goals:**
- In-app updates (ClaudioStat's `latest.json`), a Homebrew cask, CI on pull requests.

## Decisions

- **One self-hosted job.** `runs-on: [self-hosted, macOS, release]` runs `release.sh` from start to finish. Splitting build and sign across machines needs an artifact, which counts toward the private repository's shared storage allowance. One job on one Mac needs none.
- **No `pull_request` trigger and no CI workflow.** `build.sh` runs `swift test` before every release, and locally `swift test` and `run.sh` cover changes.
- **No `GH_TOKEN`.** `gh` uses z's own login on the runner, so releases are zolferfigueiredo's, as in ClaudioStat.
- **Notarization reuses the `bihan` keychain profile** ClaudioStat already stores (same Apple team).
- **The DMG layout copies ClaudioStat's `build.sh`.** 640×400 window, 128 pt icons at (160, 190) and (480, 190), background inside the app. The background is the icon plate's Estonian blue fading to black, mid blue behind the icon labels so they stay readable.
- **The workflow file is named `release.yml`,** because Deploydz shows the repositories in its `releases` list by that workflow.

## Risks / Trade-offs

- [GitHub's postponed $0.002/min fee for self-hosted runners on private repositories arrives] → about 1 to 2 cents a release; or delete the workflow and run `./release.sh` by hand, which does the same with no Actions.
- [The Mac is off or asleep when main changes] → GitHub queues the job for up to 24 hours; **Run workflow** starts it again after that.
- [A job added later uses GitHub's machines] → keep the Actions budget at $0 so it fails instead of billing.
