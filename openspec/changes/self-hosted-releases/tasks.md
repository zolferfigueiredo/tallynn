# Tasks

## 1. Release build

- [x] 1.1 Raise `Info.plist` to 0.2.0 (both versions) and verify `plutil -p Info.plist` shows 0.2.0
- [x] 1.2 Add `Icon/make-dmg-background.swift` (blue to black, arrow from the app to Applications) and verify it writes background.png and background@2x.png
- [x] 1.3 Make `build.sh` write the Finder-styled `dist/Tallynn-<version>.dmg` as ClaudioStat's does, and verify with `SIGN_ID=... ./build.sh` that the app passes `codesign --verify --strict` and the mounted DMG shows the layout

## 2. Publishing

- [x] 2.1 Add `release.sh` (skip if released, build, sign the DMG, notarize with the `bihan` profile, staple, `spctl`, `gh release create`) and verify `shellcheck release.sh` passes
- [x] 2.2 Add `.github/workflows/release.yml` with one job on `[self-hosted, macOS, release]` and no hosted jobs or artifacts, and verify the YAML parses with that `runs-on`
- [x] 2.3 Document releasing, the one-time setup and the $0 budget tip in `README.md`, and verify the steps match the scripts

## 3. Runner

- [x] 3.1 Register `~/www/actions-runner/tallynn` with the `release` label as the actions-runner README describes, and verify `gh api repos/zolferfigueiredo/tallynn/actions/runners` shows `tallynn-mac` online
- [ ] 3.2 Add zolferfigueiredo/tallynn to Deploydz's `releases` list next to the five apps, reopen Deploydz when no deploy is running, and verify Tallynn appears under Apps

## 4. First release

- [ ] 4.1 After the pull request is merged, verify the run succeeds on `tallynn-mac`, `v0.2.0` has `Tallynn-0.2.0.dmg`, and the downloaded DMG passes `xcrun stapler validate` and `spctl -a -t open --context context:primary-signature`
- [ ] 4.2 Verify GitHub Billing shows no GitHub-hosted Actions minutes used by tallynn
