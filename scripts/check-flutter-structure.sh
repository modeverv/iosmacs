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
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
  "$app_dir/android/app/build.gradle.kts"
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
if [[ ! -x scripts/run-flutter-macos-smoke.sh ]]; then
  printf 'error: missing executable Flutter macOS smoke script\n' >&2
  exit 1
fi
if [[ ! -x scripts/run-flutter-macos-native-smoke.sh ]]; then
  printf 'error: missing executable Flutter macOS native smoke script\n' >&2
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
grep -q 'Android NDK GNU Emacs core build' \
  "$app_dir/lib/src/backend/android_emacs_backend.dart"
grep -q 'android://iosmacs/workspace-placeholder' \
  "$app_dir/lib/src/backend/android_emacs_backend.dart"
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
grep -q 'LogicalKeyboardKey.keyV' \
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
grep -q 'class TerminalInputBridge' \
  "$app_dir/lib/src/ui/terminal_input_bridge.dart"
grep -q 'submitCommittedText' \
  "$app_dir/lib/src/ui/terminal_input_bridge.dart"
grep -q 'IME-committed text as UTF-8 bytes' \
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
grep -q 'pasteText' \
  "$app_dir/lib/src/ui/terminal_input_bridge.dart"
grep -q 'pasted text as raw UTF-8 bytes without carriage return' \
  "$app_dir/test/terminal_input_bridge_test.dart"
grep -q 'input row Paste button forwards clipboard text as raw bytes' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'input row Paste button ignores an empty clipboard' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'Clipboard is empty' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'paste keyboard shortcuts forward clipboard text as raw bytes' \
  "$app_dir/test/terminal_screen_test.dart"
grep -q 'paste keyboard shortcuts ignore an empty clipboard' \
  "$app_dir/test/terminal_screen_test.dart"
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
grep -q 'MacOSNativeEmacsBridge.swift in Sources' \
  "$app_dir/macos/Runner.xcodeproj/project.pbxproj"
grep -q 'macos_process_backend_pending' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'runEmacsProcessProbe' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'IOSMACS_FLUTTER_EMACS' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'iosmacs-macos-process-ok' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
grep -q 'Interactive PTY GNU Emacs backend is pending' \
  "$app_dir/macos/Runner/MacOSNativeEmacsBridge.swift"
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
grep -q 'iosmacs_host_facade.c in Sources' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q 'iosmacs_emacs_diagnostic.c in Sources' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q 'iosmacs_emacs_core.c in Sources' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
grep -q 'iosmacs_terminal_shim.c in Sources' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"
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
if grep -q 'IOSMACS_EMACS_CORE_ENTRY_OPTIONAL=1' \
  "$app_dir/ios/Runner.xcodeproj/project.pbxproj"; then
  printf 'error: Flutter Runner must link iosmacs_emacs_main instead of using optional-entry mode\n' >&2
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
grep -q 'app-container workspace list/import/export' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q 'macOS sandbox workspace list/import/export' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q '_workspaceEntryFromMap' \
  "$app_dir/lib/src/backend/native_emacs_backend.dart"
grep -q '_showWorkspace' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'exportWorkspaceSelection' \
  "$app_dir/lib/src/ui/terminal_screen.dart"
grep -q 'flutter-ios-smoke' Makefile
grep -q 'check-flutter-ios-runner-smoke.sh' Makefile
grep -q 'flutter-ios-launch-smoke' Makefile
grep -q 'run-flutter-ios-launch-smoke.sh' Makefile
grep -q 'flutter-macos-smoke' Makefile
grep -q 'run-flutter-macos-smoke.sh' Makefile
grep -q 'flutter-macos-native-smoke' Makefile
grep -q 'run-flutter-macos-native-smoke.sh' Makefile
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
grep -q 'iosmacs-resize-smoke: requested 100x30' \
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
grep -q 'iosmacs-resize-smoke: requested 100x30' \
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
grep -q 'flutter-verify' Makefile
grep -q 'flutter-doctor' Makefile
grep -q 'flutter-format-check' Makefile
grep -q 'dart format --set-exit-if-changed lib test' Makefile
grep -q 'flutter-analyze' Makefile
grep -q 'flutter analyze' Makefile
grep -q 'flutter-fake-smoke' Makefile
grep -q 'flutter-ios-launch-smoke' Makefile
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
