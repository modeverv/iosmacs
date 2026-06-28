# Swift/xterm.js 接続と wasmacs C core 接続の差分

## 目的

`dif.md` では tty/fake tty の差分を整理した。このメモでは、画面側の接続、つまり `iosmacs` の Swift + `WKWebView` + xterm.js が、`wasmacs` の browser main thread + Worker + Emacs C core とどう違うかを整理する。

## 結論

`wasmacs` は browser main thread と Worker の 2 層で閉じている。

```text
xterm.js
  -> main.js
  -> Worker message
  -> SharedArrayBuffer / Atomics.notify
  -> patched Emacs C core waitpoint
```

`iosmacs` は native app shell が間に入る。

```text
xterm.js in WKWebView
  -> WKScriptMessageHandler
  -> Swift EmacsSession
  -> C host facade ring/condition
  -> patched Emacs C core waitpoint
```

今回の direct tty 変更後、Emacs 入力待ちの意味論は `wasmacs` にかなり近づいた。違いは、`wasmacs` が `SharedArrayBuffer` / `Atomics.wait` で Worker 内に閉じるのに対して、`iosmacs` は Swift と C facade の間を `WKScriptMessageHandler` と pthread condition variable でつないでいる点。

## wasmacs の接続

`wasmacs/src/wasm/src/main.js` の xterm route は、xterm input を Worker へほぼそのまま渡す。

```text
xtermTerminal.onData(data)
  -> xtermWorker.postMessage({
       type: "emacs-input-bytes",
       bytes: xtermDataToBytes(data)
     })
```

出力は Worker から main thread に戻る。

```text
Worker message { type: "terminal-output-bytes", bytes }
  -> xtermTerminal.writeBytes(bytes)
  -> xterm.write(...)
```

Worker 側では `emacs-atomics-pdump-worker.js` が `SharedArrayBuffer` を持ち、input message を SAB に書いて `Atomics.notify` する。さらに `wasmacs-atomics-host-library.js` の `wasmacs_host_wait_for_input` が、Emacs C core から呼ばれて `Atomics.wait` する。

つまり browser main thread は renderer/coordinator で、blocking input ownership は Worker 内の host library と patched Emacs C core にある。

## iosmacs の接続

`iosmacs/TerminalWeb/iosmacs-terminal.js` は xterm input を `window.webkit.messageHandlers.iosmacsTerminal` に post する。

```text
terminal.onData(handleTerminalData)
  -> postInput(data)
  -> post({ type: "input", bytes })
```

IME 経路も同じで、composition 確定後に UTF-8 bytes として `input` message に落とす。未確定 composition は Emacs へ渡さない。

Swift 側では `IOSMacsTerminalView.Coordinator` が message を受ける。

```text
WKScriptMessageHandler
  -> handleMessage(...)
  -> session.sendInput(bytes)
  -> iosmacs_os_terminal_push_input(...)
```

出力は逆向きに Swift が drain して WebView に注入する。

```text
session.drainTerminalOutput()
  -> iosmacs_os_terminal_drain_output(...)
  -> evaluateJavaScript("window.iosmacsTerminal?.writeBase64(...)")
  -> terminal.write(...)
```

この点は `wasmacs` の Worker message と似ているが、message channel が browser Worker ではなく `WKWebView` と native Swift の境界になっている。

## C core との接続差分

### wasmacs

`wasmacs` は Emacs C core の copied source patch から、Emscripten host library の symbol を直接呼ぶ。

- `keyboard.c`: 入力待ちで `wasmacs_host_wait_for_input`
- `sysdep.c`: tty fd read で `wasmacs_host_terminal_read_byte`
- host library: SAB を見て `Atomics.wait` / input queue populate

待機中の Emacs を起こす primitive は `Atomics.notify`。

### iosmacs

`iosmacs` も今回、copied Emacs source patch から C host facade を直接呼ぶ形に寄せた。

- `keyboard.c`: 入力待ちで `iosmacs_host_wait_for_input`
- `sysdep.c`: tty fd read で `iosmacs_host_terminal_read_byte`
- host facade: input ring を見て `pthread_cond_wait` / byte read

待機中の Emacs を起こす primitive は `pthread_cond_broadcast`。

## fake tty の現在位置

`iosmacs` では native `-nw` 起動を成立させるため、fake tty fd はまだ残る。

- stdin/stdout/stderr と `/dev/tty` を Emacs に tty として見せる
- termios / winsize / isatty / `/dev/tty` open を満たす
- Emacs の terminal output fd write を output pump で C output ring に積む

ただし input については、direct tty facade が標準になったため、fake tty input pump は主経路ではない。xterm.js 由来の input bytes は Swift から host facade ring に積まれ、patched Emacs C core が `iosmacs_host_terminal_read_byte` で読む。

## まだ違う点

| 観点 | wasmacs | iosmacs |
| --- | --- | --- |
| UI runtime | browser main thread | Swift app + WKWebView |
| Emacs runtime | Worker 内 wasm | native linked Emacs thread |
| input wake | `Atomics.notify` | `pthread_cond_broadcast` |
| blocking wait | `Atomics.wait` | `pthread_cond_wait` / timedwait |
| message boundary | main thread <-> Worker | JavaScript <-> Swift <-> C |
| output source | Emscripten TTY hook accumulates bytes | native fd/fake tty output pump accumulates bytes |
| tty identity | Emscripten FS/TTY stream | native fd + facade-registered tty fd |

## 今後さらに寄せるなら

1. output も Emacs C core から named facade に寄せる

   現在の `iosmacs` output は fake tty fd に書かれた bytes を pump で拾う。`wasmacs` では host library が TTY put_char/fsync を握っている。より近づけるなら、Emacs の tty write 側も `iosmacs_host_flush_terminal_output` / `iosmacs_host_terminal_write_bytes` のような named facade に寄せる。

2. Swift は renderer coordinator にさらに限定する

   Swift は今も session lifecycle と workspace を持つ。terminal input/output については、できるだけ「JS bytes を C facade に渡す」「C output bytes を JS に戻す」だけに寄せると、`wasmacs` main thread の役割に近くなる。

3. fake tty を product path から compatibility path に下げる

   native Emacs が fd/termios を強く前提にするため完全削除は危険だが、input 側はすでに direct facade が主になった。次は output 側も direct facade 化できれば、fake tty は startup compatibility shim に近づく。
