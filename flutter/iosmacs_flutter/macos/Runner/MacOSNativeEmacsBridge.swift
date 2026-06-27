import FlutterMacOS
import Foundation
import Darwin
import Dispatch

final class MacOSNativeEmacsBridge {
  private static let bundledRuntimeDirectoryName = "iosmacs-emacs"
  private static let startupSurvivalProbeDuration: TimeInterval = 0.75
  private static let runtimeEvalForm = """
    (progn
      (when (boundp 'read-extended-command-predicate)
        (setq read-extended-command-predicate nil))
      (when (fboundp 'execute-extended-command)
        (global-set-key (kbd "M-X") #'execute-extended-command))
      (autoload 'dired "dired" nil t)
      (autoload 'tetris "tetris" nil t))
    """

  private var lifecycleState = "iosmacs macOS native bridge: idle"
  private var cols = 80
  private var rows = 24
  private var inputBytes = 0
  private var output = Data()
  private let outputLock = NSLock()
  private var emacsPID: pid_t?
  private var emacsInput: FileHandle?
  private var emacsPtyMaster: FileHandle?
  private var emacsExitSource: DispatchSourceProcess?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      start(result: result)
    case "stop":
      stop(result: result)
    case "redraw":
      redraw(result: result)
    case "sendBytes":
      sendBytes(call.arguments, result: result)
    case "resize":
      resize(call.arguments, result: result)
    case "drainOutput":
      result(FlutterStandardTypedData(bytes: drainOutput()))
    case "listWorkspace":
      listWorkspace(result: result)
    case "importWorkspace":
      importWorkspace(call.arguments, result: result)
    case "exportWorkspace":
      exportWorkspace(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  deinit {
    stopEmacsProcess()
  }

  private func start(result: FlutterResult) {
    appendOutput("macOS native channel is connected.\r\n")
    if isEmacsRunning() {
      lifecycleState = "iosmacs macOS native bridge: GNU Emacs process running"
      result(status())
      return
    }

    if startInteractiveEmacsProcess() {
      result(status())
      return
    }

    runEmacsProcessProbe()
    appendOutput("macOS Emacs process unavailable; diagnostic fallback is running.\r\n")
    result(status())
  }

  private func stop(result: FlutterResult) {
    stopEmacsProcess()
    lifecycleState = "iosmacs macOS native bridge: stopped"
    appendOutput("macOS native bridge stopped\r\n")
    result(status())
  }

  private func redraw(result: FlutterResult) {
    if writeToEmacs(Data([0x0c])) {
      lifecycleState = "iosmacs macOS native bridge: redraw sent to GNU Emacs"
      result(status())
      return
    }
    appendOutput("\u{000C}macOS native bridge redraw; process backend unavailable\r\n")
    result(status())
  }

  private func sendBytes(_ arguments: Any?, result: FlutterResult) {
    let bytes = extractBytes(arguments)
    inputBytes += bytes.count
    if bytes.isEmpty {
      result(status())
      return
    }
    if writeToEmacs(Data(bytes)) {
      lifecycleState = "iosmacs macOS native bridge: input sent to GNU Emacs"
      result(status())
      return
    }
    appendOutput("macOS native bridge accepted input; process backend unavailable\r\n")
    result(status())
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
    if isEmacsRunning() {
      resizeEmacsPty()
      lifecycleState = "iosmacs macOS native bridge: resized GNU Emacs PTY \(cols)x\(rows)"
      appendOutput("macOS native bridge resized GNU Emacs PTY \(cols)x\(rows)\r\n")
    } else {
      appendOutput("macOS native bridge resize \(cols)x\(rows); process backend unavailable\r\n")
    }
    result(status())
  }

  private func status() -> [String: Any] {
    [
      "lifecycleState": lifecycleState,
      "cols": cols,
      "rows": rows,
      "inputBytes": inputBytes,
      "outputBytes": outputByteCount(),
    ]
  }

  private func startInteractiveEmacsProcess() -> Bool {
    let candidates = emacsExecutableCandidates()
    if let bundledRuntimeURL = bundledEmacsRuntimeURL() {
      appendOutput("macOS bundled GNU Emacs runtime: \(bundledRuntimeURL.path)\r\n")
    } else {
      appendOutput("macOS bundled GNU Emacs runtime unavailable\r\n")
    }
    appendOutput("macOS Emacs process candidates:\r\n")
    for candidate in candidates {
      appendOutput("- \(candidate)\r\n")
    }

    for candidate in candidates {
      guard FileManager.default.isExecutableFile(atPath: candidate) else {
        continue
      }
      if launchEmacsProcess(candidate) {
        return true
      }
    }

    lifecycleState = "iosmacs macOS native bridge: process unavailable"
    return false
  }

  private func launchEmacsProcess(_ executablePath: String) -> Bool {
    let launchEnvironment = emacsRuntimeEnvironment(for: executablePath)
    var masterFD: Int32 = -1
    var initialSize = winsize(
      ws_row: UInt16(max(rows, 1)),
      ws_col: UInt16(max(cols, 1)),
      ws_xpixel: 0,
      ws_ypixel: 0
    )
    let argv: [UnsafeMutablePointer<CChar>?] = [
      strdup(executablePath),
      strdup("--quick"),
      strdup("--no-splash"),
      strdup("-nw"),
      strdup("--eval"),
      strdup(Self.runtimeEvalForm),
      nil,
    ]
    defer {
      for pointer in argv where pointer != nil {
        free(pointer)
      }
    }

    let childPID = forkpty(&masterFD, nil, nil, &initialSize)
    guard childPID >= 0 else {
      appendOutput("macOS forkpty failed: \(String(cString: strerror(errno)))\r\n")
      return false
    }

    if childPID == 0 {
      setenv("TERM", ProcessInfo.processInfo.environment["IOSMACS_FLUTTER_TERM"] ?? "xterm-256color", 1)
      setenv("COLUMNS", "\(cols)", 1)
      setenv("LINES", "\(rows)", 1)
      for (key, value) in launchEnvironment {
        setenv(key, value, 1)
      }
      argv.withUnsafeBufferPointer { buffer in
        _ = execv(executablePath, UnsafeMutablePointer(mutating: buffer.baseAddress))
      }
      _exit(127)
    }

    let masterHandle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)

    masterHandle.readabilityHandler = { [weak self] handle in
      let data = handle.availableData
      guard !data.isEmpty else {
        handle.readabilityHandler = nil
        return
      }
      self?.appendOutputData(data)
    }
    emacsPID = childPID
    emacsInput = masterHandle
    emacsPtyMaster = masterHandle
    Thread.sleep(forTimeInterval: Self.startupSurvivalProbeDuration)
    if let exitDescription = reapIfExited(pid: childPID) {
      masterHandle.readabilityHandler = nil
      try? masterHandle.close()
      appendOutput(
        "macOS interactive GNU Emacs process exited during startup (\(exitDescription)); trying next candidate: \(executablePath)\r\n"
      )
      emacsPID = nil
      emacsInput = nil
      emacsPtyMaster = nil
      return false
    }

    installExitSource(pid: childPID, executablePath: executablePath)
    lifecycleState = "iosmacs macOS native bridge: GNU Emacs process running"
    appendOutput("macOS interactive GNU Emacs process started: \(executablePath)\r\n")
    return true
  }

