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

The Flutter path should grow its own verification targets later, likely:

- `make flutter-fake-smoke`
- `make flutter-ios-smoke`
- `make flutter-macos-smoke`
- platform-specific backend smokes as they become real

Do not replace the existing verification path until the Flutter iOS backend has
equivalent evidence for startup, terminal rendering, input, file operations, and
diagnostics.
