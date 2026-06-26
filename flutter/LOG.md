# iosmacs Flutter Log

## 2026-06-26

- Started the Flutter workstream beside the existing native iOS app.
- Confirmed that `flutter` and `dart` are not currently available in PATH, so
  this pass will add source files and static structure but cannot run Flutter
  tests locally yet.
- Added active TODO tracking to the root `PLAN.md` and the detailed
  `flutter/PLAN.md`.
- Added `flutter/iosmacs_flutter` with a first Flutter shell:
  - `EmacsBackend` Dart interface
  - `FakeEmacsBackend`
  - workspace entry model
  - first terminal screen
  - lifecycle and diagnostics strip
  - start, reset, workspace, and font-size controls
- Added fake-backend and widget tests for startup, deterministic output, input
  echo, resize, and workspace placeholder behavior.
- Marked completed TODOs in `PLAN.md` and `flutter/PLAN.md`.
- Added `make flutter-fake-smoke`, which runs `flutter pub get` and
  `flutter test` from `flutter/iosmacs_flutter` when the Flutter SDK is
  available.
- Ran `git diff --check`: passed.

Flutter Android backend placeholder:

- Starting Android backend placeholder work.
- Goal for this unit: make Android select an explicit backend strategy instead
  of falling through to the fake development backend.
- Planned checks: backend capability tests, factory default-selection tests,
  structure check, Flutter analysis/tests, Android debug APK smoke, and full
  Flutter verification.
- Added `AndroidEmacsBackend` with explicit Android capabilities, unsupported
  native/NDK Emacs diagnostics, and Android-safe workspace placeholders.
- Updated the backend factory so `TargetPlatform.android` selects the Android
  placeholder by default.
- Added Android backend and factory default-selection tests.
- Updated the Flutter structure check to guard the Android backend file, test,
  factory enum, and placeholder capability/path markers.
- Adjusted the app startup widget test to reflect Android default backend
  selection in Flutter tests.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 29 tests.
- Ran `make flutter-android-smoke`: passed.
- Ran `make flutter-verify`: passed.

Flutter Linux/Windows desktop backend placeholders:

- Starting Linux/Windows desktop backend placeholder work.
- Goal for this unit: make Linux and Windows select explicit desktop backend
  strategies instead of falling through to the fake development backend.
- Planned checks: desktop placeholder capability tests, factory
  default-selection tests, structure check, Flutter analysis/tests, and full
  Flutter verification.
- Added `DesktopEmacsBackend` for Linux and Windows placeholder routes.
- Added `BackendKind.linux` and `BackendKind.windows`, and default platform
  selection for `TargetPlatform.linux` and `TargetPlatform.windows`.
- Added Linux/Windows capability, startup diagnostic, workspace placeholder,
  and backend factory tests.
- Updated the Flutter structure check to guard the desktop placeholder file,
  tests, factory enum entries, and common desktop unsupported/path markers.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 34 tests.
- Ran `make flutter-verify`: passed.

Flutter capabilities UI proof:

- Starting capabilities UI proof work.
- Goal for this unit: make backend identity and capability counts visible in
  the Flutter UI, then prove the same dialog path works for non-fake backend
  placeholders.
- Planned checks: widget tests for Android and desktop placeholder capability
  dialogs, structure check, Flutter analysis/tests, and full Flutter
  verification.
- Added backend id plus supported/unsupported item counts to the capabilities
  dialog.
- Added widget coverage for Android, Linux, and Windows placeholder capability
  dialogs.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 36 tests.
- Ran `make flutter-verify`: passed.

Flutter runtime capabilities smoke:

- Starting runtime capabilities smoke work.
- Goal for this unit: make the selected backend capability identity visible in
  macOS native smoke logs, not only in widget tests.
- Planned checks: widget smoke coverage, structure check, macOS native smoke,
  and full Flutter verification.
- Added `IOSMACS_FLUTTER_CAPABILITIES_SMOKE` to the Flutter app root and
  `TerminalScreen`.
- The startup smoke now logs `iosmacs-capabilities-smoke:` with backend id,
  supported count, and unsupported count when mirroring is enabled.
- Enabled the capabilities smoke in `scripts/run-flutter-macos-native-smoke.sh`.
- Updated the macOS native smoke to require
  `id=platform-native-channel` plus nonzero supported/unsupported counts.
- Updated the Flutter structure check to guard the new flag and log markers.
- Updated widget startup smoke coverage to exercise the capabilities smoke path.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 36 tests.
- Ran `make flutter-macos-native-smoke`: passed.
- Ran `make flutter-verify`: passed.

Flutter backend override:

- Starting backend override work.
- Goal for this unit: allow runtime smoke/debug builds to force a specific
  backend through a dart-define instead of relying only on host platform
  default selection.
- Planned checks: backend override parsing tests, app construction tests,
  structure check, Flutter analysis/tests, and full Flutter verification.
- Added `IOSMACS_FLUTTER_BACKEND` as a Flutter app dart-define override.
- Added `backendKindFromName()` and `backendOverride` support in
  `createDefaultEmacsBackend()`.
- Supported override names include `fake`, `native`, `ios-native`,
  `macos-native`, `web-wasm`, `android`, `linux`, `windows`, and `win`.
- Unknown override names fall back to the platform default instead of throwing.
- Added factory tests for explicit override selection and unknown fallback.
- Added an app widget test proving `IOSMacsFlutterApp` can force the fake
  backend through the same constructor path used by runtime override wiring.
- Updated the Flutter structure check to guard the override flag, parser, and
  fallback test marker.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 39 tests.
- Ran `make flutter-verify`: passed.

Flutter architecture documentation sync:

- Starting architecture documentation sync work.
- Goal for this unit: align `flutter/ARCHITECTURE.md` with the backend
  boundary, runtime smoke flags, and verification targets that now exist.
- Planned checks: structure check and diff whitespace check.
- Updated `flutter/ARCHITECTURE.md` to describe the implemented
  `EmacsBackend` boundary, current backend classes, platform defaults, and
  `IOSMACS_FLUTTER_BACKEND` override names.
- Documented Flutter runtime smoke flags for autostart, terminal-output
  mirroring, workspace smoke, capabilities smoke, and backend override runs.
- Documented the current verification contract, including `make
  flutter-verify`, native smoke, backend override smoke, Web build smoke, and
  Android APK build smoke.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter terminal input bridge:

- Starting terminal input validation work.
- Goal for this unit: make the Flutter terminal input byte boundary explicit
  and testable for xterm output, hardware/control-key strings, and
  IME-committed text.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added `TerminalInputBridge` as the single Flutter UI path for terminal input
  strings and committed text before they cross into `EmacsBackend.sendBytes`.
- Updated `TerminalScreen` so `Terminal.onOutput` forwards through
  `sendTerminalOutput()` and the smoke input row forwards through
  `submitCommittedText()`.
- Added tests proving xterm-style control-key strings are forwarded as raw
  bytes, Japanese IME-committed text is encoded as UTF-8 plus carriage return,
  and empty input sends no backend bytes.
- Added the input bridge and its tests to `scripts/check-flutter-structure.sh`.
- Ran `dart format lib test`: passed.
- Ran `flutter test test/terminal_input_bridge_test.dart`: passed, 3 tests.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 42 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter hardware keyboard shortcuts:

- Starting Flutter app-level hardware keyboard shortcut work.
- Goal for this unit: make the terminal controls reachable from a hardware
  keyboard without routing those app commands through the Emacs byte stream.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Wrapped the terminal screen in `CallbackShortcuts` and a focus scope so
  app-level commands can be handled independently from terminal byte input.
- Added Control+Shift and Meta+Shift shortcuts for Start, Reset, Workspace,
  Capabilities, font increase, and font decrease.
- Routed the toolbar and shortcuts through the same control methods so touch
  and hardware-keyboard paths stay aligned.
- Added widget coverage proving the shortcuts start the fake backend, request
  redraw, open workspace and capabilities dialogs, and adjust the font slider.
- Added structure-check guards for the shortcut surface and widget coverage.
- Ran `dart format lib test`: passed.
- Ran `flutter test test/terminal_screen_test.dart`: passed, 5 tests.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 43 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter runtime input smoke:

- Starting runtime input smoke work.
- Goal for this unit: add a compile-time smoke flag that submits committed
  text through the same Flutter input bridge used by the terminal screen and
  records backend input-byte evidence in process logs.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  backend override smoke, macOS native smoke, and diff whitespace check.
- Added `IOSMACS_FLUTTER_INPUT_SMOKE` to the Flutter app root and terminal
  screen startup smoke path.
