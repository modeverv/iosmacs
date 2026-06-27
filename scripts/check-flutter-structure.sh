#!/usr/bin/env bash
set -euo pipefail

app_dir="flutter/iosmacs_flutter"

required_files=(
  "$app_dir/pubspec.yaml"
  "$app_dir/lib/main.dart"
  "$app_dir/lib/src/backend/backend_capabilities.dart"
  "$app_dir/lib/src/backend/backend_diagnostics.dart"
  "$app_dir/lib/src/backend/backend_factory.dart"
  "$app_dir/lib/src/backend/backend_worker.dart"
  "$app_dir/lib/src/backend/emacs_backend.dart"
  "$app_dir/lib/src/backend/android_emacs_backend.dart"
  "$app_dir/lib/src/backend/desktop_emacs_backend.dart"
  "$app_dir/lib/src/backend/fake_backend_worker.dart"
  "$app_dir/lib/src/backend/fake_emacs_backend.dart"
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
  "$app_dir/lib/src/backend/web_wasm_emacs_backend.dart"
  "$app_dir/lib/src/smoke/workspace_smoke_file.dart"
  "$app_dir/lib/src/smoke/workspace_smoke_file_io.dart"
  "$app_dir/lib/src/smoke/workspace_smoke_file_stub.dart"
  "$app_dir/lib/src/backend/workspace_entry.dart"
  "$app_dir/lib/src/ui/terminal_screen.dart"
  "$app_dir/lib/src/ui/workspace_import_picker.dart"
  "$app_dir/test/backend_factory_test.dart"
  "$app_dir/test/android_emacs_backend_test.dart"
  "$app_dir/test/desktop_emacs_backend_test.dart"
  "$app_dir/test/fake_backend_worker_test.dart"
  "$app_dir/test/fake_emacs_backend_test.dart"
  "$app_dir/test/native_emacs_backend_test.dart"
  "$app_dir/test/terminal_input_bridge_test.dart"
  "$app_dir/test/web_wasm_emacs_backend_test.dart"
  "$app_dir/test/terminal_screen_test.dart"
  "$app_dir/test/widget_test.dart"
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
  "$app_dir/macos/Runner.xcodeproj/project.pbxproj"
  "$app_dir/macos/Runner/AppDelegate.swift"
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
  "$app_dir/android/app/build.gradle.kts"
  "$app_dir/android/app/src/main/cpp/CMakeLists.txt"
  "$app_dir/android/app/src/main/cpp/iosmacs_android_runtime.cpp"
  "$app_dir/web/index.html"
  "$app_dir/linux/CMakeLists.txt"
  "$app_dir/windows/CMakeLists.txt"
)

for path in "${required_files[@]}"; do
  if [[ ! -f "$path" ]]; then
    printf 'error: missing required Flutter shell file: %s\n' "$path" >&2
    exit 1
  fi
done

if [[ ! -x scripts/check-flutter-ios-runner-smoke.sh ]]; then
  printf 'error: missing executable Flutter iOS smoke script\n' >&2
  exit 1
fi
if [[ ! -x scripts/run-flutter-ios-launch-smoke.sh ]]; then
  printf 'error: missing executable Flutter iOS launch smoke script\n' >&2
  exit 1
fi
if [[ ! -x scripts/run-flutter-ios-native-smoke.sh ]]; then
  printf 'error: missing executable Flutter iOS native smoke script\n' >&2
  exit 1
fi
if [[ ! -x scripts/run-flutter-macos-smoke.sh ]]; then
  printf 'error: missing executable Flutter macOS smoke script\n' >&2
  exit 1
fi
if [[ ! -x scripts/run-flutter-android-emulator-smoke.sh ]]; then
  printf 'error: missing executable Flutter Android emulator smoke script\n' >&2
  exit 1
fi
if [[ ! -x scripts/build-flutter-android-emacs-runtime.sh ]]; then
  printf 'error: missing executable Flutter Android Emacs runtime build script\n' >&2
  exit 1
fi
if [[ ! -x scripts/run-flutter-macos-native-smoke.sh ]]; then
  printf 'error: missing executable Flutter macOS native smoke script\n' >&2
  exit 1
fi
if [[ ! -x scripts/build-flutter-macos-emacs-runtime.sh ]]; then
  printf 'error: missing executable Flutter macOS Emacs runtime build script\n' >&2
  exit 1
fi
if [[ ! -x scripts/run-flutter-backend-override-smoke.sh ]]; then
  printf 'error: missing executable Flutter backend override smoke script\n' >&2
  exit 1
fi

grep -q 'abstract interface class EmacsBackend' \
  "$app_dir/lib/src/backend/emacs_backend.dart"
grep -q 'BackendCapabilities get capabilities' \
  "$app_dir/lib/src/backend/emacs_backend.dart"
grep -q 'ValueListenable<BackendDiagnostics> get diagnostics' \
  "$app_dir/lib/src/backend/emacs_backend.dart"
grep -q 'enum BackendKind' \
  "$app_dir/lib/src/backend/backend_factory.dart"
grep -q 'iosNative' \
  "$app_dir/lib/src/backend/backend_factory.dart"
grep -q 'macosNative' \
  "$app_dir/lib/src/backend/backend_factory.dart"
grep -q 'webWasm' \
  "$app_dir/lib/src/backend/backend_factory.dart"
