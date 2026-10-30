import AppKit

final class VisorSettings {
    static let shared = VisorSettings()
    private let defaults: UserDefaults

    private enum Key {
        static let opacity = "visor.opacity"
        static let fontSize = "visor.fontSize"
        static let panelHeight = "visor.panelHeight"
        static let keyboardShortcut = "visor.keyboardShortcut"
        static let autoHide = "visor.autoHide"
        static let lockedScreenIdentifier = "visor.lockedScreenIdentifier"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var opacity: CGFloat {
        get {
            let value = defaults.double(forKey: Key.opacity)
            return value == 0 ? 0.94 : CGFloat(value)
        }
        set { defaults.set(Double(newValue), forKey: Key.opacity) }
    }

    var fontSize: CGFloat {
        get {
            let value = defaults.double(forKey: Key.fontSize)
            return value == 0 ? 14 : CGFloat(value)
        }
        set { defaults.set(Double(newValue), forKey: Key.fontSize) }
    }

    var panelHeight: CGFloat {
        get {
            let value = defaults.double(forKey: Key.panelHeight)
            return value == 0 ? 460 : CGFloat(value)
        }
        set { defaults.set(Double(newValue), forKey: Key.panelHeight) }
    }

    var autoHide: Bool {
        get {
            guard defaults.object(forKey: Key.autoHide) != nil else { return true }
            return defaults.bool(forKey: Key.autoHide)
        }
        set { defaults.set(newValue, forKey: Key.autoHide) }
    }

    var lockedScreenIdentifier: String? {
        get { defaults.string(forKey: Key.lockedScreenIdentifier) }
        set {
            if let newValue {
                defaults.set(newValue, forKey: Key.lockedScreenIdentifier)
            } else {
                defaults.removeObject(forKey: Key.lockedScreenIdentifier)
            }
        }
    }


    var keyboardShortcut: KeyboardShortcut {
        get {
            guard let data = defaults.data(forKey: Key.keyboardShortcut),
                  let shortcut = try? JSONDecoder().decode(KeyboardShortcut.self, from: data) else {
                return .defaultShortcut
            }
            return shortcut
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Key.keyboardShortcut)
        }
    }
}
