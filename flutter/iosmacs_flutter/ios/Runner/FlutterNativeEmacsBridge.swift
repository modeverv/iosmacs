import Flutter
import Foundation
import os.log
import UIKit

private let nativeTextInputLog = OSLog(
  subsystem: Bundle.main.bundleIdentifier ?? "iosmacs.flutter",
  category: "native-textinput"
)

final class FlutterNativeEmacsBridge {
  private static let workspaceBookmarkDefaultsKey = "iosmacs.flutter.workspace.bookmark"
  private static let workspacePathDefaultsKey = "iosmacs.flutter.workspace.path"

  private var lifecycleState = "iosmacs flutter bridge: idle"
  private var cols = 80
  private var rows = 24
  private var inputBytes = 0
  private var startedRealEmacs = false
  private var cachedWorkspaceRootURL: URL?
  private var selectedWorkspaceAccessURL: URL?
  private var workspacePickerDelegate: WorkspacePickerDelegate?
  private weak var terminalInputView: FlutterTerminalInputView?
  private var terminalTraceURL: URL?
  private var terminalTraceOffset: UInt64 = 0

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    focusTerminalInput()
    switch call.method {
    case "start":
      start(result: result)
    case "stop":
      stop(result: result)
    case "redraw":
      redraw(result: result)
    case "sendBytes":
      sendBytes(call.arguments, result: result)
    case "pasteSystemClipboard":
      pasteSystemClipboard(result: result)
    case "resize":
      resize(call.arguments, result: result)
    case "drainOutput":
      drainOutput(result: result)
    case "listWorkspace":
      listWorkspace(result: result)
    case "importWorkspace":
      importWorkspace(call.arguments, result: result)
    case "exportWorkspace":
      exportWorkspace(result: result)
    case "selectWorkspaceRoot":
      selectWorkspaceRoot(result: result)
    case "clearWorkspaceRoot":
      clearWorkspaceRoot(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func attachTerminalInput(to rootView: UIView?) {
    guard let rootView else {
      return
    }
    if let terminalInputView, terminalInputView.superview === rootView {
      focusTerminalInput()
      return
    }

    let inputView = FlutterTerminalInputView(frame: CGRect(x: 0, y: 0, width: 2, height: 2))
    inputView.onCommittedText = { [weak self] text, reason in
      self?.sendNativeCommittedText(text, reason: reason)
    }
    inputView.autoresizingMask = [.flexibleRightMargin, .flexibleBottomMargin]
    rootView.addSubview(inputView)
    terminalInputView = inputView
    focusTerminalInput()
  }

  func focusTerminalInput() {
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        return
      }
      if self.terminalInputView == nil {
        self.attachTerminalInput(to: self.topViewController()?.view)
      }
      guard let inputView = self.terminalInputView,
            inputView.window != nil else {
        return
      }
      guard !inputView.isFirstResponder else {
        return
      }
      _ = inputView.becomeFirstResponder()
    }
  }

  private func start(result: FlutterResult) {
    configureTerminalTraceMarker()
    iosmacs_os_terminal_reset()
    if startRealEmacs() {
      startedRealEmacs = true
      lifecycleState = "iosmacs flutter bridge: GNU Emacs running"
      iosmacs_os_set_lifecycle_state(lifecycleState)
      writeOutput("Flutter MethodChannel started linked GNU Emacs on iOS.\r\n")
      result(status())
      return
    }

    startedRealEmacs = false
    lifecycleState = "iosmacs flutter bridge: diagnostic fallback running"
    iosmacs_os_set_lifecycle_state(lifecycleState)
    iosmacs_emacs_diagnostic_start()
    writeOutput("Flutter MethodChannel is connected on iOS.\r\n")
    writeOutput("Linked GNU Emacs startup failed or resources are missing; diagnostic fallback is running.\r\n")
    result(status())
  }

  private func stop(result: FlutterResult) {
    lifecycleState = "iosmacs flutter bridge: stopped"
    iosmacs_os_set_lifecycle_state(lifecycleState)
    writeOutput("iosmacs Flutter native bridge stopped\r\n")
    result(status())
  }

  private func redraw(result: FlutterResult) {
    writeOutput("\u{000C}iosmacs Flutter native bridge redraw\r\n")
    result(status())
  }

