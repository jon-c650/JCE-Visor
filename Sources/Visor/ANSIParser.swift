import AppKit

struct ANSIParser {
    private(set) var foreground = NSColor(calibratedRed: 0.25, green: 1, blue: 0.35, alpha: 1)
    private(set) var bold = false
    private var pending = ""

    mutating func parse(_ data: Data, fontSize: CGFloat) -> NSAttributedString {
        let decoded = String(decoding: data, as: UTF8.self)
            .replacingOccurrences(of: "\r\n", with: "\n")
        let input = pending + decoded
        pending = ""
        let result = NSMutableAttributedString()
        var plain = ""
        var index = input.startIndex

        func attributes() -> [NSAttributedString.Key: Any] {
            let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: bold ? .bold : .regular)
            return [.font: font, .foregroundColor: foreground]
        }

        func flush() {
            guard !plain.isEmpty else { return }
            result.append(NSAttributedString(string: plain, attributes: attributes()))
            plain = ""
        }

        while index < input.endIndex {
            if input[index] == "\u{1B}" {
                flush()
                let escapeStart = index
                let next = input.index(after: index)
                guard next < input.endIndex else {
                    pending = String(input[index...])
                    break
                }

                if input[next] == "[" {
                    let parametersStart = input.index(after: next)
                    var final = parametersStart
                    while final < input.endIndex {
                        let scalar = input[final].unicodeScalars.first?.value ?? 0
                        if scalar >= 0x40 && scalar <= 0x7e { break }
                        final = input.index(after: final)
                    }
                    guard final < input.endIndex else {
                        pending = String(input[escapeStart...])
                        break
                    }
                    if input[final] == "m" {
                        let sequence = input[parametersStart..<final]
                        applySGR(sequence.split(separator: ";").compactMap { Int($0) })
                    }
                    index = input.index(after: final)
                } else if input[next] == "]" {
                    var end = input.index(after: next)
                    var foundEnd = false
                    while end < input.endIndex {
                        if input[end] == "\u{07}" {
                            end = input.index(after: end)
                            foundEnd = true
                            break
                        }
                        if input[end] == "\u{1B}" {
                            let afterEscape = input.index(after: end)
                            if afterEscape < input.endIndex, input[afterEscape] == "\\" {
                                end = input.index(after: afterEscape)
                                foundEnd = true
                                break
                            }
                        }
                        end = input.index(after: end)
                    }
                    guard foundEnd else {
                        pending = String(input[escapeStart...])
                        break
                    }
                    index = end
                } else {
                    index = input.index(after: next)
                }
            } else if input[index] == "\r" {
                index = input.index(after: index)
            } else if input[index] == "\u{08}" {
                if !plain.isEmpty { plain.removeLast() }
                index = input.index(after: index)
            } else {
                plain.append(input[index])
                index = input.index(after: index)
            }
        }
        flush()
        return result
    }

    private mutating func applySGR(_ codes: [Int]) {
        let values = codes.isEmpty ? [0] : codes
        for code in values {
            switch code {
            case 0:
                foreground = NSColor(calibratedRed: 0.25, green: 1, blue: 0.35, alpha: 1)
                bold = false
            case 1: bold = true
            case 22: bold = false
            case 30...37: foreground = Self.basicColors[code - 30]
            case 90...97: foreground = Self.brightColors[code - 90]
            case 39: foreground = NSColor(calibratedRed: 0.25, green: 1, blue: 0.35, alpha: 1)
            default: break
            }
        }
    }

    private static let basicColors: [NSColor] = [.black, .systemRed, .systemGreen, .systemYellow, .systemBlue, .systemPink, .systemTeal, .lightGray]
    private static let brightColors: [NSColor] = [.darkGray, .red, .green, .yellow, .blue, .magenta, .cyan, .white]
}
