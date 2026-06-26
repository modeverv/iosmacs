# iosmacs Plan

## Current Active Direction: Flutter Edition

The next active development direction is the Flutter edition of iosmacs.

Future LLM agents should treat `flutter/PLAN.md` as the working plan for the
new cross-platform Flutter app and `flutter/ARCHITECTURE.md` as the working
architecture for its UI/backend split.

The existing native Xcode/Swift app remains valuable as the reference
implementation and verification baseline. Do not remove or rewrite it while
starting the Flutter path. The Flutter work should begin beside it under
`flutter/`, first with a fake backend and then with the existing iOS native
Emacs backend connected through a Dart interface.

Key Flutter constraints:

- Do not move Emacs editor semantics into Dart. Dart and Flutter transport
  terminal bytes, display diagnostics, coordinate workers, and present UI;
  Emacs owns command semantics, buffers, minibuffer behavior, Dired, Lisp, undo,
  kill ring, and keymaps.
- Split runtime responsibilities into Flutter main isolate, backend worker, and
  Emacs runtime.
- Preserve the existing top-level `make verify` contract for the native iOS app
  until the Flutter iOS backend has equivalent smoke evidence.
- Treat Web as a separate `wasmacs`/WASM backend direction rather than a direct
  native FFI port.

### Active Flutter TODO

Detailed execution state lives in `flutter/PLAN.md`; running notes live in
`flutter/LOG.md`.

- [x] Keep the existing native iOS project untouched while adding Flutter files
  beside it.
- [x] Create a Flutter shell under `flutter/iosmacs_flutter`.
- [x] Define the Dart backend boundary before platform-specific backends.
- [x] Implement a deterministic fake backend for UI and smoke tests.
- [x] Build the first terminal screen with lifecycle diagnostics and controls.
- [x] Add tests for fake backend startup, input echo, resize, and workspace
  placeholders.
- [x] Add Flutter SDK verification steps once `flutter` and `dart` are
  available in the local PATH.
- [x] Add `make flutter-fake-smoke` as the first Flutter verification target.
- [x] Add an app-level backend selection boundary so UI code does not construct
  platform backends directly.
- [x] Add structured backend diagnostics for lifecycle, terminal geometry,
  byte counts, and workspace placeholder actions.
- [x] Expand fake-backend tests to prove diagnostics and backend selection.
- [x] Add an SDK-independent Flutter structure check for the current shell.
- [x] Add a reproducible Flutter SDK bootstrap target for generated platform
  runners.
- [x] Install Flutter SDK under `~/work/flutter` and expose it through
  `~/.zshrc`.
- [x] Run Flutter SDK verification locally once `flutter` and `dart` are
  available in the local PATH.
- [x] Generate Flutter platform runners for iOS, Android, macOS, Linux,
  Windows, and Web.
- [x] Verify fake backend tests with `make flutter-fake-smoke`.
- [x] Verify Flutter analyze, macOS debug build, Web debug build, iOS simulator
  debug build, and short macOS/iPad simulator launches.
- [x] Add a backend worker command/event boundary behind `EmacsBackend`.
- [x] Move fake backend terminal/lifecycle/workspace behavior behind that
  worker boundary.
- [x] Add tests that prove the fake worker command/event contract.
- [x] Add a real Flutter terminal widget frontend instead of the temporary
  text-buffer renderer.
- [x] Route backend output bytes into the terminal widget and terminal input
  back to `EmacsBackend.sendBytes`.
- [x] Keep a smoke-testable input path for fake backend ASCII text.
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
- [x] Verify macOS process-probe wiring without regressing Flutter verification.
- [x] Add a repeatable macOS native process-probe runtime smoke.
- [x] Add Flutter smoke controls for autostarting native backend and mirroring
  terminal output to process logs.
