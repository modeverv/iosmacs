# wasmacs と iosmacs の tty/terminal 構造差分

## 目的

`wasmacs` 側は、Emacs が通常の `-nw` 実行中に入力待ち・TTY read/write へ進み、その先で browser host の tty service を呼ぶ形に寄せている。`iosmacs` 側も同じ向き、つまり「UI が Emacs の状態を外から操作する」のではなく「Emacs の自然な tty 経路が host tty に降りる」形へ寄せるため、現状の違いを整理する。

## 結論

現状の `iosmacs` はかなり近い土台を持っている。`WKWebView` + xterm.js は terminal renderer/input surface に限定され、Emacs editor semantics は Emacs 側に残っている。また C 側には `iosmacs_os_terminal_*` ring buffer と `iosmacs_terminal_shim.c` の fake tty がある。

ただし、`wasmacs` とは tty の入り方が違う。

- `wasmacs`: Emacs C core の待機点や tty read を patch し、Emacs 側から `wasmacs_host_wait_for_input` / `wasmacs_host_terminal_read_byte` へ直接降りる。
- `iosmacs`: Emacs 自体は POSIX fd の stdin/stdout/stderr と `/dev/tty` を読む。`iosmacs_terminal_shim.c` が pty/socketpair と pump thread で、その fd と `iosmacs_os_terminal_*` ring buffer を中継する。

したがって、`iosmacs` を `wasmacs` 風に寄せる場合の主な差分は、WebView/xterm.js ではなく、Emacs C core と host tty facade の接続点にある。

## wasmacs の形

### xterm.js は renderer/input surface

`wasmacs/src/wasm/src/xterm-emacs-terminal.js` は、冒頭コメントで責務をかなり明確にしている。

- input: `xterm onData -> bytes -> emacs-input-bytes`
- output: `terminal-output-bytes -> writeBytes() -> xterm.write()`
- xterm は renderer、Emacs が command semantics を所有する

実装でも、`createXtermEmacsTerminal()` は `term.onData` を handler に渡し、`writeBytes(bytes)` で xterm へ bytes を書く程度に留めている。`xtermDataToBytes()` は xterm の raw string を UTF-8 bytes にするだけ。

### Worker が Emacs runtime と blocking wait を持つ

`wasmacs/src/wasm/src/emacs-atomics-pdump-worker.js` は `SharedArrayBuffer` を用意し、`emacs-input-bytes` message で bytes を SAB に書いて `Atomics.notify` する。

起動は `callMain(["--dump-file=/bootstrap-emacs.pdmp", "--quick", "--no-splash", "-nw"])` で、Emacs は `-nw` の command loop に入る。入力がなければ Worker 内で `Atomics.wait` する。

### Emacs C core から host tty service に降りる

`wasmacs/src/c/patches/0001-wasmacs-host-entrypoint-and-terminal.patch` が肝。

- `src/keyboard.c` の `read_char` / `kbd_buffer_get_event` 周辺で、入力がない時に `wasmacs_host_wait_for_input()` を呼ぶ。
- `src/sysdep.c` の `emacs_intr_read` で、対象 fd が tty の場合は `wasmacs_host_terminal_read_byte()` から byte を読む。
- `src/term.c` には terminal/direct color まわりの wasm 向け補正が入る。

つまり browser UI が Emacs buffer や minibuffer を再実装しているのではなく、Emacs の通常の keyboard/tty read path が、必要な時だけ host input service へ降りる。

### Emscripten TTY hooks も host library に集約されている

`wasmacs/tools/scripts/wasmacs-atomics-host-library.js` は、Emscripten の `TTY.default_tty_ops` を差し替えている。

- `get_char`: `__wasmacsTerminalInputBytes` から読む
- `put_char` / `fsync`: terminal output bytes を `__wasmacsTerminalOutputBytes` へ積む
- `ioctl_tcgets` / `ioctl_tcsets` / `ioctl_tiocgwinsz`: 最小 termios/winsize を返す
- `wasmacs_host_wait_for_input`: output flush 後に `Atomics.wait`
- `wasmacs_host_flush_terminal_output`: accumulated output を main thread へ postMessage

