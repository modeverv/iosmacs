# iosmacs Flutter Plan

## Purpose

`flutter/` is the planning area for turning iosmacs into a cross-platform
Flutter application while keeping the existing Xcode/Swift implementation
intact.

The goal is not to rewrite everything at once. The first goal is to place a
Flutter shell beside the current app, prove a terminal UI with a fake backend,
then connect the existing iOS native Emacs backend through a stable Dart
interface.

Target platforms:

- iOS
- Android
- macOS
- Windows
- Linux
- Web

## Direction

Build a Flutter shell beside the existing Xcode app.

- Keep the current `iosmacs.xcodeproj` and SwiftUI/SwiftTerm app working.
- Create a new Flutter app under this area or a child directory such as
  `flutter/iosmacs_flutter`.
- Start with a fake backend that emits terminal bytes and accepts input.
- Use that fake backend to validate terminal rendering, keyboard input,
  lifecycle state, resize events, and diagnostics before touching the native
  Emacs bridge.

## Phase 1: Flutter Shell

Goal: create a Flutter application that can run without the native Emacs core.

Current TODO:

- [x] Record this Flutter workstream in `flutter/LOG.md`.
- [x] Scaffold `flutter/iosmacs_flutter` without changing the existing native
  Xcode app.
- [x] Add a first-screen terminal UI, not a landing page.
- [x] Add lifecycle and diagnostics display.
- [x] Add controls for start, reset/redraw, font-size, and workspace actions.
- [x] Define the Dart `EmacsBackend` interface.
- [x] Implement a fake backend with deterministic output, input echo, resize
  reporting, lifecycle state, and workspace placeholders.
- [x] Add widget/unit tests that exercise fake backend startup, input bytes,
  resize, output, and workspace placeholder behavior.
- [x] Add `make flutter-fake-smoke` at the repository root.
- [x] Add an app-level backend selection boundary so the UI can depend on
  `EmacsBackend` without constructing concrete backend classes.
- [x] Add structured fake-backend diagnostics for lifecycle, terminal geometry,
  byte counts, and workspace placeholder actions.
- [x] Add tests for backend selection and structured diagnostics.
- [x] Add an SDK-independent Flutter structure check for the current shell.
- [x] Add a reproducible Flutter SDK bootstrap target for generated platform
  runners.
- [x] Install Flutter SDK under `~/work/flutter` and expose it through
  `~/.zshrc`.
- [x] Verify with `flutter test` and `make flutter-fake-smoke`.
- [x] Generate iOS, Android, macOS, Linux, Windows, and Web runner files with
  `make flutter-bootstrap`.
- [x] Verify `flutter analyze`.
- [x] Verify macOS debug build.
- [x] Verify Web debug build.
- [x] Verify iOS simulator debug build.
- [x] Launch the Flutter app briefly on macOS and iPad simulator.
- [x] Add a backend worker command/event boundary behind `EmacsBackend`.
- [x] Move fake backend terminal/lifecycle/workspace behavior behind that
  worker boundary.
- [x] Add tests that prove the fake worker command/event contract.
- [x] Add `xterm.dart` or equivalent real Flutter terminal frontend.
- [x] Route backend output bytes into the terminal widget.
- [x] Route committed terminal input bytes back through `EmacsBackend.sendBytes`.
- [x] Keep a smoke-testable fake backend ASCII path.
- [x] Install Ruby through `mise` for Flutter iOS/macOS tooling.
- [x] Install CocoaPods through the `mise` Ruby gem environment.
- [x] Re-run `flutter doctor` and clear the CocoaPods warning.
- [x] Install Android command line tools and platform tools.
- [x] Configure Flutter's Android SDK path.
- [x] Accept Android SDK licenses.
- [x] Install Android SDK packages needed for Flutter Android debug builds.
- [x] Re-run `flutter doctor` and clear the Android SDK warning.
- [x] Add backend capability reporting to `EmacsBackend`.
- [x] Show backend capabilities and explicit unsupported surfaces in the
  Flutter UI.
- [x] Test fake backend capability reporting.
- [x] Add an iOS native backend selection path behind the Dart backend factory.
- [x] Add a Flutter MethodChannel boundary for the future native Emacs bridge.
- [x] Make the native backend fail explicitly until the Emacs core bridge is
  connected.
- [x] Test native backend selection and unsupported diagnostics.
- [x] Add a native channel diagnostic bridge that returns successful lifecycle,
  output, input, and resize responses.
- [x] Drain native channel output into the Flutter terminal stream.
- [x] Test successful native channel output flow.
- [x] Compile the shared C host facade into the Flutter iOS Runner.
- [x] Route Flutter native bridge output/input/resize through the shared host
  terminal facade.
- [x] Verify iOS Runner still builds with the shared facade linked.
- [x] Compile the shared Emacs diagnostic/core availability sources into the
  Flutter iOS Runner.
- [x] Start the shared diagnostic terminal from the Flutter native bridge.
- [x] Keep real GNU Emacs core startup explicitly pending until the simulator
  archive/link step is ported.
- [x] Link the simulator Emacs static archive entry into the Flutter iOS Runner.
- [x] Remove the Flutter Runner optional-entry fallback once the archive entry
  resolves.
- [x] Verify Flutter iOS simulator build with `iosmacs_emacs_main` linked.
- [x] Bundle Emacs runtime resources into the Flutter iOS Runner.
- [x] Start linked GNU Emacs from the Flutter native channel when resources are
  present.
- [x] Keep diagnostic fallback explicit when Flutter native resources/startup
  are unavailable.
- [x] Verify Flutter iOS simulator build after native resource/startup wiring.
- [x] Replace Flutter native workspace placeholders with app-container file
  operations.
- [x] Parse native workspace entries and export URLs in the Dart backend.
- [x] Verify native workspace MethodChannel behavior with Flutter tests.
- [x] Replace the Flutter workspace count snackbar with a visible workspace
  contents dialog.
- [x] Add a UI path that calls `exportWorkspaceSelection()` and reports export
  candidates.
- [x] Verify workspace UI behavior with widget tests.
- [x] Add a repeatable `make flutter-ios-smoke` target for Flutter iOS Runner
  build evidence.
- [x] Verify the Flutter iOS Runner app bundle contains Emacs resources.
- [x] Verify the Flutter iOS Runner debug dylib resolves
  `_iosmacs_emacs_main`.
- [x] Add a repeatable `make flutter-ios-launch-smoke` target.
- [x] Verify the Flutter iOS Runner installs and launches on a booted
  simulator.
- [x] Verify the Flutter iOS Runner remains alive long enough to terminate
  cleanly.
- [x] Add a repeatable `make flutter-macos-smoke` target.
- [x] Verify the Flutter macOS app builds and launches as a desktop app.
- [x] Verify the Flutter macOS app remains alive long enough to terminate
  cleanly.
- [x] Add a repeatable `make flutter-verify` target for the Flutter workstream.
- [x] Run Flutter structure, doctor, fake backend, iOS launch, and macOS smoke
  checks through `make flutter-verify`.
- [x] Add repeatable `make flutter-web-smoke` and `make flutter-android-smoke`
  targets.
- [x] Include Web debug and Android APK debug builds in `make flutter-verify`.
- [x] Add a macOS native MethodChannel backend selection path behind the Dart
  backend factory.
- [x] Add a macOS Runner native channel bridge with explicit process-backend
  pending diagnostics.
- [x] Verify macOS native channel selection and diagnostics with Flutter tests
  and macOS smoke.
- [x] Add a macOS native Emacs process probe behind the Flutter MethodChannel.
- [x] Surface native channel status details in Dart diagnostics.
- [x] Verify macOS process-probe wiring without regressing Flutter
  verification.
- [x] Add a repeatable macOS native process-probe runtime smoke.
- [x] Add Flutter smoke controls for autostarting native backend and mirroring
  terminal output to process logs.
- [x] Include the macOS native process-probe smoke in Flutter verification.
- [x] Replace macOS native workspace pending errors with Application Support
  workspace file operations.
- [x] Expose macOS workspace list/import/export as supported backend behavior.
- [x] Verify macOS workspace bridge wiring without regressing Flutter
  verification.
- [x] Add a macOS workspace runtime smoke that exercises MethodChannel
  list/export calls.
- [x] Mirror workspace smoke results into the app process log.
- [x] Include macOS workspace runtime evidence in Flutter verification.
- [x] Extend the macOS workspace runtime smoke to exercise MethodChannel
  import/list/export together.
- [x] Keep workspace import smoke file creation out of Web builds.
- [x] Verify workspace import runtime evidence through `make flutter-verify`.
- [x] Add an explicit Flutter Web WASM-route placeholder backend.
- [x] Select the Web placeholder backend by default on Flutter Web.
- [x] Verify Web placeholder capabilities and Web debug build.
- [x] Add an explicit Flutter Android backend.
- [x] Select the Android backend by default on Android.
- [x] Verify Android native-channel capabilities and Android debug APK build.
- [x] Add explicit Flutter Linux and Windows desktop backend placeholders.
- [x] Select Linux and Windows placeholders by default on those platforms.
- [x] Verify desktop placeholder capabilities without regressing
  `make flutter-verify`.
- [x] Show backend ids and capability counts in the Flutter capabilities UI.
- [x] Add widget coverage for non-fake backend capabilities dialogs.
- [x] Verify capabilities UI changes without regressing `make flutter-verify`.
- [x] Add a Flutter runtime capabilities smoke flag.
- [x] Mirror selected backend capability identity/counts into macOS native smoke
  logs.
- [x] Verify runtime capabilities smoke through `make flutter-verify`.
- [x] Add a dart-define backend override for Flutter runtime smoke/debug runs.
- [x] Test explicit backend override parsing and app construction.
- [x] Verify backend override support without regressing `make flutter-verify`.
- [x] Add a repeatable Flutter backend override runtime smoke target.
- [x] Launch forced fake, Android, Linux, Windows, and Web placeholder backends
  through the macOS Runner.
- [x] Include backend override runtime smoke in `make flutter-verify`.
- [x] Sync `flutter/ARCHITECTURE.md` with the implemented Flutter backend
  boundary.
- [x] Document current Flutter smoke and backend override verification commands.
- [x] Verify architecture documentation sync with structure and diff checks.
- [x] Add a Flutter terminal input bridge for backend byte forwarding.
- [x] Prove xterm hardware/control-key output and IME-committed text are sent
  as UTF-8 bytes.
- [x] Verify the input bridge work with format, tests, structure check, and
  diff check.