  private func sendBytes(_ arguments: Any?, result: FlutterResult) {
    let bytes = extractBytes(arguments)
    inputBytes += bytes.count
    bytes.withUnsafeBufferPointer { buffer in
      _ = iosmacs_terminal_shim_push_input(buffer.baseAddress, buffer.count)
    }
    os_log(
      "iosmacs flutter native sendBytes pushed bytes=%ld",
      log: nativeTextInputLog,
      type: .info,
      bytes.count
    )
    if !startedRealEmacs {
      iosmacs_emacs_diagnostic_pump()
    }
    result(status())
  }

  private func pasteSystemClipboard(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        result(["accepted": false, "byteCount": 0])
        return
      }
      if self.terminalInputView == nil {
        self.attachTerminalInput(to: self.topViewController()?.view)
      }
      guard let inputView = self.terminalInputView else {
        result(["accepted": false, "byteCount": 0])
        return
      }
      self.focusTerminalInput()
      os_log(
        "iosmacs flutter native pasteSystemClipboard start",
        log: nativeTextInputLog,
        type: .info
      )
      inputView.paste(nil)
      os_log(
        "iosmacs flutter native pasteSystemClipboard returned",
        log: nativeTextInputLog,
        type: .info
      )
      result([
        "accepted": true,
        "byteCount": 0,
      ])
    }
  }

  private func sendNativeCommittedText(_ text: String, reason: String) {
    let normalizedText = normalizeTerminalInputText(text)
    let bytes = Array(normalizedText.utf8)
    guard !bytes.isEmpty else {
      return
    }
    os_log(
      "iosmacs flutter native textinput forward reason=%{public}@ chars=%ld bytes=%ld",
      log: nativeTextInputLog,
      type: .info,
      reason,
      text.count,
      bytes.count
    )
    let written = bytes.withUnsafeBufferPointer { pointer in
      iosmacs_terminal_shim_push_input(pointer.baseAddress, pointer.count)
    }
    os_log(
      "iosmacs flutter native textinput forwarded reason=%{public}@ written=%ld",
      log: nativeTextInputLog,
      type: .info,
      reason,
      written
    )
    if written > 0 {
      inputBytes += Int(written)
    }
  }

  private func normalizeTerminalInputText(_ text: String) -> String {
    text
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .replacingOccurrences(of: "\n", with: "\r")
  }

  private func resize(_ arguments: Any?, result: FlutterResult) {
    guard let dictionary = arguments as? [String: Any] else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "resize requires cols and rows",
          details: nil
        )
      )
      return
    }
    cols = dictionary["cols"] as? Int ?? cols
    rows = dictionary["rows"] as? Int ?? rows
    iosmacs_os_terminal_resize(Int32(cols), Int32(rows))
    writeOutput("native facade resize \(cols)x\(rows)\r\n")
    result(status())
  }

  private func listWorkspace(result: FlutterResult) {
    guard let workspaceRoot = ensureWorkspaceRootURL() else {
      result(workspaceError("workspace_unavailable", "default workspace is unavailable"))
      return
    }

    do {
      let urls = try FileManager.default.contentsOfDirectory(
        at: workspaceRoot,
        includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
        options: [.skipsHiddenFiles]
      )
      let entries = try urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
        .map(workspaceEntry)
      result(entries)
    } catch {
      result(workspaceError("workspace_list_failed", error.localizedDescription))
    }
  }

  private func importWorkspace(_ arguments: Any?, result: FlutterResult) {
    guard let workspaceRoot = ensureWorkspaceRootURL() else {
      result(workspaceError("workspace_unavailable", "default workspace is unavailable"))
      return
    }
    guard let dictionary = arguments as? [String: Any],
          let uriStrings = dictionary["uris"] as? [String] else {
      result(
        FlutterError(
          code: "invalid_arguments",
          message: "importWorkspace requires uris",
          details: nil
        )
      )
      return
    }

    var importedCount = 0
    do {
      for uriString in uriStrings {
        guard let sourceURL = URL(string: uriString) else {
          continue
        }
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
          if didAccess {
            sourceURL.stopAccessingSecurityScopedResource()
          }
        }

        let destinationURL = workspaceRoot.appendingPathComponent(sourceURL.lastPathComponent)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
          try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        importedCount += 1
      }
      lifecycleState = "iosmacs flutter bridge: imported \(importedCount) workspace item(s)"
      iosmacs_os_set_lifecycle_state(lifecycleState)
      result(importedCount)
    } catch {
      result(workspaceError("workspace_import_failed", error.localizedDescription))
    }
  }

  private func exportWorkspace(result: FlutterResult) {
    guard let workspaceRoot = ensureWorkspaceRootURL() else {
      result(workspaceError("workspace_unavailable", "default workspace is unavailable"))
      return
    }

    do {
      let urls = try FileManager.default.contentsOfDirectory(
        at: workspaceRoot,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
      let exportURLs = urls.isEmpty ? [workspaceRoot] : urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
      result(exportURLs.map { $0.absoluteString })
    } catch {
      result(workspaceError("workspace_export_failed", error.localizedDescription))
    }
  }

  private func selectWorkspaceRoot(result: @escaping FlutterResult) {
    guard let presentingViewController = topViewController() else {
      result(workspaceError("workspace_picker_unavailable", "no view controller can present the workspace picker"))
      return
    }

    let picker = UIDocumentPickerViewController(
      documentTypes: ["public.folder"],
      in: .open
    )
    let delegate = WorkspacePickerDelegate { [weak self] selectedURL in
      guard let self else {
        result(
          FlutterError(
            code: "workspace_selection_failed",
            message: "workspace bridge was released",
            details: nil
          )
        )
        return
      }
      self.workspacePickerDelegate = nil

      guard let selectedURL else {
        result(self.workspaceSelectionStatus(message: "Workspace selection cancelled"))
        return
      }

      do {
        let message = try self.setWorkspaceRootSelection(selectedURL)
        result(self.workspaceSelectionStatus(message: message))
      } catch {
        result(self.workspaceError("workspace_selection_failed", error.localizedDescription))
      }
    }
    workspacePickerDelegate = delegate
    picker.delegate = delegate
    presentingViewController.present(picker, animated: true)
  }

  private func clearWorkspaceRoot(result: FlutterResult) {
    UserDefaults.standard.removeObject(forKey: Self.workspaceBookmarkDefaultsKey)
    UserDefaults.standard.removeObject(forKey: Self.workspacePathDefaultsKey)
    pendingWorkspaceAccessReset()
    let message = startedRealEmacs ? "Default workspace saved for next launch" : "Default workspace set"
    if !startedRealEmacs {
      cachedWorkspaceRootURL = nil
      _ = ensureWorkspaceRootURL()
    }
    result(workspaceSelectionStatus(message: message))
  }

  private func drainOutput(result: FlutterResult) {
    var buffer = [UInt8](repeating: 0, count: 256 * 1024)
    let count = buffer.withUnsafeMutableBufferPointer { pointer in
      iosmacs_os_terminal_drain_output(pointer.baseAddress, pointer.count)
    }
    drainTerminalTraceMarker()
    guard count > 0 else {
      result(FlutterStandardTypedData(bytes: Data()))
      return
    }
    os_log(
      "iosmacs flutter native drainOutput bytes=%ld",
      log: nativeTextInputLog,
      type: .info,
      count
    )
    result(FlutterStandardTypedData(bytes: Data(buffer.prefix(count))))
  }

  private func configureTerminalTraceMarker() {
    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("iosmacs-terminal-trace.log")
    try? FileManager.default.removeItem(at: url)
    FileManager.default.createFile(atPath: url.path, contents: nil)
    setenv("IOSMACS_WEB_TERMINAL_DEBUG_MARKER", url.path, 1)
    terminalTraceURL = url
    terminalTraceOffset = 0
    os_log(
      "iosmacs flutter native trace marker path=%{public}@",
      log: nativeTextInputLog,
      type: .info,
      url.path
    )
  }

  private func drainTerminalTraceMarker() {
    guard let terminalTraceURL,
          let handle = try? FileHandle(forReadingFrom: terminalTraceURL) else {
      return
    }
    defer {
      try? handle.close()
    }
    do {
      try handle.seek(toOffset: terminalTraceOffset)
      let data = handle.readDataToEndOfFile()
      terminalTraceOffset += UInt64(data.count)
      guard !data.isEmpty,
            let text = String(data: data, encoding: .utf8) else {
        return
      }
      for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
        os_log(
          "iosmacs flutter native terminal-trace %{public}@",
          log: nativeTextInputLog,
          type: .info,
          String(rawLine)
        )
      }
    } catch {
      os_log(
        "iosmacs flutter native terminal-trace read failed %{public}@",
        log: nativeTextInputLog,
        type: .info,
        error.localizedDescription
      )
    }
  }

  private func writeOutput(_ text: String) {
    let bytes = Array(text.utf8)
    bytes.withUnsafeBufferPointer { buffer in
      _ = iosmacs_os_terminal_write(buffer.baseAddress, buffer.count)
    }
  }

  private func extractBytes(_ arguments: Any?) -> [UInt8] {
    guard let dictionary = arguments as? [String: Any],
          let typedData = dictionary["bytes"] as? FlutterStandardTypedData else {
      return []
    }
    return Array(typedData.data)
  }

  private func startRealEmacs() -> Bool {
    guard iosmacs_emacs_core_link_available(),
          let lispDir = Bundle.main.path(forResource: "lisp", ofType: nil),
          let etcDir = Bundle.main.path(forResource: "etc", ofType: nil) else {
      return false
    }

    let execDir = Bundle.main.path(forResource: "lib-src", ofType: nil)
    let dumpFile = Bundle.main.path(forResource: "emacs", ofType: "pdmp")
    let workspaceRoot = ensureWorkspaceRootURL()?.path

    return lispDir.withCString { lispPointer in
      etcDir.withCString { etcPointer in
        let startWithWorkspace: (UnsafePointer<CChar>?) -> Bool = { workspacePointer in
          if let execDir, let dumpFile {
            return execDir.withCString { execPointer in
              dumpFile.withCString { dumpPointer in
                iosmacs_emacs_core_start(lispPointer, etcPointer, execPointer, dumpPointer, workspacePointer)
              }
            }
          }
          if let execDir {
            return execDir.withCString { execPointer in
              iosmacs_emacs_core_start(lispPointer, etcPointer, execPointer, nil, workspacePointer)
            }
          }
          if let dumpFile {
            return dumpFile.withCString { dumpPointer in
              iosmacs_emacs_core_start(lispPointer, etcPointer, nil, dumpPointer, workspacePointer)
            }
          }
          return iosmacs_emacs_core_start(lispPointer, etcPointer, nil, nil, workspacePointer)
        }

        if let workspaceRoot {
          return workspaceRoot.withCString { workspacePointer in
            startWithWorkspace(workspacePointer)
          }
        }
        return startWithWorkspace(nil)
      }
    }
  }

  private func ensureWorkspaceRootURL() -> URL? {
    if let cachedWorkspaceRootURL {
      return cachedWorkspaceRootURL
    }
    return prepareWorkspaceRoot()
  }

  private func prepareWorkspaceRoot() -> URL? {
    if let selectedRoot = selectedWorkspaceRootURL() {
      return prepareWorkspaceDirectory(selectedRoot)
    }

    guard let baseURL = workspaceBaseURL() else {
      return nil
    }
    return prepareWorkspaceDirectory(
      baseURL.appendingPathComponent("home", isDirectory: true)
        .appendingPathComponent("user", isDirectory: true)
    )
  }

  private func prepareWorkspaceDirectory(_ workspaceRoot: URL) -> URL? {
    let notesRoot = workspaceRoot.appendingPathComponent("notes", isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: notesRoot,
        withIntermediateDirectories: true
      )
      let readmeURL = workspaceRoot.appendingPathComponent("README.txt")
      if !FileManager.default.fileExists(atPath: readmeURL.path) {
        try "This directory is /home/user inside iosmacs Flutter.\n".write(
          to: readmeURL,
          atomically: true,
          encoding: .utf8
        )
      }
      cachedWorkspaceRootURL = workspaceRoot
      return workspaceRoot
    } catch {
      writeOutput("iosmacs Flutter workspace setup failed: \(error.localizedDescription)\r\n")
      return nil
    }
  }

  private func workspaceBaseURL() -> URL? {
    let storage = ProcessInfo.processInfo.environment["IOSMACS_WORKSPACE_STORAGE"]?.lowercased()
    if storage != "documents",
       let iCloudRoot = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
      let documents = iCloudRoot.appendingPathComponent("Documents", isDirectory: true)
      try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
      return documents
    }
    return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
  }

  private func setWorkspaceRootSelection(_ url: URL) throws -> String {
    let didAccess = url.startAccessingSecurityScopedResource()
    defer {
      if didAccess {
        url.stopAccessingSecurityScopedResource()
      }
    }

    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory),
          isDirectory.boolValue else {
      throw CocoaError(.fileNoSuchFile)
    }

    let bookmark = try url.bookmarkData(
      options: [],
      includingResourceValuesForKeys: nil,
      relativeTo: nil
    )
    UserDefaults.standard.set(bookmark, forKey: Self.workspaceBookmarkDefaultsKey)
    UserDefaults.standard.set(url.path, forKey: Self.workspacePathDefaultsKey)

    if startedRealEmacs {
      return "Workspace saved for next launch"
    }

    cachedWorkspaceRootURL = nil
    _ = ensureWorkspaceRootURL()
    return "Workspace set"
  }

  private func selectedWorkspaceRootURL() -> URL? {
    guard let bookmark = UserDefaults.standard.data(forKey: Self.workspaceBookmarkDefaultsKey) else {
      return nil
    }

    do {
      var isStale = false
      let url = try URL(
        resolvingBookmarkData: bookmark,
        options: [],
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )
      if isStale {
        pendingWorkspaceAccessReset()
        return nil
      }
      if selectedWorkspaceAccessURL?.path != url.path {
        _ = url.startAccessingSecurityScopedResource()
        selectedWorkspaceAccessURL = url
      }
      return url
    } catch {
      pendingWorkspaceAccessReset()
      return nil
    }
  }

  private func pendingWorkspaceAccessReset() {
    if let selectedWorkspaceAccessURL {
      selectedWorkspaceAccessURL.stopAccessingSecurityScopedResource()
    }
    selectedWorkspaceAccessURL = nil
    cachedWorkspaceRootURL = nil
    UserDefaults.standard.removeObject(forKey: Self.workspaceBookmarkDefaultsKey)
    UserDefaults.standard.removeObject(forKey: Self.workspacePathDefaultsKey)
  }

  private func workspaceEntry(_ url: URL) throws -> [String: Any] {
    let values = try url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
    return [
      "name": url.lastPathComponent,
      "path": url.path,
      "isDirectory": values.isDirectory ?? false,
      "sizeBytes": values.fileSize ?? 0,
    ]
  }

  private func workspaceError(_ code: String, _ message: String) -> FlutterError {
    FlutterError(code: code, message: message, details: nil)
  }

  private func workspaceSelectionStatus(message: String) -> [String: Any] {
    [
      "message": message,
      "workspaceRootPath": ensureWorkspaceRootURL()?.path ?? "",
      "requiresRestart": startedRealEmacs,
    ]
  }

  private func topViewController() -> UIViewController? {
    let sceneRoot = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first { $0.isKeyWindow }?
      .rootViewController
    let legacyRoot = UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController
      ?? UIApplication.shared.windows.first?.rootViewController
    var top = sceneRoot ?? legacyRoot
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }

  private func hexPreview(_ bytes: [UInt8]) -> String {
    if bytes.isEmpty {
      return "<empty>"
    }
    let prefix = bytes.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " ")
    return bytes.count > 32 ? "\(prefix) ..." : prefix
  }

  private func status() -> [String: Any] {
    [
      "lifecycleState": lifecycleState,
      "cols": cols,
      "rows": rows,
      "inputBytes": inputBytes,
      "workspaceRootPath": ensureWorkspaceRootURL()?.path ?? "",
      "emacsCoreLinkAvailable": iosmacs_emacs_core_link_available(),
      "emacsCoreEntrySymbol": String(cString: iosmacs_emacs_core_entry_symbol_name()),
      "emacsCoreConnected": startedRealEmacs && iosmacs_emacs_core_is_running(),
    ]
  }
}

