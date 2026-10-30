import Foundation

struct SSHProfile: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var host: String
    var user: String
    var port: Int
    var identityFile: String

    init(id: UUID = UUID(), name: String, host: String, user: String = "", port: Int = 22, identityFile: String = "") {
        self.id = id
        self.name = name
        self.host = host
        self.user = user
        self.port = port
        self.identityFile = identityFile
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? host : trimmed
    }

    var destination: String {
        let trimmedUser = user.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedUser.isEmpty ? host : "\(trimmedUser)@\(host)"
    }

    var command: [String] {
        var arguments = ["/usr/bin/ssh", "-p", String(port)]
        let key = identityFile.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            arguments += ["-i", (key as NSString).expandingTildeInPath]
        }
        arguments += ["--", destination]
        return arguments
    }
}

final class SSHProfileStore {
    static let shared = SSHProfileStore()
    private let defaults: UserDefaults
    private let key = "visor.sshProfiles"

    private(set) var profiles: [SSHProfile] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func save(_ profile: SSHProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        persist()
    }

    func delete(id: UUID) {
        profiles.removeAll { $0.id == id }
        persist()
    }

    func profile(id: UUID) -> SSHProfile? {
        profiles.first { $0.id == id }
    }

    private func load() {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SSHProfile].self, from: data) else { return }
        profiles = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: key)
    }
}
