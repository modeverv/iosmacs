import 'dart:async';
import 'dart:convert';

import 'backend_diagnostics.dart';
import 'backend_worker.dart';
import 'workspace_entry.dart';

class FakeBackendWorker implements BackendWorker {
  FakeBackendWorker();

  final StreamController<BackendWorkerEvent> _eventsController =
      StreamController<BackendWorkerEvent>.broadcast();

  BackendDiagnostics _diagnostics = const BackendDiagnostics.initial();
  int _cols = 80;
  int _rows = 24;
  bool _started = false;
  final List<WorkspaceEntry> _importedWorkspaceEntries = <WorkspaceEntry>[];

  @override
  Stream<BackendWorkerEvent> get events => _eventsController.stream;

  @override
  Future<BackendWorkerResult> dispatch(BackendWorkerCommand command) async {
    switch (command) {
      case StartBackendCommand():
        _start();
      case StopBackendCommand():
        _stop();
      case RedrawBackendCommand():
        _redraw();
      case SendBytesBackendCommand(:final bytes):
        _sendBytes(bytes);
      case ResizeBackendCommand(:final cols, :final rows):
        _resize(cols: cols, rows: rows);
      case ListWorkspaceBackendCommand():
        return BackendWorkerResult(
          workspaceEntries: _workspaceEntries(),
        );
      case ImportWorkspaceBackendCommand(:final uris):
        _importedWorkspaceEntries.addAll(uris.map(_workspaceEntryFromUri));
        _updateDiagnostics(
          message: 'fake import requested for ${uris.length} item(s)',
          workspaceActions: _diagnostics.workspaceActions + 1,
        );
        return BackendWorkerResult(importedCount: uris.length);
      case ExportWorkspaceBackendCommand():
        _updateDiagnostics(
          message: 'fake export requested',
          workspaceActions: _diagnostics.workspaceActions + 1,
        );
        return BackendWorkerResult(
          exportedUris: _workspaceEntries()
              .map((WorkspaceEntry entry) => Uri(path: entry.path))
              .toList(growable: false),
        );
    }

    return const BackendWorkerResult();
  }

  @override
  Future<void> dispose() async {
    await _eventsController.close();
  }

  void _start() {
    if (_started) {
      _write('\r\n[iosmacs] fake backend already running\r\n');
      return;
    }

    _started = true;
    _eventsController.add(const BackendLifecycleEvent('running'));
    _updateDiagnostics(message: 'fake backend running');
    _write('\x1b[2J\x1b[H');
    _write('GNU Emacs fake terminal for iosmacs Flutter\r\n');
    _write('Buffer: *scratch*   Mode: Lisp Interaction\r\n');
    _write('Type text to echo through EmacsBackend.sendBytes.\r\n\r\n');
    _write('* ');
  }

  void _stop() {
    if (!_started) {
      return;
    }

    _started = false;
    _eventsController.add(const BackendLifecycleEvent('stopped'));
    _updateDiagnostics(message: 'fake backend stopped');
    _write('\r\n[iosmacs] stopped\r\n');
  }

  void _redraw() {
    _updateDiagnostics(message: 'redraw requested');
    _write('\x1b[2J\x1b[H');
    _write('GNU Emacs fake terminal for iosmacs Flutter\r\n');
    _write('Redraw complete at $_cols x $_rows\r\n\r\n');
    _write('* ');
  }

  void _sendBytes(List<int> bytes) {
    if (!_started) {
      _updateDiagnostics(message: 'input ignored while backend is not running');
      return;
    }

    _eventsController.add(BackendOutputEvent(List<int>.from(bytes)));
    _updateDiagnostics(
      message: 'received ${bytes.length} input byte(s)',
      inputBytes: _diagnostics.inputBytes + bytes.length,
      outputBytes: _diagnostics.outputBytes + bytes.length,
    );
  }

  void _resize({required int cols, required int rows}) {
    _cols = cols;
    _rows = rows;
    _updateDiagnostics(message: 'resize reported', cols: cols, rows: rows);
    if (_started) {
      _write('\r\n[iosmacs] resize $_cols x $_rows\r\n* ');
    }
  }

  void _write(String text) {
    final bytes = utf8.encode(text);
    _eventsController.add(BackendOutputEvent(bytes));
    _updateDiagnostics(outputBytes: _diagnostics.outputBytes + bytes.length);
  }

  WorkspaceEntry _workspaceEntryFromUri(Uri uri) {
    final path = uri.toFilePath();
    final normalizedPath = path.replaceAll('\\', '/');
    final segments = normalizedPath
        .split('/')
        .where((String segment) => segment.isNotEmpty)
        .toList(growable: false);
    final name = segments.isEmpty ? normalizedPath : segments.last;
    return WorkspaceEntry(
      name: name,
      path: '/workspace/$name',
      isDirectory: false,
      sizeBytes: 0,
    );
  }

  List<WorkspaceEntry> _workspaceEntries() {
    return <WorkspaceEntry>[
      const WorkspaceEntry(
        name: 'scratch.el',
        path: '/workspace/scratch.el',
        isDirectory: false,
        sizeBytes: 0,
      ),
      ..._importedWorkspaceEntries,
    ];
  }

  void _updateDiagnostics({
    String? message,
    int? cols,
    int? rows,
    int? inputBytes,
    int? outputBytes,
    int? workspaceActions,
  }) {
    _diagnostics = _diagnostics.copyWith(
      message: message,
      cols: cols,
      rows: rows,
      inputBytes: inputBytes,
      outputBytes: outputBytes,
      workspaceActions: workspaceActions,
    );
    _eventsController.add(BackendDiagnosticsEvent(_diagnostics));
  }
}
