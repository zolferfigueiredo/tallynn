import AppKit
import SwiftUI

/// One window with General (signing in, repositories, Total, Language) and About tabs, in the toolbar like System Settings.
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
        general.title = tr("general")
        let about = NSViewController()
        about.view = aboutPage()
        about.title = tr("about_tab")
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

    /// The tab names and the About page are AppKit, built once, so a new language rebuilds them. The General
    /// page is SwiftUI and follows on its own.
    func relabelSettings() {
        guard let window = settingsWindow, let tabs = window.contentViewController as? NSTabViewController else { return }
        for (item, key) in zip(tabs.tabViewItems, ["general", "about_tab"]) {
            item.label = tr(key)
            item.viewController?.title = tr(key)
        }
        let about = tabs.tabViewItems[SettingsTab.about.rawValue].viewController
        about?.view = aboutPage()
        about?.preferredContentSize = about?.view.fittingSize ?? .zero
        window.title = tabs.tabViewItems[tabs.selectedTabViewItemIndex].label
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
    var language = Language.current
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

    /// The menu is rebuilt on every open, so only this window needs telling.
    func setLanguage(_ language: Language) {
        self.language = language
        app.defaults.set(language.rawValue, forKey: "language")
        log.notice("language = \(language.rawValue, privacy: .public)")
        app.relabelSettings()
    }

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
                failure = tr("sign_in_failed")
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
        alert.messageText = tr("sign_out_title")
        alert.informativeText = tr("sign_out_text")
        alert.addButton(withTitle: tr("sign_out"))
        alert.addButton(withTitle: tr("cancel"))
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
        // Read here so a new language redraws every string below.
        let _ = settings.language
        VStack(alignment: .leading, spacing: 12) {
            switch settings.step {
            case .notFound:
                Text(tr("no_gh_text"))
                buttons {
                    Button(tr("try_again")) { settings.start() }
                    Button(tr("get_gh")) { NSWorkspace.shared.open(URL(string: "https://cli.github.com/")!) }
                        .keyboardShortcut(.defaultAction)
                }
            case .signedOut:
                Text(tr("signed_out_text"))
                if let failure = settings.failure { Text(failure).foregroundStyle(.red) }
                buttons {
                    Button(tr("sign_in_github")) { settings.signIn() }.keyboardShortcut(.defaultAction)
                }
            case .signingIn(let code):
                if let code {
                    Text(tr("paste_code"))
                    Text(code)
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                    Text(tr("on_clipboard")).foregroundStyle(.secondary)
                }
                waiting(tr("waiting"))
                buttons {
                    Button(tr("cancel")) { settings.cancel() }.keyboardShortcut(.cancelAction)
                    if code != nil { Button(tr("open_again")) { settings.openGitHubAgain() } }
                }
            case .signedIn(let login):
                HStack {
                    Text(tr("signed_in_as", ["login": login]))
                    Spacer()
                    Button(tr("sign_out")) { settings.signOut() }
                }
                Divider()
                repositories
                Divider()
                total
            }
            Divider()
            Picker(tr("language"), selection: Binding(get: { settings.language }, set: { settings.setLanguage($0) })) {
                ForEach(Language.allCases, id: \.self) { Text($0.name).tag($0) }
            }
            .pickerStyle(.menu)
        }
        // A fixed width wraps the text; fixedSize() then makes the window follow each step's height.
        .frame(width: 340, alignment: .leading)
        .padding(20)
        .fixedSize()
    }

    @ViewBuilder var repositories: some View {
        HStack {
            Text(tr("repositories")).font(.headline)
            Spacer()
            Button { settings.loadRepos() } label: { Image(systemName: "arrow.clockwise") }
                .buttonStyle(.borderless)
                .help(tr("reload"))
        }
        if let repos = settings.repos {
            if repos.isEmpty {
                Text(tr("no_repos")).foregroundStyle(.secondary)
            } else {
                Text(tr("tick")).foregroundStyle(.secondary)
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(repos, id: \.name) { repo in
                            Toggle(isOn: Binding(get: { settings.shown.contains(repo.name) }, set: { settings.toggle(repo.name, $0) })) {
                                HStack(spacing: 4) {
                                    Text(repo.name)
                                    if repo.private {
                                        Image(systemName: "lock.fill").foregroundStyle(.secondary).accessibilityLabel(tr("private"))
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
            Text(tr("repos_failed")).foregroundStyle(.red)
            buttons { Button(tr("try_again")) { settings.loadRepos() } }
        } else {
            waiting(tr("loading_repos"))
        }
    }

    /// Where the total shows, as in the menu's Total submenu. The last place still on can't be turned off.
    @ViewBuilder var total: some View {
        Text(tr("total")).font(.headline)
        Toggle(tr("menu_bar"), isOn: Binding(get: { settings.totalInMenuBar }, set: { settings.app.setTotal("totalInMenuBar", $0) }))
            .toggleStyle(.checkbox)
            .disabled(settings.totalInMenuBar && !settings.totalInList)
        Toggle(tr("list"), isOn: Binding(get: { settings.totalInList }, set: { settings.app.setTotal("totalInList", $0) }))
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
