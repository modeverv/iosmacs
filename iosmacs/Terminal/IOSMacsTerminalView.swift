import Foundation
import SwiftTerm
import SwiftUI
import UIKit

struct IOSMacsTerminalView: UIViewRepresentable {
    @ObservedObject var session: EmacsSession

    func makeUIView(context: Context) -> IOSMacsTerminalHostView {
        let view = IOSMacsTerminalHostView(frame: .zero)
        view.iosmacsInputDelegate = context.coordinator
        view.font = .monospacedSystemFont(ofSize: session.fontSize, weight: .regular)
        context.coordinator.attach(view)
        return view
    }

    func updateUIView(_ uiView: IOSMacsTerminalHostView, context: Context) {
        uiView.font = .monospacedSystemFont(ofSize: session.fontSize, weight: .regular)
        context.coordinator.focusTerminalIfRequested(session.focusRequest)
        context.coordinator.sendSpaceIfRequested(session.spaceRequest)
        context.coordinator.drainOutput()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    final class Coordinator: NSObject, @preconcurrency TerminalViewDelegate, IOSMacsTerminalInputDelegate {
        private let session: EmacsSession
        private weak var terminalView: TerminalView?
        private weak var hostView: IOSMacsTerminalHostView?
        private var observedOutput = ""
        private var didStartAutomatedInputSmoke = false
        private var lastFocusRequest: UInt64 = 0
        private var lastSpaceRequest: UInt64 = 0

        init(session: EmacsSession) {
            self.session = session
        }

        @MainActor
        func attach(_ hostView: IOSMacsTerminalHostView) {
            self.hostView = hostView
            self.terminalView = hostView.terminalView
            hostView.terminalView.terminalDelegate = self
            focusTerminal()
            drainOutput()
            startAutomatedInputSmokeIfRequested()
        }

        @MainActor
        func focusTerminalIfRequested(_ request: UInt64) {
            guard request != lastFocusRequest else {
                return
            }
            lastFocusRequest = request
            focusTerminal()
        }

        @MainActor
        func sendSpaceIfRequested(_ request: UInt64) {
            guard request != lastSpaceRequest else {
                return
            }
            lastSpaceRequest = request
            focusTerminal()
            sendBytes([32], reason: "toolbar-space")
            drainOutputAfterInput()
        }

        @MainActor
        @discardableResult
        func drainOutput() -> Int {
            guard let terminalView else {
                return 0
            }
            let chunks = session.drainTerminalOutput()
            var byteCount = 0
            for chunk in chunks where !chunk.isEmpty {
                byteCount += chunk.count
                session.noteTerminalBridge("swiftterm feed count=\(chunk.count) bytes=\(hexPreview(chunk))")
                observeOutput(chunk)
                terminalView.feed(byteArray: chunk[...])
            }
            if byteCount > 0 {
                hostView?.terminalCursorDidChange()
            }
            return byteCount
        }

        @MainActor
        func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
            resize(cols: newCols, rows: newRows)
        }

        func setTerminalTitle(source: TerminalView, title: String) {}
        func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

        @MainActor
        func send(source: TerminalView, data: ArraySlice<UInt8>) {
            let bytes = Array(data)
            session.noteTerminalBridge("swiftterm renderer-reply ignored count=\(bytes.count) bytes=\(hexPreview(bytes))")
        }

        func scrolled(source: TerminalView, position: Double) {}
        func requestOpenLink(source: TerminalView, link: String, params: [String: String]) {}
        func bell(source: TerminalView) {}
        func clipboardCopy(source: TerminalView, content: Data) {}
        func clipboardRead(source: TerminalView) -> Data? { nil }
        func iTermContent(source: TerminalView, content: ArraySlice<UInt8>) {}
        func rangeChanged(source: TerminalView, startY: Int, endY: Int) {}

        @MainActor
        func sendSpecialKey(_ bytes: [UInt8], reason: String) {
            focusTerminal()
            sendBytes(bytes, reason: reason)
            if shouldRedrawAfterInput(bytes, reason: reason) {
                sendBytes([12], reason: "\(reason)-redraw")
            }
            drainOutputAfterInput()
        }

        @MainActor
        func terminalLayoutChanged(cols: Int, rows: Int) {
            resize(cols: cols, rows: rows)
        }

        @MainActor
        private func focusTerminal() {
            DispatchQueue.main.async { [weak hostView] in
                hostView?.requestTerminalFocus()
            }
        }

        @MainActor
        private func resize(cols: Int, rows: Int) {
            guard cols > 0, rows > 0 else {
                return
            }
            session.resize(cols: cols, rows: rows)
        }

        @MainActor
        private func sendBytes(_ bytes: [UInt8], reason: String) {
            guard !bytes.isEmpty else {
                return
            }
            session.noteTerminalBridge("iosmacs \(reason) count=\(bytes.count) bytes=\(hexPreview(bytes))")
            session.sendInput(bytes)
        }

        @MainActor
        private func drainOutputAfterInput() {
            drainOutput()
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 20_000_000)
                self?.drainOutput()
                try? await Task.sleep(nanoseconds: 60_000_000)
                self?.drainOutput()
            }
        }

        private func shouldRedrawAfterInput(_ bytes: [UInt8], reason: String) -> Bool {
            reason.contains("delete") || bytes == [127] || bytes == [27, 91, 51, 126]
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
                guard let hostView = self.hostView else {
                    return
                }
                hostView.requestTerminalFocus()
                hostView.insertText(text)
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

        private func hexPreview(_ bytes: [UInt8]) -> String {
            let preview = bytes.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " ")
            return bytes.count > 32 ? "\(preview) ..." : preview
        }
    }
}