grep -q 'android' \
  "$app_dir/lib/src/backend/backend_factory.dart"
grep -q 'linux' \
  "$app_dir/lib/src/backend/backend_factory.dart"
grep -q 'windows' \
  "$app_dir/lib/src/backend/backend_factory.dart"
grep -q 'MethodChannel' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q '_outputPollInterval = Duration(milliseconds: 16)' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q '_maxDrainPasses = 64' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q 'IOSMACS_FLUTTER_TRACE_IO' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q '_isDrainingOutput' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q '_combineChunks' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q 'pasteSystemClipboard' \
  "$app_dir/lib/src/backend/emacs_backend.dart"
grep -q 'pasteSystemClipboard' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q 'pasteSystemClipboard' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
if sed -n '/func handle(_ call: FlutterMethodCall/,/switch call.method/p' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift" \
  | grep -q 'focusTerminalInput()'; then
  printf 'error: Flutter iOS native bridge must not focus hidden UITextView for every MethodChannel call\n' >&2
  exit 1
fi
if sed -n '/applicationDidBecomeActive/,/^  }/p' "$app_dir/ios/Runner/AppDelegate.swift" \
  | grep -q 'focusTerminalInput()'; then
  printf 'error: Flutter iOS app activation must keep focus on TerminalView for inline IME\n' >&2
  exit 1
fi
grep -q 'FlutterTerminalInputView' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'isPasteShortcut' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'normalizeTerminalInputText' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'replacingOccurrences(of: "\\n", with: "\\r")' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'textinput-paste' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'override func paste' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'native textinput paste override start' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'native textinput forward reason=' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'terminal-trace' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'native drainOutput bytes=' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'IOSMACS_WEB_TERMINAL_DEBUG_MARKER' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'macOS child-process GNU Emacs session' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q 'macOS direct PTY resize/ioctl bridge' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q 'bundled macOS GNU Emacs runtime packaging' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q 'startInteractiveEmacsProcess' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'startupSurvivalProbeDuration' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'bundledRuntimeDirectoryName = "iosmacs-emacs"' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'Bundle.main.resourceURL' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'EMACSLOADPATH' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'exited during startup (' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'macOS interactive GNU Emacs process started:' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'forkpty(&masterFD' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'TIOCSWINSZ' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'execv(executablePath' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'writeToEmacs(Data(bytes))' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
if grep -Eq '/Applications/Emacs|/opt/homebrew/bin/emacs|/usr/local/bin/emacs' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"; then
  printf 'error: macOS native bridge must not auto-discover system Emacs paths\n' >&2
  exit 1
fi
grep -q 'Bundle Flutter macOS Emacs' \
  "$app_dir/macos/Runner.xcodeproj/project.pbxproj"
grep -q 'IOSMACS_FLUTTER_MACOS_EMACS_DEST' \
  "$app_dir/macos/Runner.xcodeproj/project.pbxproj"
grep -q 'macOS native smoke did not start the bundled GNU Emacs process' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'iosmacs-macos-mx-tetris-ok' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'unexpectedly used a system Emacs candidate' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'regressed to the old PTY pending diagnostic' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'selected an Emacs process that exited during startup' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'did not keep the selected Emacs process alive at startup' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'macOS interactive GNU Emacs process started:' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'IOSMACS_GC_THRESHOLD_MB' \
  iosmacs/Emacs/iosmacs_emacs_core.c
grep -q 'IOSMACS_LIGHT_XTERM_INIT' \
  iosmacs/Emacs/iosmacs_emacs_core.c
grep -q 'IOSMACS_SKIP_XTERM_INIT' \
  iosmacs/Emacs/iosmacs_emacs_core.c
grep -q 'IOSMACS_DISABLE_TERMINFO' \
  scripts/build-emacs-ios-probe.sh
grep -q 'IOSMACS_TRACE_EMACS_HOTPATH' \
  iosmacs/Host/iosmacs_host_facade.c
grep -q 'iosmacs_host_trace_hotpath_active' \
  iosmacs/Host/iosmacs_host_facade.c
grep -q 'last_input_push_ms' \
  iosmacs/Host/iosmacs_host_facade.c
grep -q 'hotpath redisplay-internal entry' \
  scripts/build-emacs-ios-probe.sh
grep -q 'hotpath display-line entry' \
  scripts/build-emacs-ios-probe.sh
grep -q 'hotpath garbage-collect entry' \
  scripts/build-emacs-ios-probe.sh
grep -q 'kbd_buffer_events_waiting' \
  scripts/build-emacs-ios-probe.sh
grep -q '&& !kbd_buffer_events_waiting ()' \
  scripts/build-emacs-ios-probe.sh
grep -q 'Android NDK GNU Emacs runtime artifact packaging' \
  "$app_dir/lib/src/backend/android_emacs_backend.dart"
grep -q 'Android GNU Emacs NW PTY terminal route' \
  "$app_dir/lib/src/backend/android_emacs_backend.dart"
grep -q 'Android fallback diagnostic frame renderer' \
  "$app_dir/lib/src/backend/android_emacs_backend.dart"
grep -q 'official --with-android interactive terminal bridge' \
  "$app_dir/lib/src/backend/android_emacs_backend.dart"
grep -q 'android-native-channel' \
  "$app_dir/lib/src/backend/android_emacs_backend.dart"
grep -q 'Android app-private workspace list/import/export' \
  "$app_dir/lib/src/backend/android_emacs_backend.dart"
