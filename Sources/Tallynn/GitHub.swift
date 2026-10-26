import Foundation

nonisolated enum Problem: Error, Sendable {
    case notFound   // no GitHub CLI, which Tallynn signs in through
    case signedOut  // the GitHub CLI has no login, or GitHub no longer accepts it
    case failed     // network, GitHub or rate limit
    case missing    // 404: no such repository, or one this login can't read
}

nonisolated struct Repo: Decodable, Equatable, Sendable {
    let name: String
    let fullName: String
    let `private`: Bool
    let fork: Bool
}

nonisolated struct GitHubRelease: Decodable, Sendable {
    nonisolated struct Asset: Decodable, Sendable {
        let name: String
        let downloadCount: Int
    }
    let tagName: String
    let assets: [Asset]
}

nonisolated private struct User: Decodable { let login: String }

nonisolated func decode<T: Decodable>(_ data: Data) throws -> T {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(T.self, from: data)
}

/// The next page from a GitHub `Link` header, nil on the last page.
nonisolated func nextPage(_ link: String?) -> URL? {
    for part in (link ?? "").split(separator: ",") where part.contains(#"rel="next""#) {
        guard let start = part.firstIndex(of: "<"), let end = part.firstIndex(of: ">"), start < end else { continue }
        return URL(string: String(part[part.index(after: start)..<end]))
    }
    return nil
}

/// No cache: GitHub allows 60 seconds of caching, which would make Refresh show old counts and write private
/// repositories' data to disk.
nonisolated let session: URLSession = {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.urlCache = nil
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    return URLSession(configuration: configuration)
}()

/// Without a token, GitHub answers about public repositories only, 60 requests an hour from this Mac's address.
@concurrent nonisolated func get(_ url: URL, token: String?) async throws(Problem) -> (Data, HTTPURLResponse) {
    var request = URLRequest(url: url)
    if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    guard let (data, response) = try? await session.data(for: request), let http = response as? HTTPURLResponse else {
        throw .failed
    }
    if http.statusCode == 401 { throw .signedOut }
    if http.statusCode == 404 { throw .missing }
    guard http.statusCode == 200 else { throw .failed }
    return (data, http)
}

/// Every page of a list.
@concurrent nonisolated func getAll<T: Decodable & Sendable>(_ url: URL, token: String?) async throws(Problem) -> [T] {
    var items: [T] = [], next: URL? = url
    while let page = next {
        let (data, response) = try await get(page, token: token)
        guard let batch: [T] = try? decode(data) else { throw .failed }
        items += batch
        next = nextPage(response.value(forHTTPHeaderField: "Link"))
    }
    return items
}

@concurrent nonisolated func fetchLogin(token: String) async throws(Problem) -> String {
    let (data, _) = try await get(URL(string: "https://api.github.com/user")!, token: token)
    guard let user: User = try? decode(data) else { throw .failed }
    return user.login
}

/// The user's own public and private repositories, forks left out.
@concurrent nonisolated func fetchRepos(token: String) async throws(Problem) -> [Repo] {
    sourceRepos(try await getAll(URL(string: "https://api.github.com/user/repos?affiliation=owner&visibility=all&per_page=100")!,
                                 token: token))
}

/// Any repository this login can read, or any public one when signed out, by "owner/repo", to add one that isn't the
/// user's own.
@concurrent nonisolated func fetchRepo(_ path: String, token: String?) async throws(Problem) -> Repo {
    let (data, _) = try await get(URL(string: "https://api.github.com/repos/\(path)")!, token: token)
    guard let repo: Repo = try? decode(data) else { throw .failed }
    return repo
}

nonisolated func releasesURL(_ fullName: String) -> URL {
    URL(string: "https://api.github.com/repos/\(fullName)/releases?per_page=100")!
}

/// The shown repositories' releases: the user's own while signed in, and added ones. Any failure fails the whole
/// refresh, so a repository that couldn't be read never looks like a drop; a shown one that was renamed or deleted
/// just isn't listed any more.
@concurrent nonisolated func fetchReleases(token: String?, shown: Set<String>) async -> Result<[String: [Release]], Problem> {
    do {
        var releases: [String: [Release]] = [:]
        if let token {
            for repo in try await fetchRepos(token: token) where shown.contains(repo.name) {
                releases[repo.name] = releaseDownloads(try await getAll(releasesURL(repo.fullName), token: token))
            }
        }
        for path in shown where isAdded(path) {
            do {
                releases[path] = releaseDownloads(try await getAll(releasesURL(path), token: token))
            } catch .missing {
                continue
            }
        }
        return .success(releases)
    } catch {
        return .failure(error)
    }
}

// Like ClaudioStat with Claude Code, Tallynn never keeps a credential: the GitHub CLI signs in, stores the token in
// its own keychain item, and hands it over on each refresh.

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

/// The GitHub CLI's current token. `auth token` only reads the local login, so being offline isn't mistaken for
/// being signed out.
@concurrent nonisolated func ghToken(_ path: String) async -> String? {
    let token = await gh(path, ["auth", "token", "--hostname", "github.com"])?.trimmingCharacters(in: .whitespacesAndNewlines)
    return token?.isEmpty == false ? token : nil
}

/// What `gh auth login --web` prints without a terminal: "! One-time code (ABCD-1234) copied to clipboard", then
/// "Open this URL to continue in your web browser: https://github.com/login/device".
nonisolated func loginPrompt(_ line: String) -> (code: String?, url: URL?) {
    let code = line.firstMatch(of: /\(([A-Z0-9]{4}-[A-Z0-9]{4})\)/).map { String($0.1) }
    let url = line.firstMatch(of: /https:\/\/\S+/).flatMap { URL(string: String($0.0)) }
    return (code, url)
}

/// Returns once the process has exited, with its status. Cancelling the task stops it.
nonisolated func exitStatus(_ process: Process) async -> Int32 {
    await withTaskCancellationHandler {
        await withCheckedContinuation { done in
            process.terminationHandler = { done.resume(returning: $0.terminationStatus) }
            do { try process.run() } catch { done.resume(returning: -1) }
        }
    } onCancel: {
        process.terminate()
    }
}