  private func writeToEmacs(_ data: Data) -> Bool {
    guard isEmacsRunning(), let emacsInput else {
      return false
    }
    emacsInput.write(data)
    return true
  }

  private func resizeEmacsPty() {
    guard let emacsPtyMaster else {
      return
    }
    var size = winsize(
      ws_row: UInt16(max(rows, 1)),
      ws_col: UInt16(max(cols, 1)),
      ws_xpixel: 0,
      ws_ypixel: 0
    )
    _ = ioctl(emacsPtyMaster.fileDescriptor, TIOCSWINSZ, &size)
  }

  private func stopEmacsProcess() {
    guard let pid = emacsPID else {
      closeEmacsHandles()
      return
    }
    kill(pid, SIGTERM)
    _ = reapIfExited(pid: pid)
    closeEmacsHandles()
    emacsPID = nil
  }

  private func closeEmacsHandles() {
    emacsExitSource?.cancel()
    emacsExitSource = nil
    emacsPtyMaster?.readabilityHandler = nil
    try? emacsPtyMaster?.close()
    emacsInput = nil
    emacsPtyMaster = nil
  }

  private func installExitSource(pid: pid_t, executablePath: String) {
    let source = DispatchSource.makeProcessSource(
      identifier: pid,
      eventMask: .exit,
      queue: DispatchQueue.main
    )
    source.setEventHandler { [weak self] in
      guard let self else {
        return
      }
      let description = self.reapIfExited(pid: pid) ?? "unknown"
      self.appendOutput("macOS Emacs process exited \(description): \(executablePath)\r\n")
      if self.emacsPID == pid {
        self.lifecycleState = "iosmacs macOS native bridge: process exited \(description)"
        self.closeEmacsHandles()
        self.emacsPID = nil
      }
    }
    source.resume()
    emacsExitSource = source
  }