final class IOSMacsTerminalHostView: UIView {
    let terminalView = TerminalView(frame: .zero)
    weak var iosmacsInputDelegate: IOSMacsTerminalInputDelegate?
    private let keyboardInputView = IOSMacsKeyboardInputView(frame: .zero)
    private let compositionOverlayLabel = UILabel(frame: .zero)
    private var lastReportedBoundsSize: CGSize = .zero
    private var lastReportedTerminalSize: CGSize = .zero

    var font: UIFont {
        get { terminalView.font }
        set {
            terminalView.font = newValue
            compositionOverlayLabel.font = newValue
            updateMarkedTextOverlayFrame()
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        terminalView.backgroundColor = .black
        terminalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        terminalView.isUserInteractionEnabled = false
        addSubview(terminalView)
        compositionOverlayLabel.isHidden = true
        compositionOverlayLabel.isOpaque = false
        compositionOverlayLabel.backgroundColor = UIColor(white: 0.18, alpha: 0.92)
        compositionOverlayLabel.textColor = .white
        compositionOverlayLabel.layer.borderColor = UIColor(white: 0.95, alpha: 0.75).cgColor
        compositionOverlayLabel.layer.borderWidth = 1
        compositionOverlayLabel.numberOfLines = 1
        compositionOverlayLabel.clipsToBounds = true
        compositionOverlayLabel.isUserInteractionEnabled = false
        addSubview(compositionOverlayLabel)
        keyboardInputView.terminalHost = self
        addSubview(keyboardInputView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        requestTerminalFocus()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        terminalView.frame = bounds
        updateKeyboardInputAnchorFrame()
        updateMarkedTextOverlayFrame()
        requestTerminalFocus()
        reportLayoutIfNeeded()
    }

    func insertText(_ text: String) {
        sendCommittedText(text, reason: text == " " ? "textinput-space" : "textinput")
    }

    func sendCommittedText(_ text: String, reason: String) {
        let bytes = Array(text.utf8)
        guard !bytes.isEmpty else {
            return
        }
        clearMarkedTextOverlay()
        iosmacsInputDelegate?.sendSpecialKey(bytes, reason: reason)
    }

    func updateMarkedTextOverlay(_ text: String?, selectedRange: NSRange? = nil) {
        guard let text, !text.isEmpty else {
            clearMarkedTextOverlay()
            return
        }
        compositionOverlayLabel.attributedText = markedTextAttributedString(text, selectedRange: selectedRange)
        compositionOverlayLabel.isHidden = false
        updateKeyboardInputAnchorFrame()
        updateMarkedTextOverlayFrame()
    }

    func clearMarkedTextOverlay() {
        guard !compositionOverlayLabel.isHidden || compositionOverlayLabel.text != nil else {
            return
        }
        compositionOverlayLabel.attributedText = nil
        compositionOverlayLabel.isHidden = true
        updateKeyboardInputAnchorFrame()
    }

    func terminalCursorDidChange() {
        updateKeyboardInputAnchorFrame()
        updateMarkedTextOverlayFrame()
    }

    func sendDeleteBackward() {
        sendKey([127], reason: "textinput-delete")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        requestTerminalFocus()
        super.touchesBegan(touches, with: event)
    }

    @objc func handleDeleteKey(_ command: UIKeyCommand) {
        sendKey([127], reason: "hardware-delete")
    }

    @objc func handleUpArrowKey(_ command: UIKeyCommand) {
        sendKey([27, 91, 65], reason: "hardware-up")
    }

    @objc func handleDownArrowKey(_ command: UIKeyCommand) {
        sendKey([27, 91, 66], reason: "hardware-down")
    }

    @objc func handleRightArrowKey(_ command: UIKeyCommand) {
        sendKey([27, 91, 67], reason: "hardware-right")
    }

    @objc func handleLeftArrowKey(_ command: UIKeyCommand) {
        sendKey([27, 91, 68], reason: "hardware-left")
    }

    private func sendKey(_ bytes: [UInt8], reason: String) {
        requestTerminalFocus()
        iosmacsInputDelegate?.sendSpecialKey(bytes, reason: reason)
    }

    func requestTerminalFocus() {
        guard window != nil, !keyboardInputView.isFirstResponder else {
            return
        }
        DispatchQueue.main.async { [weak keyboardInputView] in
            _ = keyboardInputView?.becomeFirstResponder()
        }
    }

    func terminalBytes(for key: UIKey) -> [UInt8]? {
        switch key.keyCode {
        case .keyboardReturnOrEnter:
            return [13]
        case .keyboardTab:
            return [9]
        case .keyboardEscape:
            return [27]
        case .keyboardDeleteOrBackspace:
            return [127]
        case .keyboardDeleteForward:
            return [27, 91, 51, 126]
        case .keyboardUpArrow:
            return [27, 91, 65]
        case .keyboardDownArrow:
            return [27, 91, 66]
        case .keyboardRightArrow:
            return [27, 91, 67]
        case .keyboardLeftArrow:
            return [27, 91, 68]
        default:
            break
        }

        guard !key.modifierFlags.contains(.command) else {
            return nil
        }
        let text = key.charactersIgnoringModifiers
        guard !text.isEmpty else {
            return nil
        }

        if key.modifierFlags.contains(.control),
           text.count == 1,
           let scalar = text.unicodeScalars.first {
            let value = scalar.value
            if (65...90).contains(value) {
                return [UInt8(value - 64)]
            }
            if (97...122).contains(value) {
                return [UInt8(value - 96)]
            }
        }

        var bytes = Array((key.characters.isEmpty ? text : key.characters).utf8)
        if key.modifierFlags.contains(.alternate) {
            bytes.insert(27, at: 0)
        }
        return bytes
    }

    private func reportLayoutIfNeeded() {
        guard bounds.width > 0, bounds.height > 0 else {
            return
        }

        let boundsChanged = abs(lastReportedBoundsSize.width - bounds.size.width) > 0.5
            || abs(lastReportedBoundsSize.height - bounds.size.height) > 0.5
        let terminal = terminalView.getTerminal()
        let terminalSize = CGSize(width: terminal.cols, height: terminal.rows)
        let terminalChanged = lastReportedTerminalSize != terminalSize
        guard boundsChanged || terminalChanged else {
            return
        }

        lastReportedBoundsSize = bounds.size
        lastReportedTerminalSize = terminalSize
        iosmacsInputDelegate?.terminalLayoutChanged(cols: max(1, terminal.cols), rows: max(1, terminal.rows))
    }

    private func currentTerminalCursorRect() -> CGRect {
        guard bounds.width > 0, bounds.height > 0 else {
            return CGRect(x: 0, y: 0, width: 1, height: 1)
        }

        let terminal = terminalView.getTerminal()
        let cols = max(1, terminal.cols)
        let rows = max(1, terminal.rows)
        let cellWidth = max(1, terminalView.bounds.width / CGFloat(cols))
        let cellHeight = max(1, terminalView.bounds.height / CGFloat(rows))
        let col = min(max(terminal.buffer.x, 0), max(0, cols - 1))
        let row = min(max(terminal.buffer.y, 0), max(0, rows - 1))
        return CGRect(
            x: CGFloat(col) * cellWidth,
            y: CGFloat(row) * cellHeight,
            width: cellWidth,
            height: cellHeight
        )
    }

    private func updateKeyboardInputAnchorFrame() {
        let cursorRect = currentTerminalCursorRect()
        let widthToRightEdge = max(cursorRect.width, terminalView.bounds.width - cursorRect.minX)
        keyboardInputView.frame = CGRect(
            x: cursorRect.minX,
            y: cursorRect.minY,
            width: widthToRightEdge,
            height: cursorRect.height
        )
    }

    private func updateMarkedTextOverlayFrame() {
        guard !compositionOverlayLabel.isHidden,
              compositionOverlayLabel.attributedText?.length ?? 0 > 0,
              bounds.width > 0,
              bounds.height > 0 else {
            return
        }

        let cursorRect = currentTerminalCursorRect()
        let fittingSize = compositionOverlayLabel.sizeThatFits(
            CGSize(width: terminalView.bounds.width, height: cursorRect.height)
        )
        let width = min(
            max(cursorRect.width, ceil(fittingSize.width) + 6),
            max(cursorRect.width, terminalView.bounds.width)
        )
        let height = max(cursorRect.height, ceil(fittingSize.height))
        let originX = min(cursorRect.minX, max(0, terminalView.bounds.width - width))
        let originY = min(cursorRect.minY, max(0, terminalView.bounds.height - height))
        compositionOverlayLabel.frame = CGRect(x: originX, y: originY, width: width, height: height)
    }

    private func markedTextAttributedString(_ text: String, selectedRange: NSRange?) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: compositionOverlayLabel.font as Any,
            .foregroundColor: UIColor.white,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
        let result = NSMutableAttributedString(string: text, attributes: attributes)
        guard let selectedRange,
              selectedRange.location != NSNotFound,
              selectedRange.location <= result.length else {
            return result
        }

        let highlightRange: NSRange
        if selectedRange.length > 0, selectedRange.location < result.length {
            highlightRange = NSRange(
                location: selectedRange.location,
                length: min(selectedRange.length, result.length - selectedRange.location)
            )
        } else {
            highlightRange = NSRange(location: 0, length: result.length)
        }
        result.addAttributes(
            [
                .backgroundColor: UIColor(white: 0.92, alpha: 0.35),
                .foregroundColor: UIColor.white
            ],
            range: highlightRange
        )
        return result
    }
}

final class IOSMacsKeyboardInputView: UITextView, UITextViewDelegate {
    weak var terminalHost: IOSMacsTerminalHostView?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        delegate = self
        backgroundColor = .clear
        textColor = .clear
        tintColor = .clear
        isOpaque = false
        isScrollEnabled = false
        isEditable = true
        isSelectable = true
        autocapitalizationType = .none
        autocorrectionType = .no
        spellCheckingType = .no
        smartQuotesType = .no
        smartDashesType = .no
        smartInsertDeleteType = .no
        keyboardAppearance = .dark
        textContainerInset = .zero
        self.textContainer.lineFragmentPadding = 0
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var canBecomeFirstResponder: Bool {
        true
    }

