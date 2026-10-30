import AppKit
import Carbon

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = VisorSettings.shared
    private var visorController: VisorWindowController?
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        configureMainMenu()

        let controller = VisorWindowController()
        visorController = controller
        controller.onShortcutChange = { [weak self] shortcut in
            self?.changeShortcut(to: shortcut) ?? .failure(GlobalHotKey.RegistrationError.failed(OSStatus(paramErr)))
        }
        _ = changeShortcut(to: settings.keyboardShortcut)

        controller.show()
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu(title: "Main Menu")
        let applicationItem = NSMenuItem()
        mainMenu.addItem(applicationItem)

        let applicationMenu = NSMenu(title: "Visor")
        let about = NSMenuItem(title: "About Visor", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        about.target = NSApp
        applicationMenu.addItem(about)
        applicationMenu.addItem(.separator())
        let toggle = NSMenuItem(title: "Show or Hide Visor", action: #selector(toggleVisor), keyEquivalent: "")
        toggle.target = self
        applicationMenu.addItem(toggle)
        applicationMenu.addItem(.separator())
        let hide = NSMenuItem(title: "Hide Visor", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        hide.target = NSApp
        applicationMenu.addItem(hide)
        applicationMenu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Visor", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        applicationMenu.addItem(quit)

        applicationItem.submenu = applicationMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(menuItem("Copy", action: #selector(copyTerminal), key: "c"))
        editMenu.addItem(menuItem("Paste", action: #selector(pasteTerminal), key: "v"))
        editMenu.addItem(menuItem("Select All", action: #selector(selectAllTerminal), key: "a"))
        editMenu.addItem(.separator())
        editMenu.addItem(menuItem("Clear Scrollback", action: #selector(clearTerminal), key: "k"))
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    private func menuItem(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func toggleVisor() {
        visorController?.toggle()
    }

    @objc private func copyTerminal() { visorController?.copyTerminalSelection() }
    @objc private func pasteTerminal() { visorController?.pasteIntoTerminal() }
    @objc private func selectAllTerminal() { visorController?.selectAllTerminalText() }
    @objc private func clearTerminal() { visorController?.clearTerminalScrollback() }

    private func changeShortcut(to shortcut: KeyboardShortcut) -> Result<Void, Error> {
        let previous = settings.keyboardShortcut
        hotKey = nil
        do {
            hotKey = try GlobalHotKey(keyCode: shortcut.keyCode, modifiers: shortcut.modifiers) { [weak self] in
                self?.visorController?.toggle()
            }
            settings.keyboardShortcut = shortcut
            return .success(())
        } catch {
            hotKey = try? GlobalHotKey(keyCode: previous.keyCode, modifiers: previous.modifiers) { [weak self] in
                self?.visorController?.toggle()
            }
            return .failure(error)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        visorController?.terminateSessions()
    }

    func applicationDidResignActive(_ notification: Notification) {
        if settings.autoHide { visorController?.hide() }
    }

    func applicationDidChangeScreenParameters(_ notification: Notification) {
        visorController?.screenConfigurationChanged()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        visorController?.show()
        return true
    }
}