grep -q 'fallback diagnostic frame running' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'NativeEmacsBackend' \
  "$app_dir/lib/src/backend/android_emacs_backend.dart"
grep -q 'externalNativeBuild' \
  "$app_dir/android/app/build.gradle.kts"
grep -q 'jniLibs.srcDir' \
  "$app_dir/android/app/build.gradle.kts"
grep -q 'iosmacs/jniLibs' \
  "$app_dir/android/app/build.gradle.kts"
grep -q 'assets.srcDir' \
  "$app_dir/android/app/build.gradle.kts"
grep -q 'install_temp/assets' \
  "$app_dir/android/app/build.gradle.kts"
grep -q 'emacs-android-java.jar' \
  "$app_dir/android/app/build.gradle.kts"
grep -q 'implementation(files(androidEmacsJavaBridgeJar))' \
  "$app_dir/android/app/build.gradle.kts"
grep -q 'iosmacs_android_runtime' \
  "$app_dir/android/app/src/main/cpp/CMakeLists.txt"
grep -q 'System.loadLibrary("iosmacs_android_runtime")' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'AndroidNativeEmacsRuntime' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'OfficialAndroidEmacsRuntime' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'System.loadLibrary("emacs")' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'System.loadLibrary("android-emacs")' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'androidEmacsRuntimeAvailable' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'androidEmacsJavaBridgeAvailable' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'Class.forName("org.gnu.emacs.EmacsNative")' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'getFingerprint' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'libandroid-emacs.so").absolutePath' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'androidEmacsWrapperExecutableAvailable' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'EMACS_CLASS_PATH' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'process.waitFor(8, TimeUnit.SECONDS)' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'iosmacs Android GNU Emacs process probe:' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'probeMarkerStatus' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'startOfficialEmacs' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'sendOfficialBytes' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'drainOfficialOutput' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'useLegacyPackaging = true' \
  "$app_dir/android/app/build.gradle.kts"
grep -q 'forkpty(&master_fd' \
  "$app_dir/android/app/src/main/cpp/iosmacs_android_runtime.cpp"
grep -q 'EMACS_CLASS_PATH' \
  "$app_dir/android/app/src/main/cpp/iosmacs_android_runtime.cpp"
grep -q 'iosmacs Android GNU Emacs PTY session started:' \
  "$app_dir/android/app/src/main/cpp/iosmacs_android_runtime.cpp"
grep -q 'AndroidNativeEmacsBridge.channelName' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'Buffer: \*scratch\*' \
  "$app_dir/android/app/src/main/cpp/iosmacs_android_runtime.cpp"
grep -q 'GNU Emacs 30.2 Android terminal frame' \
  "$app_dir/android/app/src/main/cpp/iosmacs_android_runtime.cpp"
grep -q -- '-UUU:----F1  \*scratch\*   Lisp Interaction' \
  "$app_dir/android/app/src/main/cpp/iosmacs_android_runtime.cpp"
grep -q 'render_terminal_input' \
  "$app_dir/android/app/src/main/cpp/iosmacs_android_runtime.cpp"
grep -q 'scratch_buffer' \
  "$app_dir/android/app/src/main/cpp/iosmacs_android_runtime.cpp"
grep -q 'GNU Emacs 30.2 Android terminal frame' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'IOSMACS_ANDROID_ABI' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'IOSMACS_ANDROID_APP_ID' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'EmacsNoninteractive.java' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'EmacsApplication.java' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'IOSMACS_ANDROID_EMACS_BUILD_ROOT' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q -- '--with-android=' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q -- '--with-gnutls=ifavailable' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q -- '--without-native-compilation' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'llvm-ar' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'llvm-ranlib' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'AR=${android_ar}' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'RANLIB=${android_ranlib}' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q '"AR=${android_ar}"' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'prebuilt/darwin-x86_64/bin/make' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q -- '--release 8' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'IOSMACS_ANDROID_EMACS_BUILD_LIBS' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'IOSMACS_ANDROID_HOST_EMACS' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'host-emacs-for-android' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'admin/charsets' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'Android API 35 exposes SIG2STR_MAX' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'IOSMACS_ANDROID_EMACS_INSTALL_JOBS' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q '"${build_root}/exec"/\*.o' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'undeclared mktime_z on Android' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'libemacs.so' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'libandroid-emacs.so' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'packaged_jni_lib_dir' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'classes.dex' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'emacs-android-java.jar' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -q 'java_bridge_jar' \
  scripts/build-flutter-android-emacs-runtime.sh
grep -Fq 'Buffer: \*scratch\*' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'IOSMACS_FLUTTER_INPUT_SMOKE=true' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'iosmacs-input-smoke: committed' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'text="iosmacs input smoke"' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'text="\$text"' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'iosmacs input smoke' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'NW Emacs did not report \*scratch\* evidence' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'Android Emacs terminal frame evidence' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'GNU Emacs NDK runtime load evidence' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'Java bridge fingerprint evidence' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'wrapper executable evidence' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'libandroid-emacs\\.so' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'subprocess probe success evidence' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'PTY session start evidence' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'official Android Emacs text-terminal boundary evidence' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'iosmacs-resize-smoke: requested' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'iosmacs-redraw-smoke: message="iosmacs Android native bridge: redrew Emacs terminal frame"' \
  scripts/run-flutter-android-emulator-smoke.sh