- The input smoke submits `iosmacs input smoke 日本語` through
  `TerminalInputBridge.submitCommittedText()` and logs
  `iosmacs-input-smoke:` evidence with committed byte count plus backend
  diagnostics input total.
- Added input smoke to `scripts/run-flutter-backend-override-smoke.sh` so fake,
  Android, Linux, Windows, and Web placeholder backends all prove nonzero input
  counters during runtime smoke.
- Added input smoke to `scripts/run-flutter-macos-native-smoke.sh` so the
  platform native channel path proves committed input reaches backend
  diagnostics during runtime smoke.
- Added structure-check guards for the input smoke flag, log marker, and script
  assertions.
- Updated the startup smoke widget test to enable input smoke and require
  backend input bytes to increase.
- Ran `dart format lib test`: passed.
- Ran `flutter test test/widget_test.dart`: passed, 3 tests.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 43 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-backend-override-smoke`: passed for fake, Android, Linux,
  Windows, and Web-WASM backend overrides.
- Initial concurrent `make flutter-macos-native-smoke` run failed because it
  raced another Flutter macOS build while copying `FlutterMacOS.framework`.
- Re-ran `make flutter-macos-native-smoke` by itself: passed.
- Ran `git diff --check`: passed.
- Ran `make flutter-verify`: passed, including structure, doctor, fake tests,
  iOS launch smoke, macOS smoke, macOS native input smoke, backend override
  input smokes, Web debug build, and Android debug APK build.

Flutter runtime resize smoke:

- Starting runtime resize smoke work.
- Goal for this unit: add a compile-time smoke flag that sends terminal
  geometry through `EmacsBackend.resize()` at app startup and records backend
  resize diagnostics in process logs.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  backend override smoke, macOS native smoke, and diff whitespace check.
- Added `IOSMACS_FLUTTER_RESIZE_SMOKE` to the Flutter app root and terminal
  screen startup smoke path.
- The resize smoke sends fixed `100x30` geometry through
  `EmacsBackend.resize()` and logs `iosmacs-resize-smoke:` evidence with the
  requested geometry plus backend diagnostics geometry.
- Added resize smoke to `scripts/run-flutter-backend-override-smoke.sh` so
  fake, Android, Linux, Windows, and Web placeholder backend overrides all
  prove geometry forwarding during runtime smoke.
- Added resize smoke to `scripts/run-flutter-macos-native-smoke.sh` so the
  platform native channel path proves resize reaches backend diagnostics during
  runtime smoke.
- Added structure-check guards for the resize smoke flag, log marker, and
  script assertions.
- Updated the startup smoke widget test to enable resize smoke and require the
  backend diagnostics geometry to become `100x30`.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 43 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-backend-override-smoke`: passed for fake, Android, Linux,
  Windows, and Web-WASM backend overrides.
- Ran `make flutter-macos-native-smoke`: passed.
- Ran `make flutter-verify`: passed, including resize smoke evidence in macOS
  native and backend override runtime smokes.

Flutter runtime redraw smoke:

- Starting runtime redraw smoke work.
- Goal for this unit: add a compile-time smoke flag that calls
  `EmacsBackend.resetOrRedraw()` at app startup and records backend redraw
  diagnostics in process logs.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  backend override smoke, macOS native smoke, and diff whitespace check.
- Added `IOSMACS_FLUTTER_REDRAW_SMOKE` to the Flutter app root and terminal
  screen startup smoke path.
- The redraw smoke calls `EmacsBackend.resetOrRedraw()` and logs
  `iosmacs-redraw-smoke:` evidence with the backend diagnostics message after
  redraw.
- Added redraw smoke to `scripts/run-flutter-backend-override-smoke.sh` so
  fake, Android, Linux, Windows, and Web placeholder backend overrides all
  prove reset/redraw forwarding during runtime smoke.
- Added redraw smoke to `scripts/run-flutter-macos-native-smoke.sh` so the
  platform native channel path proves redraw reaches backend diagnostics during
  runtime smoke.
- Added structure-check guards for the redraw smoke flag, log marker, and
  script assertions.
- Updated startup smoke widget coverage and added a focused redraw smoke widget
  test for the fake backend.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 44 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-backend-override-smoke`: passed for fake, Android, Linux,
  Windows, and Web-WASM backend overrides.
- Ran `make flutter-macos-native-smoke`: passed.
- Ran `make flutter-verify`: passed, including redraw smoke evidence in macOS
  native and backend override runtime smokes.

Flutter runtime stop smoke:

- Starting runtime stop smoke work.
- Goal for this unit: add a compile-time smoke flag that calls
  `EmacsBackend.stop()` at app startup and records lifecycle stop evidence in
  process logs.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  backend override smoke, macOS native smoke, and diff whitespace check.
- Added `IOSMACS_FLUTTER_STOP_SMOKE` to the Flutter app root and terminal
  screen startup smoke path.
- The stop smoke calls `EmacsBackend.stop()` after the other enabled startup
  smokes and logs `iosmacs-stop-smoke:` evidence with the backend lifecycle
  state.
- Added stop smoke to `scripts/run-flutter-backend-override-smoke.sh` so fake,
  Android, Linux, Windows, and Web placeholder backend overrides all prove
  lifecycle stop forwarding during runtime smoke.
- Added stop smoke to `scripts/run-flutter-macos-native-smoke.sh` so the
  platform native channel path proves lifecycle stop during runtime smoke.
- Added structure-check guards for the stop smoke flag, log marker, and script
  assertions.
- Updated startup smoke widget coverage and added a focused stop smoke widget
  test for the fake backend.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 45 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-backend-override-smoke`: passed for fake, Android, Linux,
  Windows, and Web-WASM backend overrides.
- Ran `make flutter-macos-native-smoke`: passed.
- Ran `make flutter-verify`: passed, including stop smoke evidence in macOS
  native and backend override runtime smokes.

Flutter runtime smoke documentation sync:

- Starting runtime smoke documentation sync work.
- Goal for this unit: align `flutter/ARCHITECTURE.md` with the current
  capabilities, input, resize, redraw, stop, workspace, and backend override
  smoke evidence.
- Planned checks: structure check and diff whitespace check.
- Updated `flutter/ARCHITECTURE.md` runtime smoke flags to include
  `IOSMACS_FLUTTER_INPUT_SMOKE`, `IOSMACS_FLUTTER_RESIZE_SMOKE`,
  `IOSMACS_FLUTTER_REDRAW_SMOKE`, and `IOSMACS_FLUTTER_STOP_SMOKE`.
- Updated the verification contract so macOS native smoke and backend override
  smoke describe their current capabilities, input, resize, redraw, stop, and
  workspace evidence.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter backend override runtime smoke:

- Starting backend override runtime smoke work.
- Goal for this unit: prove `IOSMACS_FLUTTER_BACKEND` works in launched app
  binaries, not only in factory and widget tests.
- Planned checks: new macOS runtime override smoke, structure check, and full
  Flutter verification.
- Added `scripts/run-flutter-backend-override-smoke.sh`.
- Added `make flutter-backend-override-smoke` and included it in
  `make flutter-verify`.
- The override smoke builds and launches the macOS Runner with forced `fake`,
  `android`, `linux`, `windows`, and `web-wasm` backends.
- Each launch checks `iosmacs-capabilities-smoke:` for the expected backend id
  and nonzero supported/unsupported capability counts.