- [x] Include the macOS native process-probe smoke in Flutter verification.
- [x] Replace macOS native workspace pending errors with sandbox workspace file
  operations.
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
- [x] Add an explicit Flutter Android backend placeholder.
- [x] Select the Android placeholder backend by default on Android.
- [x] Verify Android placeholder capabilities and Android debug APK build.
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
- [x] Route pasted text as raw UTF-8 terminal bytes without appending `RET`.
- [x] Verify paste behavior with bridge tests, widget tests, structure check,
  and diff check.
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
- [ ] Make Flutter iOS build, install, and run on a physical iPad/iPhone with
  documented signing and device smoke evidence.

## Phase 0: Repository Baseline

- Keep `wasmacs` as a reference submodule.
- Document the native iPadOS direction.
- Keep the project explicitly self-build only.
- Avoid App Store distribution assumptions.

Status: met.

## Phase 1: Emacs Source And Build Probe

Goal: compile enough GNU Emacs for iOS to run a noninteractive smoke.

Tasks:

- Decide whether to use upstream GNU Emacs directly or the pinned source from
  the `wasmacs` reference path.
- Create an Xcode project or Swift Package plus Xcode app wrapper.
- Add a native iOS build script for the Emacs C core.
- Disable or stub unsupported configure surfaces:
  - subprocesses
  - PTYs
  - sockets as Emacs process objects
  - native compilation
  - external image or platform GUI backends
- Bundle the standard Lisp tree as app resources.
- Run a batch-style startup smoke in simulator first, with physical-device proof
  kept behind signing/device setup.

Exit criteria:

- The app target builds.
- The embedded Emacs artifact links.
- A diagnostic entrypoint can initialize Emacs far enough to report lifecycle
  state.

Status: met.

- The iOS app target builds in the simulator. The terminal view has been
  switched back to SwiftTerm so the app can avoid a WebView-hosted terminal.
- The Emacs iOS simulator probe links `src/temacs` as an arm64 Mach-O
  executable.
- A static archive probe now rebuilds the Emacs entry object as
  `iosmacs_emacs_main` so the app can link the Emacs core without exporting a
  second process `main`.
- A separate iOS simulator link smoke proves that archive can be linked into an
  arm64 simulator executable with the app owning `main`.
- The Xcode simulator app target now has a build phase that prepares the static
  archive, links it with `-lncurses`, and resolves `_iosmacs_emacs_main` inside
  the built app debug dylib.
- The simulator app bundle now contains the generated Emacs `lisp` tree, source
  `etc`, `lib-src`, and the generated `emacs.pdmp` resources.
- `scripts/run-emacs-ios-batch-smoke.sh` invokes `iosmacs_emacs_main` in the
  iOS simulator and reaches an evaluated Lisp marker.
- The same batch smoke succeeds when pointed at the built app bundle's copied
  `lisp` and `etc` resources.
- The app now starts linked GNU Emacs `-nw` through the terminal input/output
  path in the iOS simulator.
- A simulator install/launch smoke reaches `*scratch*` in Lisp Interaction mode
  without adding a new crash report.

## Phase 2: Minimal Host Facade

Goal: define the iOS small-OS boundary before building UI behavior on top.

Tasks:

- Add a C facade with names such as:
  - `iosmacs_os_lifecycle_state`
  - `iosmacs_os_terminal_read`
  - `iosmacs_os_terminal_write`
  - `iosmacs_os_open`
  - `iosmacs_os_read`
  - `iosmacs_os_write`
  - `iosmacs_os_stat`
  - `iosmacs_os_readdir`
  - `iosmacs_os_process_unavailable`
- Bridge facade calls to Swift or Objective-C where needed.
- Keep lifecycle and error reporting observable in logs.
- Return explicit unsupported errors for process, PTY, shell, and socket
  process paths.

Exit criteria:

- Unsupported host capabilities fail with clear diagnostics.
- Basic filesystem calls can reach the app container.
- Terminal read/write can be driven by a test harness.

Status: met.

