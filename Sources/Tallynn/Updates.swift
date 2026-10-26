import AppKit
import UserNotifications

let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
let releasesPage = URL(string: "https://github.com/zolferfigueiredo/tallynn/releases")!

/// The newest release as release.sh publishes it: tag v1.2.3 with Tallynn-1.2.3.dmg.
nonisolated struct LatestRelease: Equatable, Sendable {
    let version: String
    let dmg: URL  // the asset's API URL, downloaded with the sign-in
}

nonisolated private struct ReleaseInfo: Decodable {
    nonisolated struct Asset: Decodable { let name: String; let url: URL }
    let tagName: String
    let assets: [Asset]
}

/// The version without the tag's "v", and its DMG. nil when the release has no DMG for that version.
nonisolated func latestRelease(from data: Data) -> LatestRelease? {
    guard let info: ReleaseInfo = try? decode(data) else { return nil }
    let version = info.tagName.hasPrefix("v") ? String(info.tagName.dropFirst()) : info.tagName
    return info.assets.first { $0.name == "Tallynn-\(version).dmg" }.map { LatestRelease(version: version, dmg: $0.url) }
}

/// The repository is private, so its releases are read with the GitHub CLI's login. Drafts and pre-releases never
/// count as latest. nil when GitHub can't be reached or the release has no DMG.
@concurrent nonisolated func fetchLatestRelease(token: String) async -> LatestRelease? {
    let url = URL(string: "https://api.github.com/repos/zolferfigueiredo/tallynn/releases/latest")!
    guard let (data, _) = try? await get(url, token: token) else { return nil }
    return latestRelease(from: data)
}

/// GitHub answers an asset request with a redirect to a pre-signed storage link, which refuses a second credential,
/// so the token only ever goes to api.github.com.
nonisolated final class DropTokenOnRedirect: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest) async -> URLRequest? {
        var request = request
        if request.url?.host != "api.github.com" { request.setValue(nil, forHTTPHeaderField: "Authorization") }
        return request
    }
}

@concurrent nonisolated func downloadAsset(_ url: URL, token: String) async throws -> (URL, URLResponse) {
    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
    return try await session.download(for: request, delegate: DropTokenOnRedirect())
}

nonisolated func isNewer(_ remote: String, than local: String) -> Bool {
    remote.compare(local, options: .numeric) == .orderedDescending
}

/// `every` 0 means never.
nonisolated func updateCheckIsDue(last: Date?, every: TimeInterval, now: Date) -> Bool {
    every > 0 && now.timeIntervalSince(last ?? .distantPast) >= every
}

nonisolated struct UpdateError: LocalizedError {
    let errorDescription: String?
}

/// Only builds signed by this team install. A valid signature alone would accept anyone's app.
let teamRequirement = #"=anchor apple generic and certificate leaf[subject.OU] = "497V6MCDS8""#

/// Opens this app again once this process has quit, so the old and new copies never run at once.
func relaunchWhenQuit() throws {
    // The PID and the app path go in as $0 and $1, never spliced into the script.
    _ = try Process.run(URL(fileURLWithPath: "/bin/sh"),
                        arguments: ["-c", #"while kill -0 "$0" 2>/dev/null; do sleep 0.2; done; open "$1""#,
                                    "\(getpid())", Bundle.main.bundlePath])
}

/// "Update available!" over "Install version 0.3.0 now", for the menu item that replaces Check for updates.
func updateAvailableTitle(_ version: String) -> NSAttributedString {
    let bold = NSFontManager.shared.convert(NSFont.menuFont(ofSize: 0), toHaveTrait: .boldFontMask)
    let title = NSMutableAttributedString(string: tr("update_available") + "\n", attributes: [.font: bold])
    title.append(NSAttributedString(string: tr("install_now", ["version": version]),
                                    attributes: [.font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize),
                                                 .foregroundColor: NSColor.secondaryLabelColor]))
    return title
}

/// The filled download arrow in the accent color, so the item stands out.
func updateAvailableIcon() -> NSImage? {
    NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: tr("update_available"))?
        .withSymbolConfiguration(.init(paletteColors: [.controlAccentColor]))
}