grep -q 'iosmacs/workspace' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'contentResolver.openInputStream' \
  "$app_dir/android/app/src/main/kotlin/com/example/iosmacs_flutter/MainActivity.kt"
grep -q 'DesktopEmacsPlatform.linux' \
  "$app_dir/lib/src/backend/desktop_emacs_backend.dart"
grep -q 'DesktopEmacsPlatform.windows' \
  "$app_dir/lib/src/backend/desktop_emacs_backend.dart"
grep -q 'GNU Emacs process/PTY bridge' \
  "$app_dir/lib/src/backend/desktop_emacs_backend.dart"
grep -q '://iosmacs/workspace-placeholder' \
  "$app_dir/lib/src/backend/desktop_emacs_backend.dart"
grep -q 'wasmacs/WASM route visibility' \
  "$app_dir/lib/src/backend/web_wasm_emacs_backend.dart"
grep -q 'connected wasmacs WebAssembly runtime' \
  "$app_dir/lib/src/backend/web_wasm_emacs_backend.dart"
grep -q 'browser://wasmacs-placeholder' \
  "$app_dir/lib/src/backend/web_wasm_emacs_backend.dart"
grep -q 'abstract interface class BackendWorker' \
  "$app_dir/lib/src/backend/backend_worker.dart"
grep -q 'createDefaultEmacsBackend' \
  "$app_dir/lib/main.dart"
grep -q 'file_selector:' \
  "$app_dir/pubspec.yaml"
grep -q 'IOSMACS_FLUTTER_AUTOSTART_NATIVE' \
  "$app_dir/lib/main.dart"
grep -q 'defaultAutoStartBackend' \
  "$app_dir/lib/main.dart"
grep -q 'native platforms autostart backend by default' \
  "$app_dir/test/widget_test.dart"
grep -q 'web and desktop placeholder platforms do not autostart by default' \
  "$app_dir/test/widget_test.dart"
grep -q 'autostart environment override wins over platform default' \
  "$app_dir/test/widget_test.dart"
grep -q 'IOSMACS_FLUTTER_MIRROR_TERMINAL_OUTPUT' \
  "$app_dir/lib/main.dart"
grep -q 'IOSMACS_FLUTTER_WORKSPACE_SMOKE' \
  "$app_dir/lib/main.dart"
grep -q 'IOSMACS_FLUTTER_CAPABILITIES_SMOKE' \
  "$app_dir/lib/main.dart"
grep -q 'IOSMACS_FLUTTER_INPUT_SMOKE' \
  "$app_dir/lib/main.dart"
grep -q 'IOSMACS_FLUTTER_RESIZE_SMOKE' \
  "$app_dir/lib/main.dart"
grep -q 'IOSMACS_FLUTTER_REDRAW_SMOKE' \
  "$app_dir/lib/main.dart"
grep -q 'IOSMACS_FLUTTER_STATUS_SMOKE' \
  "$app_dir/lib/main.dart"
grep -q 'IOSMACS_FLUTTER_STOP_SMOKE' \
  "$app_dir/lib/main.dart"
grep -q 'IOSMACS_FLUTTER_BACKEND' \
  "$app_dir/lib/main.dart"
grep -q 'backendOverride' \
  "$app_dir/lib/main.dart"
grep -q 'backendKindFromName' \
  "$app_dir/lib/src/backend/backend_factory.dart"
grep -q 'unknown-backend' \
  "$app_dir/test/backend_factory_test.dart"
grep -q 'autoStartBackend' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q '_terminalFocusNode' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q '_inputFocusNode' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'onStop: widget.backend.stop' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'runWorkspaceSmoke' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'runCapabilitiesSmoke' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'runInputSmoke' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'runResizeSmoke' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'runRedrawSmoke' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'runStatusSmoke' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'runStopSmoke' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'iosmacs-terminal-output' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'Backend \$backendId' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q "tooltip: 'Diagnostics'" \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'Icons.info_outline' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q '_showDiagnostics' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'Workspace actions' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'iosmacs-workspace-smoke' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'workspace open requested' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'iosmacs-capabilities-smoke' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'iosmacs-input-smoke' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'iosmacs-resize-smoke' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'iosmacs-redraw-smoke' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'iosmacs-status-smoke' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'iosmacs-stop-smoke' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'TTY \${value.cols}x\${value.rows}' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'CallbackShortcuts' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'LogicalKeyboardKey.keyS' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'LogicalKeyboardKey.keyX' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'LogicalKeyboardKey.keyD' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'createWorkspaceSmokeImportUri' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'workspaceImportUriProvider' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q "label: const Text('Import')" \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'Icons.file_upload' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q "label: const Text('Refresh')" \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'Icons.refresh' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q "tooltip: 'Open \${entry.name}'" \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'Icons.open_in_new' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'workspace dialog opens entries through terminal input' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'backend.diagnostics.value.inputBytes, greaterThan(30)' \
  "$app_dir/test/widget_test.dart"
grep -q 'pickWorkspaceImportUris' \
  "$app_dir/lib/src/ui/workspace_import_picker.dart"
grep -q 'openFiles' \
  "$app_dir/lib/src/ui/workspace_import_picker.dart"
grep -q '_showWorkspaceExportCandidates' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'Workspace export candidates' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'selectWorkspaceRoot' \
  "$app_dir/lib/src/backend/emacs_backend.dart"