- [x] Add Flutter app-level hardware keyboard shortcuts for terminal controls.
- [x] Test Start, Reset, Workspace, Capabilities, and font-size shortcuts.
- [x] Verify keyboard shortcut work with format, analyze, tests, structure
  check, and diff check.
- [x] Add a Flutter runtime input smoke flag for committed text forwarding.
- [x] Include input smoke evidence in macOS native and backend override smokes.
- [x] Verify runtime input smoke with tests, structure check, targeted smokes,
  and diff check.
- [x] Add a Flutter runtime resize smoke flag for terminal geometry forwarding.
- [x] Include resize smoke evidence in macOS native and backend override smokes.
- [x] Verify runtime resize smoke with tests, structure check, targeted smokes,
  and diff check.
- [x] Add a Flutter runtime redraw smoke flag for reset/redraw forwarding.
- [x] Include redraw smoke evidence in macOS native and backend override smokes.
- [x] Verify runtime redraw smoke with tests, structure check, targeted smokes,
  and diff check.
- [x] Add a Flutter runtime stop smoke flag for lifecycle stop forwarding.
- [x] Include stop smoke evidence in macOS native and backend override smokes.
- [x] Verify runtime stop smoke with tests, structure check, targeted smokes,
  and diff check.
- [x] Sync Flutter architecture docs with the current runtime smoke flag set.
- [x] Document and guard Flutter Emacs build output isolation under
  `flutter/build/emacs-ios`.
- [x] Prevent Flutter iOS Runner references from regressing to the root
  `build/emacs-ios-probe` path.
- [x] Verify build-output isolation guards with structure and diff checks.
- [x] Make Flutter native-platform backend autostart defaults testable.
- [x] Verify iOS/macOS autostart defaults and Web/Android placeholder defaults.
- [x] Guard native autostart default behavior in the Flutter structure check.
- [x] Document input, resize, redraw, stop, capabilities, workspace, and backend
  override smoke evidence.
- [x] Verify smoke documentation sync with structure and diff checks.
- [x] Add structure-check guards for Flutter architecture smoke documentation.
- [x] Guard all current runtime smoke flags and focused smoke target
  descriptions in `flutter/ARCHITECTURE.md`.
- [x] Verify architecture smoke documentation guards with structure and diff
  checks.
- [x] Add a visible Flutter terminal geometry status indicator.
- [x] Test that backend resize diagnostics update the visible TTY geometry.
- [x] Verify terminal geometry status work with format, tests, structure check,
  and diff check.
- [x] Add a visible Flutter Stop control for backend lifecycle shutdown.
- [x] Add and test a hardware keyboard shortcut for Stop.
- [x] Verify Stop control work with format, analyze, tests, structure check,
  and diff check.
- [x] Add a visible Send control for Flutter terminal text input.
- [x] Test that the Send control forwards committed text through the backend.
- [x] Verify Send control work with format, analyze, tests, structure check,
  and diff check.
- [x] Make the Flutter toolbar usable on narrow mobile widths.
- [x] Add a widget test that guards the toolbar against narrow-width overflow.
- [x] Verify responsive toolbar work with format, analyze, tests, structure
  check, and diff check.
- [x] Replace the macOS native backend's process-probe-only path with a held
  GNU Emacs child process behind the shared MethodChannel.
- [x] Route macOS native `sendBytes`, redraw, output drain, and stop through
  the held Emacs process instead of the old pending diagnostic.
- [x] Update macOS native smoke evidence so hosts with Emacs must prove
  interactive process startup rather than accepting the old PTY-pending path.
- [x] Add an app-level narrow-width Flutter smoke test.
- [x] Verify `IOSMacsFlutterApp` keeps terminal, input, and toolbar controls
  available on phone-width viewports.
- [x] Verify app-level narrow smoke work with format, analyze, tests,
  structure check, and diff check.
- [x] Add explicit Flutter toolbar scroll reachability coverage.
- [x] Verify narrow-width users can scroll to the toolbar font-size control.
- [x] Verify toolbar scroll reachability work with format, analyze, tests,
  structure check, and diff check.
- [x] Add a visible backend id indicator to the Flutter status strip.
- [x] Test that fake and placeholder backends expose their ids without opening
  the capabilities dialog.
- [x] Verify backend status indicator work with format, analyze, tests,
  structure check, and diff check.
- [x] Add a Flutter runtime status smoke flag for backend id/lifecycle
  visibility.
- [x] Include status smoke evidence in macOS native and backend override
  smokes.
- [x] Verify status smoke work with tests, targeted smokes, structure check,
  and diff check.
- [x] Add a visible Flutter diagnostics details action from the status strip.
- [x] Show backend id, lifecycle, geometry, byte counts, workspace actions, and
  diagnostic message in the details UI.
- [x] Verify diagnostics details work with tests, structure check, and diff
  check.
- [x] Add a Flutter workspace Import action backed by a file-picker boundary.
- [x] Route selected file URIs through `EmacsBackend.importToWorkspace()` and
  refresh the visible workspace dialog.
- [x] Verify workspace import UI work with tests, structure check, and diff
  check.
- [x] Replace the Workspace export count-only Snackbar with a visible export
  candidate dialog.
- [x] Show exported URI candidates from `EmacsBackend.exportWorkspaceSelection()`
  without hiding the backend paths.
- [x] Verify workspace export results UI with tests, structure check, and diff
  check.
- [x] Add widget coverage for canceled Flutter workspace imports.
- [x] Keep the Workspace dialog open and entries unchanged when the import
  picker returns no files.
- [x] Verify import-cancel coverage with tests, structure check, and diff
  check.
- [x] Add a Flutter diagnostics keyboard shortcut alongside the visible
  Diagnostics status-strip action.
- [x] Open backend diagnostics with Ctrl/Cmd+Shift+D without changing backend
  lifecycle state.
- [x] Verify diagnostics shortcut work with tests, structure check, and diff
  check.
- [x] Include imported fake workspace entries in export candidates.
- [x] Prove imported files can be listed and exported through the Flutter
  Workspace dialog.
- [x] Verify imported export candidates with backend tests, widget tests,
  structure check, and diff check.
- [x] Enable workspace smoke evidence in Flutter backend override runtime
  smokes.
- [x] Check forced fake, Android, Linux, Windows, and Web-WASM backends for
  workspace list/import/export smoke logs.
- [x] Verify backend override workspace smoke with structure check, targeted
  runtime smoke, and diff check.
- [x] Add a repeatable `make flutter-analyze` target for Dart static analysis.
- [x] Include Flutter analyze in `make flutter-verify` before runtime smoke
  targets.
- [x] Verify analyze target wiring with structure check, targeted make
  commands, and diff check.
- [x] Add a repeatable `make flutter-format-check` target for Dart formatting
  drift.
- [x] Include Flutter format check in `make flutter-verify` before analyze and
  runtime smoke targets.
- [x] Verify format target wiring with structure check, targeted make
  commands, and diff check.
- [x] Add a Workspace Refresh action to the Flutter Workspace dialog.
- [x] Reload visible workspace entries from `EmacsBackend.listWorkspace()`
  without closing the dialog.
- [x] Verify workspace refresh with widget tests, structure check, and diff
  check.
- [x] Add a Workspace Open action for visible Flutter workspace entries.
- [x] Send the selected workspace path through the terminal input bridge as
  `C-x C-f <path> RET`.
- [x] Verify workspace open with widget tests, structure check, and diff check.
- [x] Add Workspace Open evidence to Flutter startup workspace smokes.
- [x] Require workspace open smoke logs in macOS native and backend override
  smoke scripts.
- [x] Verify workspace open smoke with widget tests, structure check, targeted
  runtime smoke, and diff check.
- [x] Add a Flutter terminal Paste action backed by the system clipboard.
- [x] Route pasted text as UTF-8 terminal bytes without appending a final
  `RET`, while normalizing pasted line feeds to terminal carriage returns.
- [x] Verify paste behavior with bridge tests, widget tests, structure check,
  and diff check.
- [x] Fix multiline Paste/Send so pasted line feeds do not arrive as Emacs
  `C-j` and trigger `eval-print-last-sexp` in Lisp Interaction mode.
- [x] Speed up Flutter iOS paste by bulk-reading available terminal input from
  the native ring instead of reading one byte at a time in Emacs.
- [x] Try a Flutter iOS Emacs `-O3 -g` static archive build for paste
  throughput, and verify it still passes native smoke with extended relaunch
  timing.
- [x] Speed up Flutter iOS paste display by decoupling `sendBytes` from output
  drain completion, draining native output every frame, and increasing native
  drain chunks from 16KB to 256KB.
- [x] Add Ctrl/Cmd+V hardware keyboard shortcuts for Flutter terminal paste.
- [x] Route paste shortcuts through the same clipboard provider and raw-byte
  input path as the visible Paste action.
- [x] Verify paste shortcuts with widget tests, structure check, and diff check.
- [x] Add widget coverage for empty Flutter terminal clipboard paste.
- [x] Verify empty paste shows feedback without sending backend input bytes.
- [x] Guard empty paste behavior with structure check and diff check.
- [x] Add widget coverage for empty Flutter terminal paste shortcuts.
- [x] Verify Ctrl+V empty paste shows feedback without sending backend input
  bytes.
- [x] Guard empty paste shortcut behavior with structure check and diff check.
- [x] Add Flutter iOS native runtime smoke harness for mirrored logs.
- [x] Prove Flutter iOS reaches the real `*scratch*` terminal frame.
- [x] Prove Flutter iOS terminal input inserts into `*scratch*`.
- [x] Prove Flutter iOS can save, reopen, and Dired-list workspace files.
- [x] Prove Flutter iOS relaunch-persist workspace files.
- [x] Fix Flutter iOS terminal geometry so mode lines do not wrap after smoke
  resize checks.
- [x] Fix Japanese committed input so it is not sent twice.
- [x] Restore `M-x dired` and `M-x tetris` command discovery in the bundled
  runtime.
- [x] Fix terminal-body Japanese IME duplicate chunks, not only the visible
  Send text-field path.
- [x] Strengthen the Flutter iOS `M-x dired` / `M-x tetris` smoke to verify
  command completion candidates, not only `commandp`.
- [x] Bind `M-X` to the ordinary `M-x` command path on bundled iOS Emacs so
  shifted/meta keyboard input does not use buffer-filtered command completion.
- [x] Add Flutter iOS support for selecting an arbitrary iPadOS/iCloud folder
  and using it as Emacs `/home/user` via a security-scoped bookmark.
- [x] Link the native iOS URLSession network bridge into the Flutter iOS Runner
  so Emacs `url.el` requests work from the Flutter app.
