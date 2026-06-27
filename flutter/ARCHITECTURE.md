# iosmacs Flutter Architecture

## Purpose

The Flutter architecture keeps the UI portable while making backend differences
explicit.

Flutter should own the cross-platform application shell and terminal surface.
Platform backends should own the details of running or embedding GNU Emacs,
connecting terminal bytes, managing workspace files, and reporting unsupported
capabilities.

The existing iOS app remains the reference implementation until the Flutter iOS
path proves equivalent behavior.

## High-Level Shape

```text
Flutter App
  - terminal screen
  - status and diagnostics
  - toolbar and keyboard affordances
  - workspace import/export UI
  - Dart EmacsBackend interface

Backends
  - FakeEmacsBackend for UI tests, deterministic smoke runs, and development
  - NativeEmacsBackend for the current iosmacs iOS/macOS MethodChannel bridge
  - AndroidEmacsBackend placeholder for Android native-runtime work
  - DesktopEmacsBackend placeholders for Linux and Windows desktop runtime work
  - WebWasmEmacsBackend placeholder for wasmacs/WASM integration

GNU Emacs Runtime
  - native static/library artifact on iOS and Android where feasible
  - child process on macOS/Linux/Windows where feasible
  - WebAssembly runtime on Web
```

## Current Implementation Status

The Flutter app currently implements the UI/backend contract in
`flutter/iosmacs_flutter`.

Implemented pieces:

- `IOSMacsFlutterApp` owns the app shell and backend selection.
- `TerminalScreen` owns the xterm terminal widget, toolbar actions, the status
  strip, diagnostics details dialog, workspace import/export/refresh/open dialogs,
  capability dialogs, startup smoke hooks, and optional mirrored terminal output
  logging.
- `EmacsBackend` owns lifecycle, terminal byte input/output, resize events,
  workspace operations, and capability reporting.
- `FakeEmacsBackend` and `FakeBackendWorker` provide deterministic output and
  UI-test behavior without native runtime dependencies.
- `NativeEmacsBackend` routes through the `iosmacs/native_emacs`
  MethodChannel. It is the default backend on iOS and macOS.
- `AndroidEmacsBackend`, `DesktopEmacsBackend`, and `WebWasmEmacsBackend`
  make non-iOS backend boundaries explicit while unsupported runtime features
  are still being built.

Default backend selection is centralized in `backend_factory.dart`.
`IOSMACS_FLUTTER_BACKEND` can force a backend for smoke testing. Supported
override names include `fake`, `ios`, `ios-native`, `macos`, `macos-native`,
`android`, `linux`, `windows`, `web`, and `web-wasm`. `default` and `platform`
fall back to the platform default.

## Ownership Rules

Flutter owns:

- app navigation and layout,
- terminal widget integration,
- font-size and display controls,
- status and diagnostic presentation,
- user-triggered workspace import/export UI,
- terminal paste buttons and keyboard paste shortcuts,
- choosing a backend implementation at runtime or build time,
- clipboard paste handoff into committed terminal bytes.
- input composition only up to the point where committed bytes are available.

The Dart backend interface owns:

- lifecycle commands,
- terminal input and output byte streams,
- resize events,
- workspace operations,
- backend capability reporting.
- worker coordination between the Flutter UI and the platform runtime.

Platform backends own:

- native library loading,
- process or embedded runtime startup,
- PTY, fake TTY, ConPTY, or WASM terminal transport,
- platform file access,
- sandbox/document-provider behavior,
- platform diagnostics,
- explicit unsupported errors.

GNU Emacs owns:

- editor semantics,
- buffers and windows,
- minibuffer behavior,
- undo and kill ring,
- keymaps and command dispatch,
- Dired behavior,
- Lisp evaluation.

Flutter and Dart must not reimplement Emacs editing behavior. They should not
own command semantics, completion semantics, buffer mutation semantics, Dired
semantics, minibuffer semantics, or keymap interpretation. Those bytes should
flow through the terminal/backend boundary and let Emacs decide what they mean.

## Runtime Separation

The Flutter implementation should use three runtime roles:

```text
Flutter main isolate
  - UI rendering
  - terminal widget
  - platform text input and IME composition
  - user-visible status and controls

Backend worker
  - byte pumping
  - lifecycle observation
  - output buffering and backpressure
  - native FFI or platform-channel calls
  - workspace import/export work
  - diagnostics collection

Emacs runtime
  - editor state
  - command loop
  - Lisp evaluation
  - terminal redisplay
  - file semantics inside the selected workspace
```

