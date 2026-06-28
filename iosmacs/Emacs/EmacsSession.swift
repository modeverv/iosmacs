import Foundation
import MachO

@MainActor
final class EmacsSession: ObservableObject {
    @Published private(set) var lifecycleState: String = "iosmacs: created"
    @Published private(set) var outputPulse: UInt64 = 0
    @Published private(set) var workspaceRootPath: String?
    @Published private(set) var pendingWorkspaceRootPath: String?
    @Published private(set) var metricsText: String = "startup: pending"
    @Published private(set) var focusRequest: UInt64 = 0
    @Published private(set) var spaceRequest: UInt64 = 0
    @Published var fontSize: CGFloat = 15

    private static let workspaceBookmarkDefaultsKey = "iosmacs.workspace.bookmark"
    private static let workspacePathDefaultsKey = "iosmacs.workspace.path"

    private let outputWorker = TerminalOutputWorker(maxDrainBytes: 16 * 1024)
    private var didStart = false
    private var diagnosticMode = false
    private var outputPumpTask: Task<Void, Never>?
    private var cachedWorkspaceRootURL: URL?
    private var selectedWorkspaceAccessURL: URL?
    private var startTime: Date?
    private var didRecordFirstOutput = false

    init() {
        pendingWorkspaceRootPath = UserDefaults.standard.string(forKey: Self.workspacePathDefaultsKey)
    }

    deinit {
        outputWorker.stop()
    }

    func start() {
        guard !didStart else {
            return
        }

        didStart = true
        startTime = Date()
        iosmacs_os_terminal_reset()
        outputWorker.start()
        if startRealEmacs() {
            diagnosticMode = false
        } else {
            diagnosticMode = true
            iosmacs_os_set_lifecycle_state("iosmacs: diagnostic terminal starting")
            iosmacs_emacs_diagnostic_start()
        }
        lifecycleState = String(cString: iosmacs_os_lifecycle_state())
        startOutputPump()
    }

    func resetDiagnosticSession() {
        if diagnosticMode {
            iosmacs_os_terminal_reset()
            iosmacs_emacs_diagnostic_start()
            lifecycleState = String(cString: iosmacs_os_lifecycle_state())
            outputPulse &+= 1
            return
        }
        sendInput([12])
    }

    func sendEscape() {
        sendInput([27])
        focusRequest &+= 1
    }

    func sendSpace() {
        spaceRequest &+= 1
        focusRequest &+= 1
    }

    func sendRedraw() {
        sendInput([12])
        focusRequest &+= 1
    }

    func sendInput(_ bytes: [UInt8]) {
        let shimWritten = bytes.withUnsafeBufferPointer { buffer in
            iosmacs_terminal_shim_push_input(buffer.baseAddress, buffer.count)
        }
        noteTerminalBridge(
            "swift send-input count=\(bytes.count) shim=\(shimWritten) ring=fd-readable bytes=\(hexPreview(bytes))"
        )
        if diagnosticMode {
            iosmacs_emacs_diagnostic_pump()
        }
        lifecycleState = String(cString: iosmacs_os_lifecycle_state())
        outputPulse &+= 1
    }

    func resize(cols: Int, rows: Int) {
        iosmacs_os_terminal_resize(Int32(cols), Int32(rows))
    }

