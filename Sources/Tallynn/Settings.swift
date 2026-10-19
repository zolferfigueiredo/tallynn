import AppKit
import SwiftUI

/// One window with General (signing in, repositories, Total) and About tabs, in the toolbar like System Settings.
var settingsWindow: NSWindow?

enum SettingsTab: Int { case general, about }

extension AppDelegate {
    @objc func showSettings() { openSettings(.general) }
    @objc func showAbout() { openSettings(.about) }

    func openSettings(_ tab: SettingsTab) {
        NSApp.activate()
        // Opening it again mid sign-in must not cancel that sign-in.
        if let window = settingsWindow, window.isVisible {
            (window.contentViewController as? NSTabViewController)?.selectedTabViewItemIndex = tab.rawValue
            return window.makeKeyAndOrderFront(nil)
        }
        let settings = SettingsModel(app: self)
        let general = NSHostingController(rootView: SettingsView(settings: settings))
        general.sizingOptions = .preferredContentSize  // the window follows each sign-in step's height
        general.title = "General"
        let about = NSViewController()
        about.view = aboutPage()
        about.title = "About"
        about.preferredContentSize = about.view.fittingSize
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        for (page, symbol) in [(general as NSViewController, "gearshape"), (about, "info.circle")] {
            let item = NSTabViewItem(viewController: page)
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: page.title)
            tabs.addTabViewItem(item)
        }
        tabs.selectedTabViewItemIndex = tab.rawValue
        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.delegate = settings
        settings.window = window
        settings.start()
        window.center()
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }
}

@Observable final class SettingsModel: NSObject, NSWindowDelegate {
    enum Step { case notFound, signedOut, signingIn(code: String?), signedIn(String) }

    let app: AppDelegate
    var step = Step.signedOut
    var failure: String?
    var repos: [Repo]?  // nil while loading
    var loadFailed = false
    var shown: Set<String> = []
    var totalInMenuBar = true
    var totalInList = false
    @ObservationIgnored weak var window: NSWindow?
    @ObservationIgnored var signingIn: Task<Void, Never>?

    init(app: AppDelegate) {
        self.app = app
    }

    func start() {
        shown = app.shownRepos
        loadTotal()
        if app.token != nil { return signedIn(app.defaults.string(forKey: "login") ?? "GitHub") }
        guard signingIn == nil else { return }
        repos = nil
        step = ghPath() == nil ? .notFound : .signedOut
    }

    func loadTotal() { (totalInMenuBar, totalInList) = app.places }

    func signedIn(_ login: String) {
        step = .signedIn(login)
        shown = app.shownRepos
        loadRepos()
    }

    /// Runs the GitHub CLI's browser sign-in, as ClaudioStat runs Claude Code's. gh copies its one-time code to the
    /// clipboard and names the page; Tallynn opens it and waits for gh to finish.
    func signIn() {
        guard signingIn == nil, let path = ghPath() else { return start() }
        failure = nil
        step = .signingIn(code: nil)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["auth", "login", "--web", "--hostname", "github.com", "--git-protocol", "https"]
        let prompt = Pipe()
        process.standardOutput = prompt
        process.standardError = prompt
        process.standardInput = FileHandle.nullDevice
        signingIn = Task {
            let reading = Task {
                var opened = false
                for try await line in prompt.fileHandleForReading.bytes.lines {
                    let found = loginPrompt(line)
                    if let code = found.code { step = .signingIn(code: code) }
                    if let url = found.url, !opened {
                        opened = true
                        NSWorkspace.shared.open(url)
                    }
                }
            }
            let status = await exitStatus(process)
            reading.cancel()
            signingIn = nil
            guard !Task.isCancelled else { return start() }
            if status == 0 {
                await app.connect()
                app.render()
                app.reschedule()
                window?.orderFrontRegardless()  // back in front of the browser
            } else {
                failure = "Couldn’t sign in to GitHub. Try again."
            }
            start()
        }
    }

    func cancel() { signingIn?.cancel() }

    func openGitHubAgain() { NSWorkspace.shared.open(URL(string: "https://github.com/login/device")!) }

    func loadRepos() {
        guard let token = app.token else { return }
        repos = nil
        loadFailed = false
        Task {
            do {
                repos = try await fetchRepos(token: token)
            } catch Problem.signedOut {
                app.disconnect(.signedOut)
            } catch {
                loadFailed = true
            }
        }
    }

    func toggle(_ repo: String, _ on: Bool) {
        if on { shown.insert(repo) } else { shown.remove(repo) }
        app.show(repo, on)
    }

