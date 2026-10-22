import Foundation

/// Downloads by repository name.
typealias Counts = [String: Int]

nonisolated struct Change: Equatable, Sendable {
    let repo: String
    let old: Int
    let new: Int
}

/// One release's installer downloads.
nonisolated struct Release: Codable, Equatable, Sendable {
    let tag: String
    let downloads: Int
}

/// Each release's installer downloads, in GitHub's order (newest first). Only installers count, as in the author's
/// script; a release whose assets are all something else stays, with 0.
nonisolated func releaseDownloads(_ releases: [GitHubRelease]) -> [Release] {
    releases.map { release in
        let installers = release.assets.filter { asset in [".dmg", ".exe", ".zip"].contains { asset.name.hasSuffix($0) } }
        return Release(tag: release.tagName, downloads: installers.reduce(0) { $0 + $1.downloadCount })
    }
}

/// Each repository's downloads, from its releases.
nonisolated func repoCounts(_ releases: [String: [Release]]) -> Counts {
    releases.mapValues { $0.reduce(0) { $0 + $1.downloads } }
}

nonisolated func total(_ counts: Counts) -> Int { counts.values.reduce(0, +) }

/// A repository with no saved count is a baseline: just ticked, or the first refresh after signing in. Its next
/// change is notified. One no longer shown is left out.
nonisolated func changes(old: Counts?, new: Counts) -> [Change] {
    new.compactMap { repo, count in
        guard let before = old?[repo], before != count else { return nil }
        return Change(repo: repo, old: before, new: count)
    }.sorted { $0.repo < $1.repo }
}

/// "theej +3 (364)", one line per repository.
nonisolated func notificationBody(_ changes: [Change]) -> String {
    changes.map { "\($0.repo) \(($0.new - $0.old).formatted(.number.sign(strategy: .always()))) (\($0.new.formatted()))" }
        .joined(separator: "\n")
}

/// The shown repositories, alphabetically, as Finder sorts names.
nonisolated func menuRows(_ counts: Counts) -> [(repo: String, count: Int)] {
    counts.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
        .map { (repo: $0.key, count: $0.value) }
}

/// The repositories that can be shown: no forks, sorted as Finder sorts names.
nonisolated func sourceRepos(_ repos: [Repo]) -> [Repo] {
    repos.filter { !$0.fork }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
}

/// Settings' list: the ticked repositories first, then the rest, each keeping its order. Sorted once as the list
/// loads, so a row doesn't jump from under the pointer when it's ticked.
nonisolated func tickedFirst(_ repos: [Repo], shown: Set<String>) -> [Repo] {
    repos.filter { shown.contains($0.name) } + repos.filter { !shown.contains($0.name) }
}

/// Before repositories could be picked, every one with downloads was shown, so an upgrade starts with those ticked.
nonisolated func migratedShownRepos(_ counts: Counts?) -> [String] { menuRows((counts ?? [:]).filter { $0.value > 0 }).map(\.repo) }
