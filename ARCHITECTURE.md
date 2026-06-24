# iosmacs Architecture

## Purpose

`iosmacs` is a native iOS/iPadOS host for GNU Emacs.

The core idea is to provide the smallest runtime environment that lets the real
GNU Emacs C core and standard Lisp runtime survive inside an iOS app sandbox.
Swift owns the app shell, rendering, storage bridge, and platform integration.
Emacs owns editor semantics.

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

## Layering

```text
Swift iOS/iPadOS App
  - window scene and lifecycle
  - terminal grid rendering
  - keyboard and touch input collection
  - file import/export UI
  - app container persistence
  - diagnostics and logs

Host Bridge
  - C/ObjC/Swift boundary
  - filesystem service
  - terminal byte service
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
- Terminal grid drawing.
- Hardware and software keyboard event capture.
- Touch affordances around the terminal.
- App container file access.
- User-driven import/export.
- iPadOS clipboard access, if and when exposed.
- Diagnostics visible to the developer.

The host bridge owns:

- Translating Emacs file operations to the app container.
- Translating terminal output bytes to the Swift terminal grid.
- Translating terminal input bytes back to Emacs.
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
a minimal terminal byte stream. Swift renders the stream into a terminal grid
and sends keyboard input back as bytes or key sequences.

The first terminal renderer can be simple:

- Monospace grid.
- Basic ANSI control sequence handling.
- Cursor drawing.
- Resize propagation.
- Hardware keyboard support first.
- Software keyboard support second.

Swift must not reinterpret Emacs keymaps. It only transports input.

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
5. Type text through the Swift terminal grid.
6. Open a file under `/home/user`.
7. Save it.
8. Open Dired for `/home/user`.
9. Quit and relaunch.
10. Confirm the saved file is still present.
