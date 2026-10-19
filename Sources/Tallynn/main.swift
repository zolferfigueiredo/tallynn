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
    /// Read from the Keychain at launch and kept in memory. Never logged.
    var token: String?

    /// The counts of the last successful refresh. nil until the first one (no baseline yet), and while signed out.
    var counts: Counts? { token == nil ? nil : defaults.dictionary(forKey: "counts") as? Counts }
    var lastRefresh: Date? { defaults.object(forKey: "lastRefresh") as? Date }
    /// Each repository's releases from the last successful refresh, for the per-version submenus.
    var releases: [String: [Release]] {
        (try? JSONDecoder().decode([String: [Release]].self, from: defaults.data(forKey: "releases") ?? Data())) ?? [:]
    }
    /// The repositories ticked in Settings. New ones stay hidden until ticked.
    var shownRepos: Set<String> { Set(defaults.stringArray(forKey: "shownRepos") ?? []) }
    var places: (menuBar: Bool, list: Bool) {
        totalPlaces(menuBar: defaults.bool(forKey: "totalInMenuBar"), list: defaults.bool(forKey: "totalInList"))
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["interval": 10, "totalInMenuBar": true, "totalInList": false])
        if defaults.object(forKey: "shownRepos") == nil {
            defaults.set(migratedShownRepos(defaults.dictionary(forKey: "counts") as? Counts), forKey: "shownRepos")
        }
        token = savedToken()
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        UNUserNotificationCenter.current().delegate = self
        render()
        reschedule()
        if token == nil { showSettings() }
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

    @objc func tick() {
        guard let token else { problem = .signedOut; return render() }
        guard !busy else { again = true; return }
        busy = true
        let shown = shownRepos
        Task {
            let result = await fetchReleases(token: token, shown: shown)
            busy = false
            // Signed out, or another account signed in, while it asked: the answer is stale.
            if token == self.token { apply(result) }
            render()
            if again {
                again = false
                tick()
            }
        }
    }

    func apply(_ result: Result<[String: [Release]], Problem>) {
        switch result {
        case .success(let fetched):
            // Unticked while it asked: not saved back.
            let shown = shownRepos
            let releases = fetched.filter { shown.contains($0.key) }
            let fresh = repoCounts(releases)
            let found = changes(old: counts, new: fresh)
            defaults.set(fresh, forKey: "counts")
            defaults.set(try? JSONEncoder().encode(releases), forKey: "releases")
            defaults.set(Date.now, forKey: "lastRefresh")
            problem = nil
            if !found.isEmpty { notify(found) }
            log.notice("counts: \(fresh.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "), privacy: .public), total \(total(fresh)), changes \(found.count)")
        case .failure(.signedOut):
            log.notice("GitHub no longer accepts the token")
            signOut()
        case .failure(let failure):
            problem = failure
            log.notice("refresh failed: \(String(describing: failure), privacy: .public)")
        }
    }

    /// Settings calls this once GitHub hands over a token. False when the Keychain refused it.
    func signedIn(token: String, login: String) -> Bool {
        guard saveToken(token) else { return false }
        // Another account's picks and counts mean nothing here; the first refresh is then a baseline.
        if let previous = defaults.string(forKey: "login"), previous != login {
            defaults.set([String](), forKey: "shownRepos")
            clearCounts()
        }
        defaults.set(login, forKey: "login")
        self.token = token
        problem = nil
        log.notice("signed in as \(login, privacy: .public)")
        reschedule()
        return true
    }

    /// The picks stay, so the same account signing in again sees the same menu, with no notifications.
    @objc func signOut() {
        deleteToken()
        token = nil
        clearCounts()
        problem = .signedOut
        (settingsWindow?.delegate as? SettingsModel)?.step = .signedOut
        render()
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
        let title = places.menuBar ? counts.map { total($0).formatted() } : nil
        button.title = title ?? ""
        button.imagePosition = title == nil ? .imageOnly : .imageLeading
    }
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
