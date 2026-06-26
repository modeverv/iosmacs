import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'backend_capabilities.dart';
import 'backend_diagnostics.dart';
import 'emacs_backend.dart';
import 'workspace_entry.dart';

class AndroidEmacsBackend implements EmacsBackend {
  final StreamController<List<int>> _outputController =
      StreamController<List<int>>.broadcast();
  final ValueNotifier<String> _lifecycleState = ValueNotifier<String>('idle');
  final ValueNotifier<BackendDiagnostics> _diagnostics =
      ValueNotifier<BackendDiagnostics>(
    const BackendDiagnostics(
      message: 'android backend pending',
      cols: 80,
      rows: 24,
      inputBytes: 0,
      outputBytes: 0,
      workspaceActions: 0,
    ),
  );

  @override
  BackendCapabilities get capabilities => const BackendCapabilities(
        id: 'android-placeholder',
        displayName: 'Android backend placeholder',
        supportedFeatures: <String>[
          'Android backend selection',
          'Android SDK debug build surface',
          'deterministic unsupported diagnostics',
          'Android-safe workspace placeholders',
        ],
        unsupportedFeatures: <String>[
          'Android NDK GNU Emacs core build',
          'Android terminal byte stream from native Emacs',
          'Android document provider import/export proof',
          'PTY/process Emacs session on Android',
        ],
      );

  @override
  Stream<List<int>> get outputStream => _outputController.stream;

  @override
  ValueListenable<String> get lifecycleState => _lifecycleState;

  @override
  ValueListenable<BackendDiagnostics> get diagnostics => _diagnostics;

  @override
  Future<void> start() async {
    _lifecycleState.value = 'unsupported';
    _write('iosmacs Flutter Android backend selected\r\n');
    _write(
        'Port the native GNU Emacs core through an Android NDK backend.\r\n');
    _setMessage('android native backend route pending');
  }

  @override
  Future<void> stop() async {
    _lifecycleState.value = 'stopped';
    _setMessage('android backend stopped');
  }

  @override
  Future<void> resetOrRedraw() async {
    _write('\u{000C}iosmacs Flutter Android backend placeholder\r\n');
    _setMessage('android redraw placeholder');
  }

  @override
  Future<void> sendBytes(List<int> bytes) async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: 'android input ignored until native runtime is connected',
      inputBytes: _diagnostics.value.inputBytes + bytes.length,
    );
  }

  @override
  Future<bool> pasteSystemClipboard() async => false;

  @override
  Future<void> resize({required int cols, required int rows}) async {
    await Future<void>.delayed(Duration.zero);
    _diagnostics.value = _diagnostics.value.copyWith(
      message: 'android resize recorded',
      cols: cols,
      rows: rows,
    );
  }

  @override
  Future<List<WorkspaceEntry>> listWorkspace() async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: 'android workspace placeholder listed',
      workspaceActions: _diagnostics.value.workspaceActions + 1,
    );
    return const <WorkspaceEntry>[
      WorkspaceEntry(
        name: 'android-placeholder',
        path: 'android://iosmacs/workspace-placeholder',
        isDirectory: true,
        sizeBytes: 0,
      ),
    ];
  }

  @override
  Future<int> importToWorkspace(List<Uri> uris) async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: 'android workspace import pending for ${uris.length} item(s)',
      workspaceActions: _diagnostics.value.workspaceActions + 1,
    );
    return 0;
  }

  @override
  Future<List<Uri>> exportWorkspaceSelection() async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: 'android workspace export pending',
      workspaceActions: _diagnostics.value.workspaceActions + 1,
    );
    return const <Uri>[];
  }

  @override
  Future<String> selectWorkspaceRoot() async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: 'android workspace root selection pending',
      workspaceActions: _diagnostics.value.workspaceActions + 1,
    );
    return 'Android workspace root selection pending';
  }

  @override
  Future<String> clearWorkspaceRootSelection() async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: 'android default workspace pending',
      workspaceActions: _diagnostics.value.workspaceActions + 1,
    );
    return 'Android default workspace pending';
  }

  @override
  void dispose() {
    _lifecycleState.dispose();
    _diagnostics.dispose();
    unawaited(_outputController.close());
  }

  void _write(String text) {
    final bytes = utf8.encode(text);
    _outputController.add(bytes);
    _diagnostics.value = _diagnostics.value.copyWith(
      outputBytes: _diagnostics.value.outputBytes + bytes.length,
    );
  }

  void _setMessage(String message) {
    _diagnostics.value = _diagnostics.value.copyWith(message: message);
  }
}
