import 'backend_diagnostics.dart';
import 'workspace_entry.dart';

sealed class BackendWorkerCommand {
  const BackendWorkerCommand();
}

class StartBackendCommand extends BackendWorkerCommand {
  const StartBackendCommand();
}

class StopBackendCommand extends BackendWorkerCommand {
  const StopBackendCommand();
}

class RedrawBackendCommand extends BackendWorkerCommand {
  const RedrawBackendCommand();
}

class SendBytesBackendCommand extends BackendWorkerCommand {
  const SendBytesBackendCommand(this.bytes);

  final List<int> bytes;
}

class ResizeBackendCommand extends BackendWorkerCommand {
  const ResizeBackendCommand({required this.cols, required this.rows});

  final int cols;
  final int rows;
}

class ListWorkspaceBackendCommand extends BackendWorkerCommand {
  const ListWorkspaceBackendCommand();
}

class ImportWorkspaceBackendCommand extends BackendWorkerCommand {
  const ImportWorkspaceBackendCommand(this.uris);

  final List<Uri> uris;
}

class ExportWorkspaceBackendCommand extends BackendWorkerCommand {
  const ExportWorkspaceBackendCommand();
}

class BackendWorkerResult {
  const BackendWorkerResult({
    this.workspaceEntries,
    this.importedCount,
    this.exportedUris,
  });

  final List<WorkspaceEntry>? workspaceEntries;
  final int? importedCount;
  final List<Uri>? exportedUris;
}

sealed class BackendWorkerEvent {
  const BackendWorkerEvent();
}

class BackendOutputEvent extends BackendWorkerEvent {
  const BackendOutputEvent(this.bytes);

  final List<int> bytes;
}

class BackendLifecycleEvent extends BackendWorkerEvent {
  const BackendLifecycleEvent(this.state);

  final String state;
}

class BackendDiagnosticsEvent extends BackendWorkerEvent {
  const BackendDiagnosticsEvent(this.diagnostics);

  final BackendDiagnostics diagnostics;
}

abstract interface class BackendWorker {
  Stream<BackendWorkerEvent> get events;

  Future<BackendWorkerResult> dispatch(BackendWorkerCommand command);

  Future<void> dispose();
}
