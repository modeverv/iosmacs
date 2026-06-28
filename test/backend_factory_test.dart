import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttmacs/src/backend/android_emacs_backend.dart';
import 'package:fluttmacs/src/backend/backend_factory.dart';
import 'package:fluttmacs/src/backend/fake_emacs_backend.dart';
import 'package:fluttmacs/src/backend/native_emacs_backend.dart';
import 'package:fluttmacs/src/backend/web_wasm_emacs_backend.dart';

void main() {
  test('default backend is fake during Flutter shell development', () {
    final backend = createEmacsBackend();
    addTearDown(backend.dispose);

    expect(backend, isA<FakeEmacsBackend>());
  });

  test('explicit iOS native backend is available behind factory', () {
    final backend = createEmacsBackend(kind: BackendKind.iosNative);
    addTearDown(backend.dispose);

    expect(backend, isA<NativeEmacsBackend>());
  });

  test('explicit macOS native backend is available behind factory', () {
    final backend = createEmacsBackend(kind: BackendKind.macosNative);
    addTearDown(backend.dispose);

    expect(backend, isA<NativeEmacsBackend>());
  });

  test('explicit Web WASM backend is available behind factory', () {
    final backend = createEmacsBackend(kind: BackendKind.webWasm);
    addTearDown(backend.dispose);

    expect(backend, isA<WebWasmEmacsBackend>());
  });

  test('explicit Android backend is available behind factory', () {
    final backend = createEmacsBackend(kind: BackendKind.android);
    addTearDown(backend.dispose);

    expect(backend, isA<AndroidEmacsBackend>());
  });

  test('explicit native desktop backends are available behind factory', () {
    final linuxBackend = createEmacsBackend(kind: BackendKind.linux);
    addTearDown(linuxBackend.dispose);

    final windowsBackend = createEmacsBackend(kind: BackendKind.windows);
    addTearDown(windowsBackend.dispose);

    expect(linuxBackend, isA<NativeEmacsBackend>());
    expect(windowsBackend, isA<NativeEmacsBackend>());
  });

  test('platform default selects platform-specific backends', () {
    final iosBackend = createDefaultEmacsBackend(
      platform: TargetPlatform.iOS,
      isWeb: false,
    );
    addTearDown(iosBackend.dispose);

    final macosBackend = createDefaultEmacsBackend(
      platform: TargetPlatform.macOS,
      isWeb: false,
    );
    addTearDown(macosBackend.dispose);

    final webBackend = createDefaultEmacsBackend(
      platform: TargetPlatform.iOS,
      isWeb: true,
    );
    addTearDown(webBackend.dispose);

    final androidBackend = createDefaultEmacsBackend(
      platform: TargetPlatform.android,
      isWeb: false,
    );
    addTearDown(androidBackend.dispose);

    final linuxBackend = createDefaultEmacsBackend(
      platform: TargetPlatform.linux,
      isWeb: false,
    );
    addTearDown(linuxBackend.dispose);

    final windowsBackend = createDefaultEmacsBackend(
      platform: TargetPlatform.windows,
      isWeb: false,
    );
    addTearDown(windowsBackend.dispose);

    expect(iosBackend, isA<NativeEmacsBackend>());
    expect(macosBackend, isA<NativeEmacsBackend>());
    expect(webBackend, isA<WebWasmEmacsBackend>());
    expect(androidBackend, isA<AndroidEmacsBackend>());
    expect(linuxBackend, isA<NativeEmacsBackend>());
    expect(windowsBackend, isA<NativeEmacsBackend>());
  });

  test('backend override names select explicit backends', () {
    final fakeBackend = createDefaultEmacsBackend(
      backendOverride: 'fake',
      platform: TargetPlatform.iOS,
      isWeb: false,
    );
    addTearDown(fakeBackend.dispose);

    final webBackend = createDefaultEmacsBackend(
      backendOverride: 'web-wasm',
      platform: TargetPlatform.macOS,
      isWeb: false,
    );
    addTearDown(webBackend.dispose);

    final linuxBackend = createDefaultEmacsBackend(
      backendOverride: 'linux',
      platform: TargetPlatform.macOS,
      isWeb: false,
    );
    addTearDown(linuxBackend.dispose);

    final windowsBackend = createDefaultEmacsBackend(
      backendOverride: 'win',
      platform: TargetPlatform.macOS,
      isWeb: false,
    );
    addTearDown(windowsBackend.dispose);

    final nativeBackend = createDefaultEmacsBackend(
      backendOverride: 'native',
      platform: TargetPlatform.android,
      isWeb: false,
    );
    addTearDown(nativeBackend.dispose);

    expect(fakeBackend, isA<FakeEmacsBackend>());
    expect(webBackend, isA<WebWasmEmacsBackend>());
    expect(linuxBackend, isA<NativeEmacsBackend>());
    expect(windowsBackend, isA<NativeEmacsBackend>());
    expect(nativeBackend, isA<NativeEmacsBackend>());
  });

  test('unknown backend override falls back to platform default', () {
    final backend = createDefaultEmacsBackend(
      backendOverride: 'unknown-backend',
      platform: TargetPlatform.android,
      isWeb: false,
    );
    addTearDown(backend.dispose);

    expect(backend, isA<AndroidEmacsBackend>());
  });
}