- A first C host facade exists for lifecycle state, terminal input/output,
  terminal resize, simple POSIX file calls, and explicit unsupported process
  paths.
- A first Emacs core facade exists to start the renamed Emacs entrypoint once
  on a background thread, wire it to the fake TTY shim, and report whether it is
  still running.

## Phase 3: Terminal Emacs Startup

Goal: reach `*scratch*` through real terminal Emacs.

Tasks:

- Start Emacs in a `--quick --no-splash -nw` style session.
- Provide minimal terminal dimensions.
- Provide stdin/stdout/stderr style byte transport.
- Ensure standard Lisp load path points at bundled resources.
- Configure Dired to avoid external `ls`.
- Capture terminal output in logs before building the visual terminal.

Exit criteria:

- Device or simulator log shows Emacs reaches `*scratch*`.
- Emacs waits for terminal input.
- A diagnostic input byte reaches Emacs and changes the terminal output.

Status: met.

- Real Emacs can run in simulator batch mode through `iosmacs_emacs_main` and
  load bundled Lisp resources.
- `scripts/run-emacs-ios-nw-smoke.sh` now exercises the first non-batch
  terminal boundary. It supplies the minimal TTY answers that Emacs asks for on
  iOS simulator: `isatty`, `/dev/tty`, termios calls, `tcflow`, and
  `TIOCGWINSZ`.
- The `-nw` smoke reaches the socket-backed fake TTY boundary, captures
  ANSI/xterm terminal output, draws the initial `*scratch*` frame, and executes
  evaluated Lisp markers.
- The pdumper path now builds `emacs.pdmp` in the iOS simulator and verifies
  that the same executable can load that dump in batch mode and reach an
  evaluated-Lisp marker.
- The `-nw` smoke now generates its local pdump with the exact executable path
  that will later load it, avoiding pdump/executable fingerprint mismatch and
  stale versioned dump reuse.
- The fake TTY now connects the socket-backed terminal endpoint to
  stdin/stdout/stderr with `dup2`, while a mirrored fd keeps simulator logs
  observable. This is the shape needed for a terminal renderer to own screen
  parsing while iosmacs owns the Emacs byte transport.
- `IOSMACS_NW_EXPECT_FULL=1 scripts/run-emacs-ios-nw-smoke.sh` now reaches
  `recursive_edit`, `normal-top-level`, `command-line-1`, draws the initial
  `*scratch*` terminal frame, runs the `--eval` form, and records
  `iosmacs-nw-ok` through both terminal output and a simulator marker file.
- The fake TTY implementation now lives in `iosmacs_terminal_shim.c`, is built
  into the app target, and is reused by the `-nw` smoke instead of being
  generated inside the script.
- The shim is connected to the host terminal byte facade through input/output
  pump threads and is now enabled by the app's Emacs runner.
- The app runner and smoke now use an expanded `EMACSLOADPATH` that includes
  terminal and calendar Lisp subdirectories needed by terminal startup.
- The host facade has an env-gated smoke responder for common xterm DA, DSR,
  window-size, and OSC color queries via `IOSMACS_TERMINAL_AUTO_XTERM_REPLIES`.
  The iOS app should not enable that responder once the SwiftTerm bridge
  forwards terminal responses through the normal input-byte path.
- The skip-free `xterm-256color` smoke now reaches the evaluated Lisp marker
  with smoke-only auto replies enabled, so GNU Emacs' xterm-specific startup is
  no longer gated on `IOSMACS_NW_SKIP_TERM_INIT=1` in the script harness.
- The input proof harness now has `IOSMACS_NW_EXPECT_INPUT=1` and
  `IOSMACS_NW_EXPECT_COMMAND_INPUT=1` modes. `FIONREAD` now reports the real
  pending socket bytes, so the first mode proves a fake-TTY byte reaches
  Emacs' `read-char`. The command-loop mode injects `abc`, lets terminal Emacs
  insert it into `*scratch*`, and verifies the resulting buffer text through a
  simulator marker file.