/// While an update installs: what it's doing, a loading bar, and Reopen once the new version is in place.
final class UpdateProgress: NSObject {
    private let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: false)
    private let status = NSTextField(labelWithString: "")
    private let bar = NSProgressIndicator()
    private let reopen = NSButton(title: tr("reopen"), target: nil, action: nil)
    /// The window outlives the code that started the update, and its Reopen button needs this object alive.
    private static var open: UpdateProgress?

    /// What the update underway says it is doing, nil when there is none. The window stays up until Reopen, so an
    /// installed update counts too: nothing may start a second install meanwhile.
    static var underway: String? { open?.status.stringValue }

    init(_ title: String) {
        super.init()
        let heading = NSTextField(labelWithString: title)
        heading.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        status.textColor = .secondaryLabelColor
        status.lineBreakMode = .byTruncatingTail  // one line, never wider than the bar
        bar.style = .bar
        bar.isIndeterminate = true
        bar.widthAnchor.constraint(equalToConstant: 300).isActive = true
        reopen.target = self
        reopen.action = #selector(relaunch)
        reopen.keyEquivalent = "\r"
        reopen.isEnabled = false  // until the new version is in place
        let buttons = NSStackView()
        buttons.setViews([reopen], in: .trailing)
        let text = NSStackView(views: [heading, status, bar, buttons])
        text.orientation = .vertical
        text.alignment = .leading
        text.setCustomSpacing(16, after: bar)
        buttons.widthAnchor.constraint(equalTo: bar.widthAnchor).isActive = true
        status.widthAnchor.constraint(equalTo: bar.widthAnchor).isActive = true
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown  // fill the 64 pt box whatever size the image says it is
        icon.widthAnchor.constraint(equalToConstant: 64).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 64).isActive = true
        let row = NSStackView(views: [icon, text])
        row.alignment = .top
        row.spacing = 16
        row.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        // The stack only applies its inset on the edge it aligns (the top), so the bottom margin is pinned here.
        row.bottomAnchor.constraint(greaterThanOrEqualTo: text.bottomAnchor, constant: 20).isActive = true
        window.contentView = row
        window.setContentSize(row.fittingSize)
        window.isReleasedWhenClosed = false
        window.center()
        bar.startAnimation(nil)
    }

    func show() {
        Self.open = self
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func step(_ text: String) { status.stringValue = text }

    /// The new version is in place: the bar fills and Reopen starts it.
    func done(_ text: String) {
        status.stringValue = text
        bar.stopAnimation(nil)
        bar.isIndeterminate = false
        bar.doubleValue = bar.maxValue
        reopen.isEnabled = true
    }

    func close() {
        window.close()
        Self.open = nil
    }

    @objc private func relaunch() {
        do {
            try relaunchWhenQuit()
            NSApp.terminate(nil)
        } catch {
            status.stringValue = tr("reopen_failed", ["error": error.localizedDescription])
        }
    }
}

/// An automatic check tells about a new version once, as a notification, instead of interrupting with an alert.
/// False when notifications aren't allowed, so the caller falls back to the alert.
func notifyUpdate(_ version: String) async -> Bool {
    if UserDefaults.standard.string(forKey: "notifiedVersion") == version { return true }
    // Notifications off: the menu's Update available! says it, without an alert either.
    guard UserDefaults.standard.bool(forKey: "notifications") else { return true }
    let center = UNUserNotificationCenter.current()
    guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return false }
    let content = UNMutableNotificationContent()
    content.title = tr("available", ["version": version])
    content.body = tr("click_to_update", ["version": appVersion])
    content.sound = .default
    guard (try? await center.add(UNNotificationRequest(identifier: "update", content: content, trigger: nil))) != nil else {
        return false
    }
    UserDefaults.standard.set(version, forKey: "notifiedVersion")
    return true
}

