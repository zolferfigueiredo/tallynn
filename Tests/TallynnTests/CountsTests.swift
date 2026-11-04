import Foundation
import Testing
@testable import Tallynn

@Test func projectFilesCountButChecksumsAndMetadataDont() throws {
    let json = """
    [{"tag_name": "v2.0", "assets": [{"name": "App.dmg", "download_count": 300}, {"name": "App.exe", "download_count": 50},
                                     {"name": "App.zip", "download_count": 10}, {"name": "checksums.txt", "download_count": 99},
                                     {"name": "App.dmg.sig", "download_count": 7}, {"name": "App.dmg.blockmap", "download_count": 8},
                                     {"name": "latest-mac.yml", "download_count": 900}, {"name": "SHA256SUMS", "download_count": 4},
                                     {"name": "sbom.spdx.json", "download_count": 3}]},
     {"tag_name": "v1.0", "assets": [{"name": "App.pkg", "download_count": 1}, {"name": "App.msi", "download_count": 2},
                                     {"name": "app_1.0_amd64.deb", "download_count": 4}, {"name": "app-1.0-linux.tar.gz", "download_count": 8},
                                     {"name": "firmware.bin", "download_count": 16}, {"name": "app-v1.0-linux-arm64", "download_count": 11}]},
     {"tag_name": "v0.9", "assets": [{"name": "notes.txt", "download_count": 5}]}]
    """
    let releases: [GitHubRelease] = try decode(Data(json.utf8))
    #expect(releaseDownloads(releases) == [Release(tag: "v2.0", downloads: 360), Release(tag: "v1.0", downloads: 42),
                                           Release(tag: "v0.9", downloads: 0)])
    #expect(releaseDownloads([]).isEmpty)
}

@Test func repoCountIsTheSumOfItsReleases() {
    let releases = ["theej": [Release(tag: "v2", downloads: 300), Release(tag: "v1", downloads: 62)], "weej": []]
    #expect(repoCounts(releases) == ["theej": 362, "weej": 0])
}

@Test func nextPageFromLinkHeader() {
    let both = #"<https://api.github.com/user/repos?page=2>; rel="next", <https://api.github.com/user/repos?page=5>; rel="last""#
    #expect(nextPage(both) == URL(string: "https://api.github.com/user/repos?page=2"))
    let last = #"<https://api.github.com/user/repos?page=4>; rel="prev", <https://api.github.com/user/repos?page=1>; rel="first""#
    #expect(nextPage(last) == nil)
    #expect(nextPage(nil) == nil)
}

@Test func readsTheGitHubCLILoginPrompt() {
    let code = loginPrompt("! One-time code (AB12-CD34) copied to clipboard")
    #expect(code.code == "AB12-CD34" && code.url == nil)
    let page = loginPrompt("Open this URL to continue in your web browser: https://github.com/login/device")
    #expect(page.code == nil && page.url == URL(string: "https://github.com/login/device"))
    #expect(loginPrompt("✓ Authentication complete.").code == nil)
}

@Test func forksAreLeftOutAndSortedLikeFinder() throws {
    let json = """
    [{"name": "weej", "full_name": "z/weej", "private": false, "fork": false},
     {"name": "someone-else", "full_name": "z/someone-else", "private": false, "fork": true},
     {"name": "app10", "full_name": "z/app10", "private": true, "fork": false},
     {"name": "App2", "full_name": "z/App2", "private": false, "fork": false}]
    """
    let repos: [Repo] = try decode(Data(json.utf8))
    #expect(sourceRepos(repos).map(\.name) == ["App2", "app10", "weej"])
    #expect(sourceRepos(repos)[1].private)
}

@Test func anEmptyAnswerKeepsTheLastReleases() {
    let before = ["theej": [Release(tag: "v2", downloads: 425)], "weej": [Release(tag: "v1", downloads: 27)]]
    let fetched: [String: [Release]] = ["theej": [], "weej": [Release(tag: "v1", downloads: 28)], "newapp": []]
    #expect(keepingLast(fetched, previous: before) == ["theej": [Release(tag: "v2", downloads: 425)],
                                                       "weej": [Release(tag: "v1", downloads: 28)], "newapp": []])
}

@Test func totalAddsUpEachRepositorysMostDownloadedRelease() {
    let releases = ["theej": [Release(tag: "v2", downloads: 0), Release(tag: "v1", downloads: 178)],
                    "weej": [Release(tag: "v1", downloads: 29), Release(tag: "v0", downloads: 3)], "new": []]
    #expect(total(releases) == 207)
}

@Test func eachChangedReleaseWithItsOwnDownloads() {
    let previous = ["tallynn": [Release(tag: "v0.6.1", downloads: 16), Release(tag: "v0.6.0", downloads: 19)],
                    "theej": [Release(tag: "v2.7.0", downloads: 7)]]
    let fresh = ["tallynn": [Release(tag: "v0.6.1", downloads: 18), Release(tag: "v0.6.0", downloads: 20)],
                 "theej": [Release(tag: "v2.7.0", downloads: 7)]]
    let found = changes(previous: previous, fresh: fresh)
    #expect(found.first == Change(repo: "tallynn", tag: "v0.6.1", old: 16, new: 18))
    #expect(notificationBody(found) == "tallynn v0.6.1 +2 (18)\ntallynn v0.6.0 +1 (20)")
}