このため、host 側の役割は「Emacs に tty として見えるものを提供する」ことに集まっている。

## iosmacs の形

### WebView/xterm.js は wasmacs と同じ方針

`iosmacs/TerminalWeb/iosmacs-terminal.js` も、xterm.js を renderer/input surface として使う方向になっている。

- `terminal.onData(handleTerminalData)` で committed terminal data を Swift へ post
- `writeBase64(base64)` で Swift から来た terminal bytes を xterm に書く
- resize は `{ type: "resize", cols, rows }` として Swift へ post
- IME composition は hidden textarea/IME proxy 側で扱い、未確定文字列は Emacs に送らない

`iosmacs/Terminal/IOSMacsTerminalView.swift` はこれを `WKScriptMessageHandler` で受け、input bytes を `session.sendInput(bytes)` に渡し、output は `window.iosmacsTerminal?.writeBase64(...)` へ流す。

この UI 境界は `wasmacs` とほぼ同じ方向で、問題の中心ではない。

### Swift が Emacs session lifecycle と output drain を持つ

`iosmacs/Emacs/EmacsSession.swift` は、アプリ起動時に `iosmacs_emacs_core_start(...)` を呼び、以後は Swift 側 task/update cycle から `iosmacs_os_terminal_drain_output` を drain する。

input は:

```text
xterm.js onData / IME commit
  -> WKScriptMessageHandler
  -> EmacsSession.sendInput
  -> iosmacs_os_terminal_push_input
  -> input ring buffer
```

output は:

```text
Emacs stdout/stderr or /dev/tty
  -> fake tty peer
  -> output pump thread
  -> iosmacs_os_terminal_write
  -> output ring buffer
  -> EmacsSession.drainTerminalOutput
  -> WKWebView evaluateJavaScript(writeBase64)
  -> xterm.write
```

### fake tty は POSIX fd 中継として実装されている

`iosmacs/Host/iosmacs_terminal_shim.c` が現在の tty 実体。

- `iosmacs_terminal_shim_attach_stdio()` が fake tty fd を stdin/stdout/stderr へ `dup2` する。
- `/dev/tty` への `open` / `openat` は `open_fake_tty()` に差し替える。
- `isatty`, `tcgetattr`, `tcsetattr`, `tcflow`, `tcdrain`, `ioctl(TIOCGWINSZ)` などを最小実装する。
- `open_fake_tty()` はまず pty pair を試し、失敗時に socketpair に fallback する。
- `output_pump_main()` は fake peer fd から読み、`iosmacs_os_terminal_write()` へ積む。
- `input_pump_main()` は `iosmacs_os_terminal_read()` で ring buffer を polling し、fake peer fd へ書く。

これは「Emacs が tty fd を読む」という意味では自然だが、`wasmacs` のように Emacs C core が host wait/read entrypoint を直接呼ぶ構造ではない。自然さの層が POSIX fd 側にあり、host facade 側には pump thread で橋をかけている。

### host facade は ring buffer API

`iosmacs/Host/iosmacs_host_facade.c` は `iosmacs_os_terminal_*` を提供する。

- `iosmacs_os_terminal_push_input`: Swift/WebView 由来の input を input ring に積む
- `iosmacs_os_terminal_read`: input ring から読む
- `iosmacs_os_terminal_write`: output ring に積む
- `iosmacs_os_terminal_drain_output`: Swift が output ring を drain する
- `iosmacs_os_terminal_resize`: cols/rows を更新して `SIGWINCH`

ここには `wasmacs_host_wait_for_input` 相当の「Emacs C core から呼ばれる blocking waitpoint」はまだない。現在は input pump thread が `usleep(10000)` しながら input ring を見て fd へ書いている。

### Emacs 起動は native linked entrypoint

`iosmacs/Emacs/iosmacs_emacs_core.c` は `iosmacs_emacs_main` を pthread で起動する。

- 起動前に `iosmacs_terminal_shim_enable()` と `iosmacs_terminal_shim_attach_stdio()` を実行
- `TERM=xterm-256color` や `HOME=/home/user` を設定
- `--quick --no-site-file --no-site-lisp --no-splash -nw` で起動
- bundled `emacs.pdmp` があれば `--dump-file` を渡す

