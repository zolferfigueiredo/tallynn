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

@Test func latestVersionAndItsDMG() {
    #expect(latestVersion(from: Data(#"{"version": "0.6.0"}"#.utf8)) == "0.6.0")
    #expect(latestVersion(from: Data("not json".utf8)) == nil)
    #expect(dmgURL("0.6.0") == URL(string: "https://github.com/zolferfigueiredo/tallynn/releases/download/v0.6.0/Tallynn-0.6.0.dmg"))
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
