import Foundation

/// Downloads by repository name.
typealias Counts = [String: Int]

nonisolated struct Change: Equatable, Sendable {
    let repo: String
    let old: Int
    let new: Int
}

/// gh prints one "name<TAB>downloads" line per release asset. Only installers count, as in the author's script.
nonisolated func installerDownloads(_ output: String) -> Int {
    output.split(whereSeparator: \.isNewline).reduce(0) { sum, line in
        let parts = line.split(separator: "\t")
        guard parts.count == 2, let downloads = Int(parts[1]),
              [".dmg", ".exe", ".zip"].contains(where: { parts[0].hasSuffix($0) }) else { return sum }
        return sum + downloads
    }
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

/// Repositories with downloads, most first.
nonisolated func menuRows(_ counts: Counts) -> [(repo: String, count: Int)] {
    counts.filter { $0.value > 0 }
        .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
        .map { (repo: $0.key, count: $0.value) }
}
