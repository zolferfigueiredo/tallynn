import AppKit
import ServiceManagement

extension AppDelegate {
    // Opening the app again (its Dock icon, Spotlight, Finder) shows the menu at the pointer, or Settings while
    // signed out. That also reaches it when the notch hides the menu bar icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if token == nil { showSettings() } else { item.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil) }
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

        if let problem {
            let line = switch problem {
            case .notFound: add("Install the GitHub CLI…", #selector(showSettings))
            case .signedOut: add("Sign in to GitHub…", #selector(showSettings))
            case .failed: add("Couldn’t refresh")
            }
            line.image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
            menu.addItem(.separator())
        } else if token != nil, shownRepos.isEmpty {
            add("Choose Repositories…", #selector(showSettings))
            menu.addItem(.separator())
        }
        let places = places
        // Badges sit at the right edge, in the column ⌘Q and the submenu arrows use, so counts line up with the border.
        if let counts {
            let releases = releases
            for row in menuRows(counts) {
                let entry = add(row.repo)
                entry.badge = NSMenuItemBadge(string: row.count.formatted())
                entry.submenu = versionsMenu(releases[row.repo] ?? [])
            }
            if places.list {
                let sum = add("TOTAL")
                sum.attributedTitle = NSAttributedString(string: "TOTAL", attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize)])
                sum.badge = NSMenuItemBadge(string: total(counts).formatted())
            }
            menu.addItem(.separator())
        }
        if let lastRefresh {
            add("Updated \(lastRefresh.formatted(date: .omitted, time: .shortened))", enabled: false)
        } else if problem == nil, token != nil {
            add("Counting downloads…", enabled: false)
        }
        add("Refresh", #selector(refreshNow), enabled: token != nil && !busy, key: "r")
        let every = NSMenu()
        for minutes in [5, 10, 30, 60] {
            let entry = NSMenuItem(title: minutes == 60 ? "1 hour" : "\(minutes) minutes", action: #selector(chooseInterval), keyEquivalent: "")
            entry.target = self
            entry.tag = minutes
            entry.state = defaults.integer(forKey: "interval") == minutes ? .on : .off
            every.addItem(entry)
        }
        add("Refresh rate").submenu = every
        menu.addItem(.separator())

        add("Settings…", #selector(showSettings), key: ",").image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        let totals = NSMenu()
        totals.autoenablesItems = false
        for (title, key, on, other) in [("Menu bar", "totalInMenuBar", places.menuBar, places.list),
                                        ("List", "totalInList", places.list, places.menuBar)] {
            let entry = NSMenuItem(title: title, action: #selector(toggleTotal), keyEquivalent: "")
            entry.target = self
            entry.representedObject = key
            entry.state = on ? .on : .off
            entry.isEnabled = !on || other  // the total always shows somewhere
            totals.addItem(entry)
        }
        add("Total").submenu = totals
        menu.addItem(.separator())

        // Registering from anywhere else (a build in /tmp) would point the login item at a bundle that disappears.
        add("Launch at Login", #selector(toggleLogin), on: SMAppService.mainApp.status == .enabled,
            enabled: Bundle.main.bundlePath.hasPrefix("/Applications/"))
        add("Keep in Dock", #selector(toggleDock), on: inDock())
        menu.addItem(.separator())
        add("About Tallynn", #selector(showAbout)).image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        let quit = add("Quit Tallynn", #selector(NSApplication.terminate), key: "q")
        quit.target = NSApp
    }

    /// A repository's releases with downloads, newest first, each with its count at the right edge.
    func versionsMenu(_ releases: [Release]) -> NSMenu? {
        let shown = releases.filter { $0.downloads > 0 }
        guard !shown.isEmpty else { return nil }
        let menu = NSMenu()
        menu.autoenablesItems = false  // rows without an action would otherwise be greyed out
        for release in shown {
            let entry = NSMenuItem(title: release.tag, action: nil, keyEquivalent: "")
            entry.badge = NSMenuItemBadge(string: release.downloads.formatted())
            menu.addItem(entry)
        }
        return menu
    }

    @objc func refreshNow() { tick() }

    @objc func toggleTotal(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        defaults.set(sender.state != .on, forKey: key)
        render()
    }

    @objc func chooseInterval(_ sender: NSMenuItem) {
        defaults.set(sender.tag, forKey: "interval")
        log.notice("interval = \(sender.tag) minutes")
        reschedule()
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
        alert.messageText = "Restart the Dock?"
        alert.informativeText = "To change this, macOS has to restart the Dock. Your screen and the menu bar will blink for a moment."
        alert.addButton(withTitle: "Restart Dock")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn { toggleDockTile() }
    }
}
