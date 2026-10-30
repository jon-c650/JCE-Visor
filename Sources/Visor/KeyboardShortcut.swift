import AppKit
import Carbon

struct KeyboardShortcut: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32
    var keyLabel: String

    static let defaultShortcut = KeyboardShortcut(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(optionKey),
        keyLabel: "Space"
    )

    var displayName: String {
        var value = ""
        if modifiers & UInt32(controlKey) != 0 { value += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { value += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { value += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { value += "⌘" }
        return value + keyLabel
    }

    init(keyCode: UInt32, modifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    init?(event: NSEvent) {
        var carbonModifiers: UInt32 = 0
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }

        let hasPrimaryModifier = flags.contains(.control) || flags.contains(.option) || flags.contains(.command)
        guard hasPrimaryModifier else { return nil }
        keyCode = UInt32(event.keyCode)
        modifiers = carbonModifiers
        keyLabel = Self.label(for: event)
    }

    private static func label(for event: NSEvent) -> String {
        let namedKeys: [UInt16: String] = [
            UInt16(kVK_Space): "Space", UInt16(kVK_Return): "Return",
            UInt16(kVK_Tab): "Tab", UInt16(kVK_Escape): "Esc",
            UInt16(kVK_Delete): "Delete", UInt16(kVK_ForwardDelete): "⌦",
            UInt16(kVK_LeftArrow): "←", UInt16(kVK_RightArrow): "→",
            UInt16(kVK_UpArrow): "↑", UInt16(kVK_DownArrow): "↓",
            UInt16(kVK_Home): "Home", UInt16(kVK_End): "End",
            UInt16(kVK_PageUp): "Page Up", UInt16(kVK_PageDown): "Page Down",
            UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
            UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
            UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8", UInt16(kVK_F9): "F9",
            UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12"
        ]
        if let name = namedKeys[event.keyCode] { return name }
        let characters = event.charactersIgnoringModifiers?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return characters.isEmpty ? "Key \(event.keyCode)" : characters.uppercased()
    }
}

final class ShortcutRecorderView: NSView {
    private let label = NSTextField(labelWithString: "")
    private(set) var shortcut: KeyboardShortcut

    override var acceptsFirstResponder: Bool { true }

    init(shortcut: KeyboardShortcut) {
        self.shortcut = shortcut
        super.init(frame: NSRect(x: 0, y: 0, width: 320, height: 54))
        wantsLayer = true
        layer?.cornerRadius = 7
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.systemGreen.withAlphaComponent(0.55).cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        label.alignment = .center
        label.font = .monospacedSystemFont(ofSize: 17, weight: .semibold)
        label.textColor = .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        updateLabel()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.window?.makeFirstResponder(self)
        }
    }

    override func keyDown(with event: NSEvent) {
        guard let captured = KeyboardShortcut(event: event) else {
            NSSound.beep()
            label.stringValue = "Include ⌃, ⌥, or ⌘"
            return
        }
        shortcut = captured
        updateLabel()
    }

    private func updateLabel() {
        label.stringValue = "Press shortcut:  \(shortcut.displayName)"
    }
}