/// Replaces the running bundle with the one in the release's DMG. The caller relaunches.
/// URLSession downloads carry no quarantine flag, so the new copy opens without the Gatekeeper prompt.
func install(_ release: LatestRelease, token: String, step: (String) -> Void) async throws {
    let files = FileManager.default
    let work = try files.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: Bundle.main.bundleURL, create: true)
    defer { try? files.removeItem(at: work) }

    step(tr("downloading", ["version": release.version]))
    let (download, response) = try await downloadAsset(release.dmg, token: token)
    let dmg = work.appending(path: "update.dmg")
    try files.moveItem(at: download, to: dmg)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError(errorDescription: tr("download_failed")) }

    let mount = work.appending(path: "mount")
    try files.createDirectory(at: mount, withIntermediateDirectories: true)
    try await run("/usr/bin/hdiutil", "attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen", "-mountpoint", mount.path)
    let fresh = work.appending(path: "Tallynn.app")
    do {
        try await run("/usr/bin/ditto", mount.appending(path: "Tallynn.app").path, fresh.path)
    } catch {
        try? await run("/usr/bin/hdiutil", "detach", mount.path, "-force")
        throw error
    }
    try? await run("/usr/bin/hdiutil", "detach", mount.path, "-force")

    step(tr("checking_signature"))
    do {
        try await run("/usr/bin/codesign", "--verify", "--strict", "-R" + teamRequirement, fresh.path)
    } catch {
        throw UpdateError(errorDescription: tr("not_signed"))
    }
    let info = Bundle(url: fresh)?.infoDictionary
    guard info?["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
          info?["CFBundleShortVersionString"] as? String == release.version else {
        throw UpdateError(errorDescription: tr("wrong_download", ["version": release.version]))
    }
    step(tr("installing"))
    _ = try files.replaceItemAt(Bundle.main.bundleURL, withItemAt: fresh)
}

/// Runs a tool and throws when it exits with an error.
private nonisolated func run(_ tool: String, _ arguments: String...) async throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool)
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    let status = await exitStatus(process)
    guard status == 0 else {
        throw UpdateError(errorDescription: tr("tool_failed", ["tool": URL(fileURLWithPath: tool).lastPathComponent, "code": status]))
    }
}

extension AppDelegate {
    @objc func autoCheck() {
        let every = TimeInterval(defaults.integer(forKey: "updateEvery"))
        guard token != nil, updateCheckIsDue(last: defaults.object(forKey: "lastUpdateCheck") as? Date, every: every, now: .now) else { return }
        checkForUpdates(quiet: true)
    }

    @objc func checkNow() { checkForUpdates(quiet: false) }

    /// The newer version a check found, while this one is still older.
    var availableUpdate: String? {
        defaults.string(forKey: "availableVersion").flatMap { isNewer($0, than: appVersion) ? $0 : nil }
    }

    /// Once, right after a self-update relaunched into this version.
    func showUpdateComplete() {
        guard let version = defaults.string(forKey: "updatedTo") else { return }
        defaults.removeObject(forKey: "updatedTo")
        guard version == appVersion else { return }
        alert(tr("update_complete"), tr("now_using", ["version": appVersion]), tr("ok"))
    }

    /// Quiet checks only speak up when there is a new version.
    func checkForUpdates(quiet: Bool) {
        guard !checking, UpdateProgress.underway == nil else { return }
        guard let token else {
            if !quiet { alert(tr("sign_in_to_check"), tr("sign_in_to_check_text"), tr("ok")) }
            return
        }
        checking = true
        Task {
            defer { checking = false }
            guard let latest = await fetchLatestRelease(token: token) else {
                log.notice("update check failed")
                if !quiet { alert(tr("check_failed"), tr("check_failed_text"), tr("ok")) }
                return
            }
            defaults.set(Date.now, forKey: "lastUpdateCheck")
            defaults.set(latest.version, forKey: "availableVersion")
            log.notice("latest \(latest.version, privacy: .public), running \(appVersion, privacy: .public)")
            guard isNewer(latest.version, than: appVersion) else {
                if !quiet { alert(tr("up_to_date"), tr("newest", ["version": appVersion]), tr("ok")) }
                return
            }
            if quiet, await notifyUpdate(latest.version) { return }
            guard alert(tr("available", ["version": latest.version]), tr("update_question", ["version": appVersion]), tr("update_now"), tr("later")) else { return }
            let progress = UpdateProgress(tr("updating_to", ["version": latest.version]))
            do {
                guard Bundle.main.bundlePath.hasPrefix("/Applications/") else {
                    throw UpdateError(errorDescription: tr("applications_only"))
                }
                progress.show()
                try await install(latest, token: token) { progress.step($0) }
                defaults.set(latest.version, forKey: "updatedTo")
                progress.done(tr("installed", ["version": latest.version]))
            } catch {
                progress.close()
                log.error("update: \(error.localizedDescription, privacy: .public)")
                if alert(tr("update_failed"), error.localizedDescription, tr("download"), tr("cancel")) {
                    NSWorkspace.shared.open(releasesPage.appending(path: "tag/v\(latest.version)"))
                }
            }
        }
    }

    /// True when the first button was clicked.
    @discardableResult
    func alert(_ title: String, _ text: String, _ buttons: String...) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        buttons.forEach { alert.addButton(withTitle: $0) }
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }
}
