import Foundation

enum SSHKeySupportError: LocalizedError, Equatable {
    case identityNotSelected
    case privateKeyMissing(String)
    case publicKeyMissing(String)
    case invalidPublicKey(String)

    var errorDescription: String? {
        switch self {
        case .identityNotSelected:
            return "Choose or generate an SSH key for this connection first."
        case let .privateKeyMissing(path):
            return "The private key could not be found at \(path)."
        case let .publicKeyMissing(path):
            return "The public key could not be found at \(path). Choose a key that includes its matching .pub file."
        case let .invalidPublicKey(path):
            return "The public key at \(path) is not a supported OpenSSH public key."
        }
    }
}

enum SSHKeySupport {
    static let supportedPublicKeyPrefixes = [
        "ssh-ed25519 ", "ssh-rsa ", "ecdsa-sha2-", "sk-ssh-ed25519@openssh.com ",
        "sk-ecdsa-sha2-nistp256@openssh.com "
    ]

    static func expandedIdentityPath(for profile: SSHProfile) throws -> String {
        let storedPath = profile.identityFile.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !storedPath.isEmpty else { throw SSHKeySupportError.identityNotSelected }
        return (storedPath as NSString).expandingTildeInPath
    }

    static func publicKeyPath(for profile: SSHProfile) throws -> String {
        try expandedIdentityPath(for: profile) + ".pub"
    }

    static func storablePath(_ path: String, homeDirectory: String = NSHomeDirectory()) -> String {
        let standardizedPath = (path as NSString).standardizingPath
        let standardizedHome = (homeDirectory as NSString).standardizingPath
        guard standardizedPath == standardizedHome || standardizedPath.hasPrefix(standardizedHome + "/") else {
            return standardizedPath
        }
        return "~" + standardizedPath.dropFirst(standardizedHome.count)
    }

    static func generationCommand(path: String) -> [String] {
        ["/usr/bin/ssh-keygen", "-t", "ed25519", "-a", "64", "-f", path]
    }

    @discardableResult
    static func validatePrivateKey(for profile: SSHProfile, fileManager: FileManager = .default) throws -> String {
        let privatePath = try expandedIdentityPath(for: profile)
        guard fileManager.fileExists(atPath: privatePath) else {
            throw SSHKeySupportError.privateKeyMissing(privatePath)
        }
        return privatePath
    }

    static func keychainCommand(profile: SSHProfile) throws -> [String] {
        ["/usr/bin/ssh-add", "--apple-use-keychain", try expandedIdentityPath(for: profile)]
    }

    static func readPublicKey(for profile: SSHProfile, fileManager: FileManager = .default) throws -> String {
        let privatePath = try validatePrivateKey(for: profile, fileManager: fileManager)
        let publicPath = privatePath + ".pub"
        guard fileManager.fileExists(atPath: publicPath) else {
            throw SSHKeySupportError.publicKeyMissing(publicPath)
        }
        let contents = try String(contentsOfFile: publicPath, encoding: .utf8)
        let key = contents.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.contains("\n"), supportedPublicKeyPrefixes.contains(where: key.hasPrefix) else {
            throw SSHKeySupportError.invalidPublicKey(publicPath)
        }
        return key
    }

    static func installCommand(profile: SSHProfile, publicKey: String) -> [String] {
        let remoteCommand = #"umask 077; mkdir -p "$HOME/.ssh"; touch "$HOME/.ssh/authorized_keys"; key=$(cat); grep -qxF "$key" "$HOME/.ssh/authorized_keys" || printf '%s\n' "$key" >> "$HOME/.ssh/authorized_keys"; chmod 700 "$HOME/.ssh"; chmod 600 "$HOME/.ssh/authorized_keys"; printf 'SSH public key installed.\n'"#
        let script = #"key=$1; shift; printf '%s\n' "$key" | exec "$@""#
        return ["/bin/sh", "-c", script, "visor-key-install", publicKey]
            + sshArguments(profile: profile)
            + [remoteCommand]
    }

    static func testCommand(profile: SSHProfile) -> [String] {
        var arguments = [
            "/usr/bin/ssh",
            "-o", "PreferredAuthentications=publickey",
            "-o", "PasswordAuthentication=no",
            "-o", "KbdInteractiveAuthentication=no",
            "-o", "ConnectTimeout=8"
        ]
        arguments += connectionArguments(profile: profile)
        arguments += ["--", profile.destination, "printf 'SSH key login succeeded.\\n'"]
        return arguments
    }

    private static func sshArguments(profile: SSHProfile) -> [String] {
        ["/usr/bin/ssh"] + connectionArguments(profile: profile) + ["--", profile.destination]
    }

    private static func connectionArguments(profile: SSHProfile) -> [String] {
        var arguments = ["-p", String(profile.port)]
        let key = profile.identityFile.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            arguments += ["-i", (key as NSString).expandingTildeInPath]
        }
        return arguments
    }
}
