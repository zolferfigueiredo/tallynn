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
        // Badges sit at the right edge, in the column ⌘Q and the submenu arrows use, so counts line up with the border.
        if let counts, !counts.isEmpty {
            let releases = releases
            for row in menuRows(counts) {
                let entry = add(row.repo)
                entry.badge = NSMenuItemBadge(string: row.count.formatted())
                entry.submenu = versionsMenu(releases[row.repo] ?? [], repo: row.repo)
            }
            if places.list {
                let sum = add(tr("total_row"))
                sum.attributedTitle = NSAttributedString(string: tr("total_row"), attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize)])
                sum.badge = NSMenuItemBadge(string: total(counts).formatted())
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
        add(tr("login"), #selector(toggleLogin), on: SMAppService.mainApp.status == .enabled,
            enabled: Bundle.main.bundlePath.hasPrefix("/Applications/"))
        add(tr("dock"), #selector(toggleDock), on: inDock())
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

    /// A repository's releases with downloads, newest first, each with its count at the right edge. Clicking one
    /// opens its page on GitHub, with its files.
    func versionsMenu(_ releases: [Release], repo: String) -> NSMenu? {
        let shown = releases.filter { $0.downloads > 0 }
        guard !shown.isEmpty else { return nil }
        let menu = NSMenu()
        let login = defaults.string(forKey: "login")
        for release in shown {
            let entry = NSMenuItem(title: release.tag, action: #selector(openRelease), keyEquivalent: "")
            entry.target = self
            entry.representedObject = releasePage(repo: repo, login: login, tag: release.tag)
            entry.badge = NSMenuItemBadge(string: release.downloads.formatted())
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

// macOS 27 hides menu item images unless an item asks to show its own (preferredImageVisibility = .visible, 1).
// Set by key, as the macOS 26 SDK has no such property.
func showImages(_ menu: NSMenu) {
    guard #available(macOS 27, *) else { return }
    for item in menu.items {
        if item.image != nil { item.setValue(1, forKey: "preferredImageVisibility") }
        if let submenu = item.submenu { showImages(submenu) }
    }
}