- The app runner now attaches Emacs stdio to the fake TTY before startup, uses a
  larger Emacs thread stack, passes the bundled `emacs.pdmp` when present, and
  sets the same Lisp/data/exec resource paths as the passing smoke harness.
- The pdump build path now records `macroexp--pending-eager-loads` as `'(skip)`
  for iosmacs pdumps. That avoids runtime eager macro-expansion failures when
  the app loads source Lisp resources from the iOS bundle.

## Phase 4: SwiftTerm Terminal Adapter

Goal: use SwiftTerm as the native terminal renderer while Swift owns the native
Emacs session and tty-compatible byte queues.

Tasks:

- Keep SwiftTerm as a Swift Package dependency and native terminal adapter.
- Feed Emacs terminal output bytes into SwiftTerm with `TerminalView.feed`.
- Forward `TerminalViewDelegate.send` bytes into the fake TTY input queue.
- Propagate SwiftTerm resize callbacks to `iosmacs_os_terminal_resize`.
- Keep SwiftTerm as a terminal emulator only; do not introduce subprocess, PTY,
  SSH, shell, filesystem, or Emacs command ownership through the terminal view.
- Add a simple developer log panel or exportable log file.
- Add simulator UI smokes for the SwiftTerm path, including ASCII insertion and
  Japanese IME composition/commit behavior.

Exit criteria:

- User can type into `*scratch*`.
- Basic Emacs control keys work from a hardware keyboard.
- Terminal redraw remains coherent across app resize/orientation changes.
- Japanese IME behavior is explicitly tested on the native UIKit path.
- Committed Japanese text reaches Emacs as UTF-8 bytes.
- WebView/xterm.js is no longer linked or bundled by the app target.

Status: implemented in the app build; simulator manual IME acceptance remains
pending. This replaces the WebView/xterm.js route.

- Historical SwiftTerm spike:
  SwiftTerm was installed through Swift Package Manager, wrapped in SwiftUI, and
  connected to the iosmacs session object. It proved that the real Emacs `-nw`
  fake TTY stream could be rendered in the simulator and that keyboard bytes
  could be forwarded back to Emacs. The route is now superseded because iOS
  Japanese IME marked-text ownership is brittle in the native terminal path.
- SwiftTerm has been restored in the Xcode target and Swift Package resolution.
- The bundled WebView/xterm.js resources have been removed from the app target.
- `IOSMacsTerminalView` now wraps `TerminalView` directly.
- Swift drains Emacs terminal output and feeds byte chunks into SwiftTerm.
- `IOSMACS_APP_AUTOTYPE_TEXT` injects through SwiftTerm's native text insertion
  path.
- The app runner sets the same expanded Lisp load path and charprop fallback
  environment used by the passing simulator `-nw` smoke.
- The script-level simulator proof verifies fake-TTY input through both
  `read-char` and command-loop insertion into `*scratch*`.
- The app-level simulator smoke should be extended to assert the SwiftTerm
  bridge marker and Japanese IME behavior.
- Simulator runtime screenshots should be refreshed after SwiftTerm renders the
  linked Emacs fake TTY state and final Lisp Interaction `*scratch*` frame.
- The current terminal library decision is SwiftTerm: iosmacs keeps ownership
  of the embedded native Emacs session and byte transport without hosting the
  terminal renderer in a WebView.
- `/home/user` now maps to `Documents/home/user` in the iOS app container. The
  app creates an initial `README.txt` and `notes/` directory before starting
  Emacs.
- The path shim translates the POSIX operations Emacs uses for local files,
  including `open/openat`, `stat/fstatat`, `access/faccessat`, directory
  creation/removal, rename/unlink, symlink/readlink, `chdir`, and `opendir`.
- Startup Lisp sets `HOME`/`default-directory` to `/home/user` and configures
  Dired to use `ls-lisp` instead of an external `ls` process.
