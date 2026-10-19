import AppKit

extension AppDelegate {
    @objc func openAuthor() { NSWorkspace.shared.open(URL(string: "https://zolfer.com/")!) }
    @objc func openGitHub() { NSWorkspace.shared.open(URL(string: "https://github.com/zolferfigueiredo/tallynn")!) }
    @objc func openCoffee() { NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/zolfer")!) }

    /// The About tab of Settings, laid out like BeeHan Brightness's About.
    func aboutPage() -> NSView {
        let logo = NSImageView(image: NSApp.applicationIconImage)
        logo.widthAnchor.constraint(equalToConstant: 96).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 96).isActive = true
        let name = NSTextField(labelWithString: "Tallynn")
        name.font = .boldSystemFont(ofSize: 16)
        let author = NSButton(title: "Zolfer Figueiredo", target: self, action: #selector(openAuthor))
        author.isBordered = false
        author.contentTintColor = .linkColor
        let by = NSStackView(views: [NSTextField(labelWithString: "Made by"), author])
        by.spacing = 3
        for case let view as NSControl in by.views { view.font = .systemFont(ofSize: NSFont.smallSystemFontSize) }
        let number = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let version = NSTextField(labelWithString: "Version \(number)")
        let line = NSBox()
        line.boxType = .separator
        let github = NSButton(title: "GitHub", target: self, action: #selector(openGitHub))
        github.isBordered = false
        github.contentTintColor = .linkColor
        let liked = NSTextField(labelWithString: "Did you like this project?")
        let coffee = NSButton(title: "Buy me a coffee", target: self, action: #selector(openCoffee))
        let page = NSStackView(views: [logo, name, by, version, line, github, liked, coffee])
        page.orientation = .vertical
        page.spacing = 4
        page.setCustomSpacing(12, after: logo)
        for view in [name, by] { page.setCustomSpacing(10, after: view) }
        for view in [version, line] { page.setCustomSpacing(16, after: view) }
        page.setCustomSpacing(10, after: github)
        page.setCustomSpacing(8, after: liked)
        page.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        page.widthAnchor.constraint(greaterThanOrEqualToConstant: 340).isActive = true
        line.widthAnchor.constraint(equalTo: page.widthAnchor, constant: -48).isActive = true
        return page
    }
}
