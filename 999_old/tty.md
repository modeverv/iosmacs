# Flutter iOS tty performance plan

Goal: make Flutter iOS terminal I/O behave like a normal OS terminal/PTY closely enough that interactive Emacs and paste reach roughly 80% of ordinary local terminal read/write responsiveness.

## Current Split

- Flutter UI/main isolate owns screen rendering, toolbar actions, and MethodChannel calls.
- `FlutterNativeEmacsBridge.swift` receives Flutter input and currently pushes bytes into the native terminal input ring.
- `iosmacs_emacs_core.c` starts GNU Emacs on a detached pthread, so Emacs may block without blocking Flutter UI.
- `iosmacs_terminal_shim.c` opens a fake tty/PTY or socketpair, redirects stdin/stdout, and pumps terminal output to the host output ring. Stderr stays on the app log stream so platform diagnostics do not appear inside Emacs.
- `iosmacs_host_facade.c` owns input/output rings and `pthread_cond` wakeups for host wait points.
- The generated Emacs probe patches `keyboard.c`/`sysdep.c` so Emacs can wait on `iosmacs_host_wait_for_input` and read from the host tty facade.

## TODO

- [x] Document the current terminal split: Flutter UI, native bridge, Emacs pthread, fake tty/shim, input/output rings.
- [x] Remove the stale byte-at-a-time Emacs direct-read path and make generated Emacs use `iosmacs_host_terminal_read(tty_buf, nbyte)` bulk reads.
- [x] Keep the native input path event-driven: input push must wake `iosmacs_host_wait_for_input` immediately and must not depend on periodic polling.
- [x] Strengthen fake tty push semantics so Flutter and root native iOS both enter through the shim-level input API instead of bypassing it.
- [x] Reduce hot-path debug overhead so paste never performs per-byte marker file writes.
- [x] Add structure checks that reject the stale `iosmacs_host_terminal_read_byte()` loop in generated Emacs patching.
- [x] Run Flutter unit tests and structure checks.
- [x] Run the iOS native smoke if the simulator/runtime is available.
- [x] Record measured or observed paste/read behavior and remaining gap.
- [x] Normalize native `UITextView` paste line feeds to terminal carriage
  returns before writing to the fake tty.
- [x] Route native `UITextView` paste through bracketed paste while keeping
  ordinary typing and IME commits as raw terminal input.
- [x] Revert hidden-text-view bypass via direct `UIPasteboard.general.string`
  after it could hang before bytes reached the fake tty.
- [x] Suppress redisplay while Emacs reads xterm bracketed paste payloads from
  the fake tty.
- [x] Add native paste-stage logging for UIKit paste start/return,
  `textViewDidChange`, bridge forward, and shim write completion.
- [x] Use Simulator logs to separate the current 20s paste delay from native
  fake-tty writes: a Japanese Cmd+V paste showed Pasteboard reads at
  23:48:06.722 and terminal output only at 23:48:26.153, while no native
  `textinput forward` log appeared.
- [x] Treat that as a Flutter `TerminalView` normal-input paste route and add
  an app-level `Cmd+V` shortcut that forwards through the existing
  clipboard/bracketed-paste path instead.
- [x] Rebuild and install the updated Simulator app, then re-test Paste button
  routing with Computer Use and Simulator logs.
- [x] Confirm Flutter Clipboard paste pushes the long Japanese test string to
  native `sendBytes` in 6ms (`00:02:18.745` start,
  `00:02:18.752` accepted) instead of spending 20s in Flutter text input.
- [x] Confirm bracketed paste is not usable as the default yet: Emacs did not
  redisplay after the bracketed payload was accepted, so the current default
  paste route must be normalized raw terminal input.
- [x] Remove bracketed markers from Flutter Paste/Cmd+V and native paste
  fallback while preserving LF/CRLF to terminal-CR normalization.
- [x] Rebuild and install the raw-normalized paste build, then re-test the same
  Japanese long paste to confirm visible insertion happens promptly.
- [x] Measure the raw-normalized paste path: 342 bytes were accepted by native
  `sendBytes` in 6ms (`00:07:26.940` to `00:07:26.946`) and first visible
  terminal output appeared at `00:07:33.025`, about 6.1 seconds after input
  acceptance.
- [x] Add unified-log instrumentation to split the remaining paste delay into
  native `sendBytes`, fake tty marker trace, Emacs `gobble_input`, native
  `drainOutput`, and Dart output-stream emission.
- [x] Rebuild the instrumented Simulator app and capture one long Japanese
  paste log with all timing markers in the same Runner log stream.
- [x] Split the remaining 6.1 second paste delay: native accepted 342 bytes at
  `00:18:08.971`, the marker trace recorded `terminal push-input`,
  `terminal read-available`, and `emacs sysdep tty-read bytes=342` in the same
  monotonic millisecond `t=20756506`, and the first `terminal write-output`
  appeared at `t=20762751`.
- [x] A/B 1: set `gc-cons-threshold` to 100MB, rebuild/relaunch, paste the same
  Japanese payload, and compare `tty-read` to first `write-output`.
- [x] A/B 2: replace or disable `terminal-init-xterm` with a wasmacs-style
  lightweight xterm setup, rebuild/relaunch, paste the same payload, and record
  whether the post-read gap changes.