- Added structure checks for the new executable script, Makefile target,
  override backend list, and expected Web placeholder marker.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-backend-override-smoke`: passed for fake, Android, Linux,
  Windows, and Web placeholder backends.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 39 tests.
- Ran `make flutter-verify`: passed.
- Ran `make flutter-fake-smoke`: stopped at the intended SDK boundary with
  `error: flutter command not found; install Flutter SDK or add it to PATH`.
- Remaining blocker: run `flutter pub get`, `flutter test`, and simulator
  launch checks after the Flutter SDK is available in PATH.

Continuation:

- Continuing with SDK-independent Phase 2 groundwork.
- Next unit: add backend selection and structured diagnostics so the Flutter UI
  remains bound to `EmacsBackend` instead of concrete platform backend classes.
- Added `BackendDiagnostics` with lifecycle-adjacent status text, terminal
  geometry, input/output byte counters, and workspace action counters.
- Added `backend_factory.dart` with the first explicit `BackendKind.fake`
  selection point.
- Updated the Flutter app root to construct backends through
  `createEmacsBackend()` rather than `FakeEmacsBackend` directly.
- Updated terminal diagnostics display to render the structured diagnostics
  summary.
- Expanded fake-backend tests for byte counters, geometry, workspace action
  counters, and backend factory selection.
- Next unit: add an SDK-independent structure check so CI or a fresh checkout
  can verify the Flutter shell boundary even before Flutter is installed.
- Added `scripts/check-flutter-structure.sh` and `make flutter-structure-check`.
- Ran `make flutter-structure-check`: passed.
- Next unit: add a reproducible Flutter SDK bootstrap target for generated iOS,
  macOS, Android, Linux, Windows, and Web runner files.
- Added `make flutter-bootstrap`, which runs `flutter create .` in the Flutter
  app directory with iOS, Android, macOS, Linux, Windows, and Web platforms.
- Ran `make flutter-bootstrap`: stopped at the intended SDK boundary with
  `error: flutter command not found; install Flutter SDK or add it to PATH`.
- Ran `make help`: confirmed the Flutter structure, bootstrap, and fake smoke
  targets are listed.
- Re-ran `make flutter-structure-check`: passed.
- Re-ran `make flutter-fake-smoke`: still stops at the intended SDK boundary.
- Re-ran `git diff --check`: passed.

SDK installation:

- Installed Flutter SDK stable under `/Users/seijiro/work/flutter`.
- `flutter --version`: Flutter 3.44.4, Dart 3.12.2.
- Added `/Users/seijiro/work/flutter/bin` to `/Users/seijiro/.zshrc`.
- Verified a new interactive zsh resolves
  `/Users/seijiro/work/flutter/bin/flutter`.
- Ran `flutter doctor -v`: Flutter, Xcode, Chrome, connected iPad simulator,
  macOS, Chrome, and network resources are detected; Android SDK and CocoaPods
  remain missing.
- Ran `make flutter-bootstrap`: generated iOS, Android, macOS, Linux, Windows,
  and Web runner files.
- Replaced Flutter template counter smoke with an iosmacs terminal-screen smoke.
- Ran `make flutter-fake-smoke`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `flutter run -d macos --debug`: launched to a Dart VM Service, then
  stopped it with `q`. Flutter reported `Failed to foreground app; open
  returned 1`, but the runtime started and exposed the service.
- Ran `flutter run -d D0F9B2BE-1CD0-49D6-BC25-6FF7650031D6 --debug`: launched
  on the iPad simulator to a Dart VM Service, then stopped it with `q`.
- Expanded `scripts/check-flutter-structure.sh` to include generated iOS,
  Android, macOS, Linux, Windows, and Web runner files.
- Re-ran `make flutter-structure-check`: passed with generated runner checks.
- Re-ran `make flutter-fake-smoke`: passed.
- Re-ran `git diff --check`: passed.

Worker boundary:

- Starting Phase 2 backend worker split.
- Goal for this unit: keep `EmacsBackend` as the UI-facing API while moving the
  fake backend's command handling behind a worker-shaped command/event boundary.
- Added `backend_worker.dart` with worker command, event, result, and interface
  types.
- Added `fake_backend_worker.dart`; fake lifecycle, terminal output, input echo,
  resize, diagnostics, and workspace placeholder behavior now live behind the
  worker boundary.
- Updated `FakeEmacsBackend` to adapt worker events into the UI-facing
  `EmacsBackend` API.
- Added `fake_backend_worker_test.dart` for lifecycle, output, resize, input,
  and workspace command results.
- Updated `scripts/check-flutter-structure.sh` to require the worker files and
  worker tests.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 10 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-fake-smoke`: passed, 10 tests.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `git diff --check`: passed.

Backend capabilities complete:

- Added `BackendCapabilities` for backend identity, supported features, and
  unsupported features.
- Extended `EmacsBackend` with a `capabilities` getter.
- Updated `FakeEmacsBackend` to report deterministic fake-supported behavior
  and explicit unsupported native/runtime surfaces.
- Added a terminal toolbar Capabilities action and dialog.
- Updated the Flutter structure check to require the capability contract.
- Added tests for fake backend capability values and UI display.
- Updated `Makefile` Flutter targets to find the SDK at `~/work/flutter` during
  non-interactive `make` runs.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed. A first parallel attempt hit Flutter startup
  lock contention, then passed when run alone.
- Ran `flutter test`: passed, 11 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-fake-smoke`: passed, 11 tests.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: first failed after a Makefile PATH adjustment
  masked `mise` Ruby/CocoaPods; fixed `flutter-doctor` to preserve `mise exec`
  PATH and re-ran successfully with no issues.

iOS native backend channel:

- Starting an iOS native backend channel scaffold.
- Goal for this unit: add a Dart/iOS MethodChannel boundary and explicit
  unsupported diagnostics before wiring the existing native Emacs core.
- Added `NativeEmacsBackend`, which implements `EmacsBackend` over the
  `iosmacs/native_emacs` MethodChannel.
- Added iOS-only default backend selection through `createDefaultEmacsBackend`;
  fake backend remains the default on non-iOS and web targets.
- Updated `main.dart` to use platform-aware default backend selection.
- Added an iOS Runner channel handler in `AppDelegate.swift`.
- The iOS channel currently returns `native_emacs_not_connected` for known
  native backend methods until the existing Emacs bridge is wired in.
- Added native backend tests for capabilities and unsupported diagnostics.
- Added factory tests for explicit native backend creation and iOS-only default
  selection.
- Updated the Flutter structure check to require the native backend scaffold and
  iOS channel registration.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 15 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-fake-smoke`: passed, 15 tests.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues.

Shared host facade:

- Starting shared C host facade integration for the Flutter iOS Runner.
- Goal for this unit: make the Flutter MethodChannel bridge use the same
  terminal input/output/resize facade as the existing native iosmacs app.
- Added `iosmacs/Host/iosmacs_host_facade.c` to the Flutter iOS Runner target.
- Exposed `iosmacs_host_facade.h` through `Runner-Bridging-Header.h`.
- Replaced the Runner-local Swift output buffer with
  `iosmacs_os_terminal_write` and `iosmacs_os_terminal_drain_output`.
- Routed Flutter input and resize calls through
  `iosmacs_os_terminal_push_input` and `iosmacs_os_terminal_resize`.
- Updated the Flutter structure check to require the shared facade source,
  bridging header include, and facade-backed bridge calls.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 16 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `make flutter-fake-smoke`: passed, 16 tests.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- First parallel `flutter build macos --debug` hit an Xcode Swift Package
  Manager resolution error; re-ran alone and it passed.
- Ran `make flutter-doctor`: passed with no issues.

Shared diagnostic terminal:

- Starting shared Emacs diagnostic/core availability integration for the
  Flutter iOS Runner.
- Goal for this unit: run the existing C diagnostic terminal through the
  Flutter native bridge while keeping real GNU Emacs core startup explicitly
  pending until the static archive/link step is ported.
- Added `iosmacs_emacs_diagnostic.c`, `iosmacs_emacs_core.c`, and
  `iosmacs_terminal_shim.c` to the Flutter iOS Runner target.
- Exposed diagnostic, core, host facade, and terminal shim headers through the
  Runner bridging header.
- Updated `FlutterNativeEmacsBridge` to start
  `iosmacs_emacs_diagnostic_start()` and pump
  `iosmacs_emacs_diagnostic_pump()` after Flutter input bytes.
- Added an optional-entry mode to `iosmacs_emacs_core.c` so the Flutter Runner
  can compile core availability without requiring the real simulator Emacs
  entry link yet.
- Added Runner build settings for the shared source header paths and optional
  core entry macro.
- Added a Flutter Runner build phase for the existing Emacs static probe so the
  archive remains prepared for the next link step.
- Updated the structure check for diagnostic/core/shim source registration,
  bridging header exposure, optional-entry macro, and static probe build phase.
