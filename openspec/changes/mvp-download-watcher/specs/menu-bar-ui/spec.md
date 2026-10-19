# Spec Delta

## Purpose

Gives the user an always-visible total and one menu for the per-repository counts and quick settings, reachable from the menu bar or the Dock, with a Settings window for signing in and choosing repositories.

## ADDED Requirements

### Requirement: Menu bar only
The app SHALL run without a running-app indicator in the Dock or the app switcher. Its windows SHALL be Settings and About, opened only on request, except that Settings SHALL open at launch while signed out.

#### Scenario: Launch signed in
- **WHEN** the app launches with a saved sign-in
- **THEN** only the Tallynn menu bar item appears; no window opens

#### Scenario: Launch signed out
- **WHEN** the app launches without a saved sign-in
- **THEN** the menu bar item appears and Settings opens to sign in

### Requirement: Single copy
Launching a copy of the app SHALL quit any other running copy, so exactly one menu bar item exists.

#### Scenario: New build opened
- **WHEN** a freshly built copy opens while the installed copy runs
- **THEN** the installed copy quits and the new one takes over

### Requirement: Menu bar item
The menu bar item SHALL show the Tallynn icon followed by the total while the total's Menu bar placement is on. Before any counts exist, while signed out, or with that placement off, it SHALL show the icon alone.

#### Scenario: Counts known
- **WHEN** the total is 1111 and the Menu bar placement is on
- **THEN** the menu bar shows the icon and "1,111"

#### Scenario: First launch before the first refresh finishes
- **WHEN** no counts have been saved yet
- **THEN** the menu bar shows the icon alone

#### Scenario: Menu bar placement off
- **WHEN** the total shows only in the list
- **THEN** the menu bar shows the icon alone

#### Scenario: Signed out
- **WHEN** no account is signed in
- **THEN** the menu bar shows the icon alone

### Requirement: Counts in the menu
The menu SHALL list each shown repository with a count above 0, alphabetically as Finder sorts names, with its count at the menu's right edge. Repositories with 0 SHALL be hidden. While the total's List placement is on, a bold TOTAL row with the total SHALL follow them. Signed in with no repository ticked, the menu SHALL offer "Choose Repositories…", opening Settings.

#### Scenario: Script's example
- **WHEN** counts are claudiostat 430, theej 361, bhbrightness 270, wrecktangle 34, weej 16, zolferfigueiredo 0, and the List placement is off
- **THEN** the menu lists bhbrightness, claudiostat, theej, weej, wrecktangle with their counts at the right edge, with no TOTAL row, and zolferfigueiredo does not appear

#### Scenario: Total in the list
- **WHEN** the List placement is on and the total is 1111
- **THEN** a bold TOTAL row with 1,111 at the right edge follows the repositories

#### Scenario: Nothing ticked yet
- **WHEN** the user is signed in and has ticked no repository
- **THEN** the menu shows "Choose Repositories…", which opens Settings

### Requirement: Downloads per version
Each repository row SHALL open a submenu listing that repository's releases with downloads above 0, newest first, each with its count at the right edge.

#### Scenario: Releases of a repository
- **WHEN** claudiostat has v0.6.0 with 78 downloads, v0.5.0 with 287 and v0.4.10 with 0
- **THEN** hovering claudiostat shows v0.6.0 78, then v0.5.0 287, and no v0.4.10 row

### Requirement: Menu actions
Below the counts and a separator, the menu SHALL show the time of the last successful refresh, then Refresh and a Refresh rate submenu (5, 10, 30, 60 minutes) with the current one checked. After a separator come Settings… (⌘,) and the Total submenu; after another, Launch at Login and Keep in Dock, each with a checkmark when on; after a last one, About Tallynn directly above Quit Tallynn.

#### Scenario: Refresh
- **WHEN** the user picks Refresh while signed in
- **THEN** a refresh starts immediately

#### Scenario: Refresh while signed out
- **WHEN** no account is signed in
- **THEN** Refresh is disabled

#### Scenario: Launch at login
- **WHEN** the user turns on Launch at Login
- **THEN** the app starts automatically at the next login, and the item shows a checkmark

