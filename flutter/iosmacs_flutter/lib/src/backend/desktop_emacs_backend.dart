import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'backend_capabilities.dart';
import 'backend_diagnostics.dart';
import 'emacs_backend.dart';
import 'workspace_entry.dart';

enum DesktopEmacsPlatform {
  linux,
  windows,
}

class DesktopEmacsBackend implements EmacsBackend {
  DesktopEmacsBackend({required DesktopEmacsPlatform platform})
      : _platform = platform;

  final DesktopEmacsPlatform _platform;
  final StreamController<List<int>> _outputController =
      StreamController<List<int>>.broadcast();
  final ValueNotifier<String> _lifecycleState = ValueNotifier<String>('idle');
  final ValueNotifier<BackendDiagnostics> _diagnostics =
      ValueNotifier<BackendDiagnostics>(
    const BackendDiagnostics(
      message: 'desktop backend pending',
      cols: 80,
      rows: 24,
      inputBytes: 0,
      outputBytes: 0,
      workspaceActions: 0,
    ),
  );

  @override
  BackendCapabilities get capabilities {
    final label = _platformLabel;
    final id = _platformId;
    return BackendCapabilities(
      id: '$id-placeholder',
      displayName: '$label backend placeholder',
      supportedFeatures: <String>[
        '$label backend selection',
        '$label generated runner visibility',
        'deterministic unsupported diagnostics',
        '$label-safe workspace placeholders',
      ],
      unsupportedFeatures: <String>[
        '$label GNU Emacs process/PTY bridge',
        '$label native file picker import/export proof',
        '$label terminal byte stream from native Emacs',
        '$label packaged Emacs runtime resources',
      ],
    );
  }

  @override
  Stream<List<int>> get outputStream => _outputController.stream;

  @override
  ValueListenable<String> get lifecycleState => _lifecycleState;

  @override
  ValueListenable<BackendDiagnostics> get diagnostics => _diagnostics;

  @override
  Future<void> start() async {
    _lifecycleState.value = 'unsupported';
    _write('iosmacs Flutter $_platformLabel backend selected\r\n');
    _write('Connect this surface to a packaged desktop Emacs runtime.\r\n');
    _setMessage('$_platformId desktop backend route pending');
  }

  @override
  Future<void> stop() async {
    _lifecycleState.value = 'stopped';
    _setMessage('$_platformId backend stopped');
  }

  @override
  Future<void> resetOrRedraw() async {
    _write('\u{000C}iosmacs Flutter $_platformLabel backend placeholder\r\n');
    _setMessage('$_platformId redraw placeholder');
  }

  @override
  Future<void> sendBytes(List<int> bytes) async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: '$_platformId input ignored until desktop runtime is connected',
      inputBytes: _diagnostics.value.inputBytes + bytes.length,
    );
  }

  @override
  Future<bool> pasteSystemClipboard() async => false;

  @override
  Future<void> resize({required int cols, required int rows}) async {
    await Future<void>.delayed(Duration.zero);
    _diagnostics.value = _diagnostics.value.copyWith(
      message: '$_platformId resize recorded',
      cols: cols,
      rows: rows,
    );
  }

  @override
  Future<List<WorkspaceEntry>> listWorkspace() async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: '$_platformId workspace placeholder listed',
      workspaceActions: _diagnostics.value.workspaceActions + 1,
    );
    return <WorkspaceEntry>[
      WorkspaceEntry(
        name: '$_platformId-placeholder',
        path: '$_platformId://iosmacs/workspace-placeholder',
        isDirectory: true,
        sizeBytes: 0,
      ),
    ];
  }

  @override
  Future<int> importToWorkspace(List<Uri> uris) async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message:
          '$_platformId workspace import pending for ${uris.length} item(s)',
      workspaceActions: _diagnostics.value.workspaceActions + 1,
    );
    return 0;
  }

  @override
  Future<List<Uri>> exportWorkspaceSelection() async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: '$_platformId workspace export pending',
      workspaceActions: _diagnostics.value.workspaceActions + 1,
    );
    return const <Uri>[];
  }

  @override
  Future<String> selectWorkspaceRoot() async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: '$_platformId workspace root selection pending',
      workspaceActions: _diagnostics.value.workspaceActions + 1,
    );
    return '$_platformLabel workspace root selection pending';
  }

  @override
  Future<String> clearWorkspaceRootSelection() async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: '$_platformId default workspace pending',
      workspaceActions: _diagnostics.value.workspaceActions + 1,
    );
    return '$_platformLabel default workspace pending';
  }

  @override
  void dispose() {
    _lifecycleState.dispose();
    _diagnostics.dispose();
    unawaited(_outputController.close());
  }

  String get _platformId {
    switch (_platform) {
      case DesktopEmacsPlatform.linux:
        return 'linux';
      case DesktopEmacsPlatform.windows:
        return 'windows';
    }
  }

  String get _platformLabel {
    switch (_platform) {
      case DesktopEmacsPlatform.linux:
        return 'Linux';
      case DesktopEmacsPlatform.windows:
        return 'Windows';
    }
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
