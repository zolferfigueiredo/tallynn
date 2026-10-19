import AppKit
import SwiftUI

/// Signing in and picking repositories. Built like ClaudioStat's setup window.
var settingsWindow: NSWindow?

/// The OAuth app's client ID. Public by design: the device flow needs no secret.
let clientID = Bundle.main.object(forInfoDictionaryKey: "GitHubClientID") as? String ?? ""

extension AppDelegate {
    @objc func showSettings() {
        NSApp.activate()
        // Opening it again mid sign-in must not cancel that sign-in.
        if let window = settingsWindow, window.isVisible { return window.makeKeyAndOrderFront(nil) }
        let settings = SettingsModel(app: self)
        let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(settings: settings)))
        window.styleMask = [.titled, .closable]
        window.title = "Tallynn Settings"
        window.isReleasedWhenClosed = false
        window.delegate = settings
        settings.window = window
        settings.start()
        // The hosting controller only sizes the window once shown, too late for center().
        window.setContentSize(window.contentView!.fittingSize)
        window.center()
        window.makeKeyAndOrderFront(nil)
        settingsWindow = window
    }
}

@Observable final class SettingsModel: NSObject, NSWindowDelegate {
    enum Step { case signedOut, starting, waiting(DeviceCode), signedIn(String) }

    let app: AppDelegate
    var step = Step.signedOut
    var failure: String?
    var repos: [Repo]?  // nil while loading
    var loadFailed = false
    var shown: Set<String> = []
    @ObservationIgnored weak var window: NSWindow?
    @ObservationIgnored var signingIn: Task<Void, Never>?

    init(app: AppDelegate) {
        self.app = app
    }

    func start() {
        shown = app.shownRepos
        guard app.token != nil else { return }
        step = .signedIn(app.defaults.string(forKey: "login") ?? "GitHub")
        loadRepos()
    }

    func signIn() {
        guard signingIn == nil else { return }
        failure = nil
        step = .starting
        signingIn = Task {
            defer { signingIn = nil }
            do {
                let code = try await requestDeviceCode(clientID: clientID)
                step = .waiting(code)
                let token = try await pollForToken(clientID: clientID, code: code)
                let login = try await fetchLogin(token: token)
                guard app.signedIn(token: token, login: login) else {
                    step = .signedOut
                    failure = "Couldn’t save the sign-in in the Keychain."
                    return
                }
                step = .signedIn(login)
                shown = app.shownRepos
                loadRepos()
                window?.orderFrontRegardless()  // back in front of the browser
            } catch {
                step = .signedOut
                if !Task.isCancelled { failure = message(error) }
            }
        }
    }

    func message(_ error: Error) -> String {
        switch error as? SignInError {
        case .denied: "Sign-in was cancelled on GitHub."
        case .expired: "The code expired. Sign in again for a new one."
        case .disabled: "Device Flow is off for the OAuth app. Tick Enable Device Flow in its settings on GitHub."
        default: "Couldn’t sign in to GitHub. Check your connection and try again."
        }
    }

    func cancel() { signingIn?.cancel() }

    func copyAndOpen(_ code: DeviceCode) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code.userCode, forType: .string)
        NSWorkspace.shared.open(code.verificationUri)
    }

    func loadRepos() {
        guard let token = app.token else { return }
        repos = nil
        loadFailed = false
        Task {
            do {
                repos = try await fetchRepos(token: token)
            } catch Problem.signedOut {
                app.signOut()
            } catch {
                loadFailed = true
            }
        }
    }

    func toggle(_ repo: String, _ on: Bool) {
        if on { shown.insert(repo) } else { shown.remove(repo) }
        app.show(repo, on)
    }

    func signOut() {
        app.signOut()
        repos = nil
    }

    func windowWillClose(_ notification: Notification) { cancel() }
}

struct SettingsView: View {
    let settings: SettingsModel

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 12) {
                switch settings.step {
                case .signedOut:
                    Text("Sign in with your GitHub account to count the downloads of your public and private repositories.")
                    if clientID.isEmpty {
                        Text("First add your OAuth app’s Client ID to Info.plist as GitHubClientID.").foregroundStyle(.secondary)
                    }
                    if let failure = settings.failure { Text(failure).foregroundStyle(.red) }
                    buttons {
                        Button("Sign in with GitHub") { settings.signIn() }
                            .keyboardShortcut(.defaultAction)
                            .disabled(clientID.isEmpty)
                    }
                case .starting:
                    waiting("Asking GitHub for a code…")
                    buttons { Button("Cancel") { settings.cancel() }.keyboardShortcut(.cancelAction) }
                case .waiting(let code):
                    Text("Enter this code on GitHub:")
                    Text(code.userCode)
                        .font(.system(size: 28, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                    waiting("Waiting for GitHub…")
                    buttons {
                        Button("Cancel") { settings.cancel() }.keyboardShortcut(.cancelAction)
                        Button("Copy Code & Open GitHub") { settings.copyAndOpen(code) }.keyboardShortcut(.defaultAction)
                    }
                case .signedIn(let login):
                    HStack {
                        Text("Signed in as @\(login)")
                        Spacer()
                        Button("Sign Out") { settings.signOut() }
                    }
                    Divider()
                    repositories
                }
            }
            // A fixed width wraps the text; fixedSize() then makes the window follow each step's height.
            .frame(width: 320, alignment: .leading)
        }
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
