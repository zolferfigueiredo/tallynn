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

/// gh prints one "tag<TAB>name<TAB>downloads" line per release asset, newest release first. Only installers count,
/// as in the author's script; a release whose assets are all something else stays, with 0.
nonisolated func releaseDownloads(_ output: String) -> [Release] {
    var tags: [String] = [], sums: [String: Int] = [:]
    for line in output.split(whereSeparator: \.isNewline) {
        let parts = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard parts.count == 3, let downloads = Int(parts[2]) else { continue }
        let tag = String(parts[0])
        if sums[tag] == nil { tags.append(tag) }
        let installer = [".dmg", ".exe", ".zip"].contains { parts[1].hasSuffix($0) }
        sums[tag, default: 0] += installer ? downloads : 0
    }
    return tags.map { Release(tag: $0, downloads: sums[$0]!) }
}

/// Each repository's downloads, from its releases.
nonisolated func repoCounts(_ releases: [String: [Release]]) -> Counts {
    releases.mapValues { $0.reduce(0) { $0 + $1.downloads } }
}

nonisolated func total(_ counts: Counts) -> Int { counts.values.reduce(0, +) }

/// No `old` means nothing was saved yet: the first refresh is a baseline. A repository seen for the first time
/// counts from 0, and one no longer listed is left out.
nonisolated func changes(old: Counts?, new: Counts) -> [Change] {
    guard let old else { return [] }
    return new.compactMap { repo, count in
        old[repo, default: 0] == count ? nil : Change(repo: repo, old: old[repo, default: 0], new: count)
    }.sorted { $0.repo < $1.repo }
}

/// "theej +3 (364)", one line per repository.
nonisolated func notificationBody(_ changes: [Change]) -> String {
    changes.map { "\($0.repo) \(($0.new - $0.old).formatted(.number.sign(strategy: .always()))) (\($0.new.formatted()))" }
        .joined(separator: "\n")
}

/// Repositories with downloads, alphabetically, as Finder sorts names.
nonisolated func menuRows(_ counts: Counts) -> [(repo: String, count: Int)] {
    counts.filter { $0.value > 0 }
        .sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
        .map { (repo: $0.key, count: $0.value) }
}