  private func isEmacsRunning() -> Bool {
    guard let pid = emacsPID else {
      return false
    }
    return kill(pid, 0) == 0
  }

  private func reapIfExited(pid: pid_t) -> String? {
    var status: Int32 = 0
    let result = waitpid(pid, &status, WNOHANG)
    guard result == pid else {
      return nil
    }
    let signal = status & 0x7f
    if signal == 0 {
      return "exit \((status >> 8) & 0xff)"
    }
    if signal != 0x7f {
      return "signal \(signal)"
    }
    return "status \(status)"
  }

  private func runEmacsProcessProbe() {
    let candidates = emacsExecutableCandidates()
    appendOutput("macOS Emacs process probe candidates:\r\n")
    for candidate in candidates {
      appendOutput("- \(candidate)\r\n")
    }

    for candidate in candidates {
      guard FileManager.default.isExecutableFile(atPath: candidate) else {
        continue
      }
      let process = Process()
      let stdoutPipe = Pipe()
      let stderrPipe = Pipe()
      process.executableURL = URL(fileURLWithPath: candidate)
      process.environment = processEnvironment(
        adding: emacsRuntimeEnvironment(for: candidate)
      )
      process.arguments = [
        "--batch",
        "--quick",
        "--eval",
        "(princ \"iosmacs-macos-process-ok\\n\")",
      ]
      process.standardOutput = stdoutPipe
      process.standardError = stderrPipe

      do {
        try process.run()
        process.waitUntilExit()

        let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        if !stdout.isEmpty {
          output.append(stdout)
          if !stdout.endsWithNewline {
            appendOutput("\r\n")
          }
        }
        if !stderr.isEmpty {
          appendOutput("stderr from \(candidate):\r\n")
          output.append(stderr)
          if !stderr.endsWithNewline {
            appendOutput("\r\n")
          }
        }

        if process.terminationStatus == 0 {
          lifecycleState = "iosmacs macOS native bridge: process probe ok"
          appendOutput("macOS Emacs process probe ok: \(candidate)\r\n")
          return
        }

        appendOutput(
          "macOS Emacs process probe exited \(process.terminationStatus): \(candidate)\r\n"
        )
      } catch {
        appendOutput("macOS Emacs process probe failed for \(candidate): \(error.localizedDescription)\r\n")
      }
    }

    lifecycleState = "iosmacs macOS native bridge: process probe unavailable"
    appendOutput("macOS Emacs process probe unavailable; PTY/process backend remains pending.\r\n")
  }

  private func emacsExecutableCandidates() -> [String] {
    var candidates: [String] = []
    if let bundledEmacsExecutablePath = bundledEmacsExecutablePath() {
      candidates.append(bundledEmacsExecutablePath)
    } else if let bundledRuntimeURL = bundledEmacsRuntimeURL() {
      candidates.append(
        bundledRuntimeURL
          .appendingPathComponent("bin", isDirectory: true)
          .appendingPathComponent("emacs")
          .path
      )
    }
    let environmentCandidate = ProcessInfo.processInfo.environment["IOSMACS_FLUTTER_EMACS"]
    if let environmentCandidate, !environmentCandidate.isEmpty {
      candidates.append(environmentCandidate)
    }
    return Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
  }

  private func bundledEmacsRuntimeURL() -> URL? {
    Bundle.main.resourceURL?
      .appendingPathComponent(Self.bundledRuntimeDirectoryName, isDirectory: true)
  }

  private func bundledEmacsExecutablePath() -> String? {
    guard let runtimeURL = bundledEmacsRuntimeURL() else {
      return nil
    }
    let executablePath = runtimeURL
      .appendingPathComponent("bin", isDirectory: true)
      .appendingPathComponent("emacs")
      .path
    return FileManager.default.isExecutableFile(atPath: executablePath) ? executablePath : nil
  }

