# Spec Delta

## Purpose

Tells the user, with a macOS notification and sound, the moment any repository's download count changes, without notifying for baselines, restarts or failed refreshes.

## ADDED Requirements

### Requirement: Notify on change
After a successful refresh the app SHALL compare each repository's count with its last saved count and, if any differ, post exactly one notification with the default sound.

#### Scenario: One repository increased
- **WHEN** theej goes from 361 to 364 and nothing else changes
- **THEN** one notification titled "Tallynn" says "theej +3 (364)" and plays a sound

#### Scenario: Several repositories changed in one refresh
- **WHEN** theej goes from 361 to 364 and weej from 16 to 17 in the same refresh
- **THEN** one notification lists both, one line per repository: "theej +3 (364)" and "weej +1 (17)"

#### Scenario: Nothing changed
- **WHEN** every count equals its saved count
- **THEN** no notification is posted

### Requirement: Decreases are changes
A count that goes down (for example after a release or asset is deleted) SHALL be notified like an increase, with a negative delta.

#### Scenario: Asset deleted
- **WHEN** claudiostat goes from 430 to 400
- **THEN** the notification says "claudiostat -30 (400)"

### Requirement: First-run baseline
The first successful refresh after the app has no saved counts SHALL save them as the baseline without posting a notification.

#### Scenario: Fresh install
- **WHEN** the app's first ever refresh finds 1111 downloads
- **THEN** no notification is posted and the counts are saved

#### Scenario: Restart is not a change
- **WHEN** the app relaunches and its first refresh matches the saved counts
- **THEN** no notification is posted

### Requirement: Newly shown repositories
A repository with no saved count, because it was just ticked or this is the first refresh after signing in, SHALL be saved as a baseline without a notification; its later changes SHALL be notified. A repository that is unticked or no longer listed SHALL be dropped silently.

#### Scenario: Ticking a repository with downloads
- **WHEN** the user ticks newapp, which already has 250 downloads
- **THEN** no notification is posted and 250 is saved

#### Scenario: Next download after ticking
- **WHEN** newapp then goes from 250 to 251
- **THEN** the notification says "newapp +1 (251)"

#### Scenario: Unticking
- **WHEN** the user unticks a repository
- **THEN** it is removed from the saved counts and no notification is posted

#### Scenario: Signing in again
- **WHEN** the same account signs in again after signing out
- **THEN** the first refresh posts no notification

### Requirement: Notification permission
The app SHALL ask for notification permission (alerts and sound) the first time it needs to post. If permission is denied, counts SHALL still update and save.

#### Scenario: Permission denied
- **WHEN** the user has denied notifications and a count changes
- **THEN** no notification appears, and the menu bar total and saved counts update