grep -q 'clearWorkspaceRootSelection' \
  "$app_dir/lib/src/backend/emacs_backend.dart"
grep -q "label: const Text('Choose /home/user')" \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q "label: const Text('Use Default')" \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'workspace dialog can choose and clear /home/user root' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'class TerminalInputBridge' \
  "$app_dir/lib/src/ui/terminal_input_bridge.dart"
grep -q 'submitCommittedText' \
  "$app_dir/lib/src/ui/terminal_input_bridge.dart"
grep -q 'duplicateTerminalTextWindow' \
  "$app_dir/lib/src/ui/terminal_input_bridge.dart"
grep -q '_isDuplicateTerminalText' \
  "$app_dir/lib/src/ui/terminal_input_bridge.dart"
grep -q 'IME-committed text as UTF-8 bytes' \
  "$app_dir/test/terminal_input_bridge_test.dart"
grep -q 'drops duplicate terminal IME chunks' \
  "$app_dir/test/terminal_input_bridge_test.dart"
grep -q "tooltip: 'Send'" \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'Icons.send' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q "tooltip: 'Paste'" \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'Icons.content_paste' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'Clipboard.getData' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'TerminalClipboardTextProvider' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'clipboardTextProvider' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'LogicalKeyboardKey.keyV, meta: true' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'keyboardType: TextInputType.text' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'PointerInputs.all' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q '_keyRepeatMultiplier = 3' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'KeyRepeatEvent' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'pasteText' \
  "$app_dir/lib/src/ui/terminal_input_bridge.dart"
grep -q 'pasteText' \
  "$app_dir/lib/src/ui/terminal_input_bridge.dart"
grep -q 'forwards pasted text as normalized UTF-8 bytes' \
  "$app_dir/test/terminal_input_bridge_test.dart"
grep -q 'normalizes pasted multiline text to terminal carriage returns' \
  "$app_dir/test/terminal_input_bridge_test.dart"
grep -q 'input row Paste button forwards normalized paste bytes' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'Cmd+V shortcut forwards normalized paste bytes' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'input row Paste button normalizes multiline clipboard text' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'input row Paste button ignores an empty clipboard' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'Clipboard is empty' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'Pasted from system clipboard' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q '_toolbarSliderWidth' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'iosmacs-toolbar-scroll' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'scrollDirection: Axis.horizontal' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'hardware keyboard shortcuts invoke terminal controls' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'status strip shows backend id without opening capabilities' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'diagnostics dialog shows current backend counters' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'workspace dialog lists entries and shows export candidates' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'workspace dialog imports files and exports refreshed entries' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q '2 export candidate(s)' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'workspace import cancel keeps dialog entries unchanged' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'workspace dialog refresh reloads backend entries' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'terminal screen can run status smoke deterministically' \
  "$app_dir/test/widget_test.dart"
grep -q 'toolbar Stop button shuts down the backend' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'input row Send button forwards committed terminal text' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'input row Send button forwards Japanese text once' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'terminal body keeps Japanese IME composing text inline until commit' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'terminal body uses normal text keyboard for IME candidates' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'terminal body forwards all pointer input for mouse reporting' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'terminal key repeat is boosted for held hardware keys' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'toolbar avoids overflow on narrow mobile width' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'toolbar scroll reaches font size control on narrow width' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'status strip shows updated backend terminal geometry' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'app keeps controls available on narrow mobile width' \
  "$app_dir/test/widget_test.dart"
grep -q 'dart.library.io' \
  "$app_dir/lib/src/smoke/workspace_smoke_file.dart"
grep -q 'Directory.systemTemp.createTemp' \
  "$app_dir/lib/src/smoke/workspace_smoke_file_io.dart"
grep -q 'Future<Uri?> createWorkspaceSmokeImportUri' \
  "$app_dir/lib/src/smoke/workspace_smoke_file_stub.dart"
grep -q 'iosmacs/native_emacs' \
  "$app_dir/ios/Runner/AppDelegate.swift"
grep -q 'iosmacs/native_emacs' \
  "$app_dir/macos/Runner/MainFlutterWindow.swift"
grep -q 'jisKanaKeyCode: UInt16 = 104' \
  "$app_dir/macos/Runner/AppDelegate.swift"
grep -q 'jisEisuKeyCode: UInt16 = 102' \
  "$app_dir/macos/Runner/AppDelegate.swift"
grep -q 'TISSelectInputSource' \
  "$app_dir/macos/Runner/AppDelegate.swift"
grep -q 'com.apple.inputmethod.Kotoeri.RomajiTyping.Japanese' \
  "$app_dir/macos/Runner/AppDelegate.swift"
grep -q 'com.apple.keylayout.ABC' \
  "$app_dir/macos/Runner/AppDelegate.swift"
grep -q 'MacOSNativeEmacsBridge.swift in Sources' \
  "$app_dir/macos/Runner.xcodeproj/project.pbxproj"
grep -A1 'com.apple.security.app-sandbox' \
  "$app_dir/macos/Runner/DebugProfile.entitlements" | grep -q '<false/>'
grep -A1 'com.apple.security.app-sandbox' \
  "$app_dir/macos/Runner/Release.entitlements" | grep -q '<false/>'
if grep -q 'macos_process_backend_pending' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"; then
  printf 'error: macOS native bridge must not report the old process-backend pending diagnostic\n' >&2
  exit 1
