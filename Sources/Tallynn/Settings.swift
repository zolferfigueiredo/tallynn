import AppKit
import SwiftUI

/// One window with General (Language, Refresh rate, Total, signing in, repositories) and About tabs, in the toolbar like System Settings.
var settingsWindow: NSWindow?

enum SettingsTab: Int { case general, about }

/// Both tabs' width, so switching tabs only changes the height.
let settingsWidth: CGFloat = 480

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
        general.sizingOptions = .preferredContentSize  // the window takes the page's size
        general.title = tr("general")
        let about = NSViewController()
        about.view = aboutPage()
        about.title = tr("about_tab")
        about.preferredContentSize = NSSize(width: settingsWidth, height: about.view.fittingSize.height)
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
        about?.preferredContentSize = NSSize(width: settingsWidth, height: about?.view.fittingSize.height ?? 0)
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
    var interval = 10
    var notifications = true
    var adding = ""
    var addFailed = false
    var addingNow = false
    var language = Language.current
    @ObservationIgnored weak var window: NSWindow?
    @ObservationIgnored var signingIn: Task<Void, Never>?

    init(app: AppDelegate) {
        self.app = app
    }

    func start() {
        shown = app.shownRepos
        loadTotal()
        interval = app.defaults.integer(forKey: "interval")
        notifications = app.defaults.bool(forKey: "notifications")
        if app.token != nil { return signedIn(app.defaults.string(forKey: "login") ?? "GitHub") }
        guard signingIn == nil else { return }
        step = ghPath() == nil ? .notFound : .signedOut
        loadRepos()
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

    /// The added repositories, and the user's own while signed in.
    func loadRepos() {
        let added = app.addedRepos.map { Repo(name: $0, fullName: $0, private: false, fork: false) }
        loadFailed = false
        guard let token = app.token else { return repos = added }
        repos = nil
        Task {
            do {
                repos = tickedFirst(added + (try await fetchRepos(token: token)), shown: shown)
            } catch Problem.signedOut {
                app.disconnect(.signedOut)
            } catch {
                loadFailed = true
            }
        }
    }

    /// Any public repository, keyed by "owner/repo". One already listed (the user's own, or added before) just has
    /// its row ticked.
    func add() {
        guard !addingNow else { return }
        guard let path = repoPath(adding) else { return addFailed = true }
        addFailed = false
        addingNow = true
        let token = app.token
        Task {
            defer { addingNow = false }
            do {
                let found = try await fetchRepo(path, token: token)
                if let listed = repos?.first(where: { $0.fullName.lowercased() == found.fullName.lowercased() }) {
                    toggle(listed.name, true)
                } else {
                    app.defaults.set(app.addedRepos + [found.fullName], forKey: "addedRepos")
                    repos?.insert(Repo(name: found.fullName, fullName: found.fullName, private: found.private, fork: false), at: 0)
                    toggle(found.fullName, true)
                }
                adding = ""
            } catch Problem.signedOut {
                app.disconnect(.signedOut)
            } catch {
                addFailed = true
            }
        }
    }

    /// Switching an added repository off keeps it listed; this takes it off the list, asked first.
    func remove(_ repo: String) {
        let alert = NSAlert()
        alert.messageText = tr("remove_title", ["repo": repo])
        alert.informativeText = tr("remove_text")
        alert.addButton(withTitle: tr("remove")).hasDestructiveAction = true
        alert.addButton(withTitle: tr("cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        app.defaults.set(app.addedRepos.filter { $0 != repo }, forKey: "addedRepos")
        repos?.removeAll { $0.name == repo }
        toggle(repo, false)
    }

    func setNotifications(_ on: Bool) {
        notifications = on
        app.defaults.set(on, forKey: "notifications")
        log.notice("notifications = \(on)")
    }

    func setInterval(_ minutes: Int) {
        interval = minutes
        app.setInterval(minutes)
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
            app.tick()  // the added public repositories count on
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
        Form {
            // First, in every step: someone who can't read the rest can still find their language.
            Section(tr("app")) {
                Picker(tr("language"), selection: Binding(get: { settings.language }, set: { settings.setLanguage($0) })) {
                    ForEach(Language.allCases, id: \.self) { Text("\($0.flag) \($0.name)").tag($0) }
                }
                Picker(tr("every"), selection: Binding(get: { settings.interval }, set: { settings.setInterval($0) })) {
                    ForEach([5, 10, 30, 60], id: \.self) { Text($0 == 60 ? tr("hour") : tr("minutes", ["n": $0])).tag($0) }
                }
                Toggle(tr("notifications"), isOn: Binding(get: { settings.notifications }, set: { settings.setNotifications($0) }))
            }
            // Where the total shows. Both can be off.
            Section(tr("total")) {
                Toggle(tr("menu_bar"), isOn: Binding(get: { settings.totalInMenuBar }, set: { settings.app.setTotal("totalInMenuBar", $0) }))
                Toggle(tr("list"), isOn: Binding(get: { settings.totalInList }, set: { settings.app.setTotal("totalInList", $0) }))
            }
            Section("GitHub") { account }
            if case .signingIn = settings.step {} else { repositories }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .frame(width: settingsWidth)
        .frame(maxHeight: 640)
    }

    @ViewBuilder var account: some View {
        switch settings.step {
        case .notFound:
            Text(tr("no_gh_text"))
            HStack {
                Spacer()
                Button(tr("try_again")) { settings.start() }
                Button(tr("get_gh")) { NSWorkspace.shared.open(URL(string: "https://cli.github.com/")!) }
                    .keyboardShortcut(.defaultAction)
            }
        case .signedOut:
            LabeledContent {
                Button(tr("sign_in_github")) { settings.signIn() }.keyboardShortcut(.defaultAction)
            } label: {
                Text(tr("signed_out_text"))
                if let failure = settings.failure { Text(failure).foregroundStyle(.red) }
            }
        case .signingIn(let code):
            if let code {
                VStack(spacing: 6) {
                    Text(tr("paste_code"))
                    Text(code)
                        .font(.system(size: 30, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                    Text(tr("on_clipboard")).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            LabeledContent {
                HStack {
                    Button(tr("cancel")) { settings.cancel() }.keyboardShortcut(.cancelAction)
                    if code != nil { Button(tr("open_again")) { settings.openGitHubAgain() } }
                }
            } label: {
                waiting(tr("waiting"))
            }
        case .signedIn(let login):
            LabeledContent {
                Button(tr("sign_out")) { settings.signOut() }
            } label: {
                Label(tr("signed_in_as", ["login": login]), systemImage: "person.crop.circle.fill")
            }
        }
    }

    @ViewBuilder var repositories: some View {
        Section {
            addField
            if let repos = settings.repos {
                // Signed out, the field above is the whole story.
                if repos.isEmpty, case .signedIn = settings.step {
                    Text(tr("no_repos")).foregroundStyle(.secondary)
                }
                // Every switch keeps the trash button's room, so they line up whether a row can be removed or not.
                let removable = repos.contains { isAdded($0.name) }
                ForEach(repos, id: \.name) { repo in
                    LabeledContent {
                        HStack(spacing: 12) {
                            Toggle(repo.name, isOn: Binding(get: { settings.shown.contains(repo.name) }, set: { settings.toggle(repo.name, $0) }))
                                .labelsHidden()
                            if removable {
                                Button { settings.remove(repo.name) } label: { Image(systemName: "trash") }
                                    .buttonStyle(.borderless)
                                    .help(tr("remove"))
                                    .accessibilityLabel(tr("remove"))
                                    .opacity(isAdded(repo.name) ? 1 : 0)
                                    .disabled(!isAdded(repo.name))
                                    .accessibilityHidden(!isAdded(repo.name))
                            }
                        }
                    } label: {
                        repoName(repo)
                    }
                }
            } else if settings.loadFailed {
                LabeledContent {
                    Button(tr("try_again")) { settings.loadRepos() }
                } label: {
                    Label(tr("repos_failed"), systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
            } else {
                waiting(tr("loading_repos"))
            }
        } header: {
            HStack {
                Text(tr("repositories"))
                Spacer()
                Button { settings.loadRepos() } label: { Image(systemName: "arrow.clockwise") }
                    .buttonStyle(.borderless)
                    .help(tr("reload"))
            }
        } footer: {
            if settings.repos?.isEmpty == false { Text(tr("tick")).foregroundStyle(.secondary) }
        }
    }

    /// Any public repository, by owner/repo or a pasted link. Typing clears the last error.
    @ViewBuilder var addField: some View {
        HStack(spacing: 8) {
            TextField(tr("add_repo"), text: Binding(get: { settings.adding }, set: { settings.adding = $0; settings.addFailed = false }),
                      prompt: Text(tr("add_repo")))
                .textFieldStyle(.roundedBorder)
                .labelsHidden()
                .autocorrectionDisabled()
                .onSubmit { settings.add() }
            if settings.addingNow { ProgressView().controlSize(.small) }
            Button(tr("add")) { settings.add() }
                .disabled(settings.adding.trimmingCharacters(in: .whitespaces).isEmpty || settings.addingNow)
        }
        if settings.addFailed {
            Label(tr("add_failed"), systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
        }
    }

    /// An added repository's owner is dimmed, so its own name reads first, as in the menu.
    func repoName(_ repo: Repo) -> some View {
        HStack(spacing: 0) {
            if isAdded(repo.name), let slash = repo.name.firstIndex(of: "/") {
                Text(repo.name[...slash]).foregroundStyle(.secondary)
                Text(repo.name[repo.name.index(after: slash)...])
            } else {
                Text(repo.name)
            }
            if repo.private {
                Image(systemName: "lock.fill")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 5)
                    .accessibilityLabel(tr("private"))
            }
        }
    }

    func waiting(_ text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(text).foregroundStyle(.secondary)
        }
    }
}
