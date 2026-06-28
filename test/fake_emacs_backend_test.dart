import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:fluttmacs/src/backend/fake_emacs_backend.dart';
import 'package:fluttmacs/src/backend/workspace_entry.dart';

void main() {
  test('reports fake backend capabilities explicitly', () {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    expect(backend.capabilities.id, 'fake');
    expect(
      backend.capabilities.supportedFeatures,
      contains('deterministic terminal output'),
    );
    expect(
      backend.capabilities.unsupportedFeatures,
      contains('native GNU Emacs runtime'),
    );
  });

  test('start emits deterministic fake terminal output', () async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    final output = backend.outputStream
        .map((List<int> bytes) => utf8.decode(bytes, allowMalformed: true));

    final firstChunk = expectLater(
      output,
      emitsThrough(contains('GNU Emacs fake terminal')),
    );

    await backend.start();
    await firstChunk;
    expect(backend.lifecycleState.value, 'running');
  });

  test('sendBytes echoes input while running', () async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await backend.start();

    final inputEcho = expectLater(
      backend.outputStream,
      emitsThrough(utf8.encode('abc\r')),
    );

    await backend.sendBytes(utf8.encode('abc\r'));
    await inputEcho;
    expect(backend.diagnostics.value.message, 'received 4 input byte(s)');
    expect(backend.diagnostics.value.inputBytes, 4);
  });

  test('resize updates diagnostics and reports output', () async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await backend.start();

    final resizeOutput = expectLater(
      backend.outputStream.map(
        (List<int> bytes) => utf8.decode(bytes, allowMalformed: true),
      ),
      emitsThrough(contains('resize 100 x 30')),
    );

    await backend.resize(cols: 100, rows: 30);
    await resizeOutput;
    expect(backend.diagnostics.value.message, 'resize reported');
    expect(backend.diagnostics.value.cols, 100);
    expect(backend.diagnostics.value.rows, 30);
  });

  test('workspace placeholders are deterministic', () async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    final entries = await backend.listWorkspace();
    expect(entries.single.name, 'scratch.el');

    final imported = await backend.importToWorkspace(<Uri>[
      Uri(path: '/tmp/a.el'),
      Uri(path: '/tmp/b.el'),
    ]);
    expect(imported, 2);
    expect(backend.diagnostics.value.workspaceActions, 1);
    final entriesAfterImport = await backend.listWorkspace();
    expect(
      entriesAfterImport.map((WorkspaceEntry entry) => entry.name),
      containsAll(<String>['scratch.el', 'a.el', 'b.el']),
    );

    final exported = await backend.exportWorkspaceSelection();
    expect(
      exported.map((Uri uri) => uri.path),
      containsAll(<String>[
        '/workspace/scratch.el',
        '/workspace/a.el',
        '/workspace/b.el',
      ]),
    );
    expect(backend.diagnostics.value.workspaceActions, 2);
  });
}