- Ran `flutter build ios --simulator --debug`: passed after adding optional
  core entry mode.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 16 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-fake-smoke`: passed, 16 tests.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- First parallel `flutter build macos --debug` hit a Flutter startup-lock
  cleanup error; re-ran alone and it passed.
- Ran `make flutter-doctor`: passed with no issues.
- Ran `make app`: passed, including existing native iOS app build.

Flutter simulator Emacs archive link:

- Starting simulator archive entry linking for the Flutter iOS Runner.
- Goal for this unit: make the Flutter Runner resolve `iosmacs_emacs_main`
  from `libiosmacs-temacs.a` instead of relying on optional-entry pending mode.
- Added `-u _iosmacs_emacs_main` to the Flutter Runner simulator linker flags
  so the static archive entry object is pulled from `libiosmacs-temacs.a`.
- Removed `IOSMACS_EMACS_CORE_ENTRY_OPTIONAL=1` from the Flutter Runner target.
- Set the Flutter iOS Runner target `ARCHS` to `arm64`, matching the existing
  simulator Emacs static archive.
- Updated the structure check to require the `_iosmacs_emacs_main` linker
  reference, arm64 Runner target, and absence of optional-entry mode.
- Ran `flutter build ios --simulator --debug`: passed.
- Verified `build/ios/iphonesimulator/Runner.app/Runner.debug.dylib` exports
  `_iosmacs_emacs_main` and `_iosmacs_emacs_core_link_available` with `nm`.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 16 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make app`: passed, including the existing native iOS app build.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues.
- Ran `git diff --check`: passed.

Flutter native Emacs resource/startup:

- Starting Flutter native Emacs resource/startup wiring.
- Goal for this unit: make the Flutter iOS Runner bundle the same Emacs runtime
  resources as the native app and have the native channel start linked GNU Emacs
  when those resources are present.
- Added `lisp`, `etc`, `lib-src`, and `emacs.pdmp` to the Flutter iOS Runner
  resource phase.
- Updated `FlutterNativeEmacsBridge.start()` to call
  `iosmacs_emacs_core_start()` with Bundle resource paths and a default
  Documents/home workspace.
- Preserved the shared diagnostic terminal as an explicit fallback when linked
  core startup or required resources are unavailable.
- Updated native backend capability text to advertise iOS simulator GNU Emacs
  startup and native terminal byte flow.
- Updated the structure check to require Flutter Runner Emacs resources and the
  real startup call.
- Ran `make flutter-structure-check`: passed.
- Ran `dart format lib test` with `~/work/flutter/bin` on PATH: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 16 tests.
- Ran `flutter build ios --simulator --debug`: passed.
- Verified `Runner.app` contains `emacs.pdmp`, `lisp`, `etc`, and `lib-src`.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues through mise/CocoaPods.
- Ran `git diff --check`: passed.

Flutter native workspace:

- Starting Flutter native workspace wiring.
- Goal for this unit: replace the native channel workspace placeholders with
  app-container file operations while keeping Dart free of editor semantics.
- Implemented Runner-side `listWorkspace` against the default Documents/home
  app-container workspace.
- Implemented Runner-side `importWorkspace` by copying file URLs into
  Documents/home and replacing same-name destination items.
- Implemented Runner-side `exportWorkspace` by returning workspace item file
  URLs, or the workspace root when empty.
- Updated `NativeEmacsBackend` to parse native workspace entry maps, import
  counts, and export URL strings.
- Updated native backend capabilities to advertise app-container workspace
  list/import/export.
- Added Flutter tests for native workspace list/import/export MethodChannel
  results.
- Updated `make flutter-structure-check` to guard native workspace wiring.
- Ran `dart format lib test` with `~/work/flutter/bin` on PATH: passed.
- Ran `flutter analyze`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 17 tests.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `flutter build web --debug`: passed.
- First parallel `flutter build macos --debug` hit a Flutter ephemeral package
  cleanup error; re-ran alone and it passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues through mise/CocoaPods.
- Ran `git diff --check`: passed.

Flutter workspace UI:

- Starting workspace UI wiring.
- Goal for this unit: surface the implemented workspace list/export backend
  APIs in the Flutter terminal screen without moving Emacs editor semantics into
  Dart.
- Replaced the toolbar workspace count SnackBar with a dialog listing workspace
  entries.
- Workspace rows now show file/directory icon, name, backend path, and size
  label.
- Added an Export action that calls `exportWorkspaceSelection()` and reports the
  number of export candidate URLs.
- Added a widget test for visible workspace entries and export result feedback.
- Updated `make flutter-structure-check` to guard the workspace dialog/export
  UI path.
- First `flutter analyze` caught an async `BuildContext` warning in the export
  action; fixed it by capturing the `NavigatorState` before awaiting.
- Ran `dart format lib test` with `~/work/flutter/bin` on PATH: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 18 tests.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues through mise/CocoaPods.
- Ran `git diff --check`: passed.

Flutter iOS smoke target:

- Starting repeatable Flutter iOS smoke target work.
- Goal for this unit: make the Flutter iOS simulator build evidence reusable by
  checking the built Runner bundle resources and linked GNU Emacs entry symbol
  through a repository make target.
- Added `scripts/check-flutter-ios-runner-smoke.sh`.
- The smoke script builds the Flutter iOS simulator app, checks `Runner.app` for
  `lisp`, `etc`, `lib-src`, and `emacs.pdmp`, and checks
  `Runner.debug.dylib` for `_iosmacs_emacs_main` and
  `_iosmacs_emacs_core_link_available`.
- Added `make flutter-ios-smoke`.
- Updated `make flutter-structure-check` to guard the smoke script and Makefile
  target.
- Ran `bash -n scripts/check-flutter-ios-runner-smoke.sh
  scripts/check-flutter-structure.sh`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `dart format lib test` with `~/work/flutter/bin` on PATH: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 18 tests.
- Ran `make flutter-ios-smoke`: passed.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues through mise/CocoaPods.
- Ran `git diff --check`: passed.

Flutter iOS launch smoke:

- Starting repeatable Flutter iOS launch smoke work.
- Goal for this unit: prove the Flutter iOS Runner can be installed, launched,
  kept alive briefly, and terminated on a booted simulator through a repository
  make target.
- Added `scripts/run-flutter-ios-launch-smoke.sh`.
- The launch smoke reuses `scripts/check-flutter-ios-runner-smoke.sh`, installs
  `Runner.app` on a booted simulator, reads the bundle id from `Info.plist`,
  launches it with `xcrun simctl launch`, waits briefly, and requires clean
  termination.
- Added `make flutter-ios-launch-smoke`.
- Updated `make flutter-structure-check` to guard the launch smoke script and
  Makefile target.
- Ran `bash -n scripts/run-flutter-ios-launch-smoke.sh
  scripts/check-flutter-ios-runner-smoke.sh scripts/check-flutter-structure.sh`:
  passed.
- Ran `make flutter-structure-check`: passed.
- Ran `dart format lib test` with `~/work/flutter/bin` on PATH: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 18 tests.
- Ran `make flutter-ios-launch-smoke`: passed and launched
  `com.example.iosmacsFlutter` on the booted iPad simulator before clean
  termination.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `flutter build macos --debug`: passed.
- First parallel `flutter build web --debug` hit a Flutter ephemeral package
  cleanup error; re-ran alone and it passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues through mise/CocoaPods.
- Ran `git diff --check`: passed.

Flutter macOS smoke:

- Starting repeatable Flutter macOS smoke work.
- Goal for this unit: prove the Flutter macOS desktop app can be built,
  launched briefly, stay alive, and terminate cleanly through a repository make
  target.
- Added `scripts/run-flutter-macos-smoke.sh`.
- The macOS smoke builds the Flutter macOS debug app, checks the
  `iosmacs_flutter.app` bundle and executable, launches the executable briefly,
  and requires clean termination.
- Added `make flutter-macos-smoke`.
- Updated `make flutter-structure-check` to guard the macOS smoke script and
  Makefile target.
- Ran `bash -n scripts/run-flutter-macos-smoke.sh
  scripts/run-flutter-ios-launch-smoke.sh scripts/check-flutter-ios-runner-smoke.sh
  scripts/check-flutter-structure.sh`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `dart format lib test` with `~/work/flutter/bin` on PATH: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 18 tests.
- Ran `make flutter-macos-smoke`: passed.
- Ran `make flutter-ios-launch-smoke`: passed.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues through mise/CocoaPods.
- Ran `git diff --check`: passed.

Flutter verification target:

- Starting repeatable Flutter verification target work.
- Goal for this unit: add a single Flutter workstream verification target that
  runs the structure, doctor, fake backend, iOS launch, and macOS smoke checks
  sequentially.
- Added `make flutter-verify`.
- `flutter-verify` runs `flutter-structure-check`, `flutter-doctor`,
  `flutter-fake-smoke`, `flutter-ios-launch-smoke`, and `flutter-macos-smoke`
  sequentially to avoid Flutter startup-lock contention.
- Updated `make flutter-structure-check` to guard the verification target.
- Ran `bash -n` for the Flutter smoke scripts and structure check: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `dart format lib test` with `~/work/flutter/bin` on PATH: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 18 tests.
- Ran `make flutter-verify`: passed.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `git diff --check`: passed.