The main isolate should stay responsive even when Emacs starts slowly, produces
large terminal output, blocks on input, or performs file work. The backend
worker is a transport and platform boundary, not a second editor model.

## Backend Interface

The Flutter UI talks to an `EmacsBackend` abstraction. A backend may be fake,
native, process-backed, or WASM-backed, but it should present the same minimum
shape to the UI.

Core responsibilities:

- `start()`: start or attach to the backend runtime.
- `stop()`: stop the backend when the platform supports it.
- `sendBytes(bytes)`: forward committed terminal input bytes.
- `resize(cols, rows)`: report terminal geometry.
- `outputStream`: stream terminal output bytes to the terminal widget.
- `lifecycleState`: expose human-readable state for diagnostics.
- `workspaceImport/export`: route user-driven file movement through the
  platform backend.

The backend interface should use bytes at the terminal boundary. It should not
use high-level Emacs commands for normal typing, and it should not expose
Dart-side editing commands that bypass Emacs.

## Terminal Boundary

The terminal widget is a renderer and input surface only.

Input path:

```text
keyboard / IME / terminal widget / clipboard paste
  -> committed bytes
  -> EmacsBackend.sendBytes
  -> backend worker
  -> platform terminal transport
  -> Emacs
```

Output path:

```text
Emacs
  -> platform terminal transport
  -> backend worker
  -> EmacsBackend.outputStream
  -> Flutter terminal widget
```

Resize path:

```text
Flutter layout
  -> terminal cols/rows
  -> EmacsBackend.resize
  -> backend worker
  -> platform terminal transport
  -> Emacs
```

Japanese IME composition must be validated at the Flutter terminal layer.
Marked text should remain owned by the platform text input system until commit.
Only committed text should cross the backend boundary as UTF-8 bytes.
After commit, Dart should transport the bytes as-is and avoid interpreting them
as Emacs commands.

## Platform Backend Strategy

### iOS

The iOS backend reuses the current iosmacs native implementation:

- GNU Emacs native static archive,
- `iosmacs/Host` facade,
- `iosmacs/Emacs` bridge,
- fake TTY terminal shim,
- app container workspace mapping,
- existing simulator marker style.

The Flutter iOS app removes SwiftTerm from the new path and uses the Flutter
xterm terminal widget. The old SwiftTerm app remains available until the
Flutter path has equivalent startup, input, resize, and file-operation proof.

### macOS

The macOS backend is the first desktop proving ground.

The current Flutter macOS path uses `NativeEmacsBackend` through the shared
MethodChannel bridge for native startup and smoke evidence. The macOS Runner
bundles a repo-built GNU Emacs runtime under
`Contents/Resources/iosmacs-emacs` and holds that Emacs as a child process
through `forkpty(3)`, giving Emacs `-nw` a real controlling terminal while
keeping the Dart contract at the same byte-stream boundary as iOS.

Implemented macOS pieces:

- Flutter desktop UI,
- bundled macOS GNU Emacs runtime packaging through
  `scripts/build-flutter-macos-emacs-runtime.sh`,
- app-bundle Emacs discovery through `Bundle.main.resourceURL`, with
  `IOSMACS_FLUTTER_EMACS` left only as an explicit debug fallback,
- child-process lifecycle behind the `iosmacs/native_emacs` MethodChannel,
- terminal output draining from the PTY master,
- committed terminal input forwarding into the PTY master,
- redraw, PTY resize, and stop forwarding,
- Application Support workspace list/import/export,
- the same Dart backend interface as iOS.

Still explicit macOS gaps:

- command-loop insertion marker proof matching the deepest iOS native smoke.

macOS should help prove the UI/backend contract before Linux and Windows are
expanded.

### Linux

The Linux backend is currently represented by a `DesktopEmacsBackend`
placeholder. It should follow the macOS process-plus-PTY shape where possible.
Linux-specific packaging, font, clipboard, and filesystem behavior should stay
behind the backend.

### Windows

The Windows backend is currently represented by a `DesktopEmacsBackend`
placeholder. It should use a Windows-native terminal transport such as ConPTY.
Windows path handling, executable discovery, bundled runtime behavior, and
workspace mapping must be explicit backend responsibilities.

### Android

The Android backend is represented by `AndroidEmacsBackend`. It is a
native-runtime project, not just a Flutter UI task. The likely hard parts are
NDK compilation, sandboxed storage, document access, keyboard/IME behavior, and
terminal transport.

