import Foundation
import SwiftUI
import UIKit
@preconcurrency import WebKit

struct IOSMacsTerminalView: UIViewRepresentable {
    @ObservedObject var session: EmacsSession

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.userContentController.add(context.coordinator, name: "iosmacsTerminal")

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black
        webView.scrollView.bounces = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.attach(webView)
        context.coordinator.loadTerminalPage()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.setFontSize(session.fontSize)
        context.coordinator.focusTerminalIfRequested(session.focusRequest)
        context.coordinator.sendSpaceIfRequested(session.spaceRequest)
        context.coordinator.drainOutput()
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "iosmacsTerminal")
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        private let session: EmacsSession
        private weak var webView: WKWebView?
        private var isTerminalReady = false
        private var observedOutput = ""
        private var pendingOutputChunks: [[UInt8]] = []
        private var didStartAutomatedInputSmoke = false
        private var currentFontSize: CGFloat = 15
        private var lastFocusRequest: UInt64 = 0
        private var lastSpaceRequest: UInt64 = 0

        init(session: EmacsSession) {
            self.session = session
        }

        @MainActor
        func attach(_ webView: WKWebView) {
            self.webView = webView
        }

        @MainActor
        func loadTerminalPage() {
            guard let url = Bundle.main.url(
                forResource: "terminal",
                withExtension: "html",
                subdirectory: "TerminalWeb"
            ) else {
                session.noteTerminalBridge("terminal web resource missing")
                return
            }

            webView?.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        @MainActor
        func setFontSize(_ fontSize: CGFloat) {
            guard currentFontSize != fontSize else {
                return
            }
            currentFontSize = fontSize
            evaluate("window.iosmacsTerminal?.setFontSize(\(Double(fontSize)));")
        }

        @MainActor
        func focusTerminalIfRequested(_ request: UInt64) {
            guard request != lastFocusRequest else {
                return
            }
            lastFocusRequest = request
            evaluate("window.iosmacsTerminal?.focus();")
        }

        @MainActor
        func sendSpaceIfRequested(_ request: UInt64) {
            guard request != lastSpaceRequest else {
                return
            }
            lastSpaceRequest = request
            evaluate("window.iosmacsTerminal?.sendSpace();")
        }

        @MainActor
        func drainOutput() {
            let chunks = session.drainTerminalOutput()
            for chunk in chunks where !chunk.isEmpty {
                session.noteTerminalBridge("swift drain-output count=\(chunk.count) bytes=\(hexPreview(chunk))")
                observeOutput(chunk)
                pendingOutputChunks.append(chunk)
            }
            flushPendingOutput()
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            Task { @MainActor [weak self] in
                self?.handleMessage(message.body)
            }
        }

        @MainActor
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if ProcessInfo.processInfo.environment["IOSMACS_IME_DEBUG"] == "1" {
                evaluate("window.localStorage?.setItem('iosmacs-ime-debug', '1');")
            } else {
                evaluate("window.localStorage?.removeItem('iosmacs-ime-debug');")
            }
            evaluate("window.iosmacsTerminal?.focus(); window.iosmacsTerminal?.fit();")
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 200_000_000)
                self?.checkTerminalBridgeReady()
            }
        }

        @MainActor
        private func handleMessage(_ body: Any) {
            guard let message = body as? [String: Any],
                  let type = message["type"] as? String else {
                return
            }

            switch type {
            case "ready":
                isTerminalReady = true
                session.noteTerminalBridge("xterm.js terminal ready")
                if let cols = message["cols"] as? Int,
                   let rows = message["rows"] as? Int {
                    session.resize(cols: cols, rows: rows)
                }
                flushPendingOutput()
                startAutomatedInputSmokeIfRequested()
            case "input":
                let bytes = terminalBytes(from: message["bytes"])
                if !bytes.isEmpty {
                    session.noteTerminalBridge("swift recv-input count=\(bytes.count) bytes=\(hexPreview(bytes))")
                    session.sendInput(bytes)
                    drainOutput()
                }
            case "resize":
                guard let cols = message["cols"] as? Int,
                      let rows = message["rows"] as? Int else {
                    return
                }
                session.resize(cols: cols, rows: rows)
            case "focus":
                break
            case "log":
                if let logMessage = message["message"] as? String {
                    observedOutput.append("\niosmacs-web-terminal: \(logMessage)\n")
                    session.noteTerminalBridge("xterm.js log: \(logMessage)")
                }
            default:
                break
            }
        }

        @MainActor
        private func flushPendingOutput() {
            guard isTerminalReady, webView != nil else {
                return
            }

            let chunks = pendingOutputChunks
            pendingOutputChunks.removeAll(keepingCapacity: true)
            for chunk in chunks {
                writeBytesToTerminal(chunk)
            }
        }

        @MainActor
        private func writeBytesToTerminal(_ bytes: [UInt8]) {
            let base64 = Data(bytes).base64EncodedString()
            let literal = javaScriptStringLiteral(base64)
            session.noteTerminalBridge("swift write-to-xterm count=\(bytes.count) bytes=\(hexPreview(bytes))")
            evaluate("window.iosmacsTerminal?.writeBase64(\(literal));")
        }

        @MainActor
        private func evaluate(_ script: String) {
            webView?.evaluateJavaScript(script)
        }

        @MainActor
        private func checkTerminalBridgeReady() {
            webView?.evaluateJavaScript("Boolean(window.iosmacsTerminal)") { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else {
                        return
                    }
                    if let error {
                        self.session.noteTerminalBridge("xterm.js probe failed: \(error.localizedDescription)")
                        return
                    }
                    if (result as? Bool) == true {
                        self.isTerminalReady = true
                        self.session.noteTerminalBridge("xterm.js terminal ready")
                        self.evaluate("window.iosmacsTerminal.focus(); window.iosmacsTerminal.fit();")
                        self.flushPendingOutput()
                        self.startAutomatedInputSmokeIfRequested()
                    } else {
                        self.session.noteTerminalBridge("xterm.js bridge not ready")
                    }
                }
            }
        }

        private func observeOutput(_ chunk: [UInt8]) {
            observedOutput.append(String(decoding: chunk, as: UTF8.self))
            if observedOutput.count > 64 * 1024 {
                observedOutput.removeFirst(observedOutput.count - 64 * 1024)
            }
        }

        @MainActor
        private func startAutomatedInputSmokeIfRequested() {
            guard !didStartAutomatedInputSmoke,
                  let text = ProcessInfo.processInfo.environment["IOSMACS_APP_AUTOTYPE_TEXT"],
                  !text.isEmpty else {
                return
            }

            didStartAutomatedInputSmoke = true
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                let forcedDelayMs = Int(ProcessInfo.processInfo.environment["IOSMACS_APP_AUTOTYPE_DELAY_MS"] ?? "")
                if let forcedDelayMs, forcedDelayMs > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(forcedDelayMs) * 1_000_000)
                } else {
                    for _ in 0..<300 {
                        self.drainOutput()
                        if self.observedOutput.contains("(Lisp Interaction")
                            || self.observedOutput.contains("For information about GNU Emacs")
                            || self.observedOutput.count > 1024 {
                            break
                        }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                }

                try? await Task.sleep(nanoseconds: 500_000_000)
                let literal = self.javaScriptStringLiteral(text)
                self.evaluate("window.iosmacsTerminal?.focus(); window.iosmacsTerminal?.injectData(\(literal));")
                self.writeAutomatedInputSmokeMarker("iosmacs-app-webview-injectData:\(text)\n")

                for _ in 0..<80 {
                    try? await Task.sleep(nanoseconds: 50_000_000)
                    self.drainOutput()
                }
            }
        }

        private func writeAutomatedInputSmokeMarker(_ text: String) {
            guard let path = ProcessInfo.processInfo.environment["IOSMACS_APP_SMOKE_SWIFT_MARKER"],
                  !path.isEmpty else {
                return
            }

            let url = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }

        private func terminalBytes(from value: Any?) -> [UInt8] {
            guard let values = value as? [Any] else {
                return []
            }
            return values.compactMap { item in
                if let number = item as? NSNumber {
                    let intValue = number.intValue
                    return (0...255).contains(intValue) ? UInt8(intValue) : nil
                }
                if let intValue = item as? Int {
                    return (0...255).contains(intValue) ? UInt8(intValue) : nil
                }
                return nil
            }
        }

        private func hexPreview(_ bytes: [UInt8]) -> String {
            let preview = bytes.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " ")
            return bytes.count > 32 ? "\(preview) ..." : preview
        }

        private func javaScriptStringLiteral(_ value: String) -> String {
            guard let data = try? JSONEncoder().encode(value),
                  let literal = String(data: data, encoding: .utf8) else {
                return "\"\""
            }
            return literal
        }
    }
}
