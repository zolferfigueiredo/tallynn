import AppKit
import Foundation
import Testing
@testable import Tallynn

@Test func versionsCompareByNumber() {
    #expect(isNewer("0.10.0", than: "0.9.0"))
    #expect(isNewer("0.2.1", than: "0.2.0"))
    #expect(!isNewer("0.2.0", than: "0.2.0"))
    #expect(!isNewer("0.1.9", than: "0.2.0"))
}

@Test func checkIsDueAfterItsInterval() {
    let now = Date(timeIntervalSince1970: 1_000_000)
    #expect(updateCheckIsDue(last: nil, every: 604800, now: now))
    #expect(updateCheckIsDue(last: now.addingTimeInterval(-8 * 86400), every: 604800, now: now))
    #expect(!updateCheckIsDue(last: now.addingTimeInterval(-86400), every: 604800, now: now))
    #expect(!updateCheckIsDue(last: nil, every: 0, now: now))  // Never
}

@Test func latestReleaseIsTheTagsVersionAndItsDMG() throws {
    let json = """
    {"tag_name": "v0.3.0", "assets": [
      {"name": "Tallynn-0.2.0.dmg", "url": "https://api.github.com/repos/zolferfigueiredo/tallynn/releases/assets/1"},
      {"name": "Tallynn-0.3.0.dmg", "url": "https://api.github.com/repos/zolferfigueiredo/tallynn/releases/assets/2"}]}
    """
    #expect(latestRelease(from: Data(json.utf8)) == LatestRelease(
        version: "0.3.0", dmg: URL(string: "https://api.github.com/repos/zolferfigueiredo/tallynn/releases/assets/2")!))
}

@Test func releaseWithoutItsDMGIsNotOffered() {
    let json = #"{"tag_name": "v0.3.0", "assets": [{"name": "notes.txt", "url": "https://api.github.com/x"}]}"#
    #expect(latestRelease(from: Data(json.utf8)) == nil)
    #expect(latestRelease(from: Data("not json".utf8)) == nil)
}

@MainActor @Test func menuImagesShowOnMacOS27() {
    guard #available(macOS 27, *) else { return }
    let icon = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    icon.image = NSImage(size: NSSize(width: 16, height: 16))
    let parent = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    parent.submenu = NSMenu()
    parent.submenu?.addItem(icon)
    let menu = NSMenu()
    menu.addItem(parent)
    showImages(menu)
    #expect(icon.value(forKey: "preferredImageVisibility") as? Int == 1)
    #expect(parent.value(forKey: "preferredImageVisibility") as? Int == 0)  // no image, left to AppKit
}
