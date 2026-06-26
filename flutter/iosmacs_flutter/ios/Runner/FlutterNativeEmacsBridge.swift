import Flutter
import Foundation

final class FlutterNativeEmacsBridge {
  private var lifecycleState = "iosmacs flutter bridge: idle"
  private var cols = 80
  private var rows = 24
  private var inputBytes = 0
  private var startedRealEmacs = false

  func handle(_ call: FlutterMethodCall, result: FlutterResult) {
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
      drainOutput(result: result)
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

  private func start(result: FlutterResult) {
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
      _ = iosmacs_os_terminal_push_input(buffer.baseAddress, buffer.count)
    }
    if !startedRealEmacs {
      iosmacs_emacs_diagnostic_pump()
    }
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
    iosmacs_os_terminal_resize(Int32(cols), Int32(rows))
    writeOutput("native facade resize \(cols)x\(rows)\r\n")
    result(status())
  }

  private func listWorkspace(result: FlutterResult) {
    guard let workspaceRoot = prepareDefaultWorkspaceRoot() else {
      result(workspaceError("workspace_unavailable", "default workspace is unavailable"))
      return
    }

    do {
      let rootURL = URL(fileURLWithPath: workspaceRoot, isDirectory: true)
      let urls = try FileManager.default.contentsOfDirectory(
        at: rootURL,
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
    guard let workspaceRoot = prepareDefaultWorkspaceRoot() else {
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

    let rootURL = URL(fileURLWithPath: workspaceRoot, isDirectory: true)
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

        let destinationURL = rootURL.appendingPathComponent(sourceURL.lastPathComponent)
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
    guard let workspaceRoot = prepareDefaultWorkspaceRoot() else {
      result(workspaceError("workspace_unavailable", "default workspace is unavailable"))
      return
    }

    do {
      let rootURL = URL(fileURLWithPath: workspaceRoot, isDirectory: true)
      let urls = try FileManager.default.contentsOfDirectory(
        at: rootURL,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
      let exportURLs = urls.isEmpty ? [rootURL] : urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
      result(exportURLs.map { $0.absoluteString })
    } catch {
      result(workspaceError("workspace_export_failed", error.localizedDescription))
    }
  }

  private func drainOutput(result: FlutterResult) {
    var buffer = [UInt8](repeating: 0, count: 16 * 1024)
    let count = buffer.withUnsafeMutableBufferPointer { pointer in
      iosmacs_os_terminal_drain_output(pointer.baseAddress, pointer.count)
    }
    guard count > 0 else {
      result(FlutterStandardTypedData(bytes: Data()))
      return
    }
    result(FlutterStandardTypedData(bytes: Data(buffer.prefix(count))))
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
    let workspaceRoot = prepareDefaultWorkspaceRoot()

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

  private func prepareDefaultWorkspaceRoot() -> String? {
    guard let documentsRoot = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first else {
      return nil
    }
    let workspaceRoot = documentsRoot.appendingPathComponent("home", isDirectory: true)
    do {
      try FileManager.default.createDirectory(
        at: workspaceRoot,
        withIntermediateDirectories: true
      )
      return workspaceRoot.path
    } catch {
      writeOutput("iosmacs Flutter workspace setup failed: \(error.localizedDescription)\r\n")
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
      "emacsCoreLinkAvailable": iosmacs_emacs_core_link_available(),
      "emacsCoreEntrySymbol": String(cString: iosmacs_emacs_core_entry_symbol_name()),
      "emacsCoreConnected": startedRealEmacs && iosmacs_emacs_core_is_running(),
    ]
  }
}
