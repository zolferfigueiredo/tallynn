import AppKit
import UserNotifications
import os

let log = Logger(subsystem: "com.zolfer.tallynn", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let defaults = UserDefaults.standard
    var problem: Problem?
    var busy = false
    var again = false  // repositories were ticked during a refresh: one more once it ends
    var timer: Timer?
    var checking = false  // an update check or install is running
    /// The GitHub CLI's token, read again on each refresh and kept only in memory. Never logged.
    var token: String?

    /// The counts of the last successful refresh, nil until the first one (no baseline yet). While signed out, only
    /// the added public repositories', so the user's own, maybe private, never show.
    var counts: Counts? {
        let counts = defaults.dictionary(forKey: "counts") as? Counts
        return token == nil ? counts?.filter { isAdded($0.key) } : counts
    }
    var lastRefresh: Date? { defaults.object(forKey: "lastRefresh") as? Date }
    /// Each repository's releases from the last successful refresh, for the per-version submenus.
    var releases: [String: [Release]] {
        (try? JSONDecoder().decode([String: [Release]].self, from: defaults.data(forKey: "releases") ?? Data())) ?? [:]
    }
    /// The releases of the repositories `counts` shows, so signed out, only the added ones'.
    var shownReleases: [String: [Release]]? {
        counts.map { counts in releases.filter { counts[$0.key] != nil } }
    }
    /// The repositories ticked in Settings. New ones stay hidden until ticked.
    var shownRepos: Set<String> { Set(defaults.stringArray(forKey: "shownRepos") ?? []) }
    /// Public repositories added in Settings, kept while switched off until removed. Ticked ones count too, so one
    /// ticked before this list existed still shows.
    var addedRepos: [String] {
        Set(defaults.stringArray(forKey: "addedRepos") ?? []).union(shownRepos.filter(isAdded)).sorted()
    }
    /// Something to count: a ticked repository of the user's while signed in, or an added public one.
    var counting: Bool { shownRepos.contains { token != nil || isAdded($0) } }
    var places: (menuBar: Bool, list: Bool) {
        (defaults.bool(forKey: "totalInMenuBar"), defaults.bool(forKey: "totalInList"))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["interval": 10, "totalInMenuBar": true, "totalInList": false, "updateEvery": 604800,
                                     "notifications": true])
        if defaults.object(forKey: "shownRepos") == nil {
            defaults.set(migratedShownRepos(defaults.dictionary(forKey: "counts") as? Counts), forKey: "shownRepos")
        }
        // 0.4.5 counts every project file, not just .dmg, .exe and .zip: a quiet baseline, so the jump isn't announced.
        if defaults.integer(forKey: "countRules") < 2 {
            clearCounts()
            defaults.set(2, forKey: "countRules")
        }
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        NSApp.mainMenu = editMenu()
        UNUserNotificationCenter.current().delegate = self
        render()
        Task {
            await connect()
            render()
            reschedule()
            if !counting, problem != .failed { showSettings() }
            autoCheck()  // needs the sign-in, so after connecting
        }
        let updates = Timer(timeInterval: 3600, target: self, selector: #selector(autoCheck), userInfo: nil, repeats: true)
        updates.tolerance = 600
        RunLoop.main.add(updates, forMode: .common)
        Task { showUpdateComplete() }  // after launch finishes, not in the middle of it
    }

    /// Refresh now, then every interval.
    func reschedule() {
        timer?.invalidate()
        tick()
        let timer = Timer(timeInterval: TimeInterval(defaults.integer(forKey: "interval") * 60), target: self,
                          selector: #selector(tick), userInfo: nil, repeats: true)
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func setInterval(_ minutes: Int) {
        defaults.set(minutes, forKey: "interval")
        log.notice("interval = \(minutes) minutes")
        reschedule()
    }

    @objc func tick() {
        guard !busy else { again = true; return }
        busy = true
        Task {
            await connect()
            let token = token
            if counting {
                let result = await fetchReleases(token: token, shown: shownRepos)
                // Signed in or out, or another account signed in, while it asked: the answer is stale.
                if token == self.token { apply(result) }
            }
            busy = false
            render()
            if again {
                again = false
                tick()
            }
        }
    }

    /// Follows the GitHub CLI's login, which can also change in Terminal (`gh auth login`, `gh auth switch`).
    func connect() async {
        guard let path = ghPath() else { return disconnect(.notFound) }
        guard let current = await ghToken(path) else { return disconnect(.signedOut) }
        guard current != token else { return }
        do {
            adopt(current, login: try await fetchLogin(token: current))
        } catch {
            problem = error == .signedOut ? .signedOut : .failed
        }
    }

    func apply(_ result: Result<[String: [Release]], Problem>) {
        switch result {
        case .success(let fetched):
            // Unticked while it asked: not saved back.
            let shown = shownRepos
            let releases = keepingLast(fetched.filter { shown.contains($0.key) }, previous: self.releases)
            let fresh = repoCounts(releases)
            let found = changes(old: counts.map { withoutPushedOut($0, previous: self.releases, fresh: releases) }, new: fresh)
            defaults.set(fresh, forKey: "counts")
            defaults.set(try? JSONEncoder().encode(releases), forKey: "releases")
            defaults.set(Date.now, forKey: "lastRefresh")
            if token != nil { problem = nil }  // signed out, the menu keeps offering to sign in
            if !found.isEmpty { notify(found) }
            log.notice("counts: \(fresh.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "), privacy: .public), total \(total(releases)), changes \(found.count)")
        case .failure(.signedOut):
            log.notice("GitHub no longer accepts the GitHub CLI's token")
            disconnect(.signedOut)
        case .failure(let failure):
            problem = failure
            log.notice("refresh failed: \(String(describing: failure), privacy: .public)")
        }
    }

    func adopt(_ token: String, login: String) {
        // Another account's picks and counts mean nothing here; its first refresh is then a baseline.
        if let previous = defaults.string(forKey: "login"), previous != login {
            defaults.set([String](), forKey: "shownRepos")
            clearCounts()
        }
        let merged = mergingOwn(added: addedRepos, shown: shownRepos, login: login)
        defaults.set(merged.added, forKey: "addedRepos")
        defaults.set(merged.shown.sorted(), forKey: "shownRepos")
        defaults.set(login, forKey: "login")
        self.token = token
        problem = nil
        log.notice("signed in as \(login, privacy: .public)")
        (settingsWindow?.delegate as? SettingsModel)?.signedIn(login)
    }

    /// No GitHub CLI or no login. Counts go, so signing in again starts from a baseline; the picks stay.
    func disconnect(_ reason: Problem) {
        if token != nil { clearCounts() }
        token = nil
        problem = reason
        (settingsWindow?.delegate as? SettingsModel)?.start()
    }

    func clearCounts() {
        for key in ["counts", "releases", "lastRefresh"] { defaults.removeObject(forKey: key) }
    }

    /// Ticked or unticked in Settings. Ticking refreshes, and the silent baseline keeps that from notifying.
    func show(_ repo: String, _ on: Bool) {
        var shown = shownRepos
        if on { shown.insert(repo) } else { shown.remove(repo) }
        defaults.set(shown.sorted(), forKey: "shownRepos")
        guard !on else { return tick() }
        if var counts = defaults.dictionary(forKey: "counts") as? Counts {
            counts[repo] = nil
            defaults.set(counts, forKey: "counts")
        }
        var releases = releases
        releases[repo] = nil
        defaults.set(try? JSONEncoder().encode(releases), forKey: "releases")
        render()
    }

    func render() {
        guard let button = item.button else { return }
        button.image = menuBarIcon
        let title = places.menuBar ? shownReleases.map { total($0).formatted() } : nil
        button.title = title ?? ""
        button.imagePosition = title == nil ? .imageOnly : .imageLeading
    }
}

/// A menu bar app has no menu bar of its own, so text fields get ⌘X, ⌘C, ⌘V, ⌘A and ⌘Z from this hidden Edit menu,
/// and ⌘W and ⌘Q close the window in front. Quitting would take the download count out of the menu bar.
/// Never shown, so its titles aren't translated.
func editMenu() -> NSMenu {
    let edit = NSMenu(title: "Edit")
    edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
    edit.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
    edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
    edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
    edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
    let item = NSMenuItem()
    item.submenu = edit
    let main = NSMenu()
    main.addItem(item)
    let keys = NSMenu()
    for key in ["w", "q"] { keys.addItem(withTitle: "", action: #selector(NSWindow.performClose(_:)), keyEquivalent: key) }
    main.addItem(withTitle: "", action: nil, keyEquivalent: "").submenu = keys
    return main
}

/// The Tallinn silhouette run.sh and build.sh draw into the bundle, or a stand-in when run without one.
let menuBarIcon: NSImage? = {
    let image = Bundle.main.image(forResource: "MenuBar")
        ?? NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Tallynn")
    image?.isTemplate = true
    return image
}()

// One copy at a time: the one just opened (a build) takes over from any other.
for other in NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "") where other != .current {
    other.terminate()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
