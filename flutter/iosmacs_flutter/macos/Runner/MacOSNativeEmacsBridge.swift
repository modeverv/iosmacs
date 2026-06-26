import FlutterMacOS
import Foundation

final class MacOSNativeEmacsBridge {
  private var lifecycleState = "iosmacs macOS native bridge: idle"
  private var cols = 80
  private var rows = 24
  private var inputBytes = 0
  private var output = Data()

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "start":
      appendOutput("macOS native channel is connected.\r\n")
      runEmacsProcessProbe()
      appendOutput("Interactive PTY GNU Emacs backend is pending.\r\n")
      result(status())
    case "stop":
      lifecycleState = "iosmacs macOS native bridge: stopped"
      appendOutput("macOS native bridge stopped\r\n")
      result(status())
    case "redraw":
      appendOutput("\u{000C}macOS native bridge redraw; process backend pending\r\n")
      result(status())
    case "sendBytes":
      inputBytes += extractBytes(call.arguments).count
      appendOutput("macOS native bridge accepted input; process backend pending\r\n")
      result(status())
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
    appendOutput("macOS native bridge resize \(cols)x\(rows); process backend pending\r\n")
    result(status())
  }

  private func status() -> [String: Any] {
    [
      "lifecycleState": lifecycleState,
      "cols": cols,
      "rows": rows,
      "inputBytes": inputBytes,
      "outputBytes": output.count,
    ]
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
    let environmentCandidate = ProcessInfo.processInfo.environment["IOSMACS_FLUTTER_EMACS"]
    if let environmentCandidate, !environmentCandidate.isEmpty {
      candidates.append(environmentCandidate)
    }
    candidates.append(contentsOf: [
      "/usr/local/bin/emacs",
      "/opt/homebrew/bin/emacs",
      "/Applications/Emacs.app/Contents/MacOS/Emacs",
      "/Applications/Emacs-takaxp/Emacs.app/Contents/MacOS/Emacs",
    ])
    return Array(NSOrderedSet(array: candidates)) as? [String] ?? candidates
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

  private func pendingError(_ method: String) -> FlutterError {
    FlutterError(
      code: "macos_process_backend_pending",
      message: "macOS PTY/process GNU Emacs backend is not connected yet",
      details: ["method": method]
    )
  }

  private func workspaceError(_ code: String, _ message: String) -> FlutterError {
    FlutterError(code: code, message: message, details: nil)
  }

  private func appendOutput(_ text: String) {
    output.append(contentsOf: text.utf8)
  }

  private func drainOutput() -> Data {
    let data = output
    output.removeAll(keepingCapacity: true)
    return data
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