@Test func aNewReleaseStartsFromZero() {
    let found = changes(previous: ["theej": [Release(tag: "v1", downloads: 9)]],
                        fresh: ["theej": [Release(tag: "v2", downloads: 3), Release(tag: "v1", downloads: 9)]])
    #expect(notificationBody(found) == "theej v2 +3 (3)")
}

@Test func aReleasePushedOutOrDeletedIsntADrop() {
    let tags = (1...51).reversed().map { Release(tag: "v\($0)", downloads: 1) }
    let previous = ["big": Array(tags.dropFirst()), "small": [Release(tag: "v2", downloads: 5), Release(tag: "v1", downloads: 4)]]
    let fresh = ["big": Array(tags.dropLast()), "small": [Release(tag: "v2", downloads: 5)]]
    #expect(notificationBody(changes(previous: previous, fresh: fresh)) == "big v51 +1 (1)")
}

@Test func aDropInAReleaseIsAChange() {
    let found = changes(previous: ["claudiostat": [Release(tag: "v1", downloads: 430)]],
                        fresh: ["claudiostat": [Release(tag: "v1", downloads: 400)]])
    #expect(notificationBody(found) == "claudiostat v1 -30 (400)")
}

@Test func firstRefreshIsABaseline() {
    #expect(changes(previous: nil, fresh: ["theej": [Release(tag: "v1", downloads: 361)]]).isEmpty)
}

@Test func newlyShownRepositoryIsABaseline() {
    let one = [Release(tag: "v1", downloads: 361)]
    #expect(changes(previous: ["theej": one], fresh: ["theej": one, "newapp": [Release(tag: "v1", downloads: 250)]]).isEmpty)
}

@Test func firstDownloadOfAShownRepository() {
    #expect(notificationBody(changes(previous: ["newapp": []], fresh: ["newapp": [Release(tag: "v1", downloads: 1)]])) == "newapp v1 +1 (1)")
}

@Test func droppedRepositoryIsSilent() {
    let one = [Release(tag: "v1", downloads: 361)]
    #expect(changes(previous: ["theej": one, "gone": one], fresh: ["theej": one]).isEmpty)
}

@Test func menuShowsZerosAndSortsAlphabetically() {
    let one = [Release(tag: "v1", downloads: 1)]
    let rows = menuRows(["theej": one, "weej": one, "bhbrightness": one, "zolferfigueiredo": [], "App2": one, "app10": one])
    #expect(rows.map(\.repo) == ["App2", "app10", "bhbrightness", "theej", "weej", "zolferfigueiredo"])
    #expect(rows.last.map { [$0.latest, $0.top] } == [0, 0])
}

@Test func rowHasTheNewestAndTheMostDownloadedRelease() {
    let rows = menuRows(["theej": [Release(tag: "v2.7.0", downloads: 0), Release(tag: "v2.2.3", downloads: 178), Release(tag: "v1", downloads: 9)],
                         "weej": [Release(tag: "v2.5.0", downloads: 29), Release(tag: "v2.4.0", downloads: 3)]])
    #expect(rows.map { [$0.latest, $0.top] } == [[0, 178], [29, 29]])
}

@Test func tickedRepositoriesComeFirst() throws {
    let json = """
    [{"name": "alpha", "full_name": "z/alpha", "private": false, "fork": false},
     {"name": "beta", "full_name": "z/beta", "private": false, "fork": false},
     {"name": "gamma", "full_name": "z/gamma", "private": false, "fork": false},
     {"name": "theej", "full_name": "z/theej", "private": false, "fork": false}]
    """
    let repos: [Repo] = try decode(Data(json.utf8))
    #expect(tickedFirst(repos, shown: ["theej", "beta"]).map(\.name) == ["beta", "theej", "alpha", "gamma"])
    #expect(tickedFirst(repos, shown: []).map(\.name) == ["alpha", "beta", "gamma", "theej"])
}

@Test func migrationShowsReposWithDownloads() {
    #expect(migratedShownRepos(["theej": 362, "weej": 16, "zolferfigueiredo": 0]) == ["theej", "weej"])
    #expect(migratedShownRepos(nil).isEmpty)
}

@Test func addsARepositoryByNameOrLinkAndOpensItsReleases() {
    #expect(repoPath("cli/cli") == "cli/cli")
    #expect(repoPath(" https://github.com/apple/swift-format/releases/tag/1.0 ") == "apple/swift-format")
    #expect(repoPath("github.com/owner/repo.git") == "owner/repo")
    #expect(repoPath("https://www.github.com/owner/my.repo?tab=readme") == "owner/my.repo")
    #expect(repoPath("nope") == nil)
    #expect(repoPath("owner/..") == nil)
    #expect(repoPath("own er/repo") == nil)
    #expect(releasePage(repo: "theej", login: "zolfer", tag: "v1.0") == URL(string: "https://github.com/zolfer/theej/releases/tag/v1.0"))
    #expect(releasePage(repo: "cli/cli", login: "zolfer", tag: "v2 beta#1") == URL(string: "https://github.com/cli/cli/releases/tag/v2%20beta%231"))
    #expect(releasePage(repo: "theej", login: nil, tag: "v1.0") == nil)
}

@Test func ownRepositoriesAddedWhileSignedOutBecomeOwnOnSignIn() {
    let merged = mergingOwn(added: ["cli/cli", "Zolfer/theej", "zolfer/weej"], shown: ["cli/cli", "Zolfer/theej", "claudiostat"],
                            login: "zolfer")
    #expect(merged.added == ["cli/cli"])
    #expect(merged.shown == ["cli/cli", "theej", "claudiostat"])
}