Flutter Web/Android smoke:

- Starting repeatable Flutter Web/Android smoke work.
- Goal for this unit: move the manually repeated Web debug and Android APK
  debug builds behind repository make targets and include them in
  `make flutter-verify`.
- Added `make flutter-web-smoke` for `flutter build web --debug`.
- Added `make flutter-android-smoke` for `flutter build apk --debug`.
- Included both new smoke targets in `make flutter-verify`.
- Updated the Flutter structure check to guard the Web/Android smoke targets
  and their underlying Flutter build commands.
- Ran `make flutter-structure-check`: passed.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 18 tests.
- Ran expanded `make flutter-verify`: passed.
- Ran `make app`: passed, including existing native iOS app build.
- Ran `git diff --check`: passed.

Flutter macOS native channel:

- Starting macOS native channel work.
- Goal for this unit: let macOS select the same Dart MethodChannel backend
  behind `EmacsBackend`, while the macOS Runner reports explicit pending
  diagnostics until a PTY/process Emacs backend is implemented.
- Renamed the Dart native backend capability identity from iOS-only wording to
  `platform-native-channel`.
- Added `BackendKind.macosNative` and made macOS non-web select the shared
  native MethodChannel backend by default.
- Added `MacOSNativeEmacsBridge.swift` to the macOS Runner target.
- Registered `iosmacs/native_emacs` from `MainFlutterWindow.swift`.
- The macOS bridge now handles start, stop, redraw, sendBytes, resize,
  drainOutput, listWorkspace, importWorkspace, and exportWorkspace with
  explicit PTY/process-backend pending diagnostics.
- Updated structure checks to guard the macOS native bridge and channel
  registration.
- Updated tests for macOS default backend selection and shared native-channel
  capabilities.
- First parallel `flutter analyze`/`flutter test` attempt collided with a
  concurrent Flutter startup lock while `make flutter-macos-smoke` was running.
- Re-ran `flutter analyze` sequentially: passed.
- Re-ran `flutter test` sequentially: passed, 19 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-macos-smoke`: passed.
- Ran expanded `make flutter-verify`: passed.

Flutter macOS process probe:

- Starting macOS Emacs process probe work.
- Goal for this unit: run a short discoverable Emacs batch process from the
  macOS native MethodChannel when allowed, surface stdout/stderr to Flutter,
  and keep interactive PTY support explicitly pending.
- Added deterministic Emacs executable candidates in the macOS Runner:
  `IOSMACS_FLUTTER_EMACS`, `/usr/local/bin/emacs`, `/opt/homebrew/bin/emacs`,
  `/Applications/Emacs.app/Contents/MacOS/Emacs`, and
  `/Applications/Emacs-takaxp/Emacs.app/Contents/MacOS/Emacs`.
- The macOS bridge now runs `emacs --batch --quick --eval` on `start` and
  writes stdout, stderr, exit status, or launch failures into the terminal
  output buffer.
- Successful batch probes emit `iosmacs-macos-process-ok`.
- Interactive PTY GNU Emacs remains explicitly pending after the process probe.
- `NativeEmacsBackend` now applies native `lifecycleState`, `cols`, and `rows`
  payloads to diagnostics.
- Added a test for native status payload handling.
- Updated structure checks for the macOS process probe markers.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 20 tests.
- Ran `make flutter-macos-smoke`: passed.
- Ran expanded `make flutter-verify`: passed.

Flutter macOS process probe runtime smoke:

- Starting runtime smoke work for the macOS Emacs process probe.
- Goal for this unit: make the macOS app start the native backend during a
  smoke build and mirror terminal output into a log so the process probe can be
  verified without manual Start-button interaction.
- Added `IOSMACS_FLUTTER_AUTOSTART_NATIVE` to start the selected backend at app
  launch in smoke builds.
- Added `IOSMACS_FLUTTER_MIRROR_TERMINAL_OUTPUT` to mirror terminal output
  chunks into the app process log.
- Added `scripts/run-flutter-macos-native-smoke.sh`.
- Added `make flutter-macos-native-smoke`.
- Included `make flutter-macos-native-smoke` in `make flutter-verify`.
- Updated `make flutter-structure-check` to guard the smoke script, Makefile
  target, and Flutter smoke hooks.
- Added a widget test for app-level autostart smoke behavior.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 21 tests.
- Ran `make flutter-macos-native-smoke`: passed.
- The macOS native smoke log shows `/usr/local/bin/emacs` exited 1, then
  `/Applications/Emacs-takaxp/Emacs.app/Contents/MacOS/Emacs` emitted
  `iosmacs-macos-process-ok`; the log also preserves the interactive PTY
  pending marker.
- Ran expanded `make flutter-verify`: passed.

Flutter macOS workspace:

- Starting macOS workspace bridge work.
- Goal for this unit: replace macOS native workspace pending errors with
  sandboxed Application Support workspace list/import/export operations.
- Implemented `listWorkspace`, `importWorkspace`, and `exportWorkspace` in
  `MacOSNativeEmacsBridge`.
- The macOS workspace root is created under Application Support at
  `iosmacs_flutter/workspace`.
- Workspace entries return name, path, directory flag, and byte size.
- `importWorkspace` copies passed file URLs into the sandbox workspace and
  replaces existing same-name items.
- `exportWorkspace` returns workspace item file URLs, or the workspace root
  when no entries exist.
- Updated backend capabilities to include `macOS sandbox workspace
  list/import/export`.
- Updated structure checks for macOS workspace methods and the Application
  Support workspace root.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 21 tests.
- Ran `make flutter-macos-smoke`: passed.
- Ran `make flutter-macos-native-smoke`: passed.
- Ran expanded `make flutter-verify`: passed.

Flutter macOS workspace runtime smoke:

- Starting runtime smoke work for macOS workspace MethodChannel operations.
- Goal for this unit: exercise workspace list/export from the running Flutter
  macOS app and verify the result through captured process logs.
- Added `IOSMACS_FLUTTER_WORKSPACE_SMOKE` to run workspace list/export at app
  launch.
- Workspace smoke mirrors result counts as `iosmacs-workspace-smoke:` process
  log lines.
- Extended `scripts/run-flutter-macos-native-smoke.sh` to pass
  `IOSMACS_FLUTTER_WORKSPACE_SMOKE=true`.
- Extended the native smoke script to require workspace list/export evidence
  in the captured log.
- Added widget coverage for app-level autostart plus workspace smoke behavior.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 21 tests.
- Ran `make flutter-macos-native-smoke`: passed.
- The latest native smoke log includes `iosmacs-macos-process-ok`,
  `Interactive PTY GNU Emacs backend is pending`, `workspace listed 0 item(s)`,
  and `workspace export candidate(s): 1`.
- Ran expanded `make flutter-verify`: passed.

Flutter macOS workspace import smoke:

- Starting workspace import runtime smoke work.
- Goal for this unit: create a smoke import file on IO-capable platforms, call
  `importWorkspace`, then verify list/export evidence through the macOS native
  smoke log while preserving Web builds.
- Added a conditional `workspace_smoke_file.dart` export with an IO
  implementation and a non-IO stub.
- The IO implementation creates a temporary `workspace-smoke.txt` file for
  import smoke.
- Startup workspace smoke now runs list, import, list-after-import, and export
  in sequence.
- Extended `scripts/run-flutter-macos-native-smoke.sh` to require
  `workspace imported 1 item(s)` and `workspace listed after import`.
- Updated structure checks for the conditional smoke helper and new log checks.
- Adjusted widget coverage to inject a deterministic import URI.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 21 tests.
- Ran `make flutter-macos-native-smoke`: passed.
- Ran `make flutter-web-smoke`: passed.
- The latest native smoke log includes `iosmacs-macos-process-ok`,
  `workspace listed 1 item(s)`, `workspace imported 1 item(s)`,
  `workspace listed after import 1 item(s)`, and
  `workspace export candidate(s): 1`.
- Ran expanded `make flutter-verify`: passed.

Flutter Web backend placeholder:

- Starting Web backend placeholder work.
- Goal for this unit: stop treating Flutter Web as the fake backend by default
  and make the separate `wasmacs`/WASM backend route visible through
  capabilities and diagnostics.
- Added `WebWasmEmacsBackend`.
- Added `BackendKind.webWasm` and selected it by default when `kIsWeb` is true.
- Web capabilities now expose `wasmacs`/WASM route visibility and explicit
  unsupported native FFI, MethodChannel, connected WASM runtime, and browser
  file import/export proof.
- Added deterministic Web startup diagnostics and browser-safe workspace
  placeholders.
- Added tests for explicit Web backend construction, default Web selection,
  Web capabilities, startup diagnostics, and workspace placeholders.
- Updated the Flutter structure check to guard the Web backend files and
  capability markers.
- Ran `dart format lib test`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 25 tests.
- Ran `make flutter-web-smoke`: passed.
- Ran expanded `make flutter-verify`: passed.

iOS native channel diagnostic bridge:

- Starting channel diagnostic bridge work.
- Goal for this unit: make the iOS MethodChannel return successful diagnostic
  lifecycle/output/input/resize responses before connecting the GNU Emacs core.
- Added `FlutterNativeEmacsBridge.swift` to the iOS Runner target.
- The native bridge now handles `start`, `stop`, `redraw`, `sendBytes`,
  `resize`, `drainOutput`, and workspace placeholder methods.
- Updated `NativeEmacsBackend` to drain `drainOutput` into `outputStream` after
  successful operations and poll while running.
- Kept missing-plugin and `PlatformException` paths as explicit unsupported
  diagnostics.
- Added a successful native output flow test from MethodChannel to Dart stream.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 16 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `make flutter-fake-smoke`: passed, 16 tests.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `flutter build apk --debug`: passed.
- Ran `make flutter-doctor`: passed with no issues.

CocoaPods environment:

- Starting Flutter doctor cleanup for CocoaPods.
- Current state: `flutter doctor -v` reports Android SDK missing and CocoaPods
  missing.
- Current Ruby state: only system Ruby `/usr/bin/ruby` 2.6.10 is active and
  `pod` is not installed.
- Per user instruction, Ruby/CocoaPods work will use `mise` rather than system
  Ruby or direct Homebrew Ruby setup.
- Added repo-local `mise.toml` pinning Ruby 3.4.9.
- Ran `mise trust` for the repo-local config.
- First Ruby build failed because the `psych` extension could not find
  `yaml.h`.
- Installed Homebrew `libyaml` as a Ruby build dependency.
- Re-ran `mise install ruby@3.4.9` with libyaml configured: passed.
- Installed CocoaPods with `mise exec -- gem install cocoapods`: CocoaPods
  1.16.2 installed.
- Verified `mise exec -- pod --version`: 1.16.2.
- Verified a new interactive zsh in this repo resolves Ruby 3.4.9 and
  `pod` 1.16.2 from the `mise` Ruby install.
- Added `make flutter-doctor`, which runs Flutter doctor through `mise exec`
  with the local Flutter SDK on PATH.
- Ran `make flutter-doctor`: Xcode/CocoaPods now passes; Android SDK remains
  the only Flutter doctor issue.
- Re-ran `make flutter-fake-smoke` from an activated zsh: passed, 10 tests.
- Re-ran `flutter build ios --simulator --debug` from an activated zsh: passed.
- Re-ran `flutter build macos --debug` from an activated zsh: passed.
- Re-ran `flutter build web --debug` from an activated zsh: passed.
- Re-ran `git diff --check`: passed.

Android environment:

- Starting Flutter doctor cleanup for Android SDK.
- Current state: `sdkmanager`, `avdmanager`, `adb`, `ANDROID_HOME`, and
  `ANDROID_SDK_ROOT` are absent.
- Current Java state: `mise` provides Java 21.0.2, which is available to this
  repo.
- Homebrew reports `android-commandlinetools` and `android-platform-tools` are
  not installed.
- Installed Homebrew `android-commandlinetools` and `android-platform-tools`.
- Ran `flutter config --android-sdk /opt/homebrew/share/android-commandlinetools`.
- Accepted Android SDK licenses with `sdkmanager --licenses`.
- Installed `platform-tools`, `platforms;android-36`, and `build-tools;36.0.0`.
- Verified installed SDK packages with `sdkmanager --list_installed`.
- Ran `flutter doctor -v`: all categories pass.
- Ran `flutter build apk --debug`: passed. The build installed NDK
  28.2.13676358 and CMake 3.22.1 on demand.
- Re-ran `make flutter-doctor`: passed with no issues.
- Re-ran `make flutter-fake-smoke`: passed, 10 tests.
- Re-ran `make flutter-structure-check`: passed.
- Re-ran `flutter build ios --simulator --debug`: passed.
- Re-ran `flutter build macos --debug`: passed.
- Re-ran `flutter build web --debug`: passed.

Backend capabilities:

- Starting backend capability reporting work.
- Goal for this unit: make backend-supported and explicitly unsupported
  surfaces visible through `EmacsBackend` before adding real platform backends.

Terminal frontend:

- Starting Phase 3 terminal-widget work.
- Goal for this unit: replace the temporary text-buffer terminal renderer with
  a real Flutter terminal widget while preserving the fake backend smoke path.
- Added `xterm` 4.0.0 through `flutter pub add xterm`.
- Updated `TerminalScreen` to render `TerminalView` with an iosmacs terminal
  palette.
- Routed backend output bytes into `Terminal.write`.
- Routed `Terminal.onOutput` back to `EmacsBackend.sendBytes`.
- Kept the existing text input row as a deterministic smoke path for ASCII input
  while hardware keyboard and IME validation remain pending.
- Updated widget tests to assert `TerminalView` presence and fake ASCII input
  diagnostics instead of searching for terminal-rendered text widgets.
- Ran `dart format lib test`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 10 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-fake-smoke`: passed, 10 tests.
- Ran `flutter build macos --debug`: passed.
- Ran `flutter build ios --simulator --debug`: passed.
- Ran `flutter build web --debug`: passed.
- Ran `git diff --check`: passed.

