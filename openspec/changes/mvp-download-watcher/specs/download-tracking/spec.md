# Spec Delta

## Purpose

Keeps an up-to-date download count for each repository the signed-in GitHub user chose to show, counted the same way as the author's existing shell script, and remembers the last counts seen.

## ADDED Requirements

### Requirement: Sign in with GitHub
The app SHALL sign in with the GitHub OAuth device flow, asking for the `repo` scope, and SHALL keep the token only in the login Keychain: never in preferences, never in the log. Without a token the app SHALL NOT refresh.

#### Scenario: Sign in
- **WHEN** the user starts signing in, enters the code shown on github.com and approves
- **THEN** the token is saved in the Keychain, the account name is shown, and a refresh starts

#### Scenario: Code denied or expired
- **WHEN** the user cancels on github.com, or the code expires before it is entered
- **THEN** no token is saved and the app says why and offers to sign in again

#### Scenario: Sign out
- **WHEN** the user signs out
- **THEN** the token is deleted from the Keychain and the saved counts, releases and last refresh time are cleared, while the chosen repositories are kept

#### Scenario: Token revoked
- **WHEN** GitHub answers a refresh with 401
- **THEN** the app signs out as above

#### Scenario: Not signed in
- **WHEN** no token is saved
- **THEN** no request is made to GitHub and the app shows that it needs a sign-in

### Requirement: Repository discovery
The app SHALL list the signed-in user's own public and private repositories that are not forks, never organization repositories. The account SHALL come from the sign-in, never from the app's code or settings.

#### Scenario: Forks and other owners excluded
- **WHEN** the user owns public and private source repositories and forks, and belongs to an organization
- **THEN** only the user's own public and private source repositories are listed

#### Scenario: New repository listed
- **WHEN** the user creates a repository between two refreshes
- **THEN** it appears in the list of repositories to choose from

### Requirement: Repository selection
Only repositories the user ticked in Settings SHALL be counted. A repository not ticked yet, including a new one, SHALL stay hidden. Ticking SHALL start a refresh; unticking SHALL remove the repository at once.

#### Scenario: New repository hidden
- **WHEN** a new repository appears in the list
- **THEN** it is not counted or shown until the user ticks it

#### Scenario: Tick and untick
- **WHEN** the user ticks a repository, then unticks it
- **THEN** a refresh adds its count, and unticking removes it from the menu and the total without a refresh

#### Scenario: Upgrade from the version without a picker
- **WHEN** the app first runs with saved counts and no saved choice
- **THEN** the repositories whose saved counts are above 0 start ticked

#### Scenario: Another account
- **WHEN** a different GitHub account signs in than the last one
- **THEN** no repository is ticked and the saved counts are cleared

### Requirement: Download counting
A repository's count SHALL be the sum of `download_count` over every asset of every release whose file name ends in `.dmg`, `.exe` or `.zip`. All pages of releases SHALL be included.

#### Scenario: Only installer assets counted
- **WHEN** a release has `App.dmg` (300), `App.exe` (50), `App.zip` (10) and `checksums.txt` (99)
- **THEN** that release adds 360 to the repository's count

#### Scenario: Many releases
- **WHEN** a repository has more releases than fit on one API page
- **THEN** assets on every page are counted

#### Scenario: Matches the existing script
- **WHEN** the app shows the same public repositories the author's shell script counts, at the same time
- **THEN** every repository count and the total are identical

### Requirement: Downloads per release
For each repository the app SHALL keep each release's installer downloads, by tag and newest first as GitHub lists them, from the same refresh as the counts, and save them with the counts. A repository's count SHALL be the sum of its releases.

#### Scenario: Releases kept
- **WHEN** a refresh finds theej v2.5.0 with 38 installer downloads and v2.4.2 with 5
- **THEN** both are saved in that order, and theej's count includes them

#### Scenario: Shown after a relaunch
- **WHEN** the app relaunches before its first refresh
- **THEN** the per-release downloads saved by the last successful refresh are available

### Requirement: Total
The total SHALL be the sum of all repository counts from the same refresh.

#### Scenario: Total of repositories
- **WHEN** repositories count 361, 16 and 34
- **THEN** the total is 411

### Requirement: Refresh interval
The app SHALL refresh every 5, 10, 30 or 60 minutes, as chosen by the user, defaulting to 10. The choice SHALL persist across launches. The app SHALL also refresh at launch and when the user asks.

#### Scenario: Default interval
- **WHEN** the app runs for the first time
- **THEN** it refreshes at launch and then every 10 minutes

#### Scenario: Interval changed
- **WHEN** the user picks 30 minutes
- **THEN** the app refreshes now, then every 30 minutes, and still uses 30 after a relaunch

#### Scenario: Refreshes never overlap
- **WHEN** a refresh is due while the previous one is still running
- **THEN** no second refresh starts

### Requirement: Remembered counts
After every successful refresh the app SHALL save each repository's count, and SHALL load the saved counts at launch, so restarts do not lose the last-seen state.

#### Scenario: Relaunch
- **WHEN** the app quits and launches again
- **THEN** the counts saved before quitting are used for comparison and shown until the first refresh finishes

### Requirement: Failed refresh keeps last counts
A refresh that fails for any reason (network, GitHub error, rate limit) SHALL leave the saved counts unchanged, SHALL NOT count as a change, and SHALL report the failure.

#### Scenario: Offline
- **WHEN** a refresh runs without network access
- **THEN** the previous counts stay shown and saved, a failure is reported, and the next scheduled refresh tries again
