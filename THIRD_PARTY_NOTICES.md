# Third Party Notices

`iosmacs` links and bundles GNU Emacs so the project is distributed under
GPL-3.0-or-later as a whole.

This file is an inventory of upstream components currently used by the project.
It is not legal advice. When distributing binaries or app bundles, include this
file, the top-level `LICENSE`, and the license texts under `LICENSES/`.

## GNU Emacs

- Component: GNU Emacs C core, Lisp runtime, standard Lisp tree, generated
  portable dump resources
- Source path: `wasmacs/vendor/emacs`
- Upstream: `https://github.com/emacs-mirror/emacs.git`
- Current pinned tag: `emacs-30.2`
- Current pinned commit: `636f166cfc86aa90d63f592fd99f3fdd9ef95ebd`
- License: GPL-3.0-or-later
- License text: `LICENSE`

`iosmacs` builds GNU Emacs into `build/emacs-ios-probe/iosmacs/libiosmacs-temacs.a`,
renames the process entrypoint to `iosmacs_emacs_main`, links that archive into
the iOS simulator app, and bundles generated Emacs resources such as `lisp`,
`etc`, `lib-src`, and `emacs.pdmp`.

## xterm.js

- Component: terminal emulator rendered inside the iOS app's `WKWebView`
- Upstream: `https://github.com/xtermjs/xterm.js`
- Package: `@xterm/xterm`
- Version: `6.0.0`
- License: MIT
- License text: `LICENSES/xterm-MIT.txt`

## xterm.js fit addon

- Component: xterm.js terminal resize fitting inside the WebView
- Upstream: `https://github.com/xtermjs/xterm.js`
- Package: `@xterm/addon-fit`
- Version: `0.11.0`
- License: MIT
- License text: `LICENSES/xterm-addon-fit-MIT.txt`

## Distribution Notes

- Local private building and installation from source does not by itself convey
  the app to another party.
- If distributing an app binary, archive, or `.ipa`, provide the corresponding
  source for the GPL-covered work, including the build scripts needed to
  reproduce and modify the distributed object code.
- App Store distribution is intentionally out of scope for this project because
  additional platform distribution terms can conflict with GPL requirements.