- [x] Verify Flutter iOS `/home/user` folder selection and network bridge work
  with tests, structure check, native smoke, and an Emacs HTTPS marker.
- [x] Commit the completed Flutter iOS tty/paste performance work before
  starting the next input fixes.
- [x] Fix Flutter iOS `C-SPC` so Emacs receives NUL for `set-mark-command`
  instead of a plain space.
- [x] Route ordinary iOS hardware text keys through `UITextView` text input so
  Japanese IME composition is not preempted by the native terminal key shim.
- [x] Verify the Japanese IME and `C-SPC` fixes with Flutter tests, structure
  check, and an iOS Simulator build.
- [x] Restore inline Japanese IME composition by keeping normal terminal text
  input on Flutter `TerminalView` instead of the hidden native `UITextView`.
- [x] Verify inline Japanese IME composition with a Flutter terminal-body
  composing/commit widget test, structure check, and iOS Simulator build.
- [x] Enable iOS Japanese IME candidate UI by using the normal text keyboard
  type for the terminal body instead of the email-address keyboard profile.
- [x] Verify terminal-body keyboard type coverage with Flutter tests,
  structure check, and iOS Simulator build.
- [x] Stop platform stderr logs such as CoreText diagnostics from entering the
  Flutter Emacs terminal screen.
- [x] Verify the stderr isolation with structure check and an iOS Simulator
  build/install smoke.
- [x] Boost held hardware-key repeat throughput in the Flutter terminal so one
  repeat event sends multiple terminal input units.
- [x] Verify boosted key repeat with Flutter widget tests, structure check, and
  an iOS Simulator build.
- [x] Enable full Flutter terminal pointer forwarding so Emacs xterm mouse
  reporting can receive taps, drags, moves, and scrolls.
- [x] Verify mouse-reporting configuration with Flutter widget tests,
  structure check, and an iOS Simulator build.
- [ ] Make Flutter iOS build, install, and run on a physical iPad/iPhone with
  documented signing and device smoke evidence.

SDK verification steps:

```sh
cd flutter/iosmacs_flutter
flutter pub get
flutter test
flutter run -d macos
flutter run -d "iPhone 16 Pro"
cd ../..
make flutter-bootstrap
make flutter-fake-smoke
make flutter-structure-check
```

Current verification status:

- Flutter SDK is installed at `~/work/flutter`.
- A new interactive zsh resolves `flutter` from `/Users/seijiro/work/flutter/bin/flutter`.
- `flutter --version`: Flutter 3.44.4 stable, Dart 3.12.2.
- `make flutter-structure-check` passes without requiring the Flutter SDK.
- `make flutter-bootstrap` generated platform runner files.
- `make flutter-fake-smoke` passes.
- `flutter analyze` passes.
- `flutter build macos --debug` passes.
- `flutter build web --debug` passes.
- `flutter build ios --simulator --debug` passes.
- `make flutter-ios-smoke` passes and checks the Flutter iOS Runner bundle
  resources plus linked Emacs core symbols.
- `make flutter-ios-launch-smoke` passes and proves the Flutter iOS Runner can
  install, launch, stay alive briefly, and terminate on a booted simulator.
- `make flutter-ios-native-smoke` passes and proves the Flutter iOS Runner can
  start linked GNU Emacs, reach `*scratch*`, insert input, save and reopen a
  file under `/home/user`, Dired-list it, and preserve it across relaunch.
- Flutter iOS now exposes Workspace dialog controls to select an arbitrary
  iPadOS/iCloud folder as `/home/user` and to return to the default workspace.
- Flutter iOS now links the native URLSession bridge; a manual Emacs smoke
  fetched `https://example.com` with `url-retrieve-synchronously` and wrote
  `iosmacs-flutter-network-ok` under `/home/user`.
- `make flutter-macos-smoke` passes and proves the Flutter macOS app can build,
  launch briefly, stay alive, and terminate cleanly.
- macOS non-web now selects the native MethodChannel backend by default, and
  the macOS Runner starts a held GNU Emacs child process through the shared
  byte-stream backend.
- `make flutter-web-smoke` passes and builds Flutter Web debug output.
- `make flutter-android-smoke` passes and builds the Flutter Android debug APK.
- `make flutter-verify` passes and runs the Flutter structure, doctor, fake
  backend, iOS launch, macOS smoke, macOS native workspace smoke, Web debug,
  and Android debug APK checks sequentially.
- Android non-web now selects an explicit Android native-channel backend by
  default. The Android Runner registers `iosmacs/native_emacs`, supports
  lifecycle/input/resize/output drain plus app-private workspace
  list/import/export, and still reports the Android NDK GNU Emacs terminal
  bridge as the next unsupported surface.
- Linux and Windows non-web now select explicit desktop backend placeholders by
  default, with unsupported process/PTY, file picker, byte-stream, and packaged
  runtime surfaces reported through backend capabilities and diagnostics.
- The capabilities dialog now shows the backend id and supported/unsupported
  item counts, with widget coverage proving Android, Linux, and Windows
  placeholder capabilities are visible through the same UI path.
- `IOSMACS_FLUTTER_CAPABILITIES_SMOKE` now mirrors selected backend capability
  identity/counts into runtime smoke logs, and macOS native smoke verifies the
  selected `platform-native-channel` backend.
- `IOSMACS_FLUTTER_BACKEND` can force a backend for smoke/debug builds, with
  tests covering explicit fake, native, Web, Linux, and Windows selection plus
  unknown-name fallback to the platform default.
- `make flutter-backend-override-smoke` now launches forced fake, Android,
  Linux, Windows, and Web placeholder backends through the macOS Runner and
  checks runtime capability ids/counts.
- `flutter run -d macos --debug` launched to a Dart VM Service and was stopped.
- `flutter run -d D0F9B2BE-1CD0-49D6-BC25-6FF7650031D6 --debug` launched on
  the iPad simulator to a Dart VM Service and was stopped.
- `make flutter-doctor` now reports no issues.
- System Ruby is `/usr/bin/ruby` 2.6.10; project-local Ruby should be provided
  through `mise` before installing CocoaPods.
- `mise.toml` pins Ruby 3.4.9 for this repo.
- CocoaPods 1.16.2 is installed in the Ruby 3.4.9 gem environment.
- `make flutter-doctor` reports Flutter, Android, Xcode/CocoaPods, Chrome,
  connected devices, and network resources as passing.

Android environment TODO:

- Install Android SDK command line tools.
- Install Android platform tools.
- Configure Flutter with the Android SDK root.
- Accept Android licenses.
- Install the minimum SDK packages needed for a Flutter Android debug build.
- Verify `flutter doctor` and `flutter build apk --debug`.

Android environment status:

- Installed Homebrew `android-commandlinetools` and `android-platform-tools`.
- Flutter Android SDK path is `/opt/homebrew/share/android-commandlinetools`.
- Installed `platform-tools`, `platforms;android-36`, and `build-tools;36.0.0`.
- Accepted Android SDK licenses.
- Android debug build installed NDK 28.2.13676358 and CMake 3.22.1 on demand.
- `flutter build apk --debug` passes.
- `make flutter-doctor` reports no issues.

Backend capability TODO:

- [x] Add a Dart capability model for backend identity, supported features, and
  unsupported features.
- [x] Expose capabilities from `EmacsBackend`.
- [x] Give the fake backend explicit capabilities instead of relying on implicit
  behavior.
- [x] Surface capabilities from the terminal UI without adding editor semantics to
  Dart.
- [x] Test fake backend capability values.

Backend capability status:

- `BackendCapabilities` exposes backend identity, supported features, and
  unsupported features.
- `FakeEmacsBackend` reports deterministic fake-supported behavior and explicit
  unsupported native/runtime surfaces.
- The terminal toolbar exposes a Capabilities dialog.
- Tests cover fake capability values and UI display of unsupported surfaces.

iOS native backend channel TODO:

- [x] Add a Dart `NativeEmacsBackend` that implements `EmacsBackend` through a
  Flutter MethodChannel.
- [x] Add backend factory selection for the iOS native backend while preserving
  fake backend defaults on non-iOS test/development platforms.
- [x] Add an iOS Runner MethodChannel handler that returns explicit
  not-connected diagnostics until the existing native Emacs bridge is wired in.
- [x] Test native backend capabilities, selection, and unsupported start
  diagnostics.

iOS native backend channel status:

- `NativeEmacsBackend` implements the shared Dart `EmacsBackend` API over the
  `iosmacs/native_emacs` MethodChannel.
- `createDefaultEmacsBackend` selects the native channel backend only for iOS
  non-web targets; fake remains the default elsewhere.
- The iOS Runner channel currently returns `native_emacs_not_connected` for
  supported method names, so native bridge gaps are visible in lifecycle,
  diagnostics, and terminal output instead of failing silently.
- Tests cover native backend capabilities, factory selection, and unsupported
  start diagnostics.

iOS native channel diagnostic bridge TODO:

- [x] Add a Runner-side native channel bridge that handles start, stop, redraw,
  sendBytes, resize, and drainOutput without requiring the Emacs core yet.
- [x] Update `NativeEmacsBackend` to drain successful native output into
  `outputStream`.
- [x] Keep unsupported diagnostics for missing channel handlers and native
  platform errors.
- [x] Test successful native output flow from MethodChannel to Dart stream.

iOS native channel diagnostic bridge status:

- `FlutterNativeEmacsBridge` is compiled into the iOS Runner target.
- The bridge handles start, stop, redraw, sendBytes, resize, workspace
  placeholders, and drainOutput.
- `NativeEmacsBackend` drains native output after successful operations and
  polls while running.
- Flutter tests cover successful native output flow and missing/native-error
  unsupported diagnostics.

Shared host facade TODO:

- [x] Add `iosmacs/Host/iosmacs_host_facade.c` to the Flutter iOS Runner target.
- [x] Expose `iosmacs_host_facade.h` through the Runner bridging header.
- [x] Replace the Runner-local Swift output buffer with
  `iosmacs_os_terminal_write` / `iosmacs_os_terminal_drain_output`.
- [x] Route Flutter input and resize calls through
  `iosmacs_os_terminal_push_input` and `iosmacs_os_terminal_resize`.
- [x] Build the Flutter iOS simulator target with the shared facade linked.

Shared host facade status:

- The Flutter iOS Runner target compiles `iosmacs_host_facade.c`.
- `Runner-Bridging-Header.h` exposes the shared C facade to Swift.
- `FlutterNativeEmacsBridge` now writes output, drains output, pushes input, and
  applies resize through the shared facade.
- The Flutter iOS simulator build proves the shared facade is linked into the
  Runner target.

Shared diagnostic terminal TODO:

