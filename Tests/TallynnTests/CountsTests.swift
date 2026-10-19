import Testing
@testable import Tallynn

@Test func onlyInstallersCount() {
    let gh = "App.dmg\t300\nApp.exe\t50\nApp.zip\t10\nchecksums.txt\t99\nApp.dmg.sig\t7\n"
    #expect(installerDownloads(gh) == 360)
    #expect(installerDownloads("") == 0)
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

@Test func menuHidesZerosAndSortsByCount() {
    let rows = menuRows(["theej": 361, "weej": 16, "wrecktangle": 34, "claudiostat": 430, "bhbrightness": 270, "zolferfigueiredo": 0])
    #expect(rows.map(\.repo) == ["claudiostat", "theej", "bhbrightness", "wrecktangle", "weej"])
}