### Requirement: Total placement
The Total submenu SHALL offer Menu bar and List, each checked when on, defaulting to Menu bar on and List off. Either or both MAY be on, but the last one on SHALL NOT be turned off, and the choice SHALL persist.

#### Scenario: Default
- **WHEN** the user has never changed it
- **THEN** the total shows in the menu bar and not as a menu row

#### Scenario: Both
- **WHEN** the user turns List on as well
- **THEN** the total shows in the menu bar and as a TOTAL row

#### Scenario: List only
- **WHEN** the user then turns Menu bar off
- **THEN** the menu bar shows the icon alone and the menu keeps the TOTAL row

#### Scenario: Last one on
- **WHEN** only one placement is on
- **THEN** its item is disabled, so the total always shows somewhere

### Requirement: Settings window
Settings SHALL let the user sign in and out and choose repositories. Signed out it SHALL offer "Sign in with GitHub"; while signing in it SHALL show the code in large type with "Copy Code & Open GitHub" and Cancel; signed in it SHALL show "Signed in as @login" with Sign Out and the user's repositories A to Z as checkboxes, private ones with a lock, and a way to reload the list. Every tick SHALL apply at once.

#### Scenario: Signing in
- **WHEN** the user picks Sign in with GitHub
- **THEN** the code appears, Copy Code & Open GitHub copies it and opens github.com, and after approval the window comes back in front showing the account and its repositories

#### Scenario: Closing mid sign-in
- **WHEN** the user closes Settings or picks Cancel while waiting for GitHub
- **THEN** the sign-in stops and nothing is saved

#### Scenario: Ticking a repository
- **WHEN** the user ticks a repository in the list
- **THEN** it appears in the menu after the refresh that follows, without a notification

#### Scenario: No client ID
- **WHEN** Info.plist has no GitHubClientID
- **THEN** Sign in with GitHub is disabled and the window says the client ID is missing

### Requirement: About window
About Tallynn SHALL open a window like BeeHan Brightness's About: the app icon, "Tallynn", "Made by Zolfer Figueiredo" linking to zolfer.com, the version, a separator, a GitHub link to the repository, and "Buy me a coffee".

#### Scenario: Open About
- **WHEN** the user picks About Tallynn
- **THEN** the About window comes to the front showing the version from the app's Info.plist

### Requirement: Keep in Dock
Keep in Dock SHALL pin the app's icon to the Dock or unpin it, like the Dock's own "Keep in Dock" option, and its checkmark SHALL reflect whether the app is currently pinned.

#### Scenario: Pin
- **WHEN** the user turns on Keep in Dock
- **THEN** the Tallynn icon appears in the Dock and stays there across logins

#### Scenario: Unpin
- **WHEN** the user turns Keep in Dock off
- **THEN** the Tallynn icon is removed from the Dock

### Requirement: Opening the app again shows the menu
Opening the app while it is running (clicking its Dock icon, Spotlight, Finder) SHALL pop up the same menu at the pointer instead of opening a window, or open Settings while signed out.

#### Scenario: Dock click
- **WHEN** the user clicks the pinned Tallynn icon in the Dock while signed in
- **THEN** the menu appears at the pointer

#### Scenario: Menu bar icon hidden by the notch
- **WHEN** the menu bar item is hidden and the user opens Tallynn from Spotlight
- **THEN** the menu appears at the pointer

#### Scenario: Signed out
- **WHEN** the user opens Tallynn again while signed out
- **THEN** Settings comes to the front

### Requirement: Problems shown in the menu
While signed out or when the last refresh failed, the menu SHALL show a problem line above the counts. A failed refresh SHALL keep the last known total in the menu bar.

#### Scenario: Signed out
- **WHEN** no account is signed in
- **THEN** the menu says "Sign in to GitHub…", which opens Settings

#### Scenario: Network or GitHub failure
- **WHEN** a refresh fails while signed in
- **THEN** the menu says "Couldn’t refresh" with the time of the last successful refresh below, and the counts stay as they were
