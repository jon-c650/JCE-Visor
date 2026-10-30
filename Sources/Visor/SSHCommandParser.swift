import Foundation

enum SSHCommandParser {
    private static let optionsWithValue: Set<String> = [
        "-B", "-b", "-c", "-D", "-E", "-e", "-F", "-I", "-i", "-J",
        "-L", "-l", "-m", "-O", "-o", "-p", "-Q", "-R", "-S", "-W", "-w"
    ]

    static func host(from command: String) -> String? {
        let words = shellWords(command)
        guard let sshIndex = words.firstIndex(where: { ($0 as NSString).lastPathComponent == "ssh" }) else {
            return nil
        }

        let permittedPrefixes = words[..<sshIndex].allSatisfy { word in
            word == "command" || word == "exec" || word == "sudo" || word.contains("=")
        }
        guard permittedPrefixes else { return nil }

        var index = words.index(after: sshIndex)
        while index < words.endIndex {
            let word = words[index]
            if word == "--" {
                index = words.index(after: index)
                break
            }
            if word.hasPrefix("-") {
                if optionsWithValue.contains(word) {
                    index = words.index(index, offsetBy: 2, limitedBy: words.endIndex) ?? words.endIndex
                } else {
                    index = words.index(after: index)
                }
                continue
            }
            break
        }

        guard index < words.endIndex else { return nil }
        return deviceName(from: words[index])
    }

    private static func deviceName(from destination: String) -> String? {
        var host = destination
        if let at = host.lastIndex(of: "@") {
            host = String(host[host.index(after: at)...])
        }
        if host.hasPrefix("[") && host.hasSuffix("]") {
            host = String(host.dropFirst().dropLast())
        }
        return host.isEmpty ? nil : host
    }

    private static func shellWords(_ command: String) -> [String] {
        var words: [String] = []
        var current = ""
        var quote: Character?
        var escaping = false

        for character in command {
            if escaping {
                current.append(character)
                escaping = false
            } else if character == "\\" && quote != "'" {
                escaping = true
            } else if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                } else {
                    current.append(character)
                }
            } else if character == "'" || character == "\"" {
                quote = character
            } else if character.isWhitespace {
                if !current.isEmpty {
                    words.append(current)
                    current = ""
                }
            } else {
                current.append(character)
            }
        }

        if escaping { current.append("\\") }
        if !current.isEmpty { words.append(current) }
        return words
    }
}