  private func emacsRuntimeEnvironment(for executablePath: String) -> [String: String] {
    let executableURL = URL(fileURLWithPath: executablePath)
    guard executableURL.lastPathComponent == "emacs",
          executableURL.deletingLastPathComponent().lastPathComponent == "bin" else {
      return [:]
    }

    let runtimeURL = executableURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let lispURL = runtimeURL.appendingPathComponent("lisp", isDirectory: true)
    guard FileManager.default.fileExists(
      atPath: lispURL.appendingPathComponent("loadup.el").path
    ) else {
      return [:]
    }

    return [
      "EMACSLOADPATH": lispURL.path,
      "EMACSDATA": runtimeURL.appendingPathComponent("etc", isDirectory: true).path,
      "EMACSDOC": runtimeURL.appendingPathComponent("etc", isDirectory: true).path,
      "EMACSPATH": runtimeURL.appendingPathComponent("libexec", isDirectory: true).path,
    ]
  }

  private func processEnvironment(adding overrides: [String: String]) -> [String: String] {
    ProcessInfo.processInfo.environment.merging(overrides) { _, new in new }
  }

  private func listWorkspace(result: FlutterResult) {
    guard let workspaceRoot = prepareWorkspaceRoot() else {
      result(workspaceError("workspace_unavailable", "macOS workspace root is unavailable"))
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
      lifecycleState = "iosmacs macOS native bridge: listed \(entries.count) workspace item(s)"
      result(entries)
    } catch {
      result(workspaceError("workspace_list_failed", error.localizedDescription))
    }
  }

  private func importWorkspace(_ arguments: Any?, result: FlutterResult) {
    guard let workspaceRoot = prepareWorkspaceRoot() else {
      result(workspaceError("workspace_unavailable", "macOS workspace root is unavailable"))
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
      lifecycleState = "iosmacs macOS native bridge: imported \(importedCount) workspace item(s)"
      result(importedCount)
    } catch {
      result(workspaceError("workspace_import_failed", error.localizedDescription))
    }
  }

  private func exportWorkspace(result: FlutterResult) {
    guard let workspaceRoot = prepareWorkspaceRoot() else {
      result(workspaceError("workspace_unavailable", "macOS workspace root is unavailable"))
      return
    }

    do {
      let urls = try FileManager.default.contentsOfDirectory(
        at: workspaceRoot,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
      let exportURLs = urls.isEmpty ? [workspaceRoot] : urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
      lifecycleState = "iosmacs macOS native bridge: exported \(exportURLs.count) workspace item(s)"
      result(exportURLs.map { $0.absoluteString })
    } catch {
      result(workspaceError("workspace_export_failed", error.localizedDescription))
    }
  }

  private func prepareWorkspaceRoot() -> URL? {
    guard let applicationSupportRoot = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first else {
      return nil
    }

    let workspaceRoot = applicationSupportRoot
      .appendingPathComponent("iosmacs_flutter", isDirectory: true)
      .appendingPathComponent("workspace", isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: workspaceRoot,
        withIntermediateDirectories: true
      )
      return workspaceRoot
    } catch {
      appendOutput("macOS workspace root failed: \(error.localizedDescription)\r\n")
      return nil
    }
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

  private func appendOutput(_ text: String) {
    appendOutputData(Data(text.utf8))
  }

  private func appendOutputData(_ data: Data) {
    outputLock.lock()
    output.append(data)
    outputLock.unlock()
  }

  private func drainOutput() -> Data {
    outputLock.lock()
    defer {
      outputLock.unlock()
    }
    let data = output
    output.removeAll(keepingCapacity: true)
    return data
  }

  private func outputByteCount() -> Int {
    outputLock.lock()
    defer {
      outputLock.unlock()
    }
    return output.count
  }

  private func extractBytes(_ arguments: Any?) -> [UInt8] {
    guard let dictionary = arguments as? [String: Any],
          let typedData = dictionary["bytes"] as? FlutterStandardTypedData else {
      return []
    }
    return Array(typedData.data)
  }
}

private extension Data {
  var endsWithNewline: Bool {
    guard let last = self.last else {
      return false
    }
    return last == 10 || last == 13
  }
}
