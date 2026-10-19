import AppKit
import ServiceManagement

extension AppDelegate {
    // Opening the app again (its Dock icon, Spotlight, Finder) shows the menu at the pointer. That also reaches
    // it when the notch hides the menu bar icon.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        item.menu?.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
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
            add(problemText(problem)).image = NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: nil)
            menu.addItem(.separator())
        }
        // Badges sit at the right edge, in the column ⌘Q and the submenu arrow use, so counts line up with the border.
        if let counts {
            for row in menuRows(counts) { add(row.repo).badge = NSMenuItemBadge(string: row.count.formatted()) }
            let sum = add("TOTAL")
            sum.attributedTitle = NSAttributedString(string: "TOTAL", attributes: [.font: NSFont.boldSystemFont(ofSize: NSFont.menuFont(ofSize: 0).pointSize)])
            sum.badge = NSMenuItemBadge(string: total(counts).formatted())
        }
        if let lastRefresh {
            add("Updated \(lastRefresh.formatted(date: .omitted, time: .shortened))", enabled: false)
        } else if problem == nil {
            add("Counting downloads…", enabled: false)
        }
        menu.addItem(.separator())

        add("Refresh Now", #selector(refreshNow), enabled: !busy, key: "r")
        let every = NSMenu()
        for minutes in [5, 10, 30, 60] {
            let entry = NSMenuItem(title: minutes == 60 ? "1 hour" : "\(minutes) minutes", action: #selector(chooseInterval), keyEquivalent: "")
            entry.target = self
            entry.tag = minutes
            entry.state = defaults.integer(forKey: "interval") == minutes ? .on : .off
            every.addItem(entry)
        }
        add("Refresh Every").submenu = every
        menu.addItem(.separator())

        // Registering from anywhere else (a build in /tmp) would point the login item at a bundle that disappears.
        add("Launch at Login", #selector(toggleLogin), on: SMAppService.mainApp.status == .enabled,
            enabled: Bundle.main.bundlePath.hasPrefix("/Applications/"))
        add("Keep in Dock", #selector(toggleDock), on: inDock())
        menu.addItem(.separator())
        let quit = add("Quit Tallynn", #selector(NSApplication.terminate), key: "q")
        quit.target = NSApp
    }

    func problemText(_ problem: Problem) -> String {
        switch problem {
        case .notFound: "GitHub CLI not found. Install it with: brew install gh"
        case .loggedOut: "Not logged in. Run in Terminal: gh auth login"
        case .failed: "Couldn’t refresh"
        }
    }

    @objc func refreshNow() { tick() }

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