- [x] Add `iosmacs_emacs_diagnostic.c` and `iosmacs_emacs_core.c` to the
  Flutter iOS Runner target.
- [x] Expose `iosmacs_emacs_diagnostic.h` and `iosmacs_emacs_core.h` through
  the Runner bridging header.
- [x] Start `iosmacs_emacs_diagnostic_start()` from `FlutterNativeEmacsBridge`
  instead of using a duplicate Swift banner.
- [x] Pump `iosmacs_emacs_diagnostic_pump()` after Flutter input bytes.
- [x] Preserve explicit pending status for real GNU Emacs startup until the
  simulator static archive/link step is ported to the Flutter Runner.

Shared diagnostic terminal status:

- The Flutter iOS Runner compiles the shared diagnostic, core availability, host
  facade, and terminal shim C sources.
- The Flutter native bridge starts the shared diagnostic terminal and pumps it
  after input bytes.
- `iosmacs_emacs_core.c` supports an optional-entry build mode so the Flutter
  Runner can report real GNU Emacs startup as pending without failing to link.
- The existing native iOS app still builds with the strong simulator Emacs entry
  link.

Flutter simulator Emacs archive link TODO:

- [x] Force the Flutter iOS Runner simulator link to resolve
  `_iosmacs_emacs_main` from `libiosmacs-temacs.a`.
- [x] Remove `IOSMACS_EMACS_CORE_ENTRY_OPTIONAL=1` from the Flutter Runner
  target once the archive entry resolves.
- [x] Keep the existing native iOS app strong-link path working.
- [x] Verify the Flutter iOS simulator build and existing native app build.

Flutter simulator Emacs archive link status:

- The Flutter iOS Runner simulator build forces `_iosmacs_emacs_main` to be
  resolved from `libiosmacs-temacs.a`.
- The Runner target is arm64-only for the simulator, matching the existing
  arm64 static Emacs archive.
- `Runner.debug.dylib` exports `_iosmacs_emacs_main` and
  `_iosmacs_emacs_core_link_available`.
- The existing native iOS app still builds with the same shared core source.

Flutter native Emacs resource/startup TODO:

- [x] Add `lisp`, `etc`, `lib-src`, and `emacs.pdmp` as Flutter iOS Runner
  bundle resources.
- [x] Update `FlutterNativeEmacsBridge.start()` to call
  `iosmacs_emacs_core_start()` when the linked core and resources are present.
- [x] Preserve the shared diagnostic terminal as an explicit fallback when real
  startup is unavailable.
- [x] Update backend capability text from diagnostic-only to simulator native
  GNU Emacs startup.
- [x] Extend `make flutter-structure-check` to guard the resource/startup
  wiring.
- [x] Verify Flutter tests, structure check, iOS simulator build, and native app
  baseline.

Flutter native Emacs resource/startup status:

- The Flutter iOS Runner copies `lisp`, `etc`, `lib-src`, and `emacs.pdmp`
  into `Runner.app`.
- `FlutterNativeEmacsBridge.start()` now attempts `iosmacs_emacs_core_start()`
  with Bundle resource paths and a default Documents/home workspace.
- If the linked core or required resources are unavailable, the bridge starts
  the shared diagnostic terminal instead of failing silently.
- Native backend capabilities now advertise simulator GNU Emacs startup and
  native terminal byte flow.
- `make flutter-structure-check` guards resource copies and the real startup
  call.

Flutter native workspace TODO:

- [x] Implement Runner-side `listWorkspace` against the default Documents/home
  app-container workspace.
- [x] Implement Runner-side `importWorkspace` by copying file URLs into the
  app-container workspace.
- [x] Implement Runner-side `exportWorkspace` by returning workspace item file
  URLs.
- [x] Parse native workspace entry maps and export URL strings in
  `NativeEmacsBackend`.
- [x] Update native backend capabilities and tests for real workspace
  list/import/export behavior.
- [x] Verify Flutter tests, structure check, iOS simulator build, and native app
  baseline.

Flutter native workspace status:

- `FlutterNativeEmacsBridge` now lists the default Documents/home workspace and
  returns entry maps with name, path, directory flag, and size.
- `importWorkspace` copies file URLs into Documents/home, replacing existing
  items with the same name.
- `exportWorkspace` returns file URL strings for workspace items, or the
  workspace root when empty.
- `NativeEmacsBackend` parses native workspace entries, import counts, and
  export URLs into the shared Dart API.
- Flutter tests cover native workspace list/import/export MethodChannel
  results.

Flutter workspace UI TODO:

- [x] Replace the toolbar workspace SnackBar with a dialog listing workspace
  entries.
- [x] Show file/directory, size, and backend path for each workspace entry
  without implementing editor semantics in Dart.
- [x] Add an Export action that calls `exportWorkspaceSelection()` and reports
  the number of export candidate URLs.
- [x] Add widget tests that prove workspace entries and export results are
  visible from the terminal screen.
- [x] Verify Flutter tests, structure check, iOS simulator build, and native app
  baseline.

Flutter workspace UI status:

- The terminal toolbar workspace action now opens a dialog listing workspace
  entries instead of only showing a count SnackBar.
- Workspace rows show file/directory icon, name, backend path, and size label.
- The dialog Export action calls `exportWorkspaceSelection()` and reports the
  number of export candidate URLs.
- Widget tests cover the visible workspace entry and export result flow.

Flutter iOS smoke target TODO:

- [x] Add a repository script that builds the Flutter iOS simulator app.
- [x] Check the built `Runner.app` for `lisp`, `etc`, `lib-src`, and
  `emacs.pdmp`.
- [x] Check the built `Runner.debug.dylib` for `_iosmacs_emacs_main` and
  `_iosmacs_emacs_core_link_available`.
- [x] Add `make flutter-ios-smoke` at the repository root.
- [x] Include the smoke target in the Flutter structure check.
- [x] Verify `make flutter-ios-smoke` alongside the existing Flutter and native
  app checks.

Flutter iOS smoke target status:

- `scripts/check-flutter-ios-runner-smoke.sh` builds the Flutter iOS simulator
  app, checks `Runner.app` for `lisp`, `etc`, `lib-src`, and `emacs.pdmp`, and
  checks `Runner.debug.dylib` for `_iosmacs_emacs_main` plus
  `_iosmacs_emacs_core_link_available`.
- `make flutter-ios-smoke` runs the repository smoke script.
- `make flutter-structure-check` now guards the smoke script and Makefile
  target.

Flutter iOS launch smoke TODO:

- [x] Add a repository script that reuses the Flutter iOS Runner build smoke.
- [x] Install the built `Runner.app` on a booted simulator.
- [x] Launch `com.example.iosmacsFlutter` through `xcrun simctl launch`.
- [x] Hold briefly, then terminate the app cleanly to prove it stayed alive.
- [x] Add `make flutter-ios-launch-smoke` at the repository root.
- [x] Include the launch smoke target in the Flutter structure check.
- [x] Verify the launch smoke alongside existing Flutter and native app checks.

Flutter iOS launch smoke status:

- `scripts/run-flutter-ios-launch-smoke.sh` reuses the Flutter iOS Runner build
  smoke, installs `Runner.app` on a booted simulator, launches the bundle id
  from `Info.plist`, waits briefly, and requires clean termination.
- `make flutter-ios-launch-smoke` runs the launch smoke.
- `make flutter-structure-check` now guards the launch smoke script and Makefile
  target.

Flutter macOS smoke TODO:

- [x] Add a repository script that builds the Flutter macOS debug app.
- [x] Check the built `iosmacs_flutter.app` bundle and executable.
- [x] Launch the macOS app executable briefly.
- [x] Require the app process to stay alive long enough for clean termination.
- [x] Add `make flutter-macos-smoke` at the repository root.
- [x] Include the macOS smoke target in the Flutter structure check.
- [x] Verify the macOS smoke alongside existing Flutter and native app checks.

Flutter macOS smoke status:

- `scripts/run-flutter-macos-smoke.sh` builds the Flutter macOS debug app,
  checks `iosmacs_flutter.app`, reads `CFBundleExecutable`, launches the app
  executable briefly, and requires clean termination.
- `make flutter-macos-smoke` runs the repository macOS smoke.
- `make flutter-structure-check` now guards the macOS smoke script and Makefile
  target.

Flutter verification target TODO:

- [x] Add `make flutter-verify` at the repository root.
- [x] Run the Flutter checks sequentially to avoid Flutter startup-lock
  contention.
- [x] Include `flutter-structure-check`, `flutter-doctor`,
  `flutter-fake-smoke`, `flutter-ios-launch-smoke`, and
  `flutter-macos-smoke`.
- [x] Include `flutter-web-smoke` and `flutter-android-smoke`.
- [x] Include the verification target in the Flutter structure check.
- [x] Verify `make flutter-verify` end to end.

Flutter verification target status:

- `make flutter-verify` runs `flutter-structure-check`, `flutter-doctor`,
  `flutter-fake-smoke`, `flutter-ios-launch-smoke`, `flutter-macos-smoke`,
  `flutter-web-smoke`, and `flutter-android-smoke` sequentially.
- `make flutter-structure-check` guards the verification target.

Flutter Web/Android smoke TODO:

- [x] Add `make flutter-web-smoke` for `flutter build web --debug`.
- [x] Add `make flutter-android-smoke` for `flutter build apk --debug`.
- [x] Include both new platform smoke targets in `make flutter-verify`.
- [x] Include the Web/Android smoke targets in the Flutter structure check.
- [x] Verify the expanded `make flutter-verify` end to end.

Flutter Web/Android smoke status:

- `make flutter-web-smoke` builds Flutter Web debug output.
- `make flutter-android-smoke` builds the Flutter Android debug APK.
- `make flutter-verify` now includes both platform smoke targets after the
  iOS launch and macOS smoke checks.
- `make flutter-structure-check` guards the new Makefile targets and their
  underlying Flutter build commands.

Flutter macOS native channel TODO:

- [x] Rename the Dart native backend capability surface away from iOS-only
  wording where the MethodChannel is shared.
- [x] Add a `macosNative` backend factory option.
- [x] Select the native MethodChannel backend by default on macOS non-web.
- [x] Register `iosmacs/native_emacs` in the macOS Runner.
- [x] Replace the initial process-backend pending diagnostics with a held macOS
  GNU Emacs child-process route for start, stop, redraw, input, resize, and
  drain calls.
- [x] Add tests for macOS default selection and shared native-channel
  capabilities.
- [x] Add structure checks for the macOS native bridge.
- [x] Verify Dart tests, structure check, and macOS smoke.

Flutter macOS native channel status:

