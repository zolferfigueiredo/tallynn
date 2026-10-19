import Testing
@testable import Tallynn

@Test func onlyInstallersCountPerRelease() {
    let gh = """
    v2.0\tApp.dmg\t300
    v2.0\tApp.exe\t50
    v2.0\tApp.zip\t10
    v2.0\tchecksums.txt\t99
    v2.0\tApp.dmg.sig\t7
    v1.0\tApp.dmg\t42
    v0.9\tnotes.txt\t5
    """
    #expect(releaseDownloads(gh) == [Release(tag: "v2.0", downloads: 360), Release(tag: "v1.0", downloads: 42),
                                     Release(tag: "v0.9", downloads: 0)])
    #expect(releaseDownloads("").isEmpty)
}

@Test func repoCountIsTheSumOfItsReleases() {
    let releases = ["theej": [Release(tag: "v2", downloads: 300), Release(tag: "v1", downloads: 62)], "weej": []]
    #expect(repoCounts(releases) == ["theej": 362, "weej": 0])
}

@Test func totalOfRepositories() {
    #expect(total(["theej": 361, "weej": 16, "wrecktangle": 34]) == 411)
}

@Test func firstRefreshIsABaseline() {
    #expect(changes(old: nil, new: ["theej": 361]).isEmpty)
}

@Test func unchangedCountsNotifyNothing() {
    #expect(changes(old: ["theej": 361, "weej": 16], new: ["theej": 361, "weej": 16]).isEmpty)
}

@Test func oneIncrease() {
    let found = changes(old: ["theej": 361, "weej": 16], new: ["theej": 364, "weej": 16])
    #expect(found == [Change(repo: "theej", old: 361, new: 364)])
    #expect(notificationBody(found) == "theej +3 (364)")
}

@Test func severalChangesInOneBody() {
    let found = changes(old: ["weej": 16, "theej": 361], new: ["weej": 17, "theej": 364])
    #expect(notificationBody(found) == "theej +3 (364)\nweej +1 (17)")
}

@Test func decreaseIsAChange() {
    #expect(notificationBody(changes(old: ["claudiostat": 430], new: ["claudiostat": 400])) == "claudiostat -30 (400)")
}

@Test func newRepositoryCountsFromZero() {
    #expect(notificationBody(changes(old: ["theej": 361], new: ["theej": 361, "newapp": 2])) == "newapp +2 (2)")
}

@Test func droppedRepositoryIsSilent() {
    #expect(changes(old: ["theej": 361, "gone": 5], new: ["theej": 361]).isEmpty)
}

@Test func menuHidesZerosAndSortsAlphabetically() {
    let rows = menuRows(["theej": 361, "weej": 16, "wrecktangle": 34, "claudiostat": 430, "bhbrightness": 270, "zolferfigueiredo": 0, "App2": 1, "app10": 1])
    #expect(rows.map(\.repo) == ["App2", "app10", "bhbrightness", "claudiostat", "theej", "weej", "wrecktangle"])
}
