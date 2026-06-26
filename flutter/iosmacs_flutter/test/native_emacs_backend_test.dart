import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iosmacs_flutter/src/backend/native_emacs_backend.dart';

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
      contains('macOS Emacs process probe'),
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
      contains('macOS sandbox workspace list/import/export'),
    );
    expect(
      backend.capabilities.unsupportedFeatures,
      contains('physical-device GNU Emacs core startup'),
    );
    expect(
      backend.capabilities.unsupportedFeatures,
      contains('macOS interactive PTY GNU Emacs session'),
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
}
