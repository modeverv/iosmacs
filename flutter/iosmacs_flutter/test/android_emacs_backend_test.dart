import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iosmacs_flutter/src/backend/android_emacs_backend.dart';

void main() {
  test('reports Android placeholder capabilities explicitly', () {
    final backend = AndroidEmacsBackend();
    addTearDown(backend.dispose);

    expect(backend.capabilities.id, 'android-placeholder');
    expect(
      backend.capabilities.supportedFeatures,
      contains('Android backend selection'),
    );
    expect(
      backend.capabilities.unsupportedFeatures,
      contains('Android NDK GNU Emacs core build'),
    );
    expect(
      backend.capabilities.unsupportedFeatures,
      contains('Android document provider import/export proof'),
    );
  });

  test('start emits Android route diagnostics', () async {
    final backend = AndroidEmacsBackend();
    addTearDown(backend.dispose);

    final output = backend.outputStream.map(
      (List<int> bytes) => utf8.decode(bytes, allowMalformed: true),
    );
    final firstOutput = expectLater(
      output,
      emitsThrough(contains('Flutter Android backend selected')),
    );

    await backend.start();
    await firstOutput;

    expect(backend.lifecycleState.value, 'unsupported');
    expect(
      backend.diagnostics.value.message,
      'android native backend route pending',
    );
    expect(backend.diagnostics.value.outputBytes, greaterThan(0));
  });

  test('workspace placeholders are Android safe', () async {
    final backend = AndroidEmacsBackend();
    addTearDown(backend.dispose);

    final entries = await backend.listWorkspace();
    expect(entries.single.path, 'android://iosmacs/workspace-placeholder');

    final importedCount = await backend.importToWorkspace(<Uri>[
      Uri.parse('content://iosmacs/scratch.el'),
    ]);
    expect(importedCount, 0);

    final exported = await backend.exportWorkspaceSelection();
    expect(exported, isEmpty);
    expect(backend.diagnostics.value.workspaceActions, 3);
  });
}