fi
grep -q 'runEmacsProcessProbe' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'IOSMACS_FLUTTER_EMACS' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'iosmacs-macos-process-ok' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'macOS interactive GNU Emacs process started:' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'global-set-key (kbd "M-X")' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q "autoload 'tetris" \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
if grep -q 'Interactive PTY GNU Emacs backend is pending' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"; then
  printf 'error: macOS native bridge must not keep the old interactive PTY pending marker\n' >&2
  exit 1
fi
grep -q 'private func listWorkspace' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'private func importWorkspace' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'private func exportWorkspace' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'prepareWorkspaceRoot' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'applicationSupportDirectory' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'FlutterNativeEmacsBridge.swift in Sources' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q 'IOSMacsURLSessionBridge.swift in Sources' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q 'iosmacs_host_facade.c in Sources' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q 'iosmacs_emacs_diagnostic.c in Sources' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q 'iosmacs_emacs_core.c in Sources' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q "autoload 'dired" iosmacs/Emacs/iosmacs_emacs_core.c
grep -q "autoload 'tetris" iosmacs/Emacs/iosmacs_emacs_core.c
grep -q 'global-set-key (kbd \\"M-X\\")' iosmacs/Emacs/iosmacs_emacs_core.c
grep -q 'iosmacs-force-xterm-input-decode' iosmacs/Emacs/iosmacs_emacs_core.c
grep -q 'terminal-init-xterm' iosmacs/Emacs/iosmacs_emacs_core.c
grep -q 'iosmacs-fast-xterm-pasted-text' iosmacs/Emacs/iosmacs_emacs_core.c
grep -q 'inhibit-redisplay t' iosmacs/Emacs/iosmacs_emacs_core.c
grep -q 'iosmacs_terminal_shim.c in Sources' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q 'iosmacs_host_terminal_read' iosmacs/Host/iosmacs_host_facade.h
grep -q 'iosmacs_os_terminal_read_available' iosmacs/Host/iosmacs_host_facade.c
if grep -q 'dup2(fd, STDERR_FILENO)' iosmacs/Host/iosmacs_terminal_shim.c; then
  printf 'error: Flutter iOS fake tty must not redirect process stderr into the terminal screen\n' >&2
  exit 1
fi
if grep -q 'fd <= STDERR_FILENO' iosmacs/Host/iosmacs_terminal_shim.c \
  || grep -q 'fd <= STDERR_FILENO' iosmacs/Host/iosmacs_host_facade.c; then
  printf 'error: Flutter iOS fake tty must not classify process stderr as the terminal tty\n' >&2
  exit 1
fi
grep -q 'iosmacs_host_terminal_read (tty_buf, nbyte)' \
  scripts/build-emacs-ios-probe.sh
if [[ -f build/emacs-ios-probe/source/src/sysdep.c ]] \
  && grep -q 'byte = iosmacs_host_terminal_read_byte' build/emacs-ios-probe/source/src/sysdep.c; then
  printf 'error: generated Emacs sysdep.c still has stale byte-at-a-time tty read path\n' >&2
  exit 1
fi
grep -q 'Build Emacs Core Probe' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q 'libiosmacs-temacs.a' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q '_iosmacs_emacs_main' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q 'ARCHS = arm64' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q 'lisp in Resources' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q 'etc in Resources' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q 'lib-src in Resources' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q 'emacs.pdmp in Resources' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q '../../build/emacs-ios/source/lisp' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q '../../build/emacs-ios/source/etc' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q '../../build/emacs-ios/lib-src' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q '../../build/emacs-ios/iosmacs/nw-pdmp/emacs.pdmp' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q '../../build/emacs-ios/iosmacs/libiosmacs-temacs.a' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q 'IOSMACS_BUILD_ROOT=\\"${SRCROOT}/../../build/emacs-ios\\"' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
if grep -q 'IOSMACS_EMACS_CORE_ENTRY_OPTIONAL=1' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"; then
  printf 'error: Flutter Runner must link iosmacs_emacs_main instead of using optional-entry mode\n' >&2
  exit 1
fi
if grep -q '../../../build/emacs-ios-probe' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"; then
  printf 'error: Flutter Runner must use flutter/build/emacs-ios, not root build/emacs-ios-probe\n' >&2
  exit 1
fi
grep -q 'iosmacs_host_facade.h' \
  "$app_dir/ios/Runner/Runner-Bridging-Header.h"
grep -q 'iosmacs_emacs_diagnostic.h' \
  "$app_dir/ios/Runner/Runner-Bridging-Header.h"
grep -q 'iosmacs_emacs_core.h' \
  "$app_dir/ios/Runner/Runner-Bridging-Header.h"
grep -q 'iosmacs_terminal_shim.h' \
  "$app_dir/ios/Runner/Runner-Bridging-Header.h"
grep -q 'drainOutput' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'count: 256 \* 1024' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'iosmacs_os_terminal_write' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'iosmacs_emacs_diagnostic_start' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'iosmacs_emacs_core_start' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'Bundle.main.path(forResource: "lisp"' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'private func listWorkspace' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'private func importWorkspace' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'private func exportWorkspace' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'private func selectWorkspaceRoot' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'workspaceBookmarkDefaultsKey' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'url(forUbiquityContainerIdentifier: nil)' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'UIDocumentPickerViewController' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'startAccessingSecurityScopedResource' \
  "$app_dir/ios/Runner/FlutterNativeEmacsBridge.swift"