    /// Like removing a profile in ClaudioStat, which signs Claude Code out too: asked first.
    func signOut() {
        guard case .signedIn(let login) = step, let path = ghPath() else { return }
        let alert = NSAlert()
        alert.messageText = "Sign out of GitHub?"
        alert.informativeText = "Tallynn uses the GitHub CLI’s login, so this also signs the GitHub CLI out on this Mac."
        alert.addButton(withTitle: "Sign Out")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task {
            _ = await gh(path, ["auth", "logout", "--hostname", "github.com", "--user", login])
            app.disconnect(.signedOut)
            app.render()
        }
    }

    // Not kept once closed: its SwiftUI views hold about 28 MB. AppKit keeps the last key window alive, so its
    // content is dropped too. After this call, as AppKit is still closing it.
    func windowWillClose(_ notification: Notification) {
        cancel()
        DispatchQueue.main.async { [window] in
            window?.contentViewController = nil
            if settingsWindow === window { settingsWindow = nil }
        }
    }
}

struct SettingsView: View {
    let settings: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch settings.step {
            case .notFound:
                Text("Tallynn signs in through the GitHub CLI, which isn’t installed. Install it with Homebrew: brew install gh")
                buttons {
                    Button("Try Again") { settings.start() }
                    Button("Get GitHub CLI") { NSWorkspace.shared.open(URL(string: "https://cli.github.com/")!) }
                        .keyboardShortcut(.defaultAction)
                }
            case .signedOut:
                Text("Sign in with your GitHub account to count the downloads of your public and private repositories.")
                if let failure = settings.failure { Text(failure).foregroundStyle(.red) }
                buttons {
                    Button("Sign in with GitHub") { settings.signIn() }.keyboardShortcut(.defaultAction)
                }
            case .signingIn(let code):
                if let code {
                    Text("GitHub opened in your browser. Paste this code there, then approve:")
                    Text(code)
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                    Text("It’s already on the clipboard.").foregroundStyle(.secondary)
                }
                waiting("Waiting for GitHub…")
                buttons {
                    Button("Cancel") { settings.cancel() }.keyboardShortcut(.cancelAction)
                    if code != nil { Button("Open GitHub Again") { settings.openGitHubAgain() } }
                }
            case .signedIn(let login):
                HStack {
                    Text("Signed in as @\(login)")
                    Spacer()
                    Button("Sign Out") { settings.signOut() }
                }
                Divider()
                repositories
                Divider()
                total
            }
        }
        // A fixed width wraps the text; fixedSize() then makes the window follow each step's height.
        .frame(width: 340, alignment: .leading)
        .padding(20)
        .fixedSize()
    }

    @ViewBuilder var repositories: some View {
        HStack {
            Text("Repositories").font(.headline)
            Spacer()
            Button { settings.loadRepos() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
                .help("Reload the list")
        }
        if let repos = settings.repos {
            if repos.isEmpty {
                Text("No repositories yet.").foregroundStyle(.secondary)
            } else {
                Text("Tick the ones to show in the menu.").foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(repos, id: \.name) { repo in
                            Toggle(isOn: Binding(get: { settings.shown.contains(repo.name) }, set: { settings.toggle(repo.name, $0) })) {
                                HStack(spacing: 4) {
                                    Text(repo.name)
                                    if repo.private {
                                        Image(systemName: "lock.fill").foregroundStyle(.secondary).accessibilityLabel("Private")
                                    }
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                // ponytail: rows taken as 22 pt; measure them if the list ever looks cut off or padded.
                .frame(height: min(CGFloat(repos.count), 12) * 22)
            }
        } else if settings.loadFailed {
            Text("Couldn’t load your repositories.").foregroundStyle(.red)
            buttons { Button("Try Again") { settings.loadRepos() } }
        } else {
            waiting("Loading repositories…")
        }
    }

    /// Where the total shows, as in the menu's Total submenu. The last place still on can't be turned off.
    @ViewBuilder var total: some View {
        Text("Total").font(.headline)
        Toggle("Menu bar", isOn: Binding(get: { settings.totalInMenuBar }, set: { settings.app.setTotal("totalInMenuBar", $0) }))
            .toggleStyle(.checkbox)
            .disabled(settings.totalInMenuBar && !settings.totalInList)
        Toggle("List", isOn: Binding(get: { settings.totalInList }, set: { settings.app.setTotal("totalInList", $0) }))
            .toggleStyle(.checkbox)
            .disabled(settings.totalInList && !settings.totalInMenuBar)
    }

    func waiting(_ text: String) -> some View {
        HStack {
            ProgressView().controlSize(.small)
            Text(text)
        }
    }

    func buttons(@ViewBuilder _ content: () -> some View) -> some View {
        HStack {
            Spacer()
            content()
        }
    }
}
