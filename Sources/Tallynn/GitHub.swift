import Foundation

nonisolated enum Problem: Error, Sendable {
    case notFound   // no gh executable
    case loggedOut  // gh has no login
    case failed     // network, GitHub or rate limit
}

nonisolated private struct Repo: Decodable {
    let name: String
    let nameWithOwner: String
}

/// Apps opened from Finder get launchd's PATH, which has no Homebrew, so gh is looked for where Homebrew puts it.
// ponytail: fixed paths; ask the login shell for PATH if gh ever lives elsewhere.
nonisolated func ghPath() -> String? {
    ["/opt/homebrew/bin/gh", "/usr/local/bin/gh"].first(where: FileManager.default.isExecutableFile(atPath:))
}

/// gh's output, or nil when it can't start or exits with an error.
@concurrent nonisolated func gh(_ path: String, _ arguments: [String]) async -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    let output = Pipe()
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    do { try process.run() } catch { return nil }
    // Read before waiting: a full pipe would block gh from exiting.
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return process.terminationStatus == 0 ? String(decoding: data, as: UTF8.self) : nil
}

/// Every public, non-fork repository of the gh user and its releases, counted like the author's script. Any
/// failure fails the whole refresh, so a repository that couldn't be read never looks like a drop.
nonisolated func fetchReleases() async -> Result<[String: [Release]], Problem> {
    guard let path = ghPath() else { return .failure(.notFound) }
    guard let list = await gh(path, ["repo", "list", "--visibility", "public", "--source", "--limit", "1000",
                                     "--json", "name,nameWithOwner"]),
          let repos = try? JSONDecoder().decode([Repo].self, from: Data(list.utf8)) else {
        // `auth token` only reads the local login, so being offline isn't mistaken for being logged out.
        return .failure(await gh(path, ["auth", "token"]) == nil ? .loggedOut : .failed)
    }
    var releases: [String: [Release]] = [:]
    for repo in repos {
        guard let assets = await gh(path, ["api", "repos/\(repo.nameWithOwner)/releases", "--paginate", "--jq",
                                           #".[] | .tag_name as $tag | .assets[] | "\($tag)\t\(.name)\t\(.download_count)""#]) else {
            return .failure(.failed)
        }
        releases[repo.name] = releaseDownloads(assets)
    }
    return .success(releases)
}