private final class WorkspacePickerDelegate: NSObject, UIDocumentPickerDelegate {
  private let completion: (URL?) -> Void

  init(completion: @escaping (URL?) -> Void) {
    self.completion = completion
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    completion(nil)
  }

  func documentPicker(
    _ controller: UIDocumentPickerViewController,
    didPickDocumentsAt urls: [URL]
  ) {
    completion(urls.first)
  }
}

private final class FlutterTerminalInputView: UITextView, UITextViewDelegate {
  var onCommittedText: ((String, String) -> Void)?
  private var isHandlingPaste = false

  override init(frame: CGRect, textContainer: NSTextContainer?) {
    super.init(frame: frame, textContainer: textContainer)
    delegate = self
    backgroundColor = .clear
    textColor = .clear
    tintColor = .clear
    alpha = 0.02
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
    accessibilityElementsHidden = true
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var canBecomeFirstResponder: Bool {
    true
  }

  func textViewDidChange(_ textView: UITextView) {
    let reason = isHandlingPaste ? "textinput-paste" : "textinput"
    os_log(
      "iosmacs flutter native textinput didChange reason=%{public}@ chars=%ld",
      log: nativeTextInputLog,
      type: .info,
      reason,
      textView.text.count
    )
    flushCommittedTextIfPossible(reason: reason)
  }

  override func unmarkText() {
    super.unmarkText()
    flushCommittedTextIfPossible(reason: "textinput")
  }

  override func deleteBackward() {
    if markedTextRange != nil || !text.isEmpty {
      super.deleteBackward()
      flushCommittedTextIfPossible(reason: "textinput")
    } else {
      onCommittedText?("\u{7f}", "textinput-delete")
    }
  }

  override func insertText(_ text: String) {
    if markedTextRange == nil, text == " " {
      onCommittedText?(text, "textinput-space")
      self.text = ""
      selectedRange = NSRange(location: 0, length: 0)
      return
    }
    super.insertText(text)
  }

  override func paste(_ sender: Any?) {
    os_log(
      "iosmacs flutter native textinput paste override start",
      log: nativeTextInputLog,
      type: .info
    )
    isHandlingPaste = true
    super.paste(sender)
    os_log(
      "iosmacs flutter native textinput paste super returned chars=%ld",
      log: nativeTextInputLog,
      type: .info,
      text.count
    )
    flushCommittedTextIfPossible(reason: "textinput-paste")
    isHandlingPaste = false
    os_log(
      "iosmacs flutter native textinput paste override done",
      log: nativeTextInputLog,
      type: .info
    )
  }

  override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    guard #available(iOS 13.4, *) else {
      super.pressesBegan(presses, with: event)
      return
    }
    guard markedTextRange == nil else {
      super.pressesBegan(presses, with: event)
      return
    }

