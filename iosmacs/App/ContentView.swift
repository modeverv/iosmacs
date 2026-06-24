import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @EnvironmentObject private var session: EmacsSession
    @State private var showingImporter = false
    @State private var showingExporter = false
    @State private var exportURLs: [URL] = []
    @State private var documentStatus: String?
    @State private var showingResetConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            IOSMacsTerminalView(session: session)

            Divider()

            HStack(spacing: 12) {
                Text(session.lifecycleState)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(session.metricsText)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button {
                    session.decreaseFontSize()
                } label: {
                    Label("Smaller", systemImage: "textformat.size.smaller")
                }
                .labelStyle(.iconOnly)
                .frame(width: 44)
                .buttonStyle(.bordered)
                .keyboardShortcut("-", modifiers: [.command])
                .accessibilityLabel("Smaller")

                Button {
                    session.increaseFontSize()
                } label: {
                    Label("Larger", systemImage: "textformat.size.larger")
                }
                .labelStyle(.iconOnly)
                .frame(width: 44)
                .buttonStyle(.bordered)
                .keyboardShortcut("=", modifiers: [.command])
                .accessibilityLabel("Larger")

                Button {
                    showingImporter = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .labelStyle(.iconOnly)
                .frame(width: 44)
                .buttonStyle(.bordered)
                .keyboardShortcut("i", modifiers: [.command, .shift])
                .accessibilityLabel("Import")

                Button {
                    exportURLs = session.workspaceExportURLs()
                    showingExporter = !exportURLs.isEmpty
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .labelStyle(.iconOnly)
                .frame(width: 44)
                .buttonStyle(.bordered)
                .keyboardShortcut("e", modifiers: [.command, .shift])
                .accessibilityLabel("Export")

                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    Label("Reset", systemImage: "trash")
                }
                .labelStyle(.iconOnly)
                .frame(width: 44)
                .buttonStyle(.bordered)
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .accessibilityLabel("Reset Workspace")

                Button {
                    session.resetDiagnosticSession()
                } label: {
                    Label("Redraw", systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .frame(width: 44)
                .buttonStyle(.bordered)
                .keyboardShortcut("l", modifiers: [.control])
                .accessibilityLabel("Redraw")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                do {
                    let count = try session.importFilesToWorkspace(urls)
                    documentStatus = "Imported \(count) item(s)"
                } catch {
                    documentStatus = "Import failed"
                }
            case .failure:
                documentStatus = "Import failed"
            }
        }
        .sheet(isPresented: $showingExporter) {
            WorkspaceExportPicker(urls: exportURLs) { message in
                documentStatus = message
                showingExporter = false
            }
        }
        .confirmationDialog(
            "Reset workspace?",
            isPresented: $showingResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset Workspace", role: .destructive) {
                do {
                    try session.resetWorkspace()
                    documentStatus = "Workspace reset"
                } catch {
                    documentStatus = "Reset failed"
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .overlay(alignment: .top) {
            if let documentStatus {
                Text(documentStatus)
                    .font(.caption.monospaced())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 12)
            }
        }
    }
}

private struct WorkspaceExportPicker: UIViewControllerRepresentable {
    let urls: [URL]
    let onCompletion: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompletion: onCompletion)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: urls, asCopy: true)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let onCompletion: (String) -> Void

        init(onCompletion: @escaping (String) -> Void) {
            self.onCompletion = onCompletion
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCompletion("Export cancelled")
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onCompletion("Exported \(urls.count) item(s)")
        }
    }
}
