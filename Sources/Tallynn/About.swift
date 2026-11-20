import AppKit

extension AppDelegate {
    @objc func openAuthor() { NSWorkspace.shared.open(URL(string: "https://zolfer.com/")!) }
    @objc func openSite() { NSWorkspace.shared.open(URL(string: "https://tallynn.zolfer.com/")!) }
    @objc func openCoffee() { NSWorkspace.shared.open(URL(string: "https://buymeacoffee.com/zolfer")!) }

    @objc func betasToggled(_ sender: NSSwitch) {
        defaults.set(sender.state == .on, forKey: "checkBetas")
        // A beta found while the switch was on isn't offered once it is off.
        defaults.removeObject(forKey: "availableVersion")
    }

    /// The About tab of Settings, laid out like BeeHan Brightness's About.
    func aboutPage(version number: String = appVersion) -> NSView {
        let logo = NSImageView(image: NSApp.applicationIconImage)
        logo.widthAnchor.constraint(equalToConstant: 96).isActive = true
        logo.heightAnchor.constraint(equalToConstant: 96).isActive = true
        let name = NSTextField(labelWithString: "Tallynn")
        name.font = .boldSystemFont(ofSize: 16)
        let author = NSButton(title: "Zolfer Figueiredo", target: self, action: #selector(openAuthor))
        author.isBordered = false
        author.contentTintColor = .linkColor
        let by = NSStackView(views: [NSTextField(labelWithString: tr("by")), author])
        by.spacing = 3
        for case let view as NSControl in by.views { view.font = .systemFont(ofSize: NSFont.smallSystemFontSize) }
        let versionLine = NSTextField(labelWithString: tr("version", ["version": number]))
        let betaLabel = NSTextField(labelWithString: tr("check_betas"))
        let betaSwitch = NSSwitch()
        betaSwitch.controlSize = .mini
        betaSwitch.state = defaults.object(forKey: "checkBetas") as? Bool ?? true ? .on : .off
        betaSwitch.target = self
        betaSwitch.action = #selector(betasToggled(_:))
        let betas = NSStackView(views: [betaLabel, betaSwitch])
        betas.spacing = 6
        let check = NSButton(title: tr("check"), target: self, action: #selector(checkNow))
        let line = NSBox()
        line.boxType = .separator
        let site = NSButton(title: tr("website"), target: self, action: #selector(openSite))
        site.isBordered = false
        site.contentTintColor = .linkColor
        let liked = NSTextField(labelWithString: tr("liked"))
        let coffee = NSButton(title: tr("coffee"), target: self, action: #selector(openCoffee))
        let beta = isBeta(number)
        let page = NSStackView(views: [logo, name, by, versionLine] + (beta ? [betas] : []) + [check, line, site, liked, coffee])
        page.orientation = .vertical
        page.spacing = 4
        page.setCustomSpacing(12, after: logo)
        for view in [name, by] { page.setCustomSpacing(10, after: view) }
        if beta { page.setCustomSpacing(10, after: versionLine) }
        for view in [beta ? betas : versionLine, check, line] { page.setCustomSpacing(16, after: view) }
        page.setCustomSpacing(10, after: site)
        page.setCustomSpacing(8, after: liked)
        page.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 24, right: 24)
        page.widthAnchor.constraint(greaterThanOrEqualToConstant: 340).isActive = true
        line.widthAnchor.constraint(equalTo: page.widthAnchor, constant: -48).isActive = true
        // Centred in whatever room the tab gets: the window can keep the General tab's size.
        let room = NSView()
        page.translatesAutoresizingMaskIntoConstraints = false
        room.addSubview(page)
        NSLayoutConstraint.activate([
            page.centerXAnchor.constraint(equalTo: room.centerXAnchor),
            page.centerYAnchor.constraint(equalTo: room.centerYAnchor),
            page.leadingAnchor.constraint(greaterThanOrEqualTo: room.leadingAnchor),
            page.topAnchor.constraint(greaterThanOrEqualTo: room.topAnchor),
        ])
        room.frame.size = page.fittingSize
        return room
    }
}