    func noteTerminalBridge(_ message: String, publish: Bool = true) {
        if publish {
            lifecycleState = "iosmacs: \(message)"
        }
        guard let path = ProcessInfo.processInfo.environment["IOSMACS_WEB_TERMINAL_DEBUG_MARKER"],
              !path.isEmpty else {
            return
        }
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let line = "\(Date()): \(message)\n"
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: Data(line.utf8))
            try? handle.close()
        } else {
            try? line.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func terminalOutputStream() -> AsyncStream<[UInt8]> {
        outputWorker.stream()
    }

    func requestTerminalOutputDrain() {
        outputWorker.requestDrain()
    }

    func noteTerminalOutputFed(byteCount: Int) {
        guard byteCount > 0 else {
            return
        }
        if !didRecordFirstOutput {
            didRecordFirstOutput = true
            updateMetrics(prefix: "first output")
        }
        outputPulse &+= 1
    }

    private func hexPreview(_ bytes: [UInt8]) -> String {
        let preview = bytes.prefix(32).map { String(format: "%02x", $0) }.joined(separator: " ")
        return bytes.count > 32 ? "\(preview) ..." : preview
    }

    func increaseFontSize() {
        fontSize = min(fontSize + 1, 28)
    }

    func decreaseFontSize() {
        fontSize = max(fontSize - 1, 10)
    }

    func resetWorkspace() throws {
        guard let workspaceRoot = ensureWorkspaceRootURL() else {
            throw CocoaError(.fileNoSuchFile)
        }

        let urls = try FileManager.default.contentsOfDirectory(
            at: workspaceRoot,
            includingPropertiesForKeys: nil,
            options: []
        )
        for url in urls {
            try FileManager.default.removeItem(at: url)
        }
        cachedWorkspaceRootURL = nil
        _ = ensureWorkspaceRootURL()
        lifecycleState = "iosmacs: workspace reset"
    }

    func importFilesToWorkspace(_ urls: [URL]) throws -> Int {
        guard let workspaceRoot = ensureWorkspaceRootURL() else {
            throw CocoaError(.fileNoSuchFile)
        }

        var importedCount = 0
        for url in urls {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let destination = workspaceRoot.appendingPathComponent(url.lastPathComponent)
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: url, to: destination)
            importedCount += 1
        }
        lifecycleState = "iosmacs: imported \(importedCount) item(s)"
        return importedCount
    }

    func workspaceExportURLs() -> [URL] {
        guard let workspaceRoot = ensureWorkspaceRootURL(),
              let urls = try? FileManager.default.contentsOfDirectory(
                at: workspaceRoot,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
              ) else {
            return []
        }
        return urls.isEmpty ? [workspaceRoot] : urls.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    func setWorkspaceRootSelection(_ url: URL) throws -> String {
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

        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: Self.workspaceBookmarkDefaultsKey)
        UserDefaults.standard.set(url.path, forKey: Self.workspacePathDefaultsKey)
        pendingWorkspaceRootPath = url.path
        if didStart {
            return "Workspace saved for next launch"
        }

        cachedWorkspaceRootURL = nil
        _ = ensureWorkspaceRootURL()
        return "Workspace set"
    }

    func clearWorkspaceRootSelection() -> String {
        UserDefaults.standard.removeObject(forKey: Self.workspaceBookmarkDefaultsKey)
        UserDefaults.standard.removeObject(forKey: Self.workspacePathDefaultsKey)
        pendingWorkspaceRootPath = nil
        if didStart {
            return "Default workspace saved for next launch"
        }

        cachedWorkspaceRootURL = nil
        _ = ensureWorkspaceRootURL()
        return "Default workspace set"
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
        let started: Bool = lispDir.withCString { lispPointer in
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
        return started
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

        guard let documentsRoot = workspaceBaseURL() else {
            return nil
        }

        let workspaceRoot = documentsRoot
            .appendingPathComponent("home", isDirectory: true)
            .appendingPathComponent("user", isDirectory: true)
        return prepareWorkspaceDirectory(workspaceRoot)
    }

    private func prepareWorkspaceDirectory(_ workspaceRoot: URL) -> URL? {
        let notesRoot = workspaceRoot.appendingPathComponent("notes", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: notesRoot, withIntermediateDirectories: true)
            let readmeURL = workspaceRoot.appendingPathComponent("README.txt")
            if !FileManager.default.fileExists(atPath: readmeURL.path) {
                try "This directory is /home/user inside iosmacs.\n".write(to: readmeURL, atomically: true, encoding: .utf8)
            }
            cachedWorkspaceRootURL = workspaceRoot
            workspaceRootPath = workspaceRoot.path
            return workspaceRoot
        } catch {
            iosmacs_os_set_lifecycle_state("iosmacs: workspace setup failed")
            return nil
        }
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
                UserDefaults.standard.removeObject(forKey: Self.workspaceBookmarkDefaultsKey)
                UserDefaults.standard.removeObject(forKey: Self.workspacePathDefaultsKey)
                pendingWorkspaceRootPath = nil
                return nil
            }
            if selectedWorkspaceAccessURL?.path != url.path {
                _ = url.startAccessingSecurityScopedResource()
                selectedWorkspaceAccessURL = url
            }
            return url
        } catch {
            UserDefaults.standard.removeObject(forKey: Self.workspaceBookmarkDefaultsKey)
            UserDefaults.standard.removeObject(forKey: Self.workspacePathDefaultsKey)
            pendingWorkspaceRootPath = nil
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

    private func startOutputPump() {
        outputPumpTask?.cancel()
        outputPumpTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard let self else {
                    return
                }
                self.lifecycleState = String(cString: iosmacs_os_lifecycle_state())
                self.outputPulse &+= 1
                self.updateMetrics(prefix: self.didRecordFirstOutput ? "running" : "starting")
                if !self.diagnosticMode && !iosmacs_emacs_core_is_running() {
                    let status = iosmacs_emacs_core_exit_status()
                    self.lifecycleState = "iosmacs: GNU Emacs exited (\(status))"
                    self.updateMetrics(prefix: "exited")
                    return
                }
            }
        }
    }

    private func updateMetrics(prefix: String) {
        let elapsed: String
        if let startTime {
            elapsed = String(format: "%.1fs", Date().timeIntervalSince(startTime))
        } else {
            elapsed = "n/a"
        }
        metricsText = "\(prefix): \(elapsed), rss \(residentMemoryMegabytes()) MB"
    }

    private func residentMemoryMegabytes() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), reboundPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return 0
        }
        return Int(info.resident_size / 1024 / 1024)
    }
}