The Android backend should reuse the same facade ideas as iOS where practical,
but it should not block the Flutter shell or desktop backend work.

### Web

The Web backend is separate from the native backend family.

Flutter Web cannot rely on the same native FFI path. The realistic direction is
to use the `wasmacs` WebAssembly/browser runtime as a separate backend and
bridge it to the Flutter Web UI through JavaScript/WASM integration.

Web is therefore tracked as `WebWasmEmacsBackend`, not as a direct port of the
iOS native backend.

## Runtime Smoke Flags

The Flutter entry point accepts these compile-time environment flags through
`--dart-define`:

- `IOSMACS_FLUTTER_AUTOSTART_NATIVE`: start the selected backend after launch.
- `IOSMACS_FLUTTER_MIRROR_TERMINAL_OUTPUT`: mirror terminal output to the debug
  log with an `iosmacs-terminal-output:` prefix.
- `IOSMACS_FLUTTER_WORKSPACE_SMOKE`: run workspace capability smoke actions
  after startup and log `iosmacs-workspace-smoke:` list, import, open, and
  export evidence.
- `IOSMACS_FLUTTER_CAPABILITIES_SMOKE`: log selected backend capability counts
  with an `iosmacs-capabilities-smoke:` prefix.
- `IOSMACS_FLUTTER_INPUT_SMOKE`: submit committed UTF-8 text through the
  terminal input bridge and log `iosmacs-input-smoke:` byte-count evidence.
- `IOSMACS_FLUTTER_RESIZE_SMOKE`: send fixed terminal geometry through
  `EmacsBackend.resize()` and log `iosmacs-resize-smoke:` evidence.
- `IOSMACS_FLUTTER_REDRAW_SMOKE`: call `EmacsBackend.resetOrRedraw()` and log
  `iosmacs-redraw-smoke:` diagnostics evidence.
- `IOSMACS_FLUTTER_STATUS_SMOKE`: log selected backend id, lifecycle, and
  geometry with an `iosmacs-status-smoke:` prefix.
- `IOSMACS_FLUTTER_STOP_SMOKE`: call `EmacsBackend.stop()` after the enabled
  startup smokes and log `iosmacs-stop-smoke:` lifecycle evidence.
- `IOSMACS_FLUTTER_BACKEND`: force backend selection for smoke runs.

These flags are part of the runtime verification surface. They should stay
small, stable, and easy to grep in simulator, desktop, and CI logs.

## Verification Contract

The top-level Flutter verification contract is:

```sh
make flutter-verify
```

That target runs the structure check, Flutter doctor, Dart format check,
Flutter analyze, fake backend tests, iOS launch smoke, macOS smoke, macOS
native smoke, backend override smoke, Web build smoke, and Android APK build
smoke.

Focused targets are available when iterating:

- `make flutter-structure-check` validates expected Flutter files, scripts,
  Make targets, and executable smoke scripts.
- `make flutter-format-check` checks Dart formatting for Flutter sources and
  tests.
- `make flutter-analyze` runs Dart static analysis for the Flutter shell.
- `make flutter-fake-smoke` runs the Flutter test suite.
- `make flutter-ios-launch-smoke` verifies iOS Runner launch evidence.
- `make flutter-macos-smoke` verifies macOS Runner launch evidence.
- `make flutter-macos-native-smoke` verifies native backend autostart,
  terminal output mirroring, capabilities, input, resize, redraw, status smoke
  evidence, stop, and workspace list/import/open/export smoke evidence.
- `make flutter-backend-override-smoke` forces `fake`, `android`, `linux`,
  `windows`, and `web-wasm` backends through the macOS Runner and checks their
  capability, input, resize, redraw, status smoke output, workspace smoke
  list/import/open/export output, and stop smoke output.
- `make flutter-web-smoke` builds the Web target.
- `make flutter-android-smoke` builds the Android APK target.

## Compatibility Principles

- Keep the existing Xcode app working while Flutter is developed.
- Prefer fake backend proof before native backend wiring.
- Preserve terminal byte ownership instead of adding Emacs-command shortcuts.
- Keep semantics in Emacs; Dart is transport, presentation, diagnostics, and
  platform coordination.
- Keep the runtime split explicit: Flutter main isolate, backend worker, Emacs
  runtime.
- Keep unsupported features explicit.
- Treat each platform backend as a named boundary with its own limitations.
- Keep Web separate because its runtime constraints differ from native Flutter.
- Promote a backend only after there is smoke evidence for startup, rendering,
  input, resize, and workspace behavior.
