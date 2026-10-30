import AppKit

enum SSHProfileEditor {
    static func present(existing: SSHProfile? = nil) -> SSHProfile? {
        let name = NSTextField(string: existing?.name ?? "")
        let host = NSTextField(string: existing?.host ?? "")
        let user = NSTextField(string: existing?.user ?? "")
        let port = NSTextField(string: String(existing?.port ?? 22))
        let identity = NSTextField(string: existing?.identityFile ?? "")

        name.placeholderString = "Production"
        host.placeholderString = "server.example.com"
        user.placeholderString = NSUserName()
        port.placeholderString = "22"
        identity.placeholderString = "~/.ssh/id_ed25519 (optional)"

        let fields: [(String, NSTextField)] = [
            ("Name", name), ("Host", host), ("User", user),
            ("Port", port), ("Identity file", identity)
        ]
        let grid = NSGridView(views: fields.map { label, field in
            let labelView = NSTextField(labelWithString: label)
            labelView.alignment = .right
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 300).isActive = true
            return [labelView, field]
        })
        grid.rowSpacing = 9
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.frame.size = grid.fittingSize

        while true {
            let alert = NSAlert()
            alert.messageText = existing == nil ? "New SSH Connection" : "Edit SSH Connection"
            alert.informativeText = "Visor saves connection details only. Passwords and key passphrases are handled by SSH."
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Cancel")
            alert.accessoryView = grid

            guard alert.runModal() == .alertFirstButtonReturn else { return nil }
            let cleanHost = host.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanHost.isEmpty, !cleanHost.hasPrefix("-") else {
                showValidation("Enter a valid host name or IP address.")
                continue
            }
            let cleanUser = user.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanUser.hasPrefix("-") else {
                showValidation("Enter a valid user name.")
                continue
            }
            guard let portNumber = Int(port.stringValue), (1...65535).contains(portNumber) else {
                showValidation("Port must be a number from 1 to 65535.")
                continue
            }

            return SSHProfile(
                id: existing?.id ?? UUID(),
                name: name.stringValue,
                host: cleanHost,
                user: cleanUser,
                port: portNumber,
                identityFile: identity.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
    }

    private static func showValidation(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Check Connection Details"
        alert.informativeText = message
        alert.runModal()
    }
}