このため、Emacs は通常の native POSIX-ish terminal Emacs として見えている。

## 主な差分

| 観点 | wasmacs | iosmacs |
| --- | --- | --- |
| Emacs runtime | WebAssembly/Emscripten Worker | native iOS simulator linked `iosmacs_emacs_main` |
| 起動 | Worker が `callMain(... -nw)` | Swift/C が pthread で `iosmacs_emacs_main(... -nw)` |
| tty の入口 | Emacs C patch から host wait/read/write entrypoint | stdin/stdout/stderr と `/dev/tty` を fake fd に `dup2` |
| input wait | `keyboard.c` / `sysdep.c` から `wasmacs_host_wait_for_input()` | Emacs は fd read 側で待ち、別 input pump が ring buffer を polling |
| input 注入 | main thread -> Worker message -> SAB -> `Atomics.notify` -> Emacs waitpoint resumes | WebView -> Swift -> input ring -> pump thread -> fake peer fd -> Emacs fd read |
| output flush | host library が output bytes を accumulate し、waitpoint/flush で postMessage | output pump thread が fake peer fd から読み output ring に積み、Swift が drain |
| resize | SAB に cols/rows と version を置き、host terminal resize API で読む | Swift が `iosmacs_os_terminal_resize`、shim の `ioctl(TIOCGWINSZ)` が cols/rows を返す |
| JS の役割 | xterm renderer + Worker message coordinator | xterm renderer + WKWebView message source/sink + IME proxy |
| host facade の粒度 | `wasmacs_host_wait_for_input`, `wasmacs_host_terminal_read_byte`, `wasmacs_host_flush_terminal_output` など C core 直結 | `iosmacs_os_terminal_push_input/read/write/drain_output` など Swift/pump 向け ring API |
| Emacs source 変更 | copied Emacs tree に patch を当てる | build scripts 側の patches はあるが、現在の tty path は主に shim/interpose で成立 |

## 「同じような作り」に寄せる時の焦点

`iosmacs` で合わせるべきは xterm.js 側ではなく、Emacs core と tty service の接続点。

候補は次の順で考えるのがよい。

1. `iosmacs_host_wait_for_input` 相当を追加する

   現在の `iosmacs_os_terminal_read` は非 blocking ring read で、input pump が polling している。`wasmacs_host_wait_for_input` と同じ意味の blocking/timeout-aware waitpoint を C facade に追加すると、Emacs 側から自然に待てる形へ近づく。

2. Emacs copied source patch で tty read path を facade へ接続する

   `wasmacs` と同じく `keyboard.c` / `sysdep.c` の copied build tree patch で、tty fd の read を `iosmacs_os_terminal_read_byte` / waitpoint に落とす。これにより input pump thread と fake peer fd を薄くできる、または不要にできる可能性がある。

3. output flush の owner を Emacs waitpoint 近くへ寄せる

   現在は output pump thread と Swift drain が主導する。`wasmacs_host_flush_terminal_output` 相当を設けると、redisplay 後や input wait 前に output を明示的に flush できる。

4. tty fd interpose と direct facade の二重構造を整理する

   iOS/native では POSIX fd route が動くため、完全に捨てる必要はない。ただし `wasmacs` に寄せるなら product path は「Emacs -> named tty facade -> Swift/WebView」にし、pty/socketpair は diagnostic fallback または compatibility shim として位置づける方が境界が明確になる。

## 注意点

`wasmacs` の `SharedArrayBuffer` / `Atomics` / Worker machinery は iOS native app へそのまま持ち込む対象ではない。`iosmacs` では Swift/C の mutex/condition variable、pthread、または dispatch primitive で同じ意味論を作るのが自然。

また、`iosmacs` の現行 fake tty はすでに `-nw` 起動、input、Dired/file smoke を通すための重要な実証経路になっている。次に実装へ進む場合は、いきなり削るより、direct facade path を追加して smoke で同等性を確認し、その後 pump/thread/fd shim の役割を縮小するのが安全。
