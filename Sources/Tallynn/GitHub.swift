import Foundation

nonisolated enum Problem: Error, Sendable {
    case signedOut  // no token, or GitHub no longer accepts it
    case failed     // network, GitHub or rate limit
}

nonisolated enum SignInError: Error, Sendable {
    case denied    // the user cancelled on github.com
    case expired   // the code timed out
    case disabled  // the OAuth app doesn't have Enable Device Flow ticked
    case failed
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

nonisolated struct DeviceCode: Decodable, Sendable {
    let deviceCode: String
    let userCode: String
    let verificationUri: URL
    let expiresIn: Int
    let interval: Int
}

nonisolated private struct User: Decodable { let login: String }
nonisolated private struct Reply: Decodable { let accessToken: String?; let error: String?; let interval: Int? }

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

@concurrent nonisolated func get(_ url: URL, token: String) async throws(Problem) -> (Data, HTTPURLResponse) {
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    guard let (data, response) = try? await session.data(for: request), let http = response as? HTTPURLResponse else {
        throw .failed
    }
    if http.statusCode == 401 { throw .signedOut }
    guard http.statusCode == 200 else { throw .failed }
    return (data, http)
}

/// Every page of a list.
@concurrent nonisolated func getAll<T: Decodable & Sendable>(_ url: URL, token: String) async throws(Problem) -> [T] {
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

/// The shown repositories' releases. Any failure fails the whole refresh, so a repository that couldn't be read never
/// looks like a drop; a shown one that was renamed or deleted just isn't listed any more.
@concurrent nonisolated func fetchReleases(token: String, shown: Set<String>) async -> Result<[String: [Release]], Problem> {
    do {
        var releases: [String: [Release]] = [:]
        for repo in try await fetchRepos(token: token) where shown.contains(repo.name) {
            let url = URL(string: "https://api.github.com/repos/\(repo.fullName)/releases?per_page=100")!
            releases[repo.name] = releaseDownloads(try await getAll(url, token: token))
        }
        return .success(releases)
    } catch {
        return .failure(error)
    }
}

/// A form POST to github.com's OAuth endpoints. Without the Accept header GitHub answers form-encoded.
@concurrent nonisolated private func post(_ url: String, _ form: [String: String]) async throws -> Data {
    var request = URLRequest(url: URL(string: url)!)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
    var body = URLComponents()
    body.queryItems = form.map { URLQueryItem(name: $0.key, value: $0.value) }
    request.httpBody = Data((body.percentEncodedQuery ?? "").utf8)
    return try await session.data(for: request).0
}

/// Starts the device flow. `repo` is the only scope that reaches private repositories; Tallynn only reads with it.
@concurrent nonisolated func requestDeviceCode(clientID: String) async throws -> DeviceCode {
    let data = try await post("https://github.com/login/device/code", ["client_id": clientID, "scope": "repo"])
    if let code: DeviceCode = try? decode(data) { return code }
    throw (try? decode(data) as Reply)?.error == "device_flow_disabled" ? SignInError.disabled : SignInError.failed
}

/// Waits for the user to enter the code on github.com, then returns the token. Cancelling the task stops it.
@concurrent nonisolated func pollForToken(clientID: String, code: DeviceCode) async throws -> String {
    var interval = code.interval
    let deadline = Date.now.addingTimeInterval(TimeInterval(code.expiresIn))
    while Date.now < deadline {
        try await Task.sleep(for: .seconds(interval))
        // A failed poll (offline for a moment) just waits for the next one, until the code expires.
        guard let data = try? await post("https://github.com/login/oauth/access_token",
                                         ["client_id": clientID, "device_code": code.deviceCode,
                                          "grant_type": "urn:ietf:params:oauth:grant-type:device_code"]),
              let reply: Reply = try? decode(data) else { continue }
        if let token = reply.accessToken { return token }
        switch reply.error {
        case "authorization_pending": continue
        case "slow_down": interval = reply.interval ?? interval + 5
        case "access_denied": throw SignInError.denied
        case "expired_token": throw SignInError.expired
        case "device_flow_disabled": throw SignInError.disabled
        default: throw SignInError.failed
        }
    }
    throw SignInError.expired
}
