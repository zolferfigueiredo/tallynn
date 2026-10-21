# Spec Delta

## Purpose

Keeps the installed Tallynn current with the releases published on GitHub: checking on request or on a schedule, announcing a new version, and installing it only when it is the author's signed build.

## ADDED Requirements

### Requirement: Check for updates
**Check for updates…** SHALL ask GitHub for the latest published release of Tallynn, using the GitHub CLI login, and compare its version with the running one. It SHALL say whether Tallynn is up to date, offer **Update now** or **Later** for a newer version, or say the check failed.

#### Scenario: Up to date
- **WHEN** the latest release is v0.2.0 and Tallynn 0.2.0 is running
- **THEN** an alert says Tallynn is up to date

#### Scenario: Newer version
- **WHEN** the latest release is v0.3.0 and Tallynn 0.2.0 is running
- **THEN** an alert says Tallynn 0.3.0 is available and offers Update now and Later

#### Scenario: Offline
- **WHEN** GitHub can't be reached
- **THEN** an alert says the check failed, and nothing else changes

#### Scenario: Signed out
- **WHEN** the user checks for updates while signed out
- **THEN** an alert says signing in with GitHub is needed first

### Requirement: Check automatically
The **Check automatically** submenu SHALL offer Daily, Weekly (default) and Never, with the current choice checked. A due check SHALL run at launch once signed in, and the app SHALL look hourly whether one is due. An automatic check SHALL stay silent unless it finds a newer version.

#### Scenario: Weekly
- **WHEN** Weekly is chosen and the last check was 8 days ago
- **THEN** a check runs at launch, or within the hour

#### Scenario: Never
- **WHEN** Never is chosen
- **THEN** no automatic check runs

### Requirement: Announce a new version once
When an automatic check finds a newer version, the app SHALL post one notification for that version, never again for the same version, and clicking it SHALL check again and offer **Update now**. If notifications aren't allowed, it SHALL show the Update now alert instead. While a newer version is known, the menu item SHALL read "Update available!" over "Install version X now".

#### Scenario: Notification
- **WHEN** an automatic check finds 0.3.0 for the first time
- **THEN** a notification says Tallynn 0.3.0 is available, and the next automatic checks post nothing more for 0.3.0

#### Scenario: Menu item
- **WHEN** 0.3.0 is known and 0.2.0 is running
- **THEN** the menu shows "Update available!" with "Install version 0.3.0 now" in place of Check for updates…

### Requirement: Install only the author's build
**Update now** SHALL download the release's `Tallynn-<version>.dmg`, and SHALL replace the running app only if the app inside is signed by the author's Developer ID team (497V6MCDS8), has Tallynn's bundle identifier and the expected version. It SHALL install only into a copy in /Applications. A window SHALL show each step and end with **Reopen**, which starts the new version; after it starts, an alert SHALL say the update is complete, once.

#### Scenario: Successful update
- **WHEN** the user picks Update now in /Applications/Tallynn.app and the DMG holds a valid signed Tallynn 0.3.0
- **THEN** the app is replaced, Reopen starts 0.3.0, and an alert says it is now using 0.3.0

#### Scenario: Wrong signature
- **WHEN** the downloaded app isn't signed by team 497V6MCDS8
- **THEN** nothing is replaced, and an alert says the update didn't install, offering to open the release page

#### Scenario: Not in Applications
- **WHEN** the running copy isn't in /Applications
- **THEN** nothing is downloaded, and an alert says updates install only into the copy in Applications