Flutter smoke documentation structure guards:

- Starting smoke documentation structure guard work.
- Goal for this unit: make `make flutter-structure-check` fail if
  `flutter/ARCHITECTURE.md` drops current runtime smoke flags or focused smoke
  target evidence.
- Planned checks: structure check and diff whitespace check.
- Added structure checks for the `flutter/ARCHITECTURE.md` runtime smoke flag
  list and focused smoke target evidence.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter terminal geometry status:

- Starting visible terminal geometry status work.
- Goal for this unit: show the active backend TTY geometry in the Flutter
  status strip and prove resize diagnostics update that visible state.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added a `TTY colsxrows` status label backed by `BackendDiagnostics`.
- Added a widget test proving `backend.resize(cols: 100, rows: 30)` updates
  the visible `TTY 100x30` status text.
- Updated the Flutter structure check to guard the geometry status label and
  widget test.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 46 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter Stop control:

- Starting visible Stop control work.
- Goal for this unit: make backend lifecycle shutdown available from normal
  Flutter UI and hardware keyboard control, not only runtime smoke flags.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Added a visible toolbar `Stop` button wired to `EmacsBackend.stop()`.
- Added Ctrl+Shift+X and Meta+Shift+X shortcuts for backend stop.
- Extended the hardware shortcut widget test to prove stop and restart
  lifecycle transitions.
- Added a dedicated toolbar Stop widget test.
- Updated the Flutter structure check to guard the Stop button wiring, shortcut
  key, and widget coverage.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 47 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter Send input control:

- Starting visible Send input control work.
- Goal for this unit: make committed terminal text sendable from touch/mouse UI
  as well as keyboard submit actions.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Added a visible `Send` icon button beside the terminal input field.
- Routed the Send button through the existing committed-text path so it clears
  the input and forwards UTF-8 text plus carriage return to `EmacsBackend`.
- Added a widget test proving the Send button forwards `send me` and clears the
  input field.
- Updated the Flutter structure check to guard the Send button and widget
  coverage.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 48 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter responsive toolbar:

- Starting narrow-width toolbar work.
- Goal for this unit: keep the growing Flutter toolbar usable on phone-width
  viewports without render overflow while preserving the existing icon controls.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Wrapped the toolbar controls in a horizontal scroll view.
- Replaced the toolbar slider's flex sizing with a stable fixed width so the
  toolbar can scroll instead of overflowing on narrow viewports.
- Added a 320px-wide widget test that verifies the toolbar renders and the
  Start action works without captured Flutter layout exceptions.
- Updated the Flutter structure check to guard the responsive toolbar markers
  and narrow-width widget coverage.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 49 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter app-level narrow smoke:

- Starting app-level narrow-width smoke work.
- Goal for this unit: prove the real `IOSMacsFlutterApp` entrypoint keeps the
  terminal, input, and toolbar controls available on phone-width viewports.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Added an app-level 320px-wide widget smoke using
  `IOSMacsFlutterApp(backendOverride: 'fake')`.
