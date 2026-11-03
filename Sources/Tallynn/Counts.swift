import Foundation

/// Downloads by repository name.
typealias Counts = [String: Int]

nonisolated struct Change: Equatable, Sendable {
    let repo: String
    let old: Int
    let new: Int
}

/// One release's downloads.
nonisolated struct Release: Codable, Equatable, Sendable {
    let tag: String
    let downloads: Int
}

/// A project file people download: any asset but checksums, signatures and the metadata updaters fetch
/// (electron-builder's latest-mac.yml and .blockmap, Sparkle's appcast). Left out rather than picked, as plain
/// binaries (tool-v1.2.3-linux-amd64) have no extension to pick them by.
nonisolated func counted(_ name: String) -> Bool {
    let name = name.lowercased()
    let skipped = [".sha1", ".sha256", ".sha512", ".md5", ".sig", ".asc", ".minisig", ".pem", ".crt",
                   ".txt", ".md", ".json", ".jsonl", ".yml", ".yaml", ".xml", ".blockmap", ".sbom", ".spdx"]
    return !skipped.contains { name.hasSuffix($0) } && !name.contains("checksum") && !name.contains("sha256sums")
}

/// Each release's downloads, in GitHub's order (newest first). A release whose assets are all left out stays, with 0.
nonisolated func releaseDownloads(_ releases: [GitHubRelease]) -> [Release] {
    releases.map { release in
        Release(tag: release.tagName, downloads: release.assets.filter { counted($0.name) }.reduce(0) { $0 + $1.downloadCount })
    }
}

/// The newest releases counted per repository: one page of GitHub's.
nonisolated let releaseLimit = 50

/// Each repository's downloads, from its releases.
nonisolated func repoCounts(_ releases: [String: [Release]]) -> Counts {
    releases.mapValues { $0.reduce(0) { $0 + $1.downloads } }
}

/// GitHub sometimes answers a repository's releases with an empty list although it has releases, so an empty answer
/// for one that had some keeps those.
// ponytail: a repository whose releases are all deleted keeps its last count; untick and tick it to clear that.
nonisolated func keepingLast(_ fetched: [String: [Release]], previous: [String: [Release]]) -> [String: [Release]] {
    Dictionary(uniqueKeysWithValues: fetched.map { repo, releases in (repo, releases.isEmpty ? previous[repo] ?? [] : releases) })
}

/// Each repository's most downloaded release, added up.
nonisolated func total(_ releases: [String: [Release]]) -> Int {
    releases.values.reduce(0) { $0 + ($1.map(\.downloads).max() ?? 0) }
}

/// The last counts without the releases a newer one pushed out of the newest 50, so those aren't a drop. A release
/// deleted from a repository with that many goes unnoticed the same way.
nonisolated func withoutPushedOut(_ old: Counts, previous: [String: [Release]], fresh: [String: [Release]]) -> Counts {
    var old = old
    for (repo, releases) in fresh where releases.count == releaseLimit && old[repo] != nil {
        let tags = Set(releases.map(\.tag))
        old[repo] = (previous[repo] ?? []).filter { tags.contains($0.tag) }.reduce(0) { $0 + $1.downloads }
    }
    return old
}

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

/// The shown repositories, alphabetically as Finder sorts names, each with its newest release's downloads and its most
/// downloaded release's.
nonisolated func menuRows(_ releases: [String: [Release]]) -> [(repo: String, latest: Int, top: Int)] {
    releases.sorted { $0.key.localizedStandardCompare($1.key) == .orderedAscending }
        .map { (repo: $0.key, latest: $0.value.first?.downloads ?? 0, top: $0.value.map(\.downloads).max() ?? 0) }
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
nonisolated func migratedShownRepos(_ counts: Counts?) -> [String] {
    (counts ?? [:]).filter { $0.value > 0 }.keys.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
}

/// Added repositories are keyed by "owner/repo", the user's own by their name, which has no "/".
nonisolated func isAdded(_ repo: String) -> Bool { repo.contains("/") }

/// "owner/repo", typed so or pasted as a GitHub link (https://github.com/owner/repo/releases, …/repo.git). nil for
/// anything else, so only a repository's path reaches the API.
nonisolated func repoPath(_ input: String) -> String? {
    var path = input.trimmingCharacters(in: .whitespacesAndNewlines)
    for prefix in ["https://", "http://", "www.", "github.com/"] where path.lowercased().hasPrefix(prefix) {
        path.removeFirst(prefix.count)
    }
    let parts = path.split(whereSeparator: { "/?#".contains($0) }).prefix(2).map(String.init)
    guard parts.count == 2 else { return nil }
    let owner = parts[0], repo = parts[1].hasSuffix(".git") ? String(parts[1].dropLast(4)) : parts[1]
    guard owner.wholeMatch(of: /[A-Za-z0-9-]+/) != nil, repo.wholeMatch(of: /[A-Za-z0-9_.-]+/) != nil,
          !repo.allSatisfy({ $0 == "." }) else { return nil }
    return "\(owner)/\(repo)"
}

/// A release's page on GitHub, with its files. An own repository is keyed by its name, an added one by "owner/repo".
nonisolated func releasePage(repo: String, login: String?, tag: String) -> URL? {
    guard let path = isAdded(repo) ? repo : login.map({ "\($0)/\(repo)" }),
          let tag = tag.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
    return URL(string: "https://github.com/\(path)/releases/tag/\(tag)")
}

/// Signing in as `login` turns the user's own repositories, added as "login/x" while signed out, into "x", so each is
/// listed and counted once. A ticked one stays ticked under its own name.
nonisolated func mergingOwn(added: [String], shown: Set<String>, login: String) -> (added: [String], shown: Set<String>) {
    let prefix = login.lowercased() + "/"
    let own = added.filter { $0.lowercased().hasPrefix(prefix) }
    var shown = shown
    for repo in own where shown.remove(repo) != nil { shown.insert(String(repo.dropFirst(prefix.count))) }
    return (added.filter { !own.contains($0) }, shown)
}
