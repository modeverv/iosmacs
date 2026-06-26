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
  - FakeBackend for UI tests and early development
  - IosNativeBackend for the current iosmacs Emacs core and fake TTY
  - MacosProcessBackend for desktop PTY experiments
  - LinuxProcessBackend for PTY-backed desktop sessions
  - WindowsConptyBackend for Windows terminal sessions
  - AndroidNativeBackend for NDK/native experiments
  - WebWasmBackend for wasmacs/WASM integration

GNU Emacs Runtime
  - native static/library artifact on iOS and Android where feasible
  - child process on macOS/Linux/Windows where feasible
  - WebAssembly runtime on Web
```

## Ownership Rules

Flutter owns:

- app navigation and layout,
- terminal widget integration,
- font-size and display controls,
- status and diagnostic presentation,
- user-triggered workspace import/export UI,
- choosing a backend implementation at runtime or build time.
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
keyboard / IME / terminal widget
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

The iOS backend should reuse the current iosmacs native implementation:

- GNU Emacs native static archive,
- `iosmacs/Host` facade,
- `iosmacs/Emacs` bridge,
- fake TTY terminal shim,
- app container workspace mapping,
- existing simulator marker style.

The Flutter iOS app should remove SwiftTerm from the new path and replace it
with the Flutter terminal widget. The old SwiftTerm app remains available until
the Flutter path has equivalent startup, input, resize, and file-operation
proof.

### macOS

The macOS backend should be the first desktop proving ground.

Start with:

- Flutter desktop UI,
- a child Emacs process or bundled native Emacs,
- PTY-backed terminal transport,
- the same Dart backend interface.

macOS should help prove the UI/backend contract before Linux and Windows are
expanded.

### Linux

The Linux backend should follow the macOS process-plus-PTY shape where
possible. Linux-specific packaging, font, clipboard, and filesystem behavior
should stay behind the backend.

### Windows

The Windows backend should use a Windows-native terminal transport such as
ConPTY. Windows path handling, executable discovery, bundled runtime behavior,
and workspace mapping must be explicit backend responsibilities.

### Android

The Android backend is a native-runtime project, not just a Flutter UI task.
The likely hard parts are NDK compilation, sandboxed storage, document access,
keyboard/IME behavior, and terminal transport.

The Android backend should reuse the same facade ideas as iOS where practical,
but it should not block the Flutter shell or desktop backend work.

### Web

The Web backend is separate from the native backend family.

Flutter Web cannot rely on the same native FFI path. The realistic direction is
to use the `wasmacs` WebAssembly/browser runtime as a separate backend and
bridge it to the Flutter Web UI through JavaScript/WASM integration.

Web should therefore be tracked as `WebWasmBackend`, not as a direct port of
the iOS native backend.

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