- Verified the app entrypoint still shows the terminal, text input, Start, and
  Send controls on the narrow viewport.
- Verified the app-level Start action reaches the running lifecycle state
  without captured Flutter layout exceptions.
- Updated the Flutter structure check to guard the app-level narrow smoke.
- Ran `dart format test/widget_test.dart`: passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 50 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter toolbar scroll reachability:

- Starting toolbar scroll reachability work.
- Goal for this unit: prove narrow-width users can horizontally scroll the
  toolbar to reach the trailing font-size control.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Added a stable `iosmacs-toolbar-scroll` key to the toolbar's horizontal
  scroll view.
- Added a 320px-wide widget test proving the font-size Slider starts beyond the
  narrow viewport and becomes reachable after horizontal toolbar scrolling.
- Updated the Flutter structure check to guard the toolbar scroll key and
  reachability test.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 51 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter backend status indicator:

- Starting backend status indicator work.
- Goal for this unit: make the selected backend id visible in the status strip
  without requiring the capabilities dialog.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Added a `Backend <id>` indicator to the status strip, sourced from
  `EmacsBackend.capabilities.id`.
- Made the backend id indicator flexible with ellipsis so the status strip does
  not regress narrow-width layout.
- Added widget coverage for fake and Android placeholder backend id visibility
  without opening the capabilities dialog.
- Updated the app startup test to assert the explicit Android backend id rather
  than a broad `android` text match.
- Updated the Flutter structure check to guard the backend id status marker and
  widget coverage.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart test/widget_test.dart`:
  passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 52 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter runtime status smoke:

- Starting runtime status smoke work.
- Goal for this unit: mirror the visible backend id and lifecycle state into
  smoke logs so runtime evidence can identify the selected backend without
  opening the UI.
- Planned checks: Dart format, Flutter tests, backend override smoke, macOS
  native smoke, structure check, and diff whitespace check.
- Added `IOSMACS_FLUTTER_STATUS_SMOKE` from the Flutter app entrypoint through
  `TerminalScreen`.
- Added mirrored status output as `iosmacs-status-smoke: id=... lifecycle=...
  geometry=...` when terminal output mirroring is enabled.
- Included status smoke evidence in the backend override smoke and macOS native
  smoke scripts.
- Added widget coverage for deterministic status smoke execution and visible
  backend id state.
- Updated architecture docs and structure guards for the new smoke flag and
  expected runtime evidence.
- Ran `dart format lib test`: passed, 0 changed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 53 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-backend-override-smoke`: passed for fake, Android, Linux,
  Windows, and Web-WASM placeholder backend overrides.
- Ran `make flutter-macos-native-smoke`: passed with platform native channel
  status smoke evidence.
- Ran `git diff --check`: passed.

Flutter diagnostics details UI:

- Starting diagnostics details UI work.
- Goal for this unit: make the current backend id, lifecycle, geometry, byte
  counters, workspace action count, and diagnostic message available from the
  status strip without opening the capabilities dialog.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Added a status-strip Diagnostics icon that opens a backend diagnostics dialog.
- The dialog shows backend id, lifecycle, terminal geometry, input/output byte
  counts, workspace action count, and the latest diagnostic message.
- Split the status strip into a two-row layout on narrow widths so the new
  diagnostics action does not reintroduce phone-width overflow.
- Added widget coverage for the diagnostics dialog values and guarded the
  diagnostics action in the narrow-width test.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  so the diagnostics details UI remains part of the Flutter shell contract.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed.
- Ran `flutter analyze`: passed.
- Ran `flutter test`: passed, 54 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter workspace import UI:

- Starting workspace import UI work.
- Goal for this unit: expose user-triggered workspace import from the Flutter
  Workspace dialog, while keeping the picker boundary injectable for widget
  tests and platform-specific picker behavior.
- Planned checks: Flutter pub get, Dart format, Flutter analyze, Flutter tests,
  structure check, and diff whitespace check.
- Added the `file_selector` dependency through `flutter pub add file_selector`.
- Added an injectable `WorkspaceImportUriProvider` boundary with
  `pickWorkspaceImportUris()` as the default file-picker implementation.
- Added an Import action to the Workspace dialog that picks files, calls
  `EmacsBackend.importToWorkspace()`, refreshes the visible workspace list, and
  reports the imported count.
- Updated the fake backend worker to include imported file names in subsequent
  workspace listings so UI tests can prove the refresh path.
- Added widget coverage for importing `imported.el` and seeing it appear in the
  Workspace dialog.
- Updated backend worker/backend tests to prove imported fake workspace entries
  are reflected after import.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  to guard the file-picker boundary and Workspace Import action.
- Ran `flutter pub add file_selector`: passed.
- Ran `dart format lib/src/ui/terminal_screen.dart lib/src/ui/workspace_import_picker.dart lib/src/backend/fake_backend_worker.dart test/terminal_screen_test.dart test/fake_backend_worker_test.dart test/fake_emacs_backend_test.dart`:
  passed.
