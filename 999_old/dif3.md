# iosmacs を Atomics.wait/notify 風にできるか

## 目的

`wasmacs` の強い点は、Emacs C core が入力待ちに入った時、host 側の `Atomics.wait` で本当に止まり、xterm.js から入力が来た時だけ `Atomics.notify` で起きるところにある。

このメモでは、`iosmacs` でも同じような構造にできるかを整理する。

## 結論

できる。ただし「JavaScript の `Atomics.wait/notify` そのもの」を iOS native Emacs と共有するのではなく、`iosmacs` 側に `Atomics.wait/notify` と同じ意味論の C host primitive を置くのが現実的。

現時点の `iosmacs` はすでに近い。

```text
wasmacs:
  input bytes -> SharedArrayBuffer
  Atomics.add(signal)
  Atomics.notify(signal)
  Emacs waitpoint -> Atomics.wait(signal)

iosmacs current:
  input bytes -> C input ring
  input_generation++
  pthread_cond_broadcast()
  Emacs waitpoint -> pthread_cond_timedwait()
```

つまり、現在の `iosmacs` は implementation が pthread condition variable で、semantic shape は `Atomics.wait/notify` に近い。さらに近づけるなら、API 名とデータ構造を `signal slot + byte count + byte payload` へ寄せればよい。

## JavaScript Atomics をそのまま使う案

### 形

```text
WKWebView JavaScript
  SharedArrayBuffer
  Atomics.store/add/notify

native Emacs thread
  same memoryを読む
  waitする
```

### 判定

これは基本的に避けるべき。

理由:

- `SharedArrayBuffer` は JavaScript VM の heap object であり、Swift/C の native thread と安定して同一メモリとして共有する public API ではない。
- WKWebView の JavaScript と native C は、`WKScriptMessageHandler` / `evaluateJavaScript` の message boundary でつながる。raw pointer sharing の境界ではない。
- `Atomics.wait` は JS Worker 側の blocking primitive で、main thread では使えない制約がある。iOS の WebView 内で wasmacs と同じ Worker/SAB route を作っても、その先は wasm Emacs 用であり、native linked Emacs とは直接つながらない。
- iOS app の目的は native Emacs core なので、JS SAB を中心にすると `wasmacs` runtime を持ち込む方向へ戻ってしまう。

したがって、JS の `Atomics.wait/notify` をそのまま native Emacs の同期 primitive にするのは、実装可能性・保守性・Apple API 境界のどれを見ても本筋ではない。

## C 側に Atomics 風 primitive を作る案

### 形

`wasmacs` の SAB layout を C struct に写す。

```c
typedef struct iosmacs_terminal_signal {
  _Atomic uint32_t version;
  _Atomic uint32_t byte_count;
  _Atomic uint32_t resize_version;
  uint8_t bytes[256];
  pthread_mutex_t mutex;
  pthread_cond_t cond;
} iosmacs_terminal_signal;
```

入力注入:

```text
Swift receives WK input bytes
  -> C function copies bytes into signal.bytes
  -> byte_count = n
  -> version++
  -> cond broadcast
```

Emacs waitpoint:

```text
iosmacs_host_wait_for_input(timeout)
  -> remember version
  -> if byte_count > 0 return input
  -> pthread_cond_timedwait until version changes
```

byte read:

```text
iosmacs_host_terminal_read_byte()
  -> pop from C signal/ring
```

### 判定

これは十分できる。今の `iosmacs/Host/iosmacs_host_facade.c` はすでにこの形にかなり近い。

現在あるもの:

- `input_generation`
- `resize_generation`
- `pthread_cond_t terminal_cond`
- `iosmacs_os_terminal_push_input`
- `iosmacs_os_terminal_wait_for_input`
- `iosmacs_host_wait_for_input`
- `iosmacs_host_terminal_read_byte`

足すとさらに wasmacs らしくなるもの:

- `input_generation` を明示的な `signal[0]` 相当として扱う
- `input_ring.count` ではなく `byte_count` slot を持つ
- resize も `terminal_size_signal[0..2]` 相当へ寄せる
- return code を `WASMACS_WAIT_TIMEOUT=0`, `WAIT_INPUT=1`, `WAIT_RESIZE=2` と同じ意味で固定する
- output flush を waitpoint の先頭で必ず呼ぶ

## C11 atomics だけで作る案

### 形

`_Atomic` 変数を置き、Emacs thread が spin/yield で version change を待つ。

