import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttmacs/src/backend/desktop_emacs_backend.dart';

void main() {
  test('reports Linux placeholder capabilities explicitly', () {
    final backend = DesktopEmacsBackend(platform: DesktopEmacsPlatform.linux);
    addTearDown(backend.dispose);

    expect(backend.capabilities.id, 'linux-placeholder');
    expect(
      backend.capabilities.supportedFeatures,
      contains('Linux backend selection'),
    );
    expect(
      backend.capabilities.unsupportedFeatures,
      contains('Linux GNU Emacs process/PTY bridge'),
    );
    expect(
      backend.capabilities.unsupportedFeatures,
      contains('Linux packaged Emacs runtime resources'),
    );
  });

  test('reports Windows placeholder capabilities explicitly', () {
    final backend = DesktopEmacsBackend(platform: DesktopEmacsPlatform.windows);
    addTearDown(backend.dispose);

    expect(backend.capabilities.id, 'windows-placeholder');
    expect(
      backend.capabilities.supportedFeatures,
      contains('Windows backend selection'),
    );
    expect(
      backend.capabilities.unsupportedFeatures,
      contains('Windows GNU Emacs process/PTY bridge'),
    );
    expect(
      backend.capabilities.unsupportedFeatures,
      contains('Windows native file picker import/export proof'),
    );
  });

  test('start emits desktop route diagnostics', () async {
    final backend = DesktopEmacsBackend(platform: DesktopEmacsPlatform.linux);
    addTearDown(backend.dispose);

    final output = backend.outputStream.map(
      (List<int> bytes) => utf8.decode(bytes, allowMalformed: true),
    );
    final firstOutput = expectLater(
      output,
      emitsThrough(contains('Flutter Linux backend selected')),
    );

    await backend.start();
    await firstOutput;

    expect(backend.lifecycleState.value, 'unsupported');
    expect(backend.diagnostics.value.message,
        'linux desktop backend route pending');
    expect(backend.diagnostics.value.outputBytes, greaterThan(0));
  });

  test('workspace placeholders are desktop safe', () async {
    final backend = DesktopEmacsBackend(platform: DesktopEmacsPlatform.windows);
    addTearDown(backend.dispose);

    final entries = await backend.listWorkspace();
    expect(entries.single.path, 'windows://iosmacs/workspace-placeholder');

    final importedCount = await backend.importToWorkspace(<Uri>[
      Uri.parse('file:///tmp/scratch.el'),
    ]);
    expect(importedCount, 0);

    final exported = await backend.exportWorkspaceSelection();
    expect(exported, isEmpty);
    expect(backend.diagnostics.value.workspaceActions, 3);
  });
}