grep -q 'app-container workspace list/import/export' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q 'iOS security-scoped /home/user folder selection' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q 'iOS URLSession network bridge for Emacs url.el' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q 'workspace root selection calls native channel' \
  "$app_dir/test/native_emacs_backend_test.dart"
grep -q 'start drains multiple native output chunks into one stream event' \
  "$app_dir/test/native_emacs_backend_test.dart"
grep -q 'sendBytes does not wait for native output drain to finish' \
  "$app_dir/test/native_emacs_backend_test.dart"
grep -q 'iosmacs-native-drainOutput: first bytes=' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q 'macOS Application Support workspace list/import/export' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q '_workspaceEntryFromMap' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q '_showWorkspace' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'exportWorkspaceSelection' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'flutter-ios-smoke' Makefile
grep -q 'check-flutter-ios-runner-smoke.sh' Makefile
grep -Fq 'FLUTTER_EMACS_BUILD_ROOT ?= $(abspath flutter/build/emacs-ios)' Makefile
grep -q 'flutter-emacs-static' Makefile
grep -q 'flutter-emacs-pdmp' Makefile
grep -q 'flutter-ipad-launch' Makefile
grep -Fq 'IOSMACS_BUILD_ROOT="$(FLUTTER_EMACS_BUILD_ROOT)"' Makefile
grep -q 'Build Emacs static lib into flutter/build/emacs-ios' Makefile
grep -q 'flutter-ios-launch-smoke' Makefile
grep -q 'run-flutter-ios-launch-smoke.sh' Makefile
grep -q 'flutter-ios-native-smoke' Makefile
grep -q 'run-flutter-ios-native-smoke.sh' Makefile
grep -q 'IOSMACS_FLUTTER_IOS_EXPECT_RELAUNCH_PERSISTENCE=1' Makefile
grep -q 'IOSMACS_FLUTTER_IOS_EXPECT_COMMANDS=1' Makefile
grep -q 'IOSMACS_FLUTTER_AUTOSTART_NATIVE=true' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'IOSMACS_FLUTTER_MIRROR_TERMINAL_OUTPUT=true' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'iosmacs-capabilities-smoke: id=platform-native-channel' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'iosmacs-status-smoke: id=platform-native-channel' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'iosmacs-terminal-output: .*GNU Emacs' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'diagnostic fallback is running' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'IOSMACS_FLUTTER_IOS_EXPECT_SCRATCH' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'IOSMACS_FLUTTER_IOS_EXPECT_INPUT_INSERTION' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'IOSMACS_FLUTTER_IOS_EXPECT_COMMAND_MARKER' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'IOSMACS_FLUTTER_IOS_EXPECT_FILE_OPS' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'IOSMACS_FLUTTER_IOS_EXPECT_RELAUNCH_PERSISTENCE' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'IOSMACS_FLUTTER_IOS_EXPECT_COMMANDS' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'SIMCTL_CHILD_IOSMACS_APP_SMOKE_MARKER' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'SIMCTL_CHILD_IOSMACS_APP_FILE_SMOKE_MARKER' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'iosmacs-app-smoke-ok' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'iosmacs-app-file-smoke-ok' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'iosmacs-app-commands-smoke-ok' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q "commandp 'dired" \
  scripts/run-flutter-ios-native-smoke.sh
grep -q "commandp 'tetris" \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'key-binding (kbd \\"M-X\\")' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'all-completions \\"dired\\" obarray' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'all-completions \\"tetris\\" obarray' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'iosmacs-file-smoke.txt' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'Flutter iOS relaunch' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'iosmacs-resize-smoke: requested \[1-9\]\[0-9\]\*x\[1-9\]\[0-9\]\*' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q '\*scratch\*' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'Lisp Interaction' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'iosmacs input smoke' \
  scripts/run-flutter-ios-native-smoke.sh
grep -q 'flutter-macos-smoke' Makefile
grep -q 'run-flutter-macos-smoke.sh' Makefile
grep -q 'flutter-macos-native-smoke' Makefile
grep -q 'run-flutter-macos-native-smoke.sh' Makefile
grep -q 'flutter/build/' .gitignore
grep -q 'flutter-backend-override-smoke' Makefile
grep -q 'run-flutter-backend-override-smoke.sh' Makefile
grep -q 'IOSMACS_FLUTTER_BACKEND_SMOKE_BACKENDS' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'IOSMACS_FLUTTER_BACKEND=' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'IOSMACS_FLUTTER_INPUT_SMOKE=true' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'IOSMACS_FLUTTER_RESIZE_SMOKE=true' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'IOSMACS_FLUTTER_REDRAW_SMOKE=true' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'IOSMACS_FLUTTER_STATUS_SMOKE=true' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'IOSMACS_FLUTTER_STOP_SMOKE=true' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'IOSMACS_FLUTTER_WORKSPACE_SMOKE=true' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'web-wasm-placeholder' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'iosmacs-capabilities-smoke: id=' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'iosmacs-input-smoke: committed' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'iosmacs-resize-smoke: requested \[1-9\]\[0-9\]\*x\[1-9\]\[0-9\]\*' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'iosmacs-redraw-smoke: message=' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'iosmacs-status-smoke: id=' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'iosmacs-workspace-smoke: workspace listed' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'iosmacs-workspace-smoke: workspace imported' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'iosmacs-workspace-smoke: workspace listed after import' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'iosmacs-workspace-smoke: workspace export candidate(s):' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'iosmacs-workspace-smoke: workspace open requested:' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'iosmacs-stop-smoke: lifecycle=stopped' \
  scripts/run-flutter-backend-override-smoke.sh