### 判定

避けるべき。

理由:

- `Atomics.wait` の価値は spin しない blocking wait にある。
- C11 atomics だけでは portable blocking wait がない。C23 の `atomic_wait` 相当も、iOS deployment target と toolchain で使える前提にしにくい。
- spin wait は battery/thermal に悪く、iPad app の terminal idle と相性が悪い。

C11 atomics は version/byte_count の可視性補助としてはよいが、blocking は pthread condition, semaphore, Mach primitive などに任せるべき。

## semaphore / dispatch semaphore 案

### 形

入力ごとに semaphore signal し、Emacs waitpoint が semaphore wait する。

### 判定

可能だが、pthread condition より少し扱いづらい。

利点:

- `notify/wait` の名前には近い。
- signal が単純。

弱点:

- resize, timeout, spurious wake, byte_count の再確認などを別状態で管理する必要がある。
- 複数 wake reason を扱うには結局 sequence counter が必要になる。
- dispatch semaphore は Grand Central Dispatch の世界に寄り、C core facade としては pthread より少し Swift/Apple runtime 色が強い。

`iosmacs` の C host facade では pthread condition variable の方が素直。

## ulock / futex 風案

Darwin には低レベル wait/wake 系の仕組みがあるが、安定した公開 API として `Atomics.wait` 相当の project foundation にするのは避けるべき。

使うなら performance tuning の後段でよい。まずは pthread condition variable で意味論を固定する方が安全。

## JS Worker を WKWebView 内で使う案

### 形

WKWebView の JavaScript 側に Worker を作り、`wasmacs` と同じ `SharedArrayBuffer` / `Atomics.wait` route を置く。

### 判定

`wasmacs` runtime を WebView 内に入れるなら可能性はある。しかし `iosmacs` の native Emacs には直接効かない。

使える場面:

- WebView 内で terminal-side latency probes を作る
- JS 側だけで input scheduling の実験をする
- wasmacs route を iOS WebView 上で動かす別モードを作る

使えない場面:

- native linked `iosmacs_emacs_main` の input wait を直接起こす
- Swift/C と raw SAB memory を安定共有する

## 推奨設計

`iosmacs` では「Atomics API 互換」ではなく「Atomics 意味論互換」を目指す。

### 1. C facade に signal object を明示する

現在の ring + generation を、wasmacs の SAB layout に似た名前へ整理する。

```text
signal.version
signal.byte_count
signal.resize_version
signal.bytes
```

### 2. public API を wasmacs に寄せる

```c
int iosmacs_host_wait_for_input(int timeout_ms);
int iosmacs_host_terminal_read_byte(void);
int iosmacs_host_terminal_input_available(void);
int iosmacs_host_terminal_resize_pending(void);
int iosmacs_host_terminal_resize_cols(void);
int iosmacs_host_terminal_resize_rows(void);
int iosmacs_host_terminal_resize_ack(void);
int iosmacs_host_flush_terminal_output(void);
```

以前は `iosmacs_host_wait_for_input(void)` だった。Emacs の従者として動く方向では、timeout を受ける形にするのがよい。

### 3. wait return code を wasmacs と揃える

```text
0 = timeout / scheduler wake
1 = input
2 = resize
-1 = unavailable
```

### 4. Swift は notify side に徹する

Swift/xterm.js 由来の input/resize は、C facade に渡したら終わりにする。

```text
Swift:
  iosmacs_os_terminal_push_input(bytes)   // notify相当
  iosmacs_os_terminal_resize(cols, rows)  // resize notify相当

Emacs C:
  iosmacs_host_wait_for_input(timeout)    // wait相当
```

Swift が polling や Emacs state interpretation を持つほど、wasmacs の形から遠ざかる。

## まとめ

`iosmacs` を `Atomics.notify/Atomics.wait` っぽく作ることはできる。

ただし実装は次がよい。

- JS の `SharedArrayBuffer` / `Atomics` を native Emacs と共有しない
- C host facade に signal/version/byte_count を置く
- wait は pthread condition variable で blocking する
- notify は Swift から C facade に input/resize を push した時に行う
- API 名と return code を `wasmacs` に寄せる

現状の `iosmacs` はすでに「pthread cond 版 Atomics.wait/notify」になりつつある。次の改善は、実装を完全に作り直すことではなく、facade の shape を `wasmacs` の `INPUT_SAB` layout と host functions に近い名前・return code・timeout contract へ整理すること。
