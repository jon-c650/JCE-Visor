import AppKit

final class ChromeIconButton: NSButton {
    init(symbol: String, help: String, target: AnyObject?, action: Selector?, size: CGFloat = 28) {
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: help)
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        toolTip = help
        self.target = target
        self.action = action
        isBordered = false
        focusRingType = .none
        contentTintColor = NSColor(calibratedWhite: 0.72, alpha: 1)
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: size).isActive = true
        heightAnchor.constraint(equalToConstant: size).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class TabChipView: NSView {
    init(
        title: String,
        symbol: String? = nil,
        index: Int,
        selected: Bool,
        target: AnyObject,
        selectAction: Selector,
        closeAction: Selector
    ) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.backgroundColor = (selected
            ? NSColor(calibratedWhite: 0.16, alpha: 1)
            : NSColor.clear).cgColor
        if selected {
            layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.32).cgColor
            layer?.borderWidth = 1
        }

        let titleButton = NSButton(title: title, target: target, action: selectAction)
        titleButton.tag = index
        titleButton.isBordered = false
        titleButton.focusRingType = .none
        titleButton.alignment = .left
        titleButton.lineBreakMode = .byTruncatingTail
        titleButton.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: selected ? .semibold : .regular),
                .foregroundColor: selected
                    ? NSColor(calibratedRed: 0.45, green: 1, blue: 0.55, alpha: 1)
                    : NSColor(calibratedWhite: 0.68, alpha: 1)
            ]
        )
        titleButton.translatesAutoresizingMaskIntoConstraints = false

        if let symbol {
            titleButton.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            titleButton.imagePosition = .imageLeading
            titleButton.imageScaling = .scaleProportionallyDown
        }

        let closeButton = ChromeIconButton(symbol: "xmark", help: "Close \(title)", target: target, action: closeAction, size: 20)
        closeButton.tag = index
        closeButton.contentTintColor = NSColor(calibratedWhite: selected ? 0.66 : 0.48, alpha: 1)

        addSubview(titleButton)
        addSubview(closeButton)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 132),
            heightAnchor.constraint(equalToConstant: 28),
            titleButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            titleButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -3),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class SSHBookmarkButton: NSButton {
    init(profile: SSHProfile, target: AnyObject, action: Selector) {
        super.init(frame: .zero)
        title = profile.displayName
        image = NSImage(systemSymbolName: "link", accessibilityDescription: "Connect to \(profile.displayName)")
        imagePosition = .imageLeading
        imageScaling = .scaleProportionallyDown
        toolTip = "Connect to \(profile.destination) on port \(profile.port)"
        self.target = target
        self.action = action
        identifier = NSUserInterfaceItemIdentifier(profile.id.uuidString)
        isBordered = false
        focusRingType = .none
        font = .systemFont(ofSize: 11, weight: .medium)
        contentTintColor = NSColor(calibratedWhite: 0.72, alpha: 1)
        wantsLayer = true
        layer?.cornerRadius = 5
        layer?.backgroundColor = NSColor(calibratedWhite: 0.13, alpha: 0.9).cgColor
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: 24).isActive = true
        widthAnchor.constraint(lessThanOrEqualToConstant: 180).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