- `NativeEmacsBackend` now presents a platform-native MethodChannel capability
  surface instead of an iOS-only identity.
- `BackendKind.macosNative` and the default backend factory select the shared
  native MethodChannel backend on macOS non-web.
- The macOS Runner registers `iosmacs/native_emacs` and handles lifecycle,
  redraw, input, resize, drain, and workspace methods through
  `MacOSNativeEmacsBridge`.
- The macOS bridge now starts the bundled GNU Emacs child process through
  `forkpty(3)` so `-nw` has a real controlling terminal, and keeps workspace
  behavior behind native Application Support file operations.
- Tests cover macOS default selection and the shared native-channel capability
  surface.
- `make flutter-structure-check`, `flutter analyze`, `flutter test`, `make
  flutter-macos-smoke`, and expanded `make flutter-verify` pass.

Flutter macOS process probe TODO:

- [x] Add deterministic bundled Emacs executable candidate discovery in the
  macOS Runner.
- [x] Run a held GNU Emacs `-nw` child process through `forkpty(3)` on
  start when the app-bundled Emacs executable is available.
- [x] Drain PTY output into the Flutter terminal stream.
- [x] Report process discovery or PTY/process failure as native
  diagnostics.
- [x] Add direct PTY resize/ioctl support while replacing the old
  process-probe-only path with a child-process byte stream.
- [x] Apply native status payloads to Dart lifecycle/diagnostic values.
- [x] Add tests for native status payload handling.
- [x] Add structure checks for the macOS process probe.
- [x] Verify Dart tests, structure check, macOS smoke, and expanded
  `make flutter-verify`.

Flutter macOS process probe status:

- `MacOSNativeEmacsBridge` discovers the app-bundled
  `Contents/Resources/iosmacs-emacs/bin/emacs` first, with
  `IOSMACS_FLUTTER_EMACS` left only as an explicit debug fallback.
- On `start`, the macOS bridge launches `<emacs> --quick --no-splash -nw`
  through `forkpty(3)`, keeps the child pid plus PTY master handle, and drains
  terminal output into the native output buffer.
- If interactive startup cannot run, the bridge falls back to the older batch
  probe and reports explicit diagnostic fallback instead of pretending the
  process backend is connected.
- `NativeEmacsBackend` now applies native `lifecycleState`, `cols`, and `rows`
  status payloads to diagnostics.
- Tests cover native status payload handling; structure checks guard the
  child-process startup markers and reject the old PTY-pending marker.
- `flutter analyze`, `flutter test`, `make flutter-macos-smoke`, and expanded
  `make flutter-verify` pass.

Flutter macOS process probe runtime smoke TODO:

- [x] Add a compile-time smoke flag that starts the selected backend when the
  app launches.
- [x] Add a compile-time smoke flag that mirrors terminal output chunks to the
  app process log.
- [x] Add a macOS script that builds with those flags, launches the app, and
  checks the process-probe output in the captured log.
- [x] Add a `make flutter-macos-native-smoke` target.
- [x] Include the new smoke in the Flutter structure check.
- [x] Include the new smoke in `make flutter-verify`.
- [x] Verify Dart tests, structure check, macOS native smoke, and expanded
  `make flutter-verify`.

Flutter macOS process probe runtime smoke status:

- `IOSMACS_FLUTTER_AUTOSTART_NATIVE` starts the selected backend when the app
  launches in smoke builds.
- `IOSMACS_FLUTTER_MIRROR_TERMINAL_OUTPUT` mirrors terminal output chunks into
  the process log with an `iosmacs-terminal-output:` prefix.
- `scripts/run-flutter-macos-native-smoke.sh` builds the macOS app with both
  flags, launches it, and checks the captured log for bundled Emacs runtime
  discovery plus interactive GNU Emacs process startup from the app bundle.
- `make flutter-macos-native-smoke` passes.
- The captured smoke log now requires
  `macOS interactive GNU Emacs process started:` with the bundled executable
  path, rejects system Emacs candidates, and rejects the old
  interactive-PTY-pending diagnostic.
- `make flutter-verify` now includes the macOS native process-probe runtime
  smoke.
- `flutter analyze`, `flutter test`, `make flutter-macos-native-smoke`, and
  expanded `make flutter-verify` pass.

Flutter macOS bundled Emacs runtime TODO:

- [x] Add a repository script that builds a relocatable-ish macOS GNU Emacs
  runtime from `wasmacs/vendor/emacs`.
- [x] Copy the Emacs executable, pdmp, lisp, etc, leim, and libexec runtime
  files into `flutter/build/emacs-macos/runtime`.
- [x] Add a macOS Runner build phase that copies the prepared runtime into
  `Contents/Resources/iosmacs-emacs`.
- [x] Make the macOS native bridge use the bundled runtime by default without
  system Emacs path discovery.
- [x] Verify smoke evidence against the app-bundled executable path.

Flutter macOS bundled Emacs runtime status:

- `scripts/build-flutter-macos-emacs-runtime.sh` builds the macOS runtime under
  `flutter/build/emacs-macos/runtime` and can copy it into an app resources
  directory through `IOSMACS_FLUTTER_MACOS_EMACS_DEST`.
- The macOS Runner project contains a `Bundle Flutter macOS Emacs` build phase
  that invokes the runtime script after Flutter's macOS embed phase.
- `MacOSNativeEmacsBridge` sets `EMACSLOADPATH`, `EMACSDATA`, `EMACSDOC`, and
  `EMACSPATH` for bundled-runtime launches, so the app does not depend on a
  host Emacs installation.

Flutter macOS Japanese input source and M-X TODO:

- [x] Handle JIS `かな` / `英数` input-source switch keys in the macOS Runner
  instead of letting the terminal key path swallow them.
- [x] Select Hiragana for keyCode 104 and ABC/US for keyCode 102 through the
  macOS TIS input-source API.
- [x] Apply the same `M-X` to ordinary `M-x` binding used by bundled iOS Emacs
  when launching bundled macOS Emacs.
- [x] Autoload `dired` and `tetris` in bundled macOS Emacs startup init.
- [x] Guard the macOS input-source bridge and `M-X` startup init in the Flutter
  structure check.
- [x] Add a direct bundled-Emacs `M-X` / `tetris` check to the macOS native
  smoke.

Flutter macOS Japanese input source and M-X status:

- `AppDelegate` installs a local key-down monitor that handles only unmodified
  JIS `英数` / `かな` key events, selects the requested macOS input source, and
  consumes those source-switch keys before xterm/Emacs terminal input handles
  them.
- `MacOSNativeEmacsBridge` launches bundled Emacs with a small `--eval` form
  that clears `read-extended-command-predicate`, binds `M-X` to
  `execute-extended-command`, and autoloads `dired` and `tetris`.
- `scripts/run-flutter-macos-native-smoke.sh` now checks the app-bundled Emacs
  executable for the same `M-X` binding and `tetris` command availability
  before launching the app.

Flutter Android native channel TODO:

- [x] Register `iosmacs/native_emacs` in the Android Runner.
- [x] Replace the Android placeholder backend with a Dart adapter over the
  shared native MethodChannel backend.
- [x] Add Android Runner native bridge methods for start, stop, redraw, input,
  resize, output drain, clipboard paste, workspace list/import/export, and
  workspace root status.
- [x] Store Android workspace files under app-private
  `filesDir/iosmacs/workspace`.
- [x] Support importing Android content URIs into the app-private workspace.
- [x] Autostart Android by default now that a native channel route exists.
- [x] Verify Android native-channel tests, structure check, and debug APK
  build.

Flutter Android native channel status:

- `AndroidEmacsBackend` now reports `android-native-channel` and delegates
  backend operations to `NativeEmacsBackend`, preserving Android-specific
  capability text while using the shared MethodChannel transport.
- `MainActivity.kt` registers `AndroidNativeEmacsBridge` on
  `iosmacs/native_emacs`.
- The Android bridge returns real native status payloads and app-private
  workspace entries. It still reports the GNU Emacs NDK runtime and actual
  native Emacs terminal stream as pending.

Flutter Android emulator scratch smoke TODO:

- [x] Install the Android Emulator SDK package.
- [x] Install an Android 36 Google APIs ARM64 system image.
- [x] Create a repeatable local AVD named `iosmacs_flutter_pixel`.
- [x] Boot the AVD and wait for ADB `sys.boot_completed=1`.
- [x] Make the Android native-channel start output land on a `*scratch*`
  terminal screen.
- [x] Install and launch the Flutter Android app on the booted emulator.
- [x] Capture emulator evidence that the app reaches the `*scratch*` screen.
- [x] Keep Android resize diagnostics out of the terminal body so the
  `*scratch*` screen stays clean after layout settles.
- [x] Verify Android emulator scratch changes with format, analyze, tests,
  structure check, Android APK build, and diff check.

Flutter Android emulator scratch smoke status:

- Android Studio's JDK is available under
  `/Users/seijiro/Applications/Android Studio.app`.
- Flutter's Android SDK path is
  `/opt/homebrew/share/android-commandlinetools`.
- The local AVD `iosmacs_flutter_pixel` targets Android 36 Google APIs
  `arm64-v8a` and boots as `emulator-5554`.
- `AndroidNativeEmacsBridge.start` now emits a terminal clear sequence,
  `GNU Emacs 30.2 Android terminal frame`,
  `Buffer: *scratch*   Mode: Lisp Interaction`, and a mode line before the
  prompt.
- `AndroidNativeEmacsBridge.resize` updates native status without appending
  resize chatter to the terminal stream.

Flutter Android terminal transport TODO:

- [x] Render Android native-channel `sendBytes` input back into the diagnostic
  terminal stream while the GNU Emacs NDK runtime is pending.
- [x] Route Android native clipboard paste through the same diagnostic terminal
  input renderer.
- [x] Make Android native redraw rebuild the clean `*scratch*` terminal screen.
- [x] Extend Dart Android backend tests so `sendBytes` drains Android terminal
  echo output.
- [x] Extend `make flutter-android-emulator-smoke` with Android capability,
  status, input, resize, and redraw smoke flags.
- [x] Guard Android terminal transport markers in the Flutter structure check.
- [x] Verify Android terminal transport with format, analyze, tests, structure
  check, APK build, emulator smoke, screenshot inspection, and diff check.

Flutter Android terminal transport status:

- The Android native bridge now has a diagnostic terminal transport for
  lifecycle, input, paste, redraw, resize status, output drain, and workspace
  operations.
- This still does not claim a real Android GNU Emacs runtime. The next
  connection step is replacing the diagnostic renderer behind
  `AndroidNativeEmacsBridge` with an NDK/JNI Emacs terminal source.

