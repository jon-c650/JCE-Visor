import AppKit
import WebKit

private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

final class TerminalWebView: NSView, WKScriptMessageHandler, WKNavigationDelegate {
    var onInput: ((Data) -> Void)?
    var onResize: ((UInt16, UInt16) -> Void)?
    var onTitleChange: ((String) -> Void)?

    private let webView: WKWebView
    private var ready = false
    private var queuedOutput: [Data] = []
    private var desiredFontSize = VisorSettings.shared.fontSize
    private static let messageNames = [
        "terminalInput", "terminalBinary", "terminalResize", "terminalReady",
        "terminalCopy", "terminalPasteRequest", "terminalTitle", "terminalBell"
    ]

    override init(frame frameRect: NSRect) {
        let controller = WKUserContentController()
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = controller
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init(frame: frameRect)

        for name in Self.messageNames {
            controller.add(WeakScriptMessageHandler(target: self), name: name)
        }

        webView.navigationDelegate = self
        webView.setValue(false, forKey: "drawsBackground")
        webView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        loadTerminal()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        let controller = webView.configuration.userContentController
        Self.messageNames.forEach(controller.removeScriptMessageHandler(forName:))
    }

    private func loadTerminal() {
        guard let url = Bundle.module.url(forResource: "terminal", withExtension: "html", subdirectory: "Resources") else {
            assertionFailure("Missing terminal.html")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "terminalInput":
            if let value = message.body as? String { onInput?(Data(value.utf8)) }
        case "terminalBinary":
            if let value = message.body as? String, let data = Data(base64Encoded: value) { onInput?(data) }
        case "terminalCopy":
            if let value = message.body as? String { writeToPasteboard(value) }
        case "terminalPasteRequest":
            paste()
        case "terminalTitle":
            if let value = message.body as? String { onTitleChange?(value) }
        case "terminalBell":
            NSSound.beep()
        case "terminalResize", "terminalReady":
            if let size = message.body as? [String: Any],
               let columns = size["cols"] as? NSNumber,
               let rows = size["rows"] as? NSNumber {
                onResize?(rows.uint16Value, columns.uint16Value)
            }
            if message.name == "terminalReady" {
                ready = true
                evaluate("window.setFontSize(\(Double(desiredFontSize)))")
                let output = queuedOutput
                queuedOutput.removeAll()
                output.forEach(write)
            }
        default: break
        }
    }

    func write(_ data: Data) {
        guard ready else {
            queuedOutput.append(data)
            return
        }
        let encoded = data.base64EncodedString()
        webView.evaluateJavaScript("window.writeBase64(\(javascriptString(encoded)))")
    }

    func replaceContents(with data: Data) {
        guard ready else {
            queuedOutput = [data]
            return
        }
        let encoded = data.base64EncodedString()
        webView.evaluateJavaScript("window.replaceBase64(\(javascriptString(encoded)))")
    }

    func focus() { evaluate("window.focusTerminal()") }
    func fit() { evaluate("window.fitTerminal()") }
    func clear() { evaluate("window.clearTerminal()") }
    func clearScrollback() { evaluate("window.clearScrollback()") }
    func selectAll() { evaluate("window.selectAllTerminal()") }
    func copySelection() {
        guard ready else { return }
        webView.evaluateJavaScript("window.getTerminalSelection()") { [weak self] result, _ in
            guard let selection = result as? String, !selection.isEmpty else { return }
            self?.writeToPasteboard(selection)
        }
    }

    func paste() {
        guard let value = NSPasteboard.general.string(forType: .string), !value.isEmpty else { return }
        evaluate("window.pasteText(\(javascriptString(value)))")
    }
    func setFontSize(_ value: CGFloat) {
        desiredFontSize = value
        evaluate("window.setFontSize(\(Double(value)))")
    }


    private func evaluate(_ script: String) {
        guard ready else { return }
        webView.evaluateJavaScript(script)
    }

    private func writeToPasteboard(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }

    private func javascriptString(_ value: String) -> String {
        let data = try! JSONSerialization.data(withJSONObject: [value])
        let array = String(decoding: data, as: UTF8.self)
        return String(array.dropFirst().dropLast())
    }
}
