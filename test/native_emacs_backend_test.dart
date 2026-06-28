import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttmacs/src/backend/native_emacs_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reports native channel backend capabilities explicitly', () {
    final backend = NativeEmacsBackend();
    addTearDown(backend.dispose);

    expect(backend.capabilities.id, 'platform-native-channel');
    expect(
      backend.capabilities.supportedFeatures,
      contains('Flutter MethodChannel transport'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('iOS simulator GNU Emacs core startup'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('macOS native channel diagnostics'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('macOS child-process GNU Emacs session'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('bundled macOS GNU Emacs runtime packaging'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('macOS direct PTY resize/ioctl bridge'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('terminal byte stream from native Emacs'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('app-container workspace list/import/export'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('iOS security-scoped /home/user folder selection'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('iOS URLSession network bridge for Emacs url.el'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('macOS Application Support workspace list/import/export'),
    );
    expect(
      backend.capabilities.unsupportedFeatures,
      contains('physical-device GNU Emacs core startup'),
    );
  });

  test('start drains successful native output into stream', () async {
    const channel = MethodChannel(NativeEmacsBackend.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var didDrain = false;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'start':
          return <String, Object>{'lifecycleState': 'diagnostic running'};
        case 'drainOutput':
          if (didDrain) {
            return Uint8List(0);
          }
          didDrain = true;
          return Uint8List.fromList(
              'iosmacs Flutter native bridge\r\n'.codeUnits);
        default:
          return null;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final backend = NativeEmacsBackend(channel: channel);
    addTearDown(backend.dispose);

    final output = expectLater(
      backend.outputStream,
      emits(containsAll('iosmacs Flutter native bridge'.codeUnits)),
    );

    await backend.start();
    await output;

    expect(backend.lifecycleState.value, 'running');
    expect(backend.diagnostics.value.message, 'diagnostic running');
    expect(backend.diagnostics.value.outputBytes, greaterThan(0));
  });

  test('start drains multiple native output chunks into one stream event',
      () async {
    const channel = MethodChannel(NativeEmacsBackend.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final chunks = <Uint8List>[
      Uint8List.fromList('first '.codeUnits),
      Uint8List.fromList('second'.codeUnits),
      Uint8List(0),
    ];
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'start':
          return <String, Object>{'lifecycleState': 'diagnostic running'};
        case 'drainOutput':
          return chunks.removeAt(0);
        default:
          return null;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final backend = NativeEmacsBackend(channel: channel);
    addTearDown(backend.dispose);

    final output = expectLater(
      backend.outputStream,
      emits('first second'.codeUnits),
    );

    await backend.start();
    await output;

    expect(backend.diagnostics.value.outputBytes, 'first second'.length);
  });

  test('sendBytes does not wait for native output drain to finish', () async {
    const channel = MethodChannel(NativeEmacsBackend.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final drainCompleter = Completer<Uint8List>();
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'sendBytes':
          return <String, Object>{'lifecycleState': 'diagnostic running'};
        case 'drainOutput':
          return drainCompleter.future;
        default:
          return null;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final backend = NativeEmacsBackend(channel: channel);
    addTearDown(backend.dispose);

    await backend.sendBytes(<int>[65, 66, 67]);

    expect(backend.diagnostics.value.inputBytes, 3);
    expect(drainCompleter.isCompleted, isFalse);
    drainCompleter.complete(Uint8List(0));
  });

  test('native status payload updates diagnostics geometry', () async {
    const channel = MethodChannel(NativeEmacsBackend.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'start':
          return <String, Object>{
            'lifecycleState': 'iosmacs macOS native bridge: process probe ok',
            'cols': 120,
            'rows': 40,
          };
        case 'drainOutput':
          return Uint8List(0);
        default:
          return null;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final backend = NativeEmacsBackend(channel: channel);
    addTearDown(backend.dispose);

    await backend.start();

    expect(backend.lifecycleState.value, 'running');
    expect(
      backend.diagnostics.value.message,
      'iosmacs macOS native bridge: process probe ok',
    );
    expect(backend.diagnostics.value.cols, 120);
    expect(backend.diagnostics.value.rows, 40);
  });

  test('start records unsupported diagnostics from native channel', () async {
    const channel = MethodChannel(NativeEmacsBackend.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      throw PlatformException(
        code: 'native_emacs_not_connected',
        message: 'existing iosmacs native Emacs bridge is not connected yet',
        details: <String, String>{'method': call.method},
      );
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final backend = NativeEmacsBackend(channel: channel);
    addTearDown(backend.dispose);

    await backend.start();

    expect(backend.lifecycleState.value, 'unsupported');
    expect(
      backend.diagnostics.value.message,
      contains('native backend unsupported: start'),
    );
    expect(
      backend.diagnostics.value.message,
      contains('existing iosmacs native Emacs bridge is not connected yet'),
    );
  });

  test('workspace calls parse native channel results', () async {
    const channel = MethodChannel(NativeEmacsBackend.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'listWorkspace':
          return <Map<String, Object>>[
            <String, Object>{
              'name': 'scratch.el',
              'path': '/Documents/home/scratch.el',
              'isDirectory': false,
              'sizeBytes': 42,
            },
          ];
        case 'importWorkspace':
          expect(call.arguments, isA<Map<Object?, Object?>>());
          return 2;
        case 'exportWorkspace':
          return <String>[
            'file:///Documents/home/scratch.el',
            'file:///Documents/home/notes',
          ];
        default:
          return <String, Object>{'lifecycleState': 'ok'};
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final backend = NativeEmacsBackend(channel: channel);
    addTearDown(backend.dispose);

    final entries = await backend.listWorkspace();
    expect(entries.single.name, 'scratch.el');
    expect(entries.single.path, '/Documents/home/scratch.el');
    expect(entries.single.sizeBytes, 42);

    final importedCount = await backend.importToWorkspace(
      <Uri>[Uri.file('/tmp/a.txt'), Uri.file('/tmp/b.txt')],
    );
    expect(importedCount, 2);

    final exported = await backend.exportWorkspaceSelection();
    expect(exported.map((Uri uri) => uri.path), <String>[
      '/Documents/home/scratch.el',
      '/Documents/home/notes',
    ]);
    expect(backend.diagnostics.value.workspaceActions, 3);
    expect(
      backend.diagnostics.value.message,
      'native workspace exported 2 item(s)',
    );
  });

  test('workspace root selection calls native channel', () async {
    const channel = MethodChannel(NativeEmacsBackend.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'selectWorkspaceRoot':
          return <String, Object>{
            'message': 'Workspace saved for next launch',
            'workspaceRootPath': '/iCloud/Documents/project',
            'requiresRestart': true,
          };
        case 'clearWorkspaceRoot':
          return <String, Object>{
            'message': 'Default workspace set',
            'workspaceRootPath': '/Documents/home/user',
            'requiresRestart': false,
          };
        default:
          return null;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final backend = NativeEmacsBackend(channel: channel);
    addTearDown(backend.dispose);

    expect(
      await backend.selectWorkspaceRoot(),
      'Workspace saved for next launch',
    );
    expect(
        await backend.clearWorkspaceRootSelection(), 'Default workspace set');
    expect(calls, <String>['selectWorkspaceRoot', 'clearWorkspaceRoot']);
    expect(backend.diagnostics.value.workspaceActions, 2);
    expect(backend.diagnostics.value.message, 'Default workspace set');
  });
}