Flutter Android JNI runtime boundary TODO:

- [x] Add an Android app CMake build for a native shared library.
- [x] Add `iosmacs_android_runtime.cpp` as the Android JNI diagnostic terminal
  runtime.
- [x] Load `libiosmacs_android_runtime.so` from the Android Runner.
- [x] Route Android native-channel start, redraw, input, and paste rendering
  through JNI instead of Kotlin-only string rendering.
- [x] Update Android backend capabilities and structure checks for the JNI
  runtime boundary.
- [x] Verify Android JNI runtime boundary with format, analyze, tests,
  structure check, APK build, emulator smoke, screenshot inspection, and diff
  check.

Flutter Android JNI runtime boundary status:

- The Android Runner now builds `libiosmacs_android_runtime.so` through CMake.
- `AndroidNativeEmacsBridge` still owns MethodChannel calls and Android file
  APIs, but terminal rendering now crosses the JNI boundary.
- This creates the replacement point for a future NDK GNU Emacs runtime without
  changing the Flutter/Dart backend contract.

Flutter Android terminal Emacs frame TODO:

- [x] Move the Android JNI renderer from one-shot diagnostic text to a
  stateful `*scratch*` terminal frame.
- [x] Render a GNU Emacs-style header, `*scratch*` buffer label, Lisp
  Interaction mode line, minibuffer/status row, and prompt.
- [x] Insert Android terminal input and paste bytes into the JNI-side scratch
  buffer before redrawing the terminal frame.
- [x] Keep redraw reconstructing the current frame instead of appending a
  placeholder line.
- [x] Verify Android terminal Emacs frame with format, analyze, tests,
  structure check, APK build, emulator smoke, screenshot inspection, and diff
  check.

Flutter Android terminal Emacs frame status:

- `libiosmacs_android_runtime.so` now owns a small stateful terminal frame
  renderer for Android. It presents the Android app's Emacs terminal surface as
  `GNU Emacs 30.2 Android terminal frame` with `Buffer: *scratch*` and a Lisp
  Interaction mode line.
- This still preserves the larger boundary: replacing the frame renderer with
  real GNU Emacs NDK terminal output should not require changing the Dart
  `EmacsBackend` contract.

Flutter Android GNU Emacs NDK runtime TODO:

- [x] Add a repeatable Android GNU Emacs configure/build entrypoint under
  `scripts/build-flutter-android-emacs-runtime.sh`.
- [x] Isolate Android GNU Emacs build state under
  `flutter/build/emacs-android/<abi>`.
- [x] Detect the local Android SDK, NDK clang, Android platform jar, build
  tools, and NDK GNU Make.
- [x] Add a Java 21-compatible `javac` wrapper that rewrites Emacs Android
  `-source/-target 1.7` checks to `--release 8`.
- [x] Force Android NDK `llvm-ar`, `llvm-ranlib`, and `llvm-nm` through the
  configure/build probe so Android objects are not archived by macOS tools.
- [x] Use Android API 35 for the NDK build so `mktime_z` is declared by the
  Android sysroot.
- [x] Generate Android cross-build Lisp inputs with the repo-built macOS Emacs
  runtime: loaddefs, Unicode data, and portable `.elc` files.
- [x] Generate Android runtime charset maps under `etc/charsets` before APK
  asset staging.
- [x] Patch the Android API 35 `SIG2STR_MAX`/`sig2str` declaration gap inside
  the isolated build tree.
- [x] Configure the vendored GNU Emacs Android port for arm64-v8a with minimal
  optional dependencies.
- [x] Add Makefile targets for configure-only and full runtime-library probes.
- [x] Guard the Android GNU Emacs runtime entrypoint in the Flutter structure
  check.
- [x] Produce `libemacs.so` and `libandroid-emacs.so` from the Android NDK
  build.
- [x] Add optional Flutter Android packaging inputs for the generated GNU
  Emacs NDK libraries and assets.
- [x] Package the generated GNU Emacs Android Java bridge classes into a
  Gradle-consumed jar.
- [x] Patch the generated Android Java bridge package-id lookups for the
  Flutter application id instead of the upstream `org.gnu.emacs` app id.
- [x] Verify `org.gnu.emacs.EmacsNative` loads in the Flutter APK by reading
  the GNU Emacs native fingerprint on the emulator.
- [x] Force APK native libraries to be extracted so the upstream
  `libandroid-emacs.so` wrapper is available as an app-private executable.
- [x] Prove the extracted upstream wrapper can run a bounded noninteractive
  GNU Emacs subprocess through `app_process64`.
- [x] Add a native Android PTY probe for the extracted upstream wrapper and
  record the official Android port's text-terminal refusal.
- [x] Add a separate GNU Emacs NW text-terminal build that intentionally omits
  `--with-android`, packages as `libemacs_nw.so`, and runs through Android
  `forkpty(3)`.
- [x] Prefer the NW binary from `AndroidNativeEmacsBridge.start` when packaged,
  while retaining the official `--with-android` runtime probes as fallback and
  comparison evidence.
- [x] Verify Android emulator evidence for real GNU Emacs NW terminal output,
  `*scratch*`, and committed input smoke text.
- [x] Reduce the Android fallback diagnostic renderer now that
  `libemacs_nw.so` is the active interactive terminal path.
- [x] Add Android emulator ADB keyboard/IME input proof against the NW runtime
  path.
- [x] Add Android document-provider export proof against the NW runtime path.
- [x] Suppress visible Android NW no-pdump startup chatter until the first
  interactive `*scratch*` terminal frame is ready.
- [ ] Improve Android NW startup packaging with a real dumped/runtime cache path
  so the interactive binary reaches `*scratch*` faster internally.

Flutter Android GNU Emacs NDK runtime status:

- `make flutter-android-emacs-configure` now configures GNU Emacs Android for
  the local SDK/NDK and writes
  `flutter/build/emacs-android/<abi>/iosmacs/android-emacs-runtime.status`.
- `make flutter-android-emacs-runtime` now produces
  `java/install_temp/lib/arm64-v8a/libemacs.so` and
  `java/install_temp/lib/arm64-v8a/libandroid-emacs.so`.
- The runtime target filters `libemacs.so` and `libandroid-emacs.so` into
  `iosmacs/jniLibs/<abi>` for APK packaging, while keeping the full
  `java/install_temp` tree as the GNU Emacs Android staging area.
- The Flutter Android Gradle project now treats generated `iosmacs/jniLibs`
  and `java/install_temp/assets` as optional packaging sources. If the runtime
  target has been run, the APK can include those GNU Emacs NDK artifacts
  without committing binaries.
- The runtime target also builds `classes.dex`, packages the generated
  `org.gnu.emacs` classes into `iosmacs/emacs-android-java.jar`, and Gradle
  consumes that jar when it exists.
- The runtime build patches upstream Android Java package-id constants for the
  Flutter app id (`com.example.iosmacs_flutter` by default) so the official
  bridge code resolves this APK instead of searching for `org.gnu.emacs` as the
  installed package.
- The runtime build now also generates charset maps such as `8859-2.map`
  before staging Android assets. Without those maps, the official
  noninteractive Emacs process reached `loadup.el` but exited while loading
  `international/mule-conf`.
- `make flutter-android-emulator-smoke` now verifies an APK that contains the
  filtered GNU Emacs Android libraries and assets; logcat shows both
  `libemacs.so` and `libandroid-emacs.so` loading successfully, reads the
  `EmacsNative.getFingerprint()` value through the packaged Java bridge,
  verifies the extracted app-private `libandroid-emacs.so` wrapper executable
  path, proves a bounded `libandroid-emacs.so --batch --eval ...` subprocess
  exits with `marker=ok`, proves an Android PTY can launch the wrapper, records
  the upstream refusal of text-terminal operation for Android application
  packages, and writes the smoke screenshot to
  `flutter/build/android-emulator-smoke/scratch.png`.
- `make flutter-android-emacs-nw-build` now builds a separate Android ARM64
  `-nw` binary without `HAVE_ANDROID` and stages it as `libemacs_nw.so` for APK
  packaging.
- `AndroidNativeEmacsBridge.start` prefers that NW binary when it exists,
  extracts the packaged Emacs `lisp` and `etc` assets to app-private storage,
  then launches the binary through `forkpty(3)`.
- The emulator smoke now treats the NW path as the active success path and
  requires the NW PTY marker, `*scratch*` evidence, and the named
  `iosmacs input smoke` committed-text marker before accepting the run.
- The Android emulator smoke requires the packaged NW route by default; the old
  fallback diagnostic checks only run when `IOSMACS_ANDROID_REQUIRE_NW=0` is set.
- The Android capability surface now advertises `Android GNU Emacs NW PTY
  terminal route` as supported and demotes the old stateful frame renderer to an
  explicit fallback diagnostic surface.
- The Android emulator smoke now also exercises workspace list/import/open/export
  while the NW route is active, so app-private workspace behavior is checked
  against the real Android terminal runtime rather than only placeholder output.
- The Android emulator smoke now focuses the Flutter terminal, sends the
  `androidadbinput` marker through `adb shell input text`, and requires
  `iosmacs-terminal-input-buffer` log evidence before accepting the run. This
  proves Android keyboard/IME input reaches the terminal input bridge while the
  NW route is active.
- Android workspace export now writes exported workspace files through
  `ContentResolver.openOutputStream()` to app-owned
  `content://com.example.iosmacs_flutter.workspace_export/...` URIs, and the
  emulator smoke requires both returned content URI evidence and native byte
  evidence while the NW route is active.
- Android NW startup now buffers early PTY output until the menu-bar
  `*scratch*` frame appears, then releases only that usable terminal frame and
  logs the number of suppressed startup bytes. This avoids showing long
  no-pdump load chatter in the Flutter terminal while preserving the real Emacs
  PTY session.
- Current remaining Android work: keep the official `--with-android` runtime as
  packaged evidence/fallback, speed up NW startup internally with a real dumped
  runtime/cache path, and add the user-facing Android document export picker
  flow.

Flutter macOS workspace TODO:

- [x] Create a workspace root under macOS Application Support.
- [x] Implement `listWorkspace` in `MacOSNativeEmacsBridge`.
- [x] Implement `importWorkspace` in `MacOSNativeEmacsBridge`.
- [x] Implement `exportWorkspace` in `MacOSNativeEmacsBridge`.
- [x] Return native workspace entries with name, path, directory flag, and size.
- [x] Update backend capabilities to include macOS Application Support
  workspace behavior.
- [x] Add structure checks for the macOS workspace methods.
- [x] Verify Dart tests, structure check, macOS smoke, macOS native smoke, and
  expanded `make flutter-verify`.

