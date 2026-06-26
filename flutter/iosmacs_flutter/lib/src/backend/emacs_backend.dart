import 'package:flutter/foundation.dart';

import 'backend_capabilities.dart';
import 'backend_diagnostics.dart';
import 'workspace_entry.dart';

abstract interface class EmacsBackend {
  Stream<List<int>> get outputStream;
  ValueListenable<String> get lifecycleState;
  ValueListenable<BackendDiagnostics> get diagnostics;
  BackendCapabilities get capabilities;

  Future<void> start();
  Future<void> stop();
  Future<void> resetOrRedraw();
  Future<void> sendBytes(List<int> bytes);
  Future<bool> pasteSystemClipboard();
  Future<void> resize({required int cols, required int rows});

  Future<List<WorkspaceEntry>> listWorkspace();
  Future<int> importToWorkspace(List<Uri> uris);
  Future<List<Uri>> exportWorkspaceSelection();
  Future<String> selectWorkspaceRoot();
  Future<String> clearWorkspaceRootSelection();

  void dispose();
}