private final class TerminalOutputWorker: @unchecked Sendable {
    private let maxDrainBytes: Int
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<[UInt8]>.Continuation] = [:]
    private var didStart = false
    private var workerThread: Thread?

    init(maxDrainBytes: Int) {
        self.maxDrainBytes = maxDrainBytes
    }

    deinit {
        stop()
    }

    func start() {
        let shouldStart: Bool = lock.withLock {
            if !didStart {
                didStart = true
                return true
            }
            return false
        }
        guard shouldStart else {
            return
        }

        let thread = Thread { [weak self] in
            self?.runOutputLoop()
        }
        thread.name = "local.iosmacs.terminal-output-worker"
        workerThread = thread
        thread.start()
    }

    func stop() {
        let continuationsToFinish: [AsyncStream<[UInt8]>.Continuation] = lock.withLock {
            didStart = false
            let values = Array(continuations.values)
            continuations.removeAll()
            workerThread = nil
            return values
        }
        for continuation in continuationsToFinish {
            continuation.finish()
        }
    }

    func stream() -> AsyncStream<[UInt8]> {
        AsyncStream { continuation in
            let id = UUID()
            lock.withLock {
                continuations[id] = continuation
            }
            requestDrain()
            continuation.onTermination = { @Sendable [weak self] _ in
                guard let worker = self else {
                    return
                }
                _ = worker.lock.withLock {
                    worker.continuations.removeValue(forKey: id)
                }
            }
        }
    }

    func requestDrain() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.drainAvailableOutput()
        }
    }

    private func runOutputLoop() {
        while isRunning {
            drainAvailableOutput()
            _ = iosmacs_os_terminal_wait_for_output(250)
        }
    }

    private func drainAvailableOutput() {
        while true {
            var buffer = [UInt8](repeating: 0, count: maxDrainBytes)
            let count = buffer.withUnsafeMutableBufferPointer { pointer in
                iosmacs_os_terminal_drain_output(pointer.baseAddress, pointer.count)
            }
            guard count > 0 else {
                return
            }

            let chunk = Array(buffer.prefix(count))
            let continuationsSnapshot = lock.withLock {
                Array(continuations.values)
            }
            for continuation in continuationsSnapshot {
                continuation.yield(chunk)
            }
        }
    }

    private var isRunning: Bool {
        lock.withLock { didStart }
    }
}
