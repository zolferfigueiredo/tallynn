import AppKit
import ServiceManagement

extension AppDelegate {
    // Opening the app again (its Dock icon, Spotlight, Finder) shows the menu at the pointer, or Settings while
    // there's nothing to count. That also reaches it when the notch hides the menu bar icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !counting { showSettings() } else { item.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil) }
        return false
    }

    // Rebuilt on every open, so counts and the login and Dock states are always current.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        @discardableResult
        func add(_ title: String, _ action: Selector? = nil, on: Bool = false, enabled: Bool = true, key: String = "") -> NSMenuItem {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: key)
            entry.target = self
            entry.state = on ? .on : .off
            entry.isEnabled = enabled
            menu.addItem(entry)
            return entry
        }

        add(tr("settings"), #selector(showSettings), key: ",").image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(.separator())
        // Signed out or without the GitHub CLI, the line only shows while there's nothing to count; Settings still offers
        // to sign in.
        if let problem, !counting || problem == .failed || problem == .missing {
            let line = switch problem {
            case .notFound: add(tr("no_gh"), #selector(showSettings))
            case .signedOut: add(tr("signed_out"), #selector(showSettings))
            case .failed, .missing: add(tr("refresh_failed"))
            }
            line.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
            menu.addItem(.separator())
        } else if token != nil, shownRepos.isEmpty {
            add(tr("choose"), #selector(showSettings))
            menu.addItem(.separator())
        }
        let login = SMAppService.mainApp.status == .enabled, docked = inDock()
        if let releases = shownReleases, !releases.isEmpty {
            let rows = menuRows(releases), sum = total(releases)
            let column = (rows.map { CountRow.badgeWidth($0.top) } + (places.list ? [CountRow.badgeWidth(sum)] : [])).max() ?? 0
            // macOS moves every title past a checkmark column, but only while some item is ticked.
            let indent: CGFloat = login || docked ? 30 : 16
            for row in rows {
                let entry = add(row.repo)  // the title still serves type-select and VoiceOver
                entry.submenu = versionsMenu(releases[row.repo] ?? [], repo: row.repo)
                entry.view = CountRow(name: row.repo, latest: row.latest == row.top ? nil : row.latest, top: row.top,
                                      column: column, indent: indent)
            }
            if places.list {
                add(tr("total_row"), enabled: false).view = CountRow(name: tr("total_row"), latest: nil, top: sum, column: column,
                                                                     indent: indent, bold: true)
            }
            menu.addItem(.separator())
        }
        if counting {
            if let lastRefresh {
                add(tr("updated", ["time": lastRefresh.formatted(date: .omitted, time: .shortened)]), enabled: false)
            } else if problem == nil {
                add(tr("counting"), enabled: false)
            }
            add(tr("refresh"), #selector(refreshNow), enabled: !busy, key: "r")
            menu.addItem(.separator())
        }

        // Registering from anywhere else (a build in /tmp) would point the login item at a bundle that disappears.
        add(tr("login"), #selector(toggleLogin), on: login, enabled: Bundle.main.bundlePath.hasPrefix("/Applications/"))
        add(tr("dock"), #selector(toggleDock), on: docked)
        menu.addItem(.separator())
        add(tr("about"), #selector(showAbout)).image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        menu.addItem(.separator())
        // While an update installs, its step stands in, in plain text that greys out.
        let check = add(UpdateProgress.underway ?? tr("check"), #selector(checkNow), enabled: !checking && UpdateProgress.underway == nil)
        if let version = availableUpdate, UpdateProgress.underway == nil {
            check.attributedTitle = updateAvailableTitle(version)
            check.image = updateAvailableIcon()
        } else {
            check.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: nil)
        }
        let automatic = NSMenu()
        for (title, every) in [(tr("daily"), 86400), (tr("weekly"), 604800), (tr("never"), 0)] {
            let entry = NSMenuItem(title: title, action: #selector(chooseUpdateEvery), keyEquivalent: "")
            entry.target = self
            entry.tag = every
            entry.state = defaults.integer(forKey: "updateEvery") == every ? .on : .off
            automatic.addItem(entry)
        }
        let auto = add(tr("auto"))
        auto.submenu = automatic
        auto.image = NSImage(size: NSSize(width: 16, height: 16))  // blank, so the title lines up with the icon rows
        menu.addItem(.separator())
        let quit = add(tr("quit"), #selector(NSApplication.terminate), key: "q")
        quit.target = NSApp
        showImages(menu)
    }

    /// A repository's releases with downloads, newest first, each with its count in grey on the right, the most
    /// downloaded's in a badge as in the repository's row. Clicking one opens its page on GitHub, with its files.
    func versionsMenu(_ releases: [Release], repo: String) -> NSMenu? {
        let shown = releases.filter { $0.downloads > 0 }
        guard let top = shown.map(\.downloads).max() else { return nil }
        let menu = NSMenu()
        let login = defaults.string(forKey: "login")
        for release in shown {
            let entry = NSMenuItem(title: release.tag, action: #selector(openRelease), keyEquivalent: "")
            entry.target = self
            entry.representedObject = releasePage(repo: repo, login: login, tag: release.tag)
            entry.view = CountRow(name: release.tag, latest: nil, top: release.downloads, column: CountRow.badgeWidth(top),
                                  indent: 16, badge: release.downloads == top)
            menu.addItem(entry)
        }
        return menu
    }

    @objc func openRelease(_ sender: NSMenuItem) {
        if let url = sender.representedObject as? URL { NSWorkspace.shared.open(url) }
    }

    @objc func refreshNow() { tick() }

    /// Settings' Total checkboxes land here, and the menu bar follows.
    func setTotal(_ key: String, _ on: Bool) {
        defaults.set(on, forKey: key)
        render()
        (settingsWindow?.delegate as? SettingsModel)?.loadTotal()
    }

    @objc func chooseUpdateEvery(_ sender: NSMenuItem) {
        defaults.set(sender.tag, forKey: "updateEvery")
        log.notice("updateEvery = \(sender.tag)")
        autoCheck()
    }

    @objc func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            log.error("launch at login: \(error.localizedDescription, privacy: .public)")
        }
        if service.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
    }

    // The restart blinks the screen and the menu bar, so it's asked first.
    @objc func toggleDock() {
        let alert = NSAlert()
        alert.messageText = tr("dock_restart_title")
        alert.informativeText = tr("dock_restart_text")
        alert.addButton(withTitle: tr("dock_restart"))
        alert.addButton(withTitle: tr("cancel"))
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn { toggleDockTile() }
    }
}

/// A repository's row, TOTAL, or a release: the name, the newest release's downloads in grey right beside the badge
/// with the most downloaded release's, then the submenu arrow. Drawn here, as macOS keeps a menu item's own title far
/// from its badge. In a menu with submenus every badge ends where the arrows start, so TOTAL's lines up with the rest.
final class CountRow: NSView {
    static let font = NSFont.menuFont(ofSize: 0)
    static let badgeFont = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize, weight: .semibold)
    static func badgeWidth(_ count: Int) -> CGFloat { ceil(count.formatted().size(withAttributes: [.font: badgeFont]).width) + 14 }

    let name: String, latest: Int?, top: Int, column: CGFloat, indent: CGFloat, bold: Bool, badge: Bool

    /// `column` is the widest badge, so the grey counts line up on the right. `latest` is nil when it's the most
    /// downloaded too. `indent` is where the menu's own titles start. Without `badge`, `top` is in grey, its digits
    /// lined up with the badge's.
    init(name: String, latest: Int?, top: Int, column: CGFloat, indent: CGFloat, bold: Bool = false, badge: Bool = true) {
        (self.name, self.latest, self.top, self.column, self.indent, self.bold, self.badge) = (name, latest, top, column, indent, bold, badge)
        let text = name.size(withAttributes: [.font: bold ? NSFont.boldSystemFont(ofSize: Self.font.pointSize) : Self.font]).width
            + (latest.map { 24 + $0.formatted().size(withAttributes: [.font: Self.font]).width } ?? 0)
        super.init(frame: NSRect(x: 0, y: 0, width: ceil(indent + text + 24 + column + 30), height: 24))
        autoresizingMask = .width  // the menu widens it to its own width
        setAccessibilityElement(true)
        setAccessibilityRole(.menuItem)
        setAccessibilityLabel([name, latest?.formatted(), top.formatted()].compactMap { $0 }.joined(separator: ", "))
    }

    required init?(coder: NSCoder) { fatalError() }

    // A menu item with a view draws nothing of its own, its highlight included.
    override func draw(_ dirtyRect: NSRect) {
        let enabled = enclosingMenuItem?.isEnabled != false
        let lit = enabled && enclosingMenuItem?.isHighlighted == true
        if lit {
            NSColor.selectedContentBackgroundColor.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 5, dy: 0), xRadius: 6, yRadius: 6).fill()
        }
        let ink: NSColor = lit ? .selectedMenuItemTextColor : enabled ? .labelColor : .disabledControlTextColor
        let font = bold ? NSFont.boldSystemFont(ofSize: Self.font.pointSize) : Self.font
        let y = (bounds.height - font.ascender + font.descender) / 2
        name.draw(at: NSPoint(x: indent, y: y), withAttributes: [.font: font, .foregroundColor: ink])

        var right = bounds.maxX - 16
        if enclosingMenuItem?.menu?.items.contains(where: \.hasSubmenu) == true,
           let chevron = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)?
            .withSymbolConfiguration(.init(pointSize: 12, weight: .bold).applying(.init(paletteColors: [ink]))) {
            right -= 3
            if enclosingMenuItem?.hasSubmenu == true {
                chevron.draw(in: NSRect(x: right - chevron.size.width, y: (bounds.height - chevron.size.height) / 2,
                                        width: chevron.size.width, height: chevron.size.height))
            }
            right -= chevron.size.width + 2
        }
        let greyInk = lit ? ink.withAlphaComponent(0.75) : .secondaryLabelColor
        if badge {
            let badge = NSRect(x: right - Self.badgeWidth(top), y: (bounds.height - 17) / 2, width: Self.badgeWidth(top), height: 17)
            (lit ? NSColor.white.withAlphaComponent(0.2) : NSColor.labelColor.withAlphaComponent(0.12)).setFill()
            NSBezierPath(roundedRect: badge, xRadius: badge.height / 2, yRadius: badge.height / 2).fill()
            let count = top.formatted() as NSString
            let size = count.size(withAttributes: [.font: Self.badgeFont])
            count.draw(at: NSPoint(x: badge.midX - size.width / 2, y: badge.midY - size.height / 2),
                       withAttributes: [.font: Self.badgeFont, .foregroundColor: ink])
        } else {
            let grey = top.formatted() as NSString
            grey.draw(at: NSPoint(x: right - 7 - grey.size(withAttributes: [.font: Self.font]).width, y: y),
                      withAttributes: [.font: Self.font, .foregroundColor: greyInk])
        }

        if let latest {
            let grey = latest.formatted() as NSString
            grey.draw(at: NSPoint(x: right - column - 6 - grey.size(withAttributes: [.font: Self.font]).width, y: y),
                      withAttributes: [.font: Self.font, .foregroundColor: greyInk])
        }
    }

    // An item with a view gets no click of its own, so a release's opens from here.
    override func mouseUp(with event: NSEvent) {
        guard let item = enclosingMenuItem, item.isEnabled, item.action != nil, let menu = item.menu else { return }
        menu.cancelTracking()
        menu.performActionForItem(at: menu.index(of: item))
    }
}

// macOS 27 hides menu item images unless an item asks to show its own (preferredImageVisibility = .visible, 1).
// Set by key, as the macOS 26 SDK has no such property.
func showImages(_ menu: NSMenu) {
    guard #available(macOS 27, *) else { return }
    for item in menu.items {
        if item.image != nil { item.setValue(1, forKey: "preferredImageVisibility") }
        if let submenu = item.submenu { showImages(submenu) }
    }
}
