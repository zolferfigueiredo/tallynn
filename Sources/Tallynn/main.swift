import AppKit
import UserNotifications
import os

let log = Logger(subsystem: "com.zolfer.tallynn", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let defaults = UserDefaults.standard
    var problem: Problem?
    var busy = false
    var timer: Timer?

    /// The counts of the last successful refresh. nil until the first one: no baseline yet.
    var counts: Counts? { defaults.dictionary(forKey: "counts") as? Counts }
    var lastRefresh: Date? { defaults.object(forKey: "lastRefresh") as? Date }
    /// Each repository's releases from the last successful refresh, for the per-version submenus.
    var releases: [String: [Release]] {
        (try? JSONDecoder().decode([String: [Release]].self, from: defaults.data(forKey: "releases") ?? Data())) ?? [:]
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.register(defaults: ["interval": 10])
        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        item.menu = menu
        UNUserNotificationCenter.current().delegate = self
        render()
        reschedule()
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
        guard !busy else { return }
        busy = true
        Task {
            let result = await fetchReleases()
            busy = false
            switch result {
            case .success(let releases):
                let fresh = repoCounts(releases)
                let found = changes(old: counts, new: fresh)
                defaults.set(fresh, forKey: "counts")
                defaults.set(try? JSONEncoder().encode(releases), forKey: "releases")
                defaults.set(Date.now, forKey: "lastRefresh")
                problem = nil
                if !found.isEmpty { notify(found) }
                log.notice("counts: \(fresh.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "), privacy: .public), total \(total(fresh)), changes \(found.count)")
            case .failure(let failure):
                problem = failure
                log.notice("refresh failed: \(String(describing: failure), privacy: .public)")
            }
            render()
        }
    }

    func render() {
        guard let button = item.button else { return }
        button.image = menuBarIcon
        button.title = counts.map { total($0).formatted() } ?? ""
        button.imagePosition = counts == nil ? .imageOnly : .imageLeading
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