Flutter macOS workspace status:

- `MacOSNativeEmacsBridge` now creates a workspace root under
  Application Support at `iosmacs_flutter/workspace`.
- `listWorkspace` returns sorted entries with name, path, directory flag, and
  byte size.
- `importWorkspace` copies passed file URLs into the Application Support
  workspace,
  replacing existing items with the same name.
- `exportWorkspace` returns workspace item file URLs, or the workspace root when
  it is empty.
- Backend capabilities now report
  `macOS Application Support workspace list/import/export` as supported
  behavior.
- Structure checks guard the macOS workspace methods and Application Support
  workspace root.
- `flutter analyze`, `flutter test`, `make flutter-macos-smoke`, `make
  flutter-macos-native-smoke`, and expanded `make flutter-verify` pass.

Flutter macOS workspace runtime smoke TODO:

- [x] Add a compile-time smoke flag that runs workspace list/export at app
  launch.
- [x] Mirror workspace list/export counts into the app process log.
- [x] Extend the macOS native smoke script to enable and check workspace smoke
  output.
- [x] Add widget coverage for workspace smoke startup behavior.
- [x] Verify Dart tests, macOS native smoke, and expanded `make
  flutter-verify`.

Flutter macOS workspace runtime smoke status:

- `IOSMACS_FLUTTER_WORKSPACE_SMOKE` runs workspace list/export after launch.
- Workspace smoke output is mirrored as `iosmacs-workspace-smoke:` log lines.
- `scripts/run-flutter-macos-native-smoke.sh` now enables the workspace smoke
  flag and checks the captured log for list/export evidence.
- The latest native smoke log includes `workspace listed 0 item(s)` and
  `workspace export candidate(s): 1`.
- `flutter analyze`, `flutter test`, `make flutter-macos-native-smoke`, and
  expanded `make flutter-verify` pass.

Flutter macOS workspace import smoke TODO:

- [x] Add a conditional IO helper that creates a smoke import file only on
  platforms with `dart:io`.
- [x] Import the smoke file during startup workspace smoke when a file URI is
  available.
- [x] Mirror import count and post-import list/export counts into process logs.
- [x] Extend the macOS native smoke script to check import evidence.
- [x] Keep Web debug build passing.
- [x] Verify Dart tests, macOS native smoke, Web smoke, and expanded
  `make flutter-verify`.

Flutter macOS workspace import smoke status:

- `workspace_smoke_file.dart` uses a conditional export so only IO-capable
  builds create a temporary smoke import file.
- Workspace startup smoke now runs list, import, list-after-import, and export
  in sequence.
- The macOS native smoke script checks for `workspace imported 1 item(s)` and
  `workspace listed after import`.
- The latest native smoke log includes `workspace listed 1 item(s)`,
  `workspace imported 1 item(s)`, `workspace listed after import 1 item(s)`,
  and `workspace export candidate(s): 1`.
- `flutter analyze`, `flutter test`, `make flutter-macos-native-smoke`, `make
  flutter-web-smoke`, and expanded `make flutter-verify` pass.

Flutter Web backend placeholder TODO:

- [x] Add a Dart `WebWasmEmacsBackend` implementing `EmacsBackend`.
- [x] Report Web as a separate `wasmacs`/WASM backend route, not a native FFI
  backend.
- [x] Select the Web backend by default when `kIsWeb` is true.
- [x] Keep deterministic terminal output and unsupported diagnostics visible.
- [x] Add tests for explicit and default Web backend selection.
- [x] Add tests for Web backend capabilities and workspace placeholders.
- [x] Include the Web backend in the structure check.
- [x] Verify Dart tests, Web debug build, and expanded `make flutter-verify`.

Flutter Web backend placeholder status:

- `WebWasmEmacsBackend` implements `EmacsBackend` for Flutter Web.
- Web now defaults to `BackendKind.webWasm` instead of the fake backend.
- Capabilities identify Web as a separate `wasmacs`/WASM route and explicitly
  mark native FFI, MethodChannel, and connected WASM runtime as unsupported.
- Web workspace behavior is browser-safe placeholder list/import/export.
- Tests cover explicit Web backend construction, default Web selection,
  capabilities, startup diagnostics, and workspace placeholders.
- `make flutter-structure-check`, `flutter analyze`, `flutter test`, `make
  flutter-web-smoke`, and expanded `make flutter-verify` pass.

Phase 2 worker-boundary TODO:

- Add command/event objects for backend worker traffic.
- Keep `EmacsBackend` as the UI-facing API.
- Keep fake terminal behavior behind a worker-shaped boundary instead of in the
  UI-facing backend class.
- Test command handling for start, stop, redraw, input bytes, resize,
  workspace list, import, and export.

Phase 2 worker-boundary status:

- `BackendWorkerCommand`, `BackendWorkerEvent`, `BackendWorkerResult`, and
  `BackendWorker` now define the worker traffic boundary.
- `FakeBackendWorker` owns the fake lifecycle, terminal output, input echo,
  resize, diagnostics, and workspace placeholder behavior.
- `FakeEmacsBackend` now adapts worker events to the UI-facing
  `EmacsBackend` streams and listenables.
- Worker tests cover lifecycle, output, resize, input bytes, workspace list,
  import, and export.

Phase 3 terminal-widget TODO:

- Add a real terminal widget dependency.
- Replace the temporary text-buffer renderer with the terminal widget.
- Preserve start/reset/workspace/font controls.
- Preserve a test-friendly text input path until hardware keyboard and IME
  behavior are explicitly validated.
- Verify fake backend output and ASCII input still work through the new screen.

Phase 3 terminal-widget status:

- Added `xterm` 4.0.0.
- `TerminalScreen` now renders a real `TerminalView` instead of the temporary
  `SelectableText` buffer.
- Backend output bytes are decoded and written into `Terminal.write`.
- `Terminal.onOutput` routes terminal input back through
  `EmacsBackend.sendBytes`.
- The smoke-friendly text field remains for deterministic ASCII input testing
  until hardware keyboard and IME behavior are validated.
- Widget tests now assert the `TerminalView` is present and fake ASCII input
  updates backend diagnostics.

CocoaPods environment TODO:

- Use `mise` for Ruby installation.
- Keep CocoaPods in the `mise` Ruby gem environment rather than installing
  against system Ruby.
- Re-check `flutter doctor -v` after `pod` is available.

CocoaPods environment status:

- Ruby 3.4.9 is installed through `mise`.
- Ruby build required Homebrew `libyaml` so Ruby's `psych` extension could
  compile.
- CocoaPods 1.16.2 is installed through the `mise` Ruby gem environment.
- `make flutter-doctor` runs Flutter doctor with repo mise tools and confirms
  CocoaPods is available.

Tasks:

- Create a Flutter project under `flutter/`.
- Add a terminal screen as the first screen, not a landing page.
- Add a small status strip for lifecycle state and backend diagnostics.
- Add simple controls for start, reset/redraw, font size, and workspace actions.
- Implement a fake backend that:
  - exposes a byte output stream,
  - accepts input bytes,
  - responds to resize events,
  - reports lifecycle state,
  - emits deterministic terminal output for smoke tests.

Exit criteria:

- The Flutter app launches on at least macOS and iOS simulator.
- The fake backend paints a terminal-like screen.
- ASCII input reaches the fake backend.
- Resize events reach the fake backend.
- A smoke test can verify terminal output after input.

## Phase 2: Dart Backend Interface

Goal: fix the boundary between Flutter UI and Emacs runtime before adding real
platform backends.

Create a Dart interface that captures the responsibilities currently held by
`EmacsSession.swift`, without importing SwiftUI or SwiftTerm assumptions.

Candidate interface shape:

```dart
abstract interface class EmacsBackend {
  Stream<List<int>> get outputStream;
  ValueListenable<String> get lifecycleState;
  ValueListenable<BackendDiagnostics> get diagnostics;

  Future<void> start();
  Future<void> stop();
  Future<void> resetOrRedraw();
  Future<void> sendBytes(List<int> bytes);
  Future<void> resize({required int cols, required int rows});

  Future<List<WorkspaceEntry>> listWorkspace();
  Future<int> importToWorkspace(List<Uri> uris);
  Future<List<Uri>> exportWorkspaceSelection();
}
```

Rules:

- Flutter terminal widgets only send and receive bytes.
- Flutter UI must not reinterpret Emacs keymaps.
- Editor semantics must not live in the Dart layer. Text editing, command
  dispatch, minibuffer behavior, completion, kill ring, undo, Dired behavior,
  and Lisp evaluation must pass through to Emacs instead of being recreated in
  Flutter.
- Backend implementations own platform-specific process, FFI, file, and
  lifecycle details.
- Unsupported capabilities must fail explicitly and visibly.
- The same fake backend must remain available for UI tests on every platform.
- Runtime work should be split into three roles:
  - Flutter main isolate for UI and input composition.
  - A backend worker isolate or platform worker for byte pumping, lifecycle
    observation, native calls, and file operations.
  - The Emacs runtime itself for editor semantics and command execution.

Exit criteria:

- The Flutter UI depends on the Dart backend interface, not on any iOS-specific
  code.
- No Emacs editing semantics are implemented in Dart beyond transporting
  terminal bytes and displaying diagnostics.
- The fake backend implements the full interface.
- Tests cover `start`, `sendBytes`, `resize`, `outputStream`, lifecycle state,
  and workspace import/export placeholders.
- Worker separation is represented in the backend design before the real iOS
  native backend is connected.

## Phase 3: Flutter Terminal UI

Goal: choose and validate the Flutter terminal frontend.

Candidate:

- `xterm.dart` for terminal parsing, rendering, keyboard input, selection, and
  mobile/desktop Flutter integration.

Validation focus:

- ASCII input.
- Hardware keyboard control keys.
- Terminal resize.
- Redraw after app lifecycle changes.
- Japanese IME composition and commit behavior.
- UTF-8 committed text reaching the backend as bytes.
- Confirming that key and text semantics are owned by Emacs, not by Dart-side
  command interpretation.

Exit criteria:

- ASCII typing works through the fake backend.
- Control-key input has a documented byte mapping.
- Japanese IME marked text does not corrupt the terminal before commit.
- Committed Japanese text reaches the backend as UTF-8 bytes.
- The UI can be smoke-tested without a real Emacs runtime.

## Phase 4: iOS Native Backend

Goal: connect Flutter to the current iosmacs native Emacs implementation first.

Use the existing native pieces as the starting point:

- `iosmacs/Host`
- `iosmacs/Emacs`
- the static GNU Emacs archive build
- the fake TTY terminal shim
- the app-container workspace mapping