- Ran `flutter test`: passed, 55 tests.
- Ran `flutter analyze`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-macos-smoke`: passed.
- Ran `make flutter-web-smoke`: passed.
- Ran `git diff --check`: passed.

Flutter workspace export results UI:

- Starting workspace export results UI work.
- Goal for this unit: replace the count-only Workspace export Snackbar with a
  dialog that shows the concrete export candidate URIs returned by the backend.
- Planned checks: Dart format, Flutter analyze, Flutter tests, structure check,
  and diff whitespace check.
- Replaced the Workspace Export action's count-only Snackbar with a
  `Workspace export candidates` dialog.
- The export dialog shows the candidate count and each backend-provided URI as
  selectable text so paths remain inspectable.
- Updated widget coverage to prove the fake backend export candidate
  `/workspace/scratch.el` is visible.
- Updated `scripts/check-flutter-structure.sh` to guard the export candidates
  dialog and focused widget test.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed.
- Ran `flutter test`: passed, 55 tests.
- Ran `flutter analyze`: passed.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter workspace import cancel coverage:

- Starting workspace import cancel coverage work.
- Goal for this unit: prove that canceling the file picker keeps the Workspace
  dialog open, leaves entries unchanged, and reports the cancellation without
  calling backend import.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added widget coverage for an empty `workspaceImportUriProvider()` result.
- Verified canceling import keeps the Workspace dialog open, leaves
  `scratch.el` visible, does not add imported entries, reports `Import
  canceled`, and leaves fake backend workspace action count at 0.
- Updated `scripts/check-flutter-structure.sh` to guard the import-cancel
  widget coverage.
- Ran `dart format test/terminal_screen_test.dart`: passed, 0 changed.
- Ran `flutter test`: passed, 56 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter backend override workspace smoke:

- Starting backend override workspace smoke work.
- Goal for this unit: make `make flutter-backend-override-smoke` prove
  workspace list/import/export smoke evidence for every forced backend override
  it launches.
- Planned checks: structure check, backend override runtime smoke, and diff
  whitespace check.
- Enabled `IOSMACS_FLUTTER_WORKSPACE_SMOKE=true` in
  `scripts/run-flutter-backend-override-smoke.sh`.
- Added backend override smoke checks for workspace list, import,
  list-after-import, and export candidate log evidence.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  so backend override smoke documentation and guards include workspace smoke
  output.
- Ran `make flutter-structure-check`: passed.
- Ran `make flutter-backend-override-smoke`: passed for fake, Android, Linux,
  Windows, and Web-WASM placeholder backend overrides with workspace smoke
  checks enabled.
- Ran `git diff --check`: passed.

Flutter analyze verify target:

- Starting Flutter analyze target work.
- Goal for this unit: make Dart static analysis a first-class `make` target and
  include it in `make flutter-verify` before the longer runtime smoke targets.
- Planned checks: `make flutter-analyze`, structure check, and diff whitespace
  check.
- Added `make flutter-analyze` to run `flutter pub get` followed by
  `flutter analyze` in `flutter/iosmacs_flutter`.
- Added `flutter-analyze` to the Makefile phony/help surfaces.
- Included `flutter-analyze` in `make flutter-verify` immediately after
  `flutter-doctor` and before fake tests/runtime smoke targets.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  so the verification contract and structure guard include Flutter analyze.
- Ran `make flutter-analyze`: passed, no analyzer issues.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter format check target:

- Starting Flutter format check target work.
- Goal for this unit: make Dart format drift a first-class `make` verification
  target and include it in `make flutter-verify` before analyze/tests/smokes.
- Planned checks: `make flutter-format-check`, structure check, and diff
  whitespace check.
- Added `make flutter-format-check` to run
  `dart format --set-exit-if-changed lib test` in `flutter/iosmacs_flutter`.
- Added `flutter-format-check` to the Makefile phony/help surfaces.
- Included `flutter-format-check` in `make flutter-verify` immediately after
  `flutter-doctor` and before analyze/tests/runtime smoke targets.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  so the verification contract and structure guard include Dart format check.
- Ran `make flutter-format-check`: passed, 29 files checked and 0 changed.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter workspace refresh action:

- Starting workspace refresh action work.
- Goal for this unit: let users refresh the visible Workspace dialog from the
  backend without closing and reopening it.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added a Refresh action to the Workspace dialog that reloads entries through
  `EmacsBackend.listWorkspace()` without closing the dialog.
- Added widget coverage proving an externally imported fake workspace entry
  appears after Refresh.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  to guard the refresh action and test.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed, 0 changed.
- Ran `flutter test`: passed, 57 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter workspace open action:

- Starting workspace open action work.
- Goal for this unit: let users open a visible Workspace dialog entry by
  forwarding its path to Emacs through the existing terminal input boundary.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added an Open action to each visible Workspace dialog entry.
- The Open action forwards `C-x C-f`, the workspace path, and `RET` to
  `EmacsBackend.sendBytes()`.
- Added widget coverage proving `scratch.el` sends the expected terminal input
  byte count and surfaces an opening snackbar.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  to guard the open action and test.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed, 0 changed.
- Ran `flutter test`: passed, 58 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter workspace open runtime smoke:

- Starting workspace open runtime smoke work.
- Goal for this unit: make startup workspace smokes prove that a visible
  workspace entry can be opened through the same terminal byte path as the UI
  Open action.
- Planned checks: Dart format, Flutter tests, backend override smoke, structure
  check, and diff whitespace check.
- Startup workspace smoke now opens the last visible workspace entry after
  import/list refresh and logs `workspace open requested` evidence with the
  selected path, sent byte count, and backend input total.
- Reused the Workspace dialog Open byte command for smoke execution so UI and
  runtime evidence share the same `C-x C-f <path> RET` path.
- Updated backend override and macOS native smoke scripts to require workspace
  open evidence.
- Updated widget coverage, architecture docs, and structure guards for
  workspace list/import/open/export smoke evidence.
- Ran `dart format lib/src/ui/terminal_screen.dart test/widget_test.dart`:
  passed, 0 changed.
- Ran `flutter test`: passed, 58 tests.
- Ran `flutter test test/widget_test.dart`: passed, 7 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `IOSMACS_FLUTTER_BACKEND_SMOKE_BACKENDS=fake IOSMACS_FLUTTER_BACKEND_OVERRIDE_HOLD_SECONDS=4 make flutter-backend-override-smoke`:
  passed.
- Ran `IOSMACS_FLUTTER_MACOS_NATIVE_HOLD_SECONDS=5 make flutter-macos-native-smoke`:
  passed.
- Ran `git diff --check`: passed.

Flutter terminal paste action:

- Starting terminal paste action work.
- Goal for this unit: let users paste system clipboard text into the Flutter
  terminal path as raw terminal bytes without forcing a carriage return.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added `TerminalInputBridge.pasteText()` for raw UTF-8 terminal paste without
  appending `RET`.
- Added a Paste icon button to the terminal input row, backed by
  `Clipboard.getData(Clipboard.kTextPlain)` in the app.
- Added an injectable clipboard text provider so widget tests can prove paste
  behavior without relying on the platform clipboard channel.
- Added bridge and widget coverage proving pasted Japanese text is counted as
  raw bytes and forwarded to the backend.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  to guard clipboard paste ownership and tests.
- Ran `dart format lib/src/ui/terminal_input_bridge.dart lib/src/ui/terminal_screen.dart test/terminal_input_bridge_test.dart test/terminal_screen_test.dart`:
  passed, 0 changed.
- Ran `flutter test test/terminal_input_bridge_test.dart test/terminal_screen_test.dart`:
  passed, 21 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 60 tests.
- Ran `git diff --check`: passed.

Flutter terminal paste shortcut:

- Starting terminal paste shortcut work.
- Goal for this unit: let hardware-keyboard users paste into the Flutter
  terminal with Ctrl+V and Cmd+V through the same raw byte path as the Paste
  button.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added Ctrl+V and Cmd+V shortcut bindings to call the same
  `_pasteClipboardText()` path as the visible Paste button.
- Added widget coverage proving the paste shortcut forwards injected clipboard
  text as raw UTF-8 bytes and updates backend diagnostics.
- Updated `flutter/ARCHITECTURE.md` and `scripts/check-flutter-structure.sh`
  to guard the paste shortcut surface and test.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed, 0 changed.
- Ran `flutter test test/terminal_screen_test.dart`: passed, 18 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 61 tests.
- Ran `git diff --check`: passed.

Flutter empty clipboard paste coverage:

- Starting empty clipboard paste coverage work.
- Goal for this unit: prove that the Flutter terminal Paste action reports an
  empty clipboard without sending bytes into the backend.
- Planned checks: Dart format, focused Flutter widget test, structure check,
  full Flutter tests, and diff whitespace check.
- Added widget coverage for the empty clipboard Paste path.
- Verified empty paste shows `Clipboard is empty`, leaves backend input byte
  count at zero, and preserves the running fake backend diagnostic message.
- Updated `scripts/check-flutter-structure.sh` to guard the empty clipboard UI
  message and widget coverage.
- Ran `dart format test/terminal_screen_test.dart`: passed, 0 changed.
- Ran `flutter test test/terminal_screen_test.dart`: passed, 19 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 62 tests.
- Ran `git diff --check`: passed.

Flutter empty paste shortcut coverage:

- Starting empty paste shortcut coverage work.
- Goal for this unit: prove that Ctrl+V on an empty clipboard follows the same
  no-input path as the visible Paste button.
- Planned checks: Dart format, focused Flutter widget test, structure check,
  full Flutter tests, and diff whitespace check.
- Added widget coverage for Ctrl+V with an empty clipboard.
- Verified empty shortcut paste shows `Clipboard is empty`, leaves backend
  input byte count at zero, and preserves the running fake backend diagnostic
  message.
- Updated `scripts/check-flutter-structure.sh` to guard the empty paste
  shortcut test.
- Ran `dart format test/terminal_screen_test.dart`: passed, 0 changed.
- Ran `flutter test test/terminal_screen_test.dart`: passed, 20 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `flutter test`: passed, 63 tests.
- Ran `git diff --check`: passed.

Flutter imported workspace export candidates:

- Starting imported workspace export candidate work.
- Goal for this unit: make fake backend export candidates reflect imported
  workspace entries, then prove the Flutter Workspace dialog can import a file
  and export it as a visible candidate.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Updated `FakeBackendWorker` so export candidates are derived from the current
  fake workspace entries instead of always returning only `scratch.el`.
- Extended fake worker and fake backend tests to prove imported entries are
  included in exported URI candidates.
- Extended the Workspace dialog widget test to import `imported.el`, export
  immediately, and verify both `/workspace/scratch.el` and
  `/workspace/imported.el` are visible candidates.
- Updated `scripts/check-flutter-structure.sh` to guard the refreshed
  import/export widget coverage.
- Ran `dart format lib/src/backend/fake_backend_worker.dart test/fake_backend_worker_test.dart test/fake_emacs_backend_test.dart test/terminal_screen_test.dart`:
  passed, 0 changed.
- Ran `flutter test`: passed, 56 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.

Flutter diagnostics keyboard shortcut:

- Starting diagnostics keyboard shortcut work.
- Goal for this unit: let keyboard users open the backend diagnostics dialog
  from the terminal screen using the same Ctrl/Cmd+Shift shortcut pattern as
  the other toolbar/status actions.
- Planned checks: Dart format, Flutter tests, structure check, and diff
  whitespace check.
- Added Ctrl+Shift+D and Cmd+Shift+D bindings to open backend diagnostics.
- Extended the hardware shortcut widget test to prove the diagnostics dialog
  opens from the keyboard path.
- Updated `scripts/check-flutter-structure.sh` to guard the diagnostics
  shortcut key marker.
- Ran `dart format lib/src/ui/terminal_screen.dart test/terminal_screen_test.dart`:
  passed, 0 changed.
- Ran `flutter test`: passed, 56 tests.
- Ran `make flutter-structure-check`: passed.
- Ran `git diff --check`: passed.