- [x] A/B 3: check whether the iOS Emacs build can avoid `TERMINFO` and use the
  explicit `TERMCAP`/internal-termcap path like wasmacs; if buildable, measure
  the same paste path.
- [x] Add Emacs-side timing markers around command-loop input dispatch,
  redisplay entry/exit, `garbage_collect`, `try_window`, and `display_line` so
  the 6245ms post-tty-read/pre-`write-output` section is split further.
- [x] Reduce the remaining Emacs-side post-read delay: after a 1077 byte
  Japanese raw paste, Emacs receives the full paste in the same monotonic
  millisecond as native `push-input`, then loops through 50ms
  wait/gobble-input checks for about 19.8 seconds before redisplay emits the
  pasted text.
- [ ] Re-run a larger multiline paste and normal typing smoke without hotpath
  trace enabled to make sure the `kbd_buffer` wait guard has no interactive
  regressions.

## Verification

- `flutter test`: passed, 74 tests.
- `make flutter-structure-check`: passed.
- `git diff --check`: passed.
- `IOSMACS_FLUTTER_IOS_NATIVE_HOLD_SECONDS=30 make flutter-ios-native-smoke`: passed.
- Native ring bulk-read probe: 30,400 input bytes pushed and read back in one `iosmacs_host_terminal_read` call.
- Manual Simulator paste of a 411 byte Lisp form reached the native ring and
  Emacs bulk read in the same monotonic millisecond. The first visible output
  followed about 0.87 seconds later; the later 22.9 second delay was Emacs
  loading/evaluating/debugger output, not terminal input delivery.
- Manual Simulator paste A/B payload: 1077 UTF-8 bytes of repeated Japanese
  text.
- Baseline 1077 byte paste with normal TERMINFO: `tty-read` to first
  `write-output` was 19754ms.
- `gc-cons-threshold=100MB`: 19794ms, no improvement.
- Lightweight `terminal-init-xterm`: 20137ms, no improvement.
- Disabled `terminal-init-xterm`: 19725ms, no improvement.
- TERMINFO disabled / internal termcap path: 19658ms, no improvement; display
  regressed with literal terminal capability fragments, so this is not usable
  as-is.
- Hotpath marker pass with normal TERMINFO and bounded markers:
  `push-input`, `read-available`, and `sysdep tty-read bytes=1077` all occurred
  at `t=23633386`; first `redisplay-internal` for the pasted text occurred at
  `t=23653200`; first `write-output` occurred at `t=23653201`; first
  `drain-output` occurred at `t=23653203`.
- After changing the direct tty waitpoint to skip the 50ms wait when
  `kbd_buffer_events_waiting()` is already true, the same 1077 byte paste
  measured `push-input` at `t=24209193`, `sysdep tty-read bytes=1077` at
  `t=24209194`, first `redisplay-internal` at `t=24209217`, first
  `write-output` at `t=24209219`, and first `drain-output` at `t=24209240`.
  The post-read-to-output gap dropped from about 19.8 seconds to 25ms.

## Remaining Gap

- This pass removes byte-at-a-time reads and per-byte debug writes from the hot path. It also fixes native paste line endings, wraps native paste in bracketed-paste markers, and suppresses redisplay while Emacs slurps bracketed paste bytes so UIKit multiline paste does not enter Emacs as many independent `RET` commands. A direct `UIPasteboard.general.string` bypass was tried and reverted because it could hang before bytes reached the fake tty. It does not yet prove an end-to-end 30KB manual Simulator paste latency target against macOS Terminal.app; that should be measured with a real paste benchmark after the app is relaunched from this build.
- The latest manual Cmd+V test did not emit the native paste-stage logs,
  but did show Simulator Pasteboard reads about 19.4 seconds before the pasted
  Japanese text appeared in terminal output. Flutter Clipboard paste avoids
  that front-end delay and pushed a 354 byte test payload to native `sendBytes`
  in 6ms. However, bracketed paste then failed to redisplay, so the active
  paste route is now normalized raw UTF-8 terminal input. The normalized raw
  route visibly inserted the same Japanese paste after about 6.1 seconds.
- The unified marker pass shows the current normalized raw paste is no longer
  blocked in Flutter, native `sendBytes`, fake tty wakeup, fake tty read, native
  `drainOutput`, or Dart terminal emission. The 342 byte Japanese paste was in
  Emacs' tty read buffer at `t=20756506`; Emacs did not write terminal output
  until `t=20762751`, leaving about 6245ms inside Emacs after read and before
  redisplay/output.
- The 1077 byte A/B run shows the same shape at larger payload size: the bytes
  reach Emacs immediately, but Emacs stays in repeated 50ms
  wait/gobble-input checks until redisplay finally runs about 19.8 seconds
  later. Once redisplay starts, terminal output and native drain are immediate.
- The root cause of that 19.8 second delay was the iosmacs direct tty waitpoint
  itself: after `gobble_input` had already filled Emacs' `kbd_buffer`, the
  next `read_char` iteration still waited up to 50ms before reading the
  buffered event. A paste then paid that wait once per buffered input chunk or
  character. Guarding the waitpoint with `!kbd_buffer_events_waiting()` removes
  the artificial delay while preserving the event-driven wait when both the
  Emacs buffer and fake tty input ring are empty.