    func textViewDidChange(_ textView: UITextView) {
        if updateMarkedTextOverlayFromCurrentState() {
            return
        }
        terminalHost?.clearMarkedTextOverlay()
        flushCommittedTextIfPossible(reason: text == " " ? "textinput-space" : "textinput")
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        _ = updateMarkedTextOverlayFromCurrentState()
    }

    override var keyCommands: [UIKeyCommand]? {
        guard markedTextRange == nil else {
            return super.keyCommands
        }
        let commands = [
            keyCommand(
                title: "Delete",
                input: UIKeyCommand.inputDelete,
                action: #selector(handleDeleteKey)
            ),
            keyCommand(
                title: "Up",
                input: UIKeyCommand.inputUpArrow,
                action: #selector(handleUpArrowKey)
            ),
            keyCommand(
                title: "Down",
                input: UIKeyCommand.inputDownArrow,
                action: #selector(handleDownArrowKey)
            ),
            keyCommand(
                title: "Left",
                input: UIKeyCommand.inputLeftArrow,
                action: #selector(handleLeftArrowKey)
            ),
            keyCommand(
                title: "Right",
                input: UIKeyCommand.inputRightArrow,
                action: #selector(handleRightArrowKey)
            )
        ]
        return commands + (super.keyCommands ?? [])
    }

