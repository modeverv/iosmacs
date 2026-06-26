import 'package:flutter/foundation.dart';

import 'android_emacs_backend.dart';
import 'desktop_emacs_backend.dart';
import 'emacs_backend.dart';
import 'fake_emacs_backend.dart';
import 'native_emacs_backend.dart';
import 'web_wasm_emacs_backend.dart';

enum BackendKind {
  fake,
  iosNative,
  macosNative,
  webWasm,
  android,
  linux,
  windows,
}

EmacsBackend createEmacsBackend({BackendKind kind = BackendKind.fake}) {
  switch (kind) {
    case BackendKind.fake:
      return FakeEmacsBackend();
    case BackendKind.iosNative:
      return NativeEmacsBackend();
    case BackendKind.macosNative:
      return NativeEmacsBackend();
    case BackendKind.webWasm:
      return WebWasmEmacsBackend();
    case BackendKind.android:
      return AndroidEmacsBackend();
    case BackendKind.linux:
      return DesktopEmacsBackend(platform: DesktopEmacsPlatform.linux);
    case BackendKind.windows:
      return DesktopEmacsBackend(platform: DesktopEmacsPlatform.windows);
  }
}

EmacsBackend createDefaultEmacsBackend({
  TargetPlatform? platform,
  bool isWeb = kIsWeb,
  String backendOverride = '',
}) {
  final overrideKind = backendKindFromName(backendOverride);
  if (overrideKind != null) {
    return createEmacsBackend(kind: overrideKind);
  }

  if (isWeb) {
    return createEmacsBackend(kind: BackendKind.webWasm);
  }
  final targetPlatform = platform ?? defaultTargetPlatform;
  if (!isWeb && targetPlatform == TargetPlatform.iOS) {
    return createEmacsBackend(kind: BackendKind.iosNative);
  }
  if (!isWeb && targetPlatform == TargetPlatform.macOS) {
    return createEmacsBackend(kind: BackendKind.macosNative);
  }
  if (!isWeb && targetPlatform == TargetPlatform.android) {
    return createEmacsBackend(kind: BackendKind.android);
  }
  if (!isWeb && targetPlatform == TargetPlatform.linux) {
    return createEmacsBackend(kind: BackendKind.linux);
  }
  if (!isWeb && targetPlatform == TargetPlatform.windows) {
    return createEmacsBackend(kind: BackendKind.windows);
  }
  return createEmacsBackend();
}

BackendKind? backendKindFromName(String name) {
  switch (name.trim().toLowerCase()) {
    case '':
    case 'default':
    case 'platform':
      return null;
    case 'fake':
      return BackendKind.fake;
    case 'ios':
    case 'ios-native':
    case 'iosnative':
      return BackendKind.iosNative;
    case 'macos':
    case 'macos-native':
    case 'macosnative':
    case 'native':
      return BackendKind.macosNative;
    case 'web':
    case 'web-wasm':
    case 'webwasm':
      return BackendKind.webWasm;
    case 'android':
      return BackendKind.android;
    case 'linux':
      return BackendKind.linux;
    case 'windows':
    case 'win':
      return BackendKind.windows;
  }
  return null;
}
