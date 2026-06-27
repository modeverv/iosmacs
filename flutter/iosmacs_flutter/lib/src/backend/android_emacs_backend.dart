import 'package:flutter/foundation.dart';

import 'backend_capabilities.dart';
import 'backend_diagnostics.dart';
import 'emacs_backend.dart';
import 'native_emacs_backend.dart';
import 'workspace_entry.dart';

class AndroidEmacsBackend implements EmacsBackend {
  AndroidEmacsBackend({NativeEmacsBackend? nativeBackend})
      : _nativeBackend = nativeBackend ??
            NativeEmacsBackend(
              initialDiagnosticsMessage: 'android native backend channel ready',
            );

  final NativeEmacsBackend _nativeBackend;

  @override
  BackendCapabilities get capabilities => const BackendCapabilities(
        id: 'android-native-channel',
        displayName: 'Android native channel backend',
        supportedFeatures: <String>[
          'Android backend selection',
          'Android SDK debug build surface',
          'Flutter MethodChannel transport',
          'Android GNU Emacs NW PTY terminal route',
          'Android native bridge diagnostics',
          'Android app-private workspace list/import/export',
          'Android content URI workspace import',
          'Android document-provider content URI export',
          'Android user-facing document export picker flow',
          'Android document-tree workspace exchange folder selection',
          'Android workspace exchange folder import',
          'Android workspace exchange folder refresh sync',
          'Android workspace exchange folder export',
          'Android INTERNET permission for Emacs network processes',
          'Android keyboard/IME runtime proof',
          'Android Japanese committed UTF-8 runtime proof',
          'Android xterm pointer/mouse runtime proof',
          'Android Ctrl/Meta modifier key row for terminal input',
          'Android inline terminal input with IME and keyboard support',
          'Android NDK GNU Emacs runtime artifact packaging',
          'Android GNU Emacs Java bridge packaging',
          'terminal input and resize channel calls',
          'terminal byte stream from Android native bridge',
          'deterministic unsupported diagnostics',
        ],
        unsupportedFeatures: <String>[
          'official --with-android interactive terminal bridge',
          'Android fallback diagnostic frame renderer is diagnostic-only',
        ],
      );

  @override
  Stream<List<int>> get outputStream => _nativeBackend.outputStream;

  @override
  ValueListenable<String> get lifecycleState => _nativeBackend.lifecycleState;

  @override
  ValueListenable<BackendDiagnostics> get diagnostics =>
      _nativeBackend.diagnostics;

  @override
  Future<void> start() => _nativeBackend.start();

  @override
  Future<void> stop() => _nativeBackend.stop();

  @override
  Future<void> resetOrRedraw() => _nativeBackend.resetOrRedraw();

  @override
  Future<void> sendBytes(List<int> bytes) => _nativeBackend.sendBytes(bytes);

  @override
  Future<bool> pasteSystemClipboard() => _nativeBackend.pasteSystemClipboard();

  @override
  Future<void> resize({required int cols, required int rows}) =>
      _nativeBackend.resize(cols: cols, rows: rows);

  @override
  Future<List<WorkspaceEntry>> listWorkspace() =>
      _nativeBackend.listWorkspace();

  @override
  Future<int> importToWorkspace(List<Uri> uris) =>
      _nativeBackend.importToWorkspace(uris);

  @override
  Future<List<Uri>> exportWorkspaceSelection() =>
      _nativeBackend.exportWorkspaceSelection();

  @override
  Future<String> selectWorkspaceRoot() => _nativeBackend.selectWorkspaceRoot();

  @override
  Future<String> clearWorkspaceRootSelection() =>
      _nativeBackend.clearWorkspaceRootSelection();

  @override
  void dispose() {
    _nativeBackend.dispose();
  }
}