- `IOSMACS_NW_EXPECT_FILE_OPS=1 IOSMACS_NW_EXPECT_FULL=1
  scripts/run-emacs-ios-nw-smoke.sh` now creates, saves, reopens, and Dired
  lists `/home/user/notes/iosmacs-file-smoke.txt`.
- The simulator app also has an env-gated
  `IOSMACS_APP_FILE_SMOKE_MARKER` proof that performs the same file operation
  sequence in the running app and leaves the saved file in the app container.
- The bottom app toolbar now exposes document Import and Export controls.
  Import copies selected iPadOS document-picker files into `/home/user`; Export
  presents the current workspace contents through the iPadOS document picker as
  copies.
- The toolbar also includes icon-only font-size controls, workspace reset, and
  terminal redraw. App-level hardware keyboard shortcuts cover those controls,
  while the status strip reports lifecycle state, startup elapsed time, and
  resident memory.
- Emacs exit status is surfaced in lifecycle state when the background Emacs
  thread ends, and diagnostic fallback remains available when the core cannot
  start.
- README documents the MVP unsupported surface: subprocesses, shell buffers,
  TRAMP, LSP servers, native compilation, package-managed native executables,
  device/App Store distribution, and the Phase 7 iCloud/network/color proof
  boundaries.

## Phase 5: App Container Files

Goal: support useful local editing.

Tasks:

- [x] Map `/home/user` to the app container.
- [x] Add initial workspace skeleton.
- [x] Verify `find-file` under `/home/user`.
- [x] Verify save and reload.
- [x] Verify Dired under `/home/user`.
- [x] Add user-initiated import/export through iPadOS document APIs.

Exit criteria:

- User can create, edit, save, reopen, and list files inside the app container.
- Dired does not require an external process.
- Relaunch preserves saved files.

## Phase 6: Hardening

Goal: make the experiment pleasant enough for daily dogfooding.

Tasks:

- [x] Improve crash diagnostics.
- [x] Add lifecycle state display.
- [x] Add reset workspace action.
- [x] Add font size controls.
- [x] Improve keyboard shortcuts for iPad hardware keyboards.
- [x] Measure startup time and memory usage.
- [x] Document known unsupported Emacs features in the README.

Exit criteria:

- A developer can clone, build, install, launch, edit a file, and recover from
  common failures using documented steps.

## Deferred

These are not MVP work:

- App Store distribution.
- Package byte/native compilation and package-managed native executables.
- Native compilation.
- TRAMP.
- Full subprocess support.
- PTY-backed shell buffers.
- LSP server processes inside the app.
- Native GUI Emacs frames.
- Full POSIX emulation.

## Phase 7: Optional Next Steps

- [x] /home/userをiCloud領域ににおいてファイルシステムが見えること
- [x] networkが動き、任意のelispパッケージをインストールできること
- [x] xterm256-color相当のカラー表示が可能なこと

Status: met.

- `/home/user` now prefers the app's iCloud ubiquity container when iCloud is
  available, and falls back to app Documents otherwise. The same path shim and
  Dired/file-save smoke cover the visible filesystem behavior; simulator iCloud
  availability still depends on signing/account/entitlement setup.
- The script-level color proof sends 256-color SGR sequences through Emacs
  terminal output. The app-level color screenshot should be refreshed after
  SwiftTerm simulator IME QA.
- `scripts/run-emacs-ios-nw-smoke.sh` now has
  `IOSMACS_NW_EXPECT_NETWORK=1`, which generates an Emacs Lisp package smoke
  that downloads `a68-mode-1.3.tar` from GNU ELPA over HTTP, writes the tarball
  under `/home/user`, installs it with `package-install-file`, and verifies
  `(require 'a68-mode)`. The smoke disables package byte/native compilation,
  which remains outside the iOS MVP, but verifies network transport, tar
  extraction, package descriptor registration, load-path activation, and
  loading an installed pure-Elisp package.
