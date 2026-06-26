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