grep -q 'IOSMACS_FLUTTER_WORKSPACE_SMOKE=true' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'IOSMACS_FLUTTER_CAPABILITIES_SMOKE=true' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'IOSMACS_FLUTTER_INPUT_SMOKE=true' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'IOSMACS_FLUTTER_RESIZE_SMOKE=true' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'IOSMACS_FLUTTER_REDRAW_SMOKE=true' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'IOSMACS_FLUTTER_STATUS_SMOKE=true' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'IOSMACS_FLUTTER_STOP_SMOKE=true' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'iosmacs-capabilities-smoke: id=platform-native-channel' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'iosmacs-input-smoke: committed' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'iosmacs-resize-smoke: requested \[1-9\]\[0-9\]\*x\[1-9\]\[0-9\]\*' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'iosmacs-redraw-smoke: message=' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'iosmacs-status-smoke: id=platform-native-channel' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'iosmacs-stop-smoke: lifecycle=stopped' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'iosmacs-workspace-smoke: workspace listed' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'iosmacs-workspace-smoke: workspace imported 1 item(s)' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'iosmacs-workspace-smoke: workspace listed after import' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'iosmacs-workspace-smoke: workspace open requested:' \
  scripts/run-flutter-macos-native-smoke.sh
grep -q 'flutter-web-smoke' Makefile
grep -q 'flutter build web --debug' Makefile
grep -q 'flutter-android-smoke' Makefile
grep -q 'flutter build apk --debug' Makefile
grep -q 'flutter-android-emacs-configure' Makefile
grep -q 'flutter-android-emacs-runtime' Makefile
grep -q 'flutter-verify' Makefile
grep -q 'flutter-doctor' Makefile
grep -q 'flutter-format-check' Makefile
grep -q 'dart format --set-exit-if-changed lib test' Makefile
grep -q 'flutter-analyze' Makefile
grep -q 'flutter analyze' Makefile
grep -q 'flutter-fake-smoke' Makefile
grep -q 'flutter-ios-launch-smoke' Makefile
grep -q 'flutter-ios-native-smoke' Makefile
grep -q 'flutter-macos-smoke' Makefile
grep -q 'flutter-macos-native-smoke' Makefile

grep -q 'Runtime Smoke Flags' \
  flutter/ARCHITECTURE.md
grep -q 'IOSMACS_FLUTTER_AUTOSTART_NATIVE' \
  flutter/ARCHITECTURE.md
grep -q 'IOSMACS_FLUTTER_MIRROR_TERMINAL_OUTPUT' \
  flutter/ARCHITECTURE.md
grep -q 'IOSMACS_FLUTTER_WORKSPACE_SMOKE' \
  flutter/ARCHITECTURE.md
grep -q 'IOSMACS_FLUTTER_CAPABILITIES_SMOKE' \
  flutter/ARCHITECTURE.md
grep -q 'IOSMACS_FLUTTER_INPUT_SMOKE' \
  flutter/ARCHITECTURE.md
grep -q 'IOSMACS_FLUTTER_RESIZE_SMOKE' \
  flutter/ARCHITECTURE.md
grep -q 'IOSMACS_FLUTTER_REDRAW_SMOKE' \
  flutter/ARCHITECTURE.md
grep -q 'IOSMACS_FLUTTER_STATUS_SMOKE' \
  flutter/ARCHITECTURE.md
grep -q 'IOSMACS_FLUTTER_STOP_SMOKE' \
  flutter/ARCHITECTURE.md
grep -q 'IOSMACS_FLUTTER_BACKEND' \
  flutter/ARCHITECTURE.md
grep -q 'make flutter-macos-native-smoke' \
  flutter/ARCHITECTURE.md
grep -q 'make flutter-analyze' \
  flutter/ARCHITECTURE.md
grep -q 'make flutter-format-check' \
  flutter/ARCHITECTURE.md
grep -q 'Dart format check' \
  flutter/ARCHITECTURE.md
grep -q 'Flutter analyze' \
  flutter/ARCHITECTURE.md
grep -q 'terminal output mirroring, capabilities, input, resize, redraw, status smoke' \
  flutter/ARCHITECTURE.md
grep -q 'evidence, stop, and workspace list/import/open/export smoke evidence' \
  flutter/ARCHITECTURE.md
grep -q 'list, import, open, and' \
  flutter/ARCHITECTURE.md
grep -q 'make flutter-backend-override-smoke' \
  flutter/ARCHITECTURE.md
grep -q 'capability, input, resize, redraw, status smoke output, workspace smoke' \
  flutter/ARCHITECTURE.md
grep -q 'list/import/open/export output, and stop smoke output' \
  flutter/ARCHITECTURE.md
grep -q 'status smoke output' \
  flutter/ARCHITECTURE.md

if grep -q 'FakeEmacsBackend()' "$app_dir/lib/main.dart"; then
  printf 'error: main.dart must construct backends through createEmacsBackend()\n' >&2
  exit 1
fi

printf 'flutter structure check ok\n'
