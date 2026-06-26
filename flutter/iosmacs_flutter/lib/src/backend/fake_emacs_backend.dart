import 'dart:async';

import 'package:flutter/foundation.dart';

import 'backend_capabilities.dart';
import 'backend_diagnostics.dart';
import 'backend_worker.dart';
import 'emacs_backend.dart';
import 'fake_backend_worker.dart';
import 'workspace_entry.dart';

class FakeEmacsBackend implements EmacsBackend {
  FakeEmacsBackend({BackendWorker? worker})
      : _worker = worker ?? FakeBackendWorker() {
    _workerSubscription = _worker.events.listen(_handleWorkerEvent);
  }

  final BackendWorker _worker;
  final StreamController<List<int>> _outputController =
      StreamController<List<int>>.broadcast();
  final ValueNotifier<String> _lifecycleState = ValueNotifier<String>('idle');
  final ValueNotifier<BackendDiagnostics> _diagnostics =
      ValueNotifier<BackendDiagnostics>(
    const BackendDiagnostics.initial(),
  );

  late final StreamSubscription<BackendWorkerEvent> _workerSubscription;

  @override
  BackendCapabilities get capabilities => const BackendCapabilities(
        id: 'fake',
        displayName: 'Fake backend',
        supportedFeatures: <String>[
          'deterministic terminal output',
          'ASCII input echo',
          'terminal resize diagnostics',
          'workspace placeholder listing',
          'workspace placeholder import/export',
        ],
        unsupportedFeatures: <String>[
          'native GNU Emacs runtime',
          'PTY or subprocess execution',
          'real filesystem import/export',
          'network/process Emacs primitives',
          'platform IME acceptance proof',
        ],
      );

  @override
  Stream<List<int>> get outputStream => _outputController.stream;

  @override
  ValueListenable<String> get lifecycleState => _lifecycleState;

  @override
  ValueListenable<BackendDiagnostics> get diagnostics => _diagnostics;

  @override
  Future<void> start() => _dispatch(const StartBackendCommand());

  @override
  Future<void> stop() => _dispatch(const StopBackendCommand());

  @override
  Future<void> resetOrRedraw() => _dispatch(const RedrawBackendCommand());

  @override
  Future<void> sendBytes(List<int> bytes) =>
      _dispatch(SendBytesBackendCommand(bytes));

  @override
  Future<bool> pasteSystemClipboard() async => false;

  @override
  Future<void> resize({required int cols, required int rows}) =>
      _dispatch(ResizeBackendCommand(cols: cols, rows: rows));

  @override
  Future<List<WorkspaceEntry>> listWorkspace() async {
    final result = await _worker.dispatch(const ListWorkspaceBackendCommand());
    return result.workspaceEntries ?? const <WorkspaceEntry>[];
  }

  @override
  Future<int> importToWorkspace(List<Uri> uris) async {
    final result = await _worker.dispatch(ImportWorkspaceBackendCommand(uris));
    return result.importedCount ?? 0;
  }

  @override
  Future<List<Uri>> exportWorkspaceSelection() async {
    final result =
        await _worker.dispatch(const ExportWorkspaceBackendCommand());
    return result.exportedUris ?? const <Uri>[];
  }

  @override
  Future<String> selectWorkspaceRoot() async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: 'fake workspace root selection requested',
      workspaceActions: _diagnostics.value.workspaceActions + 1,
    );
    return 'Fake workspace root selected for next launch';
  }

  @override
  Future<String> clearWorkspaceRootSelection() async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: 'fake default workspace requested',
      workspaceActions: _diagnostics.value.workspaceActions + 1,
    );
    return 'Fake default workspace set';
  }

  @override
  void dispose() async {
    await _workerSubscription.cancel();
    await _worker.dispose();
    _lifecycleState.dispose();
    _diagnostics.dispose();
    await _outputController.close();
  }

  Future<void> _dispatch(BackendWorkerCommand command) async {
    await _worker.dispatch(command);
  }

  void _handleWorkerEvent(BackendWorkerEvent event) {
    switch (event) {
      case BackendOutputEvent(:final bytes):
        _outputController.add(bytes);
      case BackendLifecycleEvent(:final state):
        _lifecycleState.value = state;
      case BackendDiagnosticsEvent(:final diagnostics):
        _diagnostics.value = diagnostics;
    }
  }
}
