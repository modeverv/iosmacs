import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iosmacs_flutter/src/backend/backend_capabilities.dart';
import 'package:iosmacs_flutter/src/backend/backend_diagnostics.dart';
import 'package:iosmacs_flutter/src/backend/emacs_backend.dart';
import 'package:iosmacs_flutter/src/backend/workspace_entry.dart';
import 'package:iosmacs_flutter/src/ui/terminal_input_bridge.dart';

void main() {
  test('forwards xterm output strings as raw UTF-8 bytes', () async {
    final backend = _RecordingBackend();
    final bridge = TerminalInputBridge(backend);

    await bridge.sendTerminalOutput('\x1b[A');
    await bridge.sendTerminalOutput('a');

    expect(backend.sentBytes, <List<int>>[
      <int>[0x1b, 0x5b, 0x41],
      <int>[0x61],
    ]);
  });

  test('forwards IME-committed text as UTF-8 bytes followed by carriage return',
      () async {
    final backend = _RecordingBackend();
    final bridge = TerminalInputBridge(backend);

    await bridge.submitCommittedText('日本語');

    expect(backend.sentBytes, <List<int>>[
      utf8.encode('日本語\r'),
    ]);
  });

  test('normalizes committed multiline text to terminal carriage returns',
      () async {
    final backend = _RecordingBackend();
    final bridge = TerminalInputBridge(backend);

    await bridge.submitCommittedText("(require 'url)\n\n(message \"ok\")");

    expect(backend.sentBytes, <List<int>>[
      utf8.encode("(require 'url)\r\r(message \"ok\")\r"),
    ]);
  });

  test('drops duplicate terminal IME chunks without filtering ASCII input',
      () async {
    final backend = _RecordingBackend();
    var now = DateTime(2026, 6, 26, 19, 20);
    final bridge = TerminalInputBridge(backend, now: () => now);

    await bridge.sendTerminalOutput('日本語');
    now = now.add(const Duration(milliseconds: 100));
    await bridge.sendTerminalOutput('日本語');
    now = now.add(const Duration(milliseconds: 100));
    await bridge.sendTerminalOutput('a');
    now = now.add(const Duration(milliseconds: 100));
    await bridge.sendTerminalOutput('a');

    expect(backend.sentBytes, <List<int>>[
      utf8.encode('日本語'),
      <int>[0x61],
      <int>[0x61],
    ]);
  });

  test('allows repeated terminal IME text outside the duplicate window',
      () async {
    final backend = _RecordingBackend();
    var now = DateTime(2026, 6, 26, 19, 21);
    final bridge = TerminalInputBridge(backend, now: () => now);

    await bridge.sendTerminalOutput('日本語');
    now = now.add(const Duration(seconds: 1));
    await bridge.sendTerminalOutput('日本語');

    expect(backend.sentBytes, <List<int>>[
      utf8.encode('日本語'),
      utf8.encode('日本語'),
    ]);
  });

  test('forwards pasted text as normalized UTF-8 bytes', () async {
    final backend = _RecordingBackend();
    final bridge = TerminalInputBridge(backend);

    await bridge.pasteText('clip 日本語');

    expect(backend.sentBytes, <List<int>>[
      utf8.encode('clip 日本語'),
    ]);
  });

  test('normalizes pasted multiline text to terminal carriage returns',
      () async {
    final backend = _RecordingBackend();
    final bridge = TerminalInputBridge(backend);

    await bridge.pasteText("(require 'url)\r\n\n(message \"ok\")");

    expect(backend.sentBytes, <List<int>>[
      utf8.encode("(require 'url)\r\r(message \"ok\")"),
    ]);
  });

  test('does not send bytes for empty terminal, committed, or pasted input',
      () async {
    final backend = _RecordingBackend();
    final bridge = TerminalInputBridge(backend);

    await bridge.sendTerminalOutput('');
    await bridge.submitCommittedText('');
    await bridge.pasteText('');

    expect(backend.sentBytes, isEmpty);
  });
}

class _RecordingBackend implements EmacsBackend {
  final List<List<int>> sentBytes = <List<int>>[];
  final StreamController<List<int>> _outputController =
      StreamController<List<int>>.broadcast();
  final ValueNotifier<String> _lifecycleState = ValueNotifier<String>('idle');
  final ValueNotifier<BackendDiagnostics> _diagnostics =
      ValueNotifier<BackendDiagnostics>(
    const BackendDiagnostics.initial(),
  );

  @override
  BackendCapabilities get capabilities => const BackendCapabilities(
        id: 'recording',
        displayName: 'Recording backend',
        supportedFeatures: <String>['record sent bytes'],
        unsupportedFeatures: <String>[],
      );

  @override
  Stream<List<int>> get outputStream => _outputController.stream;

  @override
  ValueListenable<String> get lifecycleState => _lifecycleState;

  @override
  ValueListenable<BackendDiagnostics> get diagnostics => _diagnostics;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> resetOrRedraw() async {}

  @override
  Future<void> sendBytes(List<int> bytes) async {
    sentBytes.add(List<int>.from(bytes));
  }

  @override
  Future<bool> pasteSystemClipboard() async => false;

  @override
  Future<void> resize({required int cols, required int rows}) async {}

  @override
  Future<List<WorkspaceEntry>> listWorkspace() async => <WorkspaceEntry>[];

  @override
  Future<int> importToWorkspace(List<Uri> uris) async => 0;

  @override
  Future<List<Uri>> exportWorkspaceSelection() async => <Uri>[];

  @override
  Future<String> selectWorkspaceRoot() async => 'recording workspace selected';

  @override
  Future<String> clearWorkspaceRootSelection() async =>
      'recording default workspace set';

  @override
  void dispose() {
    _outputController.close();
    _lifecycleState.dispose();
    _diagnostics.dispose();
  }
}