    override func deleteBackward() {
        if markedTextRange != nil || !text.isEmpty {
            super.deleteBackward()
        } else {
            terminalHost?.sendDeleteBackward()
        }
        if updateMarkedTextOverlayFromCurrentState() {
            return
        }
        terminalHost?.clearMarkedTextOverlay()
        flushCommittedTextIfPossible(reason: "textinput")
    }

    override func setMarkedText(_ markedText: String?, selectedRange: NSRange) {
        super.setMarkedText(markedText, selectedRange: selectedRange)
        if let markedText, !markedText.isEmpty {
            terminalHost?.updateMarkedTextOverlay(markedText, selectedRange: selectedRange)
        } else {
            terminalHost?.clearMarkedTextOverlay()
        }
    }

    override func unmarkText() {
        super.unmarkText()
        terminalHost?.clearMarkedTextOverlay()
        flushCommittedTextIfPossible(reason: "textinput")
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard markedTextRange == nil else {
            super.pressesBegan(presses, with: event)
            return
        }

        var handled = false
        for press in presses {
            guard let key = press.key,
                  shouldHandleOutsideTextInput(key),
                  let bytes = terminalHost?.terminalBytes(for: key) else {
                continue
            }
            terminalHost?.iosmacsInputDelegate?.sendSpecialKey(bytes, reason: "hardware-key")
            handled = true
        }
        if !handled {
            super.pressesBegan(presses, with: event)
        }
    }

