import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttmacs/src/backend/web_wasm_emacs_backend.dart';

void main() {
  test('reports Web WASM placeholder capabilities explicitly', () {
    final backend = WebWasmEmacsBackend();
    addTearDown(backend.dispose);

    expect(backend.capabilities.id, 'web-wasm-placeholder');
    expect(
      backend.capabilities.supportedFeatures,
      contains('wasmacs/WASM route visibility'),
    );
    expect(
      backend.capabilities.unsupportedFeatures,
      contains('connected wasmacs WebAssembly runtime'),
    );
    expect(
      backend.capabilities.unsupportedFeatures,
      contains('native Dart FFI'),
    );
  });

  test('start emits Web route diagnostics', () async {
    final backend = WebWasmEmacsBackend();
    addTearDown(backend.dispose);

    final output = backend.outputStream.map(
      (List<int> bytes) => utf8.decode(bytes, allowMalformed: true),
    );
    final firstOutput = expectLater(
      output,
      emitsThrough(contains('Flutter Web backend selected')),
    );

    await backend.start();
    await firstOutput;

    expect(backend.lifecycleState.value, 'unsupported');
    expect(backend.diagnostics.value.message, 'web wasm backend route pending');
    expect(backend.diagnostics.value.outputBytes, greaterThan(0));
  });

  test('workspace placeholders are browser safe', () async {
    final backend = WebWasmEmacsBackend();
    addTearDown(backend.dispose);

    final entries = await backend.listWorkspace();
    expect(entries.single.path, 'browser://wasmacs-placeholder');

    final importedCount = await backend.importToWorkspace(<Uri>[
      Uri.parse('browser://upload/scratch.el'),
    ]);
    expect(importedCount, 0);

    final exported = await backend.exportWorkspaceSelection();
    expect(exported, isEmpty);
    expect(backend.diagnostics.value.workspaceActions, 3);
  });
}