    var handled = false
    for press in presses {
      guard let key = press.key else {
        continue
      }
      if isPasteShortcut(key) {
        paste(nil)
        handled = true
        continue
      }
      guard let text = terminalText(for: key) else {
        continue
      }
      onCommittedText?(text, "hardware-key")
      handled = true
    }
    if !handled {
      super.pressesBegan(presses, with: event)
    }
  }

  @available(iOS 13.4, *)
  private func isPasteShortcut(_ key: UIKey) -> Bool {
    key.modifierFlags.contains(.command)
      && key.charactersIgnoringModifiers.lowercased() == "v"
  }

  @available(iOS 13.4, *)
  private func terminalText(for key: UIKey) -> String? {
    switch key.keyCode {
    case .keyboardSpacebar:
      return " "
    case .keyboardReturnOrEnter:
      return "\r"
    case .keyboardTab:
      return "\t"
    case .keyboardEscape:
      return "\u{1b}"
    case .keyboardDeleteOrBackspace:
      return "\u{7f}"
    case .keyboardDeleteForward:
      return "\u{1b}[3~"
    case .keyboardUpArrow:
      return "\u{1b}[A"
    case .keyboardDownArrow:
      return "\u{1b}[B"
    case .keyboardRightArrow:
      return "\u{1b}[C"
    case .keyboardLeftArrow:
      return "\u{1b}[D"
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
        return String(UnicodeScalar(value - 64)!)
      }
      if (97...122).contains(value) {
        return String(UnicodeScalar(value - 96)!)
      }
    }

    if key.modifierFlags.contains(.alternate) {
      return "\u{1b}" + text
    }
    return key.characters.isEmpty ? text : key.characters
  }

  private func flushCommittedTextIfPossible(reason: String) {
    guard markedTextRange == nil, !text.isEmpty else {
      return
    }
    let committedText = text ?? ""
    onCommittedText?(committedText, reason)
    text = ""
    selectedRange = NSRange(location: 0, length: 0)
  }
}
