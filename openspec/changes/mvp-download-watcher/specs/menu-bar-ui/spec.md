# Spec Delta

## Purpose

Gives the user an always-visible total in the menu bar and one menu for the per-repository counts and every setting, reachable from the menu bar or the Dock, with no windows.

## ADDED Requirements

### Requirement: Menu bar only
The app SHALL run without windows and without a running-app indicator in the Dock or the app switcher. Its only UI SHALL be the menu bar item, its menu and notifications.

#### Scenario: Launch
- **WHEN** the app launches
- **THEN** only the Tallynn menu bar item appears; no window opens

### Requirement: Single copy
Launching a copy of the app SHALL quit any other running copy, so exactly one menu bar item exists.

#### Scenario: New build opened
- **WHEN** a freshly built copy opens while the installed copy runs
- **THEN** the installed copy quits and the new one takes over

### Requirement: Menu bar item
The menu bar item SHALL show the Tallynn icon followed by the total. Before any counts exist it SHALL show the icon alone.

#### Scenario: Counts known
- **WHEN** the total is 1111
- **THEN** the menu bar shows the icon and "1,111"

#### Scenario: First launch before the first refresh finishes
- **WHEN** no counts have been saved yet
- **THEN** the menu bar shows the icon alone

### Requirement: Counts in the menu
The menu SHALL list each repository with a count above 0 and its count, sorted by count with the highest first, followed by a TOTAL row and the time of the last successful refresh. Repositories with 0 SHALL be hidden.

#### Scenario: Script's example
- **WHEN** counts are claudiostat 430, theej 361, bhbrightness 270, wrecktangle 34, weej 16, zolferfigueiredo 0
- **THEN** the menu lists claudiostat, theej, bhbrightness, wrecktangle, weej with their counts, then "TOTAL 1,111", and zolferfigueiredo does not appear

### Requirement: Menu actions
The menu SHALL offer: Refresh now, an interval choice (5, 10, 30, 60 minutes) with the current one checked, Launch at login, Keep in Dock, and Quit. Launch at login and Keep in Dock SHALL show a checkmark when on.

#### Scenario: Refresh now
- **WHEN** the user picks Refresh now
- **THEN** a refresh starts immediately

#### Scenario: Launch at login
- **WHEN** the user turns on Launch at login
- **THEN** the app starts automatically at the next login, and the item shows a checkmark

### Requirement: Keep in Dock
Keep in Dock SHALL pin the app's icon to the Dock or unpin it, like the Dock's own "Keep in Dock" option, and its checkmark SHALL reflect whether the app is currently pinned.

#### Scenario: Pin
- **WHEN** the user turns on Keep in Dock
- **THEN** the Tallynn icon appears in the Dock and stays there across logins

#### Scenario: Unpin
- **WHEN** the user turns Keep in Dock off
- **THEN** the Tallynn icon is removed from the Dock

### Requirement: Opening the app again shows the menu
Opening the app while it is running (clicking its Dock icon, Spotlight, Finder) SHALL pop up the same menu at the pointer instead of opening a window.

#### Scenario: Dock click
- **WHEN** the user clicks the pinned Tallynn icon in the Dock
- **THEN** the menu appears at the pointer

#### Scenario: Menu bar icon hidden by the notch
- **WHEN** the menu bar item is hidden and the user opens Tallynn from Spotlight
- **THEN** the menu appears at the pointer

### Requirement: Problems shown in the menu
When the last refresh failed, the menu SHALL show a problem line above the counts, and the menu bar SHALL keep showing the last known total. GitHub CLI problems SHALL say how to fix them.

#### Scenario: gh missing
- **WHEN** the GitHub CLI is not found
- **THEN** the menu says "GitHub CLI not found. Install it with: brew install gh"

#### Scenario: gh logged out
- **WHEN** the GitHub CLI is not logged in
- **THEN** the menu says "Not logged in. Run in Terminal: gh auth login"

#### Scenario: Network or GitHub failure
- **WHEN** a refresh fails for another reason
- **THEN** the menu says "Couldn't refresh" with the time of the last successful refresh, and the counts stay as they were
