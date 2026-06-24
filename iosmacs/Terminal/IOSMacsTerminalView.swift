import Foundation
import SwiftTerm
import SwiftUI
import UIKit

struct IOSMacsTerminalView: UIViewRepresentable {
    @ObservedObject var session: EmacsSession

    func makeUIView(context: Context) -> IOSMacsTerminalHostView {
        let view = IOSMacsTerminalHostView(frame: .zero)
        view.terminalDelegate = context.coordinator
        view.backgroundColor = .black
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.font = .monospacedSystemFont(ofSize: 15, weight: .regular)
        context.coordinator.attach(view)
        return view
    }

    func updateUIView(_ uiView: IOSMacsTerminalHostView, context: Context) {
        uiView.font = .monospacedSystemFont(ofSize: session.fontSize, weight: .regular)
        context.coordinator.drainOutput()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    final class Coordinator: NSObject, @preconcurrency TerminalViewDelegate {
        private let session: EmacsSession
        private weak var terminalView: TerminalView?
        private var observedOutput = ""
        private var didStartAutomatedInputSmoke = false

        init(session: EmacsSession) {
            self.session = session
        }

        @MainActor
        func attach(_ terminalView: TerminalView) {
            self.terminalView = terminalView
            DispatchQueue.main.async {
                _ = terminalView.becomeFirstResponder()
            }
            drainOutput()
            startAutomatedInputSmokeIfRequested()
        }

        @MainActor
        func drainOutput() {
            guard let terminalView else {
                return
            }
            let chunks = session.drainTerminalOutput()
            for chunk in chunks where !chunk.isEmpty {
                observeOutput(chunk)
                terminalView.feed(byteArray: chunk[...])
            }
        }

        @MainActor
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            session.resize(cols: newCols, rows: newRows)
        }

        func setTerminalTitle(source: TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        @MainActor
        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            session.sendInput(Array(data))
            drainOutput()
        }

        func scrolled(source: TerminalView, position: Double) {}
        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
        func bell(source: TerminalView) {}
        func clipboardCopy(source: TerminalView, content: Data) {}
        func clipboardRead(source: TerminalView) -> Data? { nil }
        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

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

                for _ in 0..<1800 {
                    self.drainOutput()
                    if self.observedOutput.contains("(Lisp Interaction")
                        || self.observedOutput.contains("For information about GNU Emacs") {
                        break
                    }
                    try? await Task.sleep(nanoseconds: 100_000_000)
                }

                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let terminalView = self.terminalView else {
                    return
                }
                _ = terminalView.becomeFirstResponder()
                terminalView.insertText(text)
                self.writeAutomatedInputSmokeMarker("iosmacs-app-swiftterm-insertText:\(text)\n")

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
    }
}

final class IOSMacsTerminalHostView: TerminalView {
}
