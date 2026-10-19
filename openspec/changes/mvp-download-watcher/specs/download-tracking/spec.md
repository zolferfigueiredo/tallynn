# Spec Delta

## Purpose

Keeps an up-to-date download count for each of the logged-in GitHub user's public repositories, counted the same way as the author's existing shell script, and remembers the last counts seen.

## ADDED Requirements

### Requirement: GitHub CLI login
The app SHALL access GitHub using the GitHub CLI's existing login and SHALL NOT ask for, store or display a token itself.

#### Scenario: gh installed and logged in
- **WHEN** the GitHub CLI is installed and logged in
- **THEN** refreshes use that login and succeed without any setup in the app

#### Scenario: gh not installed
- **WHEN** no GitHub CLI executable is found
- **THEN** the refresh fails with a "GitHub CLI not found" problem and no counts change

#### Scenario: gh logged out
- **WHEN** the GitHub CLI is installed but not logged in
- **THEN** the refresh fails with a "not logged in to GitHub CLI" problem and no counts change

### Requirement: Repository discovery
On every refresh the app SHALL list the logged-in user's public repositories that are not forks. The username SHALL come from the login, never from the app's code or settings.

#### Scenario: Forks and private repositories excluded
- **WHEN** the user owns public source repositories, public forks and private repositories
- **THEN** only the public source repositories are counted

#### Scenario: New repository picked up
- **WHEN** the user creates a new public repository between two refreshes
- **THEN** the second refresh includes it

### Requirement: Download counting
A repository's count SHALL be the sum of `download_count` over every asset of every release whose file name ends in `.dmg`, `.exe` or `.zip`. All pages of releases SHALL be included.

#### Scenario: Only installer assets counted
- **WHEN** a release has `App.dmg` (300), `App.exe` (50), `App.zip` (10) and `checksums.txt` (99)
- **THEN** that release adds 360 to the repository's count

#### Scenario: Many releases
- **WHEN** a repository has more releases than fit on one API page
- **THEN** assets on every page are counted

#### Scenario: Matches the existing script
- **WHEN** the app and the author's shell script run against the same account at the same time
- **THEN** every repository count and the total are identical

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
A refresh that fails for any reason (network, GitHub error, rate limit, gh problem) SHALL leave the saved counts unchanged, SHALL NOT count as a change, and SHALL report the failure.

#### Scenario: Offline
- **WHEN** a refresh runs without network access
- **THEN** the previous counts stay shown and saved, a failure is reported, and the next scheduled refresh tries again