    @objc private func handleDeleteKey(_ command: UIKeyCommand) {
        terminalHost?.handleDeleteKey(command)
    }

    @objc private func handleUpArrowKey(_ command: UIKeyCommand) {
        terminalHost?.handleUpArrowKey(command)
    }

    @objc private func handleDownArrowKey(_ command: UIKeyCommand) {
        terminalHost?.handleDownArrowKey(command)
    }

    @objc private func handleRightArrowKey(_ command: UIKeyCommand) {
        terminalHost?.handleRightArrowKey(command)
    }

    @objc private func handleLeftArrowKey(_ command: UIKeyCommand) {
        terminalHost?.handleLeftArrowKey(command)
    }

    private func keyCommand(title: String, input: String, action: Selector) -> UIKeyCommand {
        UIKeyCommand(
            title: title,
            image: nil,
            action: action,
            input: input,
            modifierFlags: [],
            propertyList: nil,
            alternates: [],
            discoverabilityTitle: title,
            attributes: [],
            state: .off
        )
    }

    private func shouldHandleOutsideTextInput(_ key: UIKey) -> Bool {
        switch key.keyCode {
        case .keyboardReturnOrEnter,
             .keyboardTab,
             .keyboardEscape,
             .keyboardDeleteOrBackspace,
             .keyboardDeleteForward,
             .keyboardUpArrow,
             .keyboardDownArrow,
             .keyboardRightArrow,
             .keyboardLeftArrow:
            return true
        default:
            return key.modifierFlags.contains(.control) || key.modifierFlags.contains(.alternate)
        }
    }

    private func updateMarkedTextOverlayFromCurrentState() -> Bool {
        guard let markedTextRange,
              let markedText = text(in: markedTextRange),
              !markedText.isEmpty else {
            return false
        }
        terminalHost?.updateMarkedTextOverlay(markedText)
        return true
    }

    private func flushCommittedTextIfPossible(reason: String) {
        guard markedTextRange == nil, !text.isEmpty else {
            return
        }
        let committedText = text ?? ""
        terminalHost?.clearMarkedTextOverlay()
        terminalHost?.sendCommittedText(committedText, reason: reason)
        text = ""
        selectedRange = NSRange(location: 0, length: 0)
    }
}

@MainActor
protocol IOSMacsTerminalInputDelegate: AnyObject {
    func sendSpecialKey(_ bytes: [UInt8], reason: String)
    func terminalLayoutChanged(cols: Int, rows: Int)
}
