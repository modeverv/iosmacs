# iosmacs Architecture

## Purpose

`iosmacs` is a native iOS/iPadOS host for GNU Emacs.

The core idea is to provide the smallest runtime environment that lets the real
GNU Emacs C core and standard Lisp runtime survive inside an iOS app sandbox.
Swift owns the app shell, the `WKWebView` host, the storage bridge, and platform
integration. xterm.js owns terminal rendering inside the WebView. Emacs owns
editor semantics.

This project intentionally does not target App Store distribution. The expected
installation path is local developer build and deployment to a user's own
iPhone or iPad.

## Relationship To wasmacs

`wasmacs` runs GNU Emacs in a browser-oriented WebAssembly environment. It is
valuable here because it identifies the OS-like contracts Emacs needs when it
is not running on a normal Unix desktop.

`iosmacs` should reuse those lessons, not the browser runtime:

- Keep Emacs editor state inside Emacs.
- Keep host capabilities explicit.
- Treat subprocesses, PTYs, sockets, and arbitrary command execution as
  deliberate unavailable boundaries.
- Prefer small named facades over scattered ad hoc shims.
- Separate product behavior from diagnostic probes.
- Reuse the xterm.js terminal-front-end boundary, not the WebAssembly Emacs
  runtime.
- Treat xterm.js as a renderer/input surface only: no process, filesystem,
  shell, PTY, or Emacs command semantics live in JavaScript.
- Avoid importing `wasmacs` SharedArrayBuffer, Atomics, worker, or `.wasifs`
  runtime machinery into the iOS app.

## Layering

```text
Swift iOS/iPadOS App
  - window scene and lifecycle
  - WKWebView host and script message handlers
  - file import/export UI
  - app container persistence
  - diagnostics and logs

Bundled Web Terminal
  - xterm.js renderer
  - terminal bridge JavaScript
  - TextEncoder/TextDecoder byte conversion
  - IME/composition surface
  - browser keyboard, selection, cursor, and terminal grid behavior

Host Bridge
  - C/ObjC/Swift boundary
  - filesystem service
  - tty-compatible byte service
  - clock, random, environment, cwd
  - unavailable process service
  - optional URLSession-backed fetch service

GNU Emacs Core
  - C core
  - Lisp runtime
  - command loop
  - buffers, windows, undo, kill ring, minibuffer
  - terminal redisplay for -nw
  - file visiting and Dired semantics

Bundled Resources
  - standard Emacs Lisp tree
  - site startup files required by iosmacs
  - initial user skeleton
```

## Ownership Rules

Emacs owns:

- Buffers and buffer text.
- Undo and kill ring.
- Minibuffer behavior.
- Keymaps and command dispatch.
- Dired semantics.
- File visiting and save semantics.
- Lisp evaluation and GC safety.

Swift owns:

- UIKit and SwiftUI lifecycle.
- WKWebView lifecycle and configuration.
- `WKScriptMessageHandler` dispatch for terminal events from JavaScript.
- Touch affordances around the terminal.
- App container file access.
- User-driven import/export.
- iPadOS clipboard access, if and when exposed.
- Diagnostics visible to the developer.

xterm.js and the bundled bridge JavaScript own:

- Terminal grid drawing.
- ANSI/xterm parsing.
- Cursor state.
- Selection.
- Browser text input.
- IME marked-text/composition UI.
- Conversion of committed `onData` strings to UTF-8 bytes.
- Terminal resize calculation.

The host bridge owns:

- Translating Emacs file operations to the app container.
- Translating terminal output bytes to the WebView terminal bridge.
- Translating terminal input bytes back to Emacs.
- Translating terminal resize events back to Emacs.
- Returning explicit unavailable errors for unsupported process APIs.

## Filesystem Model

The MVP filesystem is intentionally small:

```text
/system      read-only bundled Emacs Lisp and resources
/home/user   writable workspace in the app container
/tmp         volatile temporary storage
```

Rules:

- `/system` is bundled with the app and read-only.
- `/home/user` maps to the app container by default, or to a user-selected
  document-provider folder after the next launch.
- `find-file`, save, and Dired are scoped to `/home/user` for the MVP.
- User import/export should be explicit and user initiated.
- Dired should use Lisp-level directory listing behavior such as `ls-lisp`,
  not an external `ls` subprocess.

## Terminal Model

The MVP uses terminal Emacs, not native GUI Emacs frames.

Emacs starts in a `--quick --no-splash -nw` style mode. The host bridge provides
a minimal tty-compatible byte stream. `WKWebView` hosts xterm.js, xterm.js
renders the stream into a terminal grid, and committed terminal input returns to
Swift as bytes.

The terminal byte paths are:

- Input: `term.onData(data)` in JavaScript uses `TextEncoder` to produce UTF-8
  bytes and posts `{ type: "input", bytes: [...] }` to Swift through
  `WKScriptMessageHandler`.
- Output: Swift drains `iosmacs_os_terminal_drain_output` and calls a bundled
  JavaScript bridge function that writes a `Uint8Array` chunk into xterm.js.
- Resize: xterm.js calculates rows and columns, then posts
  `{ type: "resize", cols, rows }`; Swift forwards that to
  `iosmacs_os_terminal_resize`.
- Readiness and diagnostics: JavaScript posts explicit ready/focus/log events
  so the native side can drive smoke tests and expose errors.

IME composition is owned by the browser/xterm input surface. Uncommitted marked
text must not be injected into Emacs or painted by Swift. Only committed
`onData` text crosses to Swift as UTF-8 bytes.

Swift must not reinterpret Emacs keymaps. JavaScript must not reinterpret Emacs
keymaps either. The WebView bridge transports terminal bytes and resize events.

## Process And Network Boundaries

Subprocesses are unavailable in the MVP.

The following should fail clearly:

- `shell-command`
- `call-process` for external commands
- `make-process`
- arbitrary PTY use
- native compilation
- external compilers, grep, find, LSP servers, and shells

Network should not be modeled as raw sockets in the first version. If package
metadata or downloads are explored later, they should cross an explicit
`host.network.fetch` style boundary backed by `URLSession`. Arbitrary package
installation is out of MVP scope.

## Build Shape

The preferred shape is:

- Build GNU Emacs for iOS as a native artifact.
- Link or embed that artifact in an Xcode app target.
- Keep standard Lisp resources in the app bundle.
- Add a small C facade for `iosmacs_os_*` calls where direct POSIX behavior is
  unavailable or unsafe.
- Bridge the facade to Swift only for host-owned capabilities.

Avoid spreading iOS-specific behavior throughout Emacs source. Keep patches
small, named, and tied to a host service.

## First Acceptance Test

The first real acceptance test is:

1. Install the app on an iPad from Xcode.
2. Launch the app.
3. Start embedded Emacs with bundled standard Lisp.
4. Reach `*scratch*`.
5. Type ASCII and Japanese text through the xterm.js WebView terminal.
6. Open a file under `/home/user`.
7. Save it.
8. Open Dired for `/home/user`.
9. Quit and relaunch.
10. Confirm the saved file is still present.
11. Confirm Japanese IME composition does not corrupt the terminal while marked
    text is uncommitted.