Implementation direction:

- Package the current iOS native C/Swift bridge as a Flutter plugin or FFI
  backend.
- Remove SwiftTerm from the new Flutter app path.
- Keep SwiftTerm available in the existing Xcode app until the Flutter path has
  equivalent proof.
- Send terminal bytes from native Emacs to Flutter.
- Send Flutter terminal input bytes back to the fake TTY input queue.
- Forward terminal resize from Flutter to the native resize facade.
- Preserve the existing simulator smoke style with explicit markers.

Exit criteria:

- The Flutter iOS simulator app starts the existing native Emacs core.
- The terminal reaches the `*scratch*` frame.
- ASCII input reaches Emacs.
- A marker proves command-loop insertion.
- Existing native Xcode verification still works.

### Phase 4A: Flutter iOS Parity And Device Readiness

Goal: turn the current Flutter iOS launch proof into an existing-native-app
equivalent proof, then make the same app ordinary to run on a physical iPad or
iPhone.

Simulator runtime-smoke TODO:

- [x] Add `make flutter-ios-native-smoke` as a dedicated Flutter iOS runtime
  smoke that builds with terminal-output mirroring and startup smoke flags,
  installs on a booted simulator, captures Runner logs, and checks native
  backend markers.
- [x] Require the Flutter iOS native smoke to report
  `iosmacs-capabilities-smoke: id=platform-native-channel`.
- [x] Require Flutter iOS terminal output to include linked GNU Emacs startup
  evidence rather than only diagnostic fallback text.
- [x] Add a Flutter iOS `*scratch*` smoke mode that waits for terminal output
  containing `*scratch*` and Lisp Interaction mode.
- [x] Add a Flutter iOS command-input smoke mode that injects ASCII through the
  Flutter terminal input bridge and verifies command-loop insertion into
  `*scratch*` with a marker.
- [x] Add a Flutter iOS file-ops smoke mode that creates, saves, reopens, and
  Dired-lists a file under `/home/user`, matching the existing
  `IOSMACS_NW_EXPECT_FILE_OPS=1` native smoke.
- [x] Add a Flutter iOS relaunch-persistence smoke that launches, writes a
  workspace file, terminates, relaunches, and verifies the saved file is still
  visible through both Emacs and the Flutter workspace bridge.
- [x] Include the Flutter iOS native smoke in `make flutter-verify` only after
  it is stable on a clean booted simulator.

Bridge/workspace implementation TODO:

- [x] Add native bridge support for smoke-only evaluated Lisp markers without
  moving editor semantics into Dart.
- [x] Keep all command semantics inside Emacs: Flutter may submit terminal
  bytes and observe logs/diagnostics, but must not implement Emacs commands in
  Dart.
- [x] Reuse the existing fake TTY input/output facade for Flutter iOS input,
  resize, and terminal output proof.
- [x] Align Flutter iOS workspace root behavior with the native app's
  `/home/user` app-container mapping.
- [x] Prefer the native app's iCloud ubiquity `Documents/home/user` location
  for the default Flutter iOS workspace when available, with app Documents as
  the fallback.
- [x] Add a Flutter Workspace dialog action that lets the user select an
  arbitrary folder for `/home/user`.
- [x] Persist the selected `/home/user` folder as an iOS security-scoped
  bookmark and make reset-to-default available from Flutter.
- [x] Add explicit diagnostics when the Flutter iOS bridge falls back to the
  diagnostic backend so the smoke cannot silently pass on fallback output.

Network implementation TODO:

- [x] Add the existing native iOS `IOSMacsURLSessionBridge.swift` source to the
  Flutter iOS Runner target.
- [x] Resolve the Swift URLSession bridge from the shared C host facade so
  Flutter iOS and native iOS use the same Emacs `url.el` transport path.
- [x] Verify `url-retrieve-synchronously` from the Flutter iOS app can fetch
  HTTPS content and write an Emacs-side success marker.

Paste/input parity TODO:

- [x] Inspect the root native iOS terminal input implementation before adding
  more Flutter-specific paste behavior.
- [x] Replace the Flutter iOS paste-first path with a root-native-style hidden
  `UITextView` first responder that forwards committed text directly to the
  native terminal input ring.
- [x] Route the Flutter iOS Paste button through native `UITextView.paste(nil)`
  before falling back to Dart clipboard handling on non-native backends.
- [x] Stop intercepting `Cmd+V` in Flutter shortcuts so hardware paste can
  reach the native first responder.
- [x] Verify small paste reaches native input as one `push-input`.
- [x] Verify a 30KB paste reaches native input as one `push-input` and record
  the remaining Emacs-side read timing.
- [x] Normalize native `UITextView` committed/pasted line feeds to terminal
  carriage returns so multiline paste into `*scratch*` inserts text instead of
  triggering `C-j` / `eval-print-last-sexp`.
- [x] Wrap native `UITextView` paste bytes in terminal bracketed-paste markers
  so long multiline paste is inserted as paste instead of processed as many
  individual RET commands.
- [x] Add a structure guard for the native line-ending normalization.
- [x] Add a structure guard for native bracketed-paste routing.
- [x] Revert direct `UIPasteboard.general.string` reads after Simulator paste
  could hang before any bytes reached the fake tty.
- [x] Add an iOS runtime override for `xterm--pasted-text` that suppresses
  redisplay/message work while Emacs slurps bracketed paste bytes.
- [x] Instrument native iOS paste stages so the remaining 20s delay can be
  attributed to UIKit paste, native forward, fake tty read, or Emacs output.
- [x] Inspect the latest Simulator paste logs and identify that a 20s Japanese
  Cmd+V paste can bypass the native hidden `UITextView` paste markers and
  arrive through Flutter terminal text input instead.
- [x] Route Flutter app-level `Cmd+V` through the same clipboard/bracketed-paste
  path as the Paste toolbar button before `TerminalView` can process it as
  ordinary terminal input.
- [x] Add widget and structure-check coverage for the `Cmd+V` bracketed-paste
  route.
- [x] Re-test the Flutter Clipboard path and confirm native input accepts the
  paste bytes in milliseconds, while bracketed paste can leave Emacs waiting
  without redisplay in the current fake tty path.
- [x] Switch Flutter Paste/Cmd+V and native paste fallback from bracketed paste
  markers to normalized raw UTF-8 text with LF/CRLF converted to terminal CR.
- [x] Update paste tests and structure guards to assert normalized raw paste
  bytes instead of bracketed paste bytes.
- [x] Add unified timing markers for native `sendBytes`, fake tty
  `read-available`, Emacs `tty-read`, terminal `write-output`, native
  `drainOutput`, and Dart output-stream emission.
- [x] Rebuild and measure the unified trace: 342 bytes reached Emacs
  `tty-read` in the same monotonic millisecond as the fake tty push/read, while
  first terminal output came about 6245ms later.
- [ ] Instrument and reduce the Emacs post-tty-read/pre-write-output section;
  this is now the measured owner of the remaining roughly 6 second Japanese
  paste delay.

Physical-device TODO:

- [ ] Add `make flutter-ios-device-build` for a generic/device iOS build that
  uses the Flutter Runner and linked iosmacs native sources without simulator
  assumptions.
- [ ] Document required signing inputs for local physical-device runs:
  development team, bundle identifier override, provisioning profile, and
  trusted developer mode.
- [ ] Add `make flutter-ios-device-launch` or documented `flutter run -d`
  workflow for a connected iPad/iPhone.
- [ ] Verify the physical device app starts the linked native backend and shows
  terminal output without relying on simulator-only build products.
- [ ] Verify physical-device workspace create/save/reopen behavior under the
  app container.
- [ ] Verify physical-device relaunch persistence.
- [ ] Keep App Store distribution explicitly out of scope until local physical
  device smoke is repeatable.

Completion criteria:

- `make flutter-ios-native-smoke` proves Flutter iOS startup reaches real
  Emacs terminal output and `*scratch*`.
- A Flutter iOS smoke proves terminal input reaches the Emacs command loop.
- A Flutter iOS smoke proves save/reopen/Dired behavior and relaunch
  persistence under `/home/user`.
- A connected physical iPad/iPhone can build, install, launch, edit, save,
  relaunch, and reopen a file using documented commands.
- Existing native `make verify` remains green while Flutter iOS parity grows.

## Phase 5: macOS Backend

Goal: use macOS as the fast desktop proving ground.

Preferred first route:

- Flutter desktop UI.
- A native or bundled Emacs child process.
- PTY-backed terminal bridge.
- The same Dart `EmacsBackend` interface.

Rationale:

- macOS has fewer sandbox constraints than iOS.
- PTY/process support can prove UI and backend contracts quickly.
- Lessons from macOS should shape Linux and Windows backends.

Exit criteria:

- Flutter macOS can run an Emacs terminal session.
- The same terminal UI works with fake, iOS native, and macOS process backends.
- File/workspace behavior is documented separately from iOS app-container
  behavior.

## Phase 6: Android, Linux, Windows, And Web

Goal: add platforms one at a time instead of pretending one backend fits all.

Android:

- Build the Emacs core with the Android NDK or choose a clearly scoped process
  route if available.
- Reuse the fake TTY facade shape where possible.
- Treat filesystem permissions and document access as Android-specific backend
  responsibilities.

Linux:

- Start with a process plus PTY backend.
- Keep the interface aligned with macOS.

Windows:

- Start with a bundled or discoverable Emacs process.
- Use ConPTY or an equivalent pipe bridge for terminal I/O.
- Treat path translation and workspace semantics as first-class risks.

Web:

- Do not assume Dart FFI or the native Emacs backend is available.
- Use the `wasmacs` WebAssembly/browser route as a separate backend candidate.
- Bridge Flutter Web UI to a JavaScript/WASM backend if the experiment stays in
  Flutter Web.

Exit criteria:

- Each platform has an explicit backend strategy.
- Platform-specific limitations are visible in the app and docs.
- Web is documented as a separate WASM backend path, not a native backend port.

## Verification Contract

The current top-level `make verify` remains the verification contract for the
existing native iOS app.

The Flutter path now has its own verification targets:

- `make flutter-fake-smoke`
- `make flutter-ios-smoke`
- `make flutter-macos-smoke`
- `make flutter-ios-native-smoke`
- `make flutter-macos-native-smoke`
- `make flutter-backend-override-smoke`
- `make flutter-web-smoke`
- `make flutter-android-smoke`
- `make flutter-verify`

Do not replace the existing verification path until the Flutter iOS backend has
equivalent evidence for startup, terminal rendering, input, file operations, and
diagnostics.
