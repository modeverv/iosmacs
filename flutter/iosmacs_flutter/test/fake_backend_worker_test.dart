import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iosmacs_flutter/src/backend/backend_worker.dart';
import 'package:iosmacs_flutter/src/backend/fake_backend_worker.dart';
import 'package:iosmacs_flutter/src/backend/workspace_entry.dart';

void main() {
  test('worker emits lifecycle, diagnostics, and terminal output on start',
      () async {
    final worker = FakeBackendWorker();
    addTearDown(worker.dispose);

    final lifecycle = expectLater(
      worker.events,
      emitsThrough(
        isA<BackendLifecycleEvent>()
            .having((event) => event.state, 'state', 'running'),
      ),
    );
    final output = expectLater(
      worker.events,
      emitsThrough(
        isA<BackendOutputEvent>().having(
          (event) => utf8.decode(event.bytes, allowMalformed: true),
          'output',
          contains('GNU Emacs fake terminal'),
        ),
      ),
    );

    await worker.dispatch(const StartBackendCommand());

    await lifecycle;
    await output;
  });

  test('worker handles resize and input as command events', () async {
    final worker = FakeBackendWorker();
    addTearDown(worker.dispose);

    await worker.dispatch(const StartBackendCommand());

    final resize = expectLater(
      worker.events,
      emitsThrough(
        isA<BackendDiagnosticsEvent>().having(
          (event) => event.diagnostics.cols,
          'cols',
          100,
        ),
      ),
    );
    await worker.dispatch(const ResizeBackendCommand(cols: 100, rows: 30));
    await resize;

    final echo = expectLater(
      worker.events,
      emitsThrough(
        isA<BackendOutputEvent>().having(
          (event) => event.bytes,
          'bytes',
          utf8.encode('abc\r'),
        ),
      ),
    );
    await worker.dispatch(SendBytesBackendCommand(utf8.encode('abc\r')));
    await echo;
  });

  test('worker returns workspace command results', () async {
    final worker = FakeBackendWorker();
    addTearDown(worker.dispose);

    final listed = await worker.dispatch(const ListWorkspaceBackendCommand());
    expect(listed.workspaceEntries?.single.name, 'scratch.el');

    final imported = await worker.dispatch(
      ImportWorkspaceBackendCommand(<Uri>[Uri(path: '/tmp/a.el')]),
    );
    expect(imported.importedCount, 1);

    final listedAfterImport =
        await worker.dispatch(const ListWorkspaceBackendCommand());
    expect(
      listedAfterImport.workspaceEntries
          ?.map((WorkspaceEntry entry) => entry.name),
      containsAll(<String>['scratch.el', 'a.el']),
    );

    final exported =
        await worker.dispatch(const ExportWorkspaceBackendCommand());
    expect(
      exported.exportedUris?.map((Uri uri) => uri.path),
      containsAll(<String>['/workspace/scratch.el', '/workspace/a.el']),
    );
  });
}
