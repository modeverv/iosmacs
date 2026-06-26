import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'backend_capabilities.dart';
import 'backend_diagnostics.dart';
import 'emacs_backend.dart';
import 'workspace_entry.dart';

class WebWasmEmacsBackend implements EmacsBackend {
  final StreamController<List<int>> _outputController =
      StreamController<List<int>>.broadcast();
  final ValueNotifier<String> _lifecycleState = ValueNotifier<String>('idle');
  final ValueNotifier<BackendDiagnostics> _diagnostics =
      ValueNotifier<BackendDiagnostics>(
    const BackendDiagnostics(
      message: 'web wasm backend pending',
      cols: 80,
      rows: 24,
      inputBytes: 0,
      outputBytes: 0,
      workspaceActions: 0,
    ),
  );

  @override
  BackendCapabilities get capabilities => const BackendCapabilities(
        id: 'web-wasm-placeholder',
        displayName: 'Web WASM backend placeholder',
        supportedFeatures: <String>[
          'Flutter Web backend selection',
          'wasmacs/WASM route visibility',
          'deterministic unsupported diagnostics',
          'browser-safe workspace placeholders',
        ],
        unsupportedFeatures: <String>[
          'native Dart FFI',
          'Flutter MethodChannel native Emacs bridge',
          'connected wasmacs WebAssembly runtime',
          'browser file import/export proof',
          'terminal byte stream from WebAssembly Emacs',
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
    _write('iosmacs Flutter Web backend selected\r\n');
    _write(
        'Connect this surface to the separate wasmacs/WASM backend route.\r\n');
    _setMessage('web wasm backend route pending');
  }

  @override
  Future<void> stop() async {
    _lifecycleState.value = 'stopped';
    _setMessage('web wasm backend stopped');
  }

  @override
  Future<void> resetOrRedraw() async {
    _write('\u{000C}iosmacs Flutter Web backend placeholder\r\n');
    _setMessage('web wasm redraw placeholder');
  }

  @override
  Future<void> sendBytes(List<int> bytes) async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: 'web wasm input ignored until WASM runtime is connected',
      inputBytes: _diagnostics.value.inputBytes + bytes.length,
    );
  }

  @override
  Future<void> resize({required int cols, required int rows}) async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: 'web wasm resize recorded',
      cols: cols,
      rows: rows,
    );
  }

  @override
  Future<List<WorkspaceEntry>> listWorkspace() async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: 'web workspace placeholder listed',
      workspaceActions: _diagnostics.value.workspaceActions + 1,
    );
    return const <WorkspaceEntry>[
      WorkspaceEntry(
        name: 'wasmacs-placeholder',
        path: 'browser://wasmacs-placeholder',
        isDirectory: true,
        sizeBytes: 0,
      ),
    ];
  }

  @override
  Future<int> importToWorkspace(List<Uri> uris) async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: 'web workspace import pending for ${uris.length} item(s)',
      workspaceActions: _diagnostics.value.workspaceActions + 1,
    );
    return 0;
  }

  @override
  Future<List<Uri>> exportWorkspaceSelection() async {
    _diagnostics.value = _diagnostics.value.copyWith(
      message: 'web workspace export pending',
      workspaceActions: _diagnostics.value.workspaceActions + 1,
    );
    return const <Uri>[];
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
