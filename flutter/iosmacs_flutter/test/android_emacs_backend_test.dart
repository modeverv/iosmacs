import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iosmacs_flutter/src/backend/android_emacs_backend.dart';
import 'package:iosmacs_flutter/src/backend/native_emacs_backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('reports Android native channel capabilities explicitly', () {
    final backend = AndroidEmacsBackend();
    addTearDown(backend.dispose);

    expect(backend.capabilities.id, 'android-native-channel');
    expect(
      backend.capabilities.supportedFeatures,
      contains('Android backend selection'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('Flutter MethodChannel transport'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('Android GNU Emacs NW PTY terminal route'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('Android fallback diagnostic frame renderer'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('Android app-private workspace list/import/export'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('Android document-provider content URI export'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('Android keyboard/IME runtime proof'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('Android NDK GNU Emacs runtime artifact packaging'),
    );
    expect(
      backend.capabilities.supportedFeatures,
      contains('Android GNU Emacs Java bridge packaging'),
    );
    expect(
      backend.capabilities.unsupportedFeatures,
      contains('official --with-android interactive terminal bridge'),
    );
    expect(
      backend.capabilities.unsupportedFeatures,
      contains('Android user-facing document export picker flow'),
    );
  });

  test('start emits Android native channel diagnostics', () async {
    const channel = MethodChannel(NativeEmacsBackend.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var didDrain = false;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'start':
          return <String, Object>{
            'lifecycleState':
                'iosmacs Android native bridge: fallback diagnostic frame running',
            'cols': 80,
            'rows': 24,
          };
        case 'drainOutput':
          if (didDrain) {
            return Uint8List(0);
          }
          didDrain = true;
          return Uint8List.fromList(
            'GNU Emacs 30.2 Android terminal frame\r\n'
                    'Buffer: *scratch*   Mode: Lisp Interaction\r\n'
                    '-UUU:----F1  *scratch*   Lisp Interaction\r\n'
                    '* '
                .codeUnits,
          );
        default:
          return null;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final backend = AndroidEmacsBackend(
      nativeBackend: NativeEmacsBackend(
        channel: channel,
        initialDiagnosticsMessage: 'android native backend channel ready',
      ),
    );
    addTearDown(backend.dispose);

    final output = backend.outputStream.map(
      (List<int> bytes) => utf8.decode(bytes, allowMalformed: true),
    );
    final firstOutput = expectLater(
      output,
      emitsThrough(contains('Buffer: *scratch*')),
    );

    await backend.start();
    await firstOutput;

    expect(backend.lifecycleState.value, 'running');
    expect(
      backend.diagnostics.value.message,
      'iosmacs Android native bridge: fallback diagnostic frame running',
    );
    expect(backend.diagnostics.value.outputBytes, greaterThan(0));
  });

  test('sendBytes drains Android diagnostic terminal echo', () async {
    const channel = MethodChannel(NativeEmacsBackend.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var didSend = false;
    var didDrainScratch = false;
    var didDrainInput = false;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'start':
          return <String, Object>{
            'lifecycleState':
                'iosmacs Android native bridge: fallback diagnostic frame running',
            'cols': 80,
            'rows': 24,
          };
        case 'sendBytes':
          final arguments = call.arguments as Map<Object?, Object?>;
          final bytes = arguments['bytes'] as Uint8List;
          expect(utf8.decode(bytes), 'android input\r');
          didSend = true;
          return <String, Object>{
            'lifecycleState':
                'iosmacs Android native bridge: accepted ${bytes.length} byte(s)',
            'cols': 80,
            'rows': 24,
            'inputBytes': bytes.length,
          };
        case 'drainOutput':
          if (!didDrainScratch) {
            didDrainScratch = true;
            return Uint8List.fromList(
              'Buffer: *scratch*   Mode: Lisp Interaction\r\n* '.codeUnits,
            );
          }
          if (didSend && !didDrainInput) {
            didDrainInput = true;
            return Uint8List.fromList('android input\r\n* '.codeUnits);
          }
          return Uint8List(0);
        default:
          return null;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final backend = AndroidEmacsBackend(
      nativeBackend: NativeEmacsBackend(channel: channel),
    );
    addTearDown(backend.dispose);

    final output = backend.outputStream.map(
      (List<int> bytes) => utf8.decode(bytes, allowMalformed: true),
    );
    final firstOutput = expectLater(
      output,
      emitsThrough(contains('android input')),
    );

    await backend.start();
    await backend.sendBytes(utf8.encode('android input\r'));
    await firstOutput;

    expect(backend.diagnostics.value.inputBytes, 'android input\r'.length);
    expect(
      backend.diagnostics.value.message,
      'sent input bytes to native backend',
    );
  });

  test('workspace calls use Android native channel results', () async {
    const channel = MethodChannel(NativeEmacsBackend.channelName);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      switch (call.method) {
        case 'listWorkspace':
          return <Map<String, Object>>[
            <String, Object>{
              'name': 'scratch.el',
              'path': '/data/user/0/com.example.iosmacs_flutter/files/'
                  'iosmacs/workspace/scratch.el',
              'isDirectory': false,
              'sizeBytes': 12,
            },
          ];
        case 'importWorkspace':
          return 1;
        case 'exportWorkspace':
          return <String>[
            'content://com.example.iosmacs_flutter.workspace_export/'
                'exports/scratch.el',
          ];
        default:
          return null;
      }
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final backend = AndroidEmacsBackend(
      nativeBackend: NativeEmacsBackend(channel: channel),
    );
    addTearDown(backend.dispose);

    final entries = await backend.listWorkspace();
    expect(entries.single.name, 'scratch.el');
    expect(entries.single.path, contains('/iosmacs/workspace/scratch.el'));

    final importedCount = await backend.importToWorkspace(<Uri>[
      Uri.parse('content://iosmacs/scratch.el'),
    ]);
    expect(importedCount, 1);

    final exported = await backend.exportWorkspaceSelection();
    expect(exported.single.scheme, 'content');
    expect(exported.single.authority, contains('workspace_export'));
    expect(backend.diagnostics.value.workspaceActions, 3);
  });
}
