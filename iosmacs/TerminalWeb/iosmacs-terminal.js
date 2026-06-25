(function () {
  "use strict";

  const DEFAULT_DIMENSIONS = Object.freeze({ cols: 80, rows: 24 });
  const MIN_COLS = 20;
  const MIN_ROWS = 3;
  const RESIZE_KEEPALIVE_INTERVAL_MS = 60000;
  const encoder = new TextEncoder();
  let terminal = null;
  let fitAddon = null;
  let lastDimensions = DEFAULT_DIMENSIONS;
  let resizeKeepaliveId = 0;
  let initialized = false;
  let isComposing = false;
  let compositionText = "";
  let lastForwardedText = "";
  let lastForwardedTextTime = 0;
  let imeProxy = null;
  let imeComposition = null;
  let imeProxyAttached = false;
  let suppressXtermDataUntil = 0;

  function post(message) {
    const handler = window.webkit?.messageHandlers?.iosmacsTerminal;
    if (!handler) {
      return;
    }
    handler.postMessage(message);
  }

  function debugIme(message) {
    if (window.localStorage?.getItem("iosmacs-ime-debug") !== "1") {
      return;
    }
    post({ type: "log", level: "debug", message: `ime ${message}` });
  }

  function traceIo(message) {
    post({ type: "log", level: "trace", message: `js ${message}` });
  }

  function bytesToHex(bytes) {
    return bytes.slice(0, 32).map((byte) => byte.toString(16).padStart(2, "0")).join(" ");
  }

  function normalizeDimensions(cols, rows) {
    return {
      cols: Math.max(MIN_COLS, Number.isInteger(cols) ? cols : DEFAULT_DIMENSIONS.cols),
      rows: Math.max(MIN_ROWS, Number.isInteger(rows) ? rows : DEFAULT_DIMENSIONS.rows),
    };
  }

  function postResize(cols, rows, options = {}) {
    const next = normalizeDimensions(cols, rows);
    if (!options.force && next.cols === lastDimensions.cols && next.rows === lastDimensions.rows) {
      return;
    }
    lastDimensions = next;
    post({ type: "resize", cols: next.cols, rows: next.rows });
  }

  function stripBracketedPasteMarkers(data) {
    return data.replaceAll("\x1b[200~", "").replaceAll("\x1b[201~", "");
  }

  function postInput(data, options = {}) {
    const text = options.stripPasteMarkers ? stripBracketedPasteMarkers(data) : data;
    const bytes = Array.from(encoder.encode(text));
    if (bytes.length > 0) {
      traceIo(`post-input text=${JSON.stringify(text)} count=${bytes.length} bytes=${bytesToHex(bytes)}`);
      post({ type: "input", bytes });
    }
  }

  function normalizeInsertedText(data) {
    return String(data ?? "").replace(/\r\n|\n/g, "\r");
  }

  function forwardText(data, dedupe = false) {
    const text = normalizeInsertedText(data);
    if (!text) {
      debugIme("forward skipped empty text");
      return false;
    }

    const now = performance.now();
    if (dedupe && text === lastForwardedText && now - lastForwardedTextTime < 80) {
      return true;
    }

    lastForwardedText = text;
    lastForwardedTextTime = now;
    debugIme(`forward ${JSON.stringify(text)}`);
    postInput(text);
    return true;
  }

  function handleTerminalData(data) {
    if (isComposing || performance.now() < suppressXtermDataUntil) {
      return;
    }
    traceIo(`xterm-onData text=${JSON.stringify(data)}`);
    postInput(data);
  }

  function clearTextareaValue(textarea) {
    try {
      textarea.value = "";
    } catch (_error) {
      // Some WebKit builds protect xterm's helper textarea. Leaving the value is harmless.
    }
  }

  function stopHandledImeEvent(event, textarea) {
    event.preventDefault?.();
    event.stopImmediatePropagation?.();
    clearTextareaValue(textarea);
  }

  function stopHandledTerminalEvent(event) {
    event.preventDefault?.();
    event.stopImmediatePropagation?.();
    if (event.target && typeof event.target.value === "string") {
      clearTextareaValue(event.target);
    }
  }

  function handledInputType(inputType) {
    return inputType === "insertText"
      || inputType === "insertReplacementText"
      || inputType === "insertFromPaste"
      || inputType === "insertFromDrop";
  }

  function isImeProxyEvent(event) {
    if (!imeProxy) {
      return false;
    }
    return event.target === imeProxy;
  }

  function terminalCellDimensions() {
    const dimensions = terminal?._core?._renderService?.dimensions?.css?.cell;
    const fontSize = Number(terminal?.options?.fontSize) || 15;
    return {
      width: Math.max(1, Number(dimensions?.width) || fontSize * 0.62),
      height: Math.max(1, Number(dimensions?.height) || fontSize * 1.35),
    };
  }

  function terminalCursorRect() {
    const screen = document.querySelector("#terminal .xterm-screen") || document.getElementById("terminal");
    const rect = screen?.getBoundingClientRect?.();
    if (!rect || !terminal?.buffer?.active) {
      return null;
    }

    const cell = terminalCellDimensions();
    const buffer = terminal.buffer.active;
    return {
      left: rect.left + buffer.cursorX * cell.width,
      top: rect.top + buffer.cursorY * cell.height,
      width: cell.width,
      height: cell.height,
    };
  }

  function moveImeSurface() {
    if (!imeProxy) {
      return;
    }

    const cursor = terminalCursorRect();
    if (!cursor) {
      return;
    }

    const fontSize = Number(terminal?.options?.fontSize) || 15;
    const left = `${Math.round(cursor.left)}px`;
    const top = `${Math.round(cursor.top)}px`;
    const height = `${Math.ceil(cursor.height)}px`;
    const width = `${Math.max(1, Math.ceil(cursor.width))}px`;

    imeProxy.style.left = left;
    imeProxy.style.top = top;
    imeProxy.style.width = width;
    imeProxy.style.height = height;
    imeProxy.style.fontSize = `${fontSize}px`;
    imeProxy.style.lineHeight = height;

    if (imeComposition) {
      imeComposition.style.left = left;
      imeComposition.style.top = top;
      imeComposition.style.minHeight = height;
      imeComposition.style.fontSize = `${fontSize}px`;
      imeComposition.style.lineHeight = height;
    }
  }

  function setImeCompositionText(text) {
    compositionText = String(text || "");
    moveImeSurface();
    if (!imeComposition) {
      return;
    }
    imeComposition.textContent = compositionText;
    imeComposition.style.display = compositionText ? "block" : "none";
  }

  function hideImeComposition() {
    compositionText = "";
    if (imeComposition) {
      imeComposition.textContent = "";
      imeComposition.style.display = "none";
    }
  }

  function terminalKeySequence(event) {
    if (event.metaKey || event.isComposing || event.keyCode === 229) {
      return "";
    }

    if (event.ctrlKey) {
      if (event.key === " ") {
        return "\x00";
      }
      if (event.key.length === 1) {
        const key = event.key.toLowerCase();
        if (key >= "a" && key <= "z") {
          return String.fromCharCode(key.charCodeAt(0) - 96);
        }
        if (event.key === "[") {
          return "\x1b";
        }
        if (event.key === "]") {
          return "\x1d";
        }
        if (event.key === "\\") {
          return "\x1c";
        }
        if (event.key === "^") {
          return "\x1e";
        }
        if (event.key === "_") {
          return "\x1f";
        }
        if (event.key === "?") {
          return "\x7f";
        }
      }
      return "";
    }

    if (event.altKey) {
      const ch = printableAsciiFromCode(event);
      if (ch) {
        return `\x1b${ch}`;
      }
      if (typeof event.key === "string" && event.key.length === 1 && event.key.charCodeAt(0) < 128) {
        return `\x1b${event.key}`;
      }
      return "";
    }

    switch (event.key) {
      case "Enter":
        return "\r";
      case "Backspace":
        return "\x7f";
      case "Tab":
        return "\t";
      case "Escape":
        return "\x1b";
      case "ArrowUp":
        return "\x1b[A";
      case "ArrowDown":
        return "\x1b[B";
      case "ArrowRight":
        return "\x1b[C";
      case "ArrowLeft":
        return "\x1b[D";
      case "Home":
        return "\x1b[H";
      case "End":
        return "\x1b[F";
      case "PageUp":
        return "\x1b[5~";
      case "PageDown":
        return "\x1b[6~";
      case "Delete":
        return "\x1b[3~";
      default:
        return "";
    }
  }

  function printableAsciiFromCode(event) {
    if (typeof event?.code !== "string") {
      return "";
    }

    if (/^Key[A-Z]$/.test(event.code)) {
      const ch = event.code.slice(3).toLowerCase();
      return event.shiftKey ? ch.toUpperCase() : ch;
    }

    if (/^Digit[0-9]$/.test(event.code)) {
      return event.code.slice(5);
    }

    return "";
  }

  function printableAsciiFromKey(event) {
    if (event.metaKey || event.ctrlKey || event.altKey || event.isComposing || event.keyCode === 229) {
      return "";
    }
    if (typeof event.key !== "string" || event.key.length !== 1) {
      return "";
    }

    const code = event.key.charCodeAt(0);
    return code >= 0x20 && code <= 0x7e ? event.key : "";
  }

  function captureEmacsKey(event) {
    const sequence = terminalKeySequence(event) || printableAsciiFromKey(event);
    if (!sequence) {
      return true;
    }
    event.preventDefault?.();
    event.stopPropagation?.();
    postInput(sequence);
    return false;
  }

  function attachAsciiInputFallback(container) {
    const forwardEventText = (event, text, dedupe = false) => {
      if (!text || isComposing || event.isComposing || event.keyCode === 229) {
        return false;
      }
      if (forwardText(text, dedupe)) {
        stopHandledTerminalEvent(event);
        focusInput();
        return true;
      }
      return false;
    };

    document.addEventListener("keydown", (event) => {
      const sequence = terminalKeySequence(event) || printableAsciiFromKey(event);
      if (sequence) {
        forwardEventText(event, sequence, true);
      }
    }, true);

    document.addEventListener("beforeinput", (event) => {
      if (isComposing) {
        return;
      }
      if (handledInputType(event.inputType)) {
        forwardEventText(event, event.data || "", true);
        return;
      }
      if (event.inputType === "insertLineBreak" || event.inputType === "insertParagraph") {
        forwardEventText(event, "\r", true);
      }
    }, true);

    document.addEventListener("input", (event) => {
      if (isComposing || !event.target || typeof event.target.value !== "string") {
        return;
      }
      forwardEventText(event, event.target.value, true);
    }, true);

    document.addEventListener("paste", (event) => {
      const text = event.clipboardData?.getData("text/plain") || "";
      forwardEventText(event, text, false);
    }, true);

    container.addEventListener("click", () => {
      focusInput();
      terminal?.focus?.();
    }, true);
  }

  function focusInput() {
    if (!imeProxy) {
      return;
    }
    moveImeSurface();
    try {
      imeProxy.focus({ preventScroll: true });
    } catch (_error) {
      imeProxy.focus();
    }
  }

  function attachImeProxy(proxy, container) {
    if (!proxy || imeProxyAttached) {
      return;
    }
    imeProxy = proxy;
    imeComposition = document.getElementById("ime-composition");
    imeProxyAttached = true;

    proxy.addEventListener("compositionstart", (event) => {
      if (!isImeProxyEvent(event)) {
        return;
      }
      isComposing = true;
      setImeCompositionText(event.data || proxy.value || "");
      suppressXtermDataUntil = performance.now() + 1000;
      debugIme(`compositionstart data=${JSON.stringify(event.data || "")} value=${JSON.stringify(proxy.value)}`);
    });

    proxy.addEventListener("compositionupdate", (event) => {
      if (!isImeProxyEvent(event)) {
        return;
      }
      setImeCompositionText(event.data || proxy.value || compositionText);
      suppressXtermDataUntil = performance.now() + 1000;
      debugIme(`compositionupdate data=${JSON.stringify(event.data || "")} value=${JSON.stringify(proxy.value)}`);
    });

    proxy.addEventListener("compositionend", (event) => {
      if (!isImeProxyEvent(event)) {
        return;
      }
      const committedText = event.data || proxy.value || compositionText;
      debugIme(`compositionend data=${JSON.stringify(event.data || "")} value=${JSON.stringify(proxy.value)} committed=${JSON.stringify(committedText)}`);
      isComposing = false;
      hideImeComposition();
      suppressXtermDataUntil = performance.now() + 500;
      if (forwardText(committedText, true)) {
        stopHandledImeEvent(event, proxy);
      }
      setTimeout(() => {
        debugIme(`compositionend deferred value=${JSON.stringify(proxy.value)}`);
        if (forwardText(proxy.value, true)) {
          clearTextareaValue(proxy);
        }
      }, 0);
    });

    proxy.addEventListener("beforeinput", (event) => {
      if (!isImeProxyEvent(event)) {
        return;
      }
      if (isComposing) {
        debugIme(`beforeinput composing type=${event.inputType} data=${JSON.stringify(event.data || "")} value=${JSON.stringify(proxy.value)}`);
        setImeCompositionText(event.data || proxy.value || compositionText);
        return;
      }
      debugIme(`beforeinput type=${event.inputType} data=${JSON.stringify(event.data || "")} value=${JSON.stringify(proxy.value)}`);
      if (handledInputType(event.inputType) && forwardText(event.data, true)) {
        stopHandledImeEvent(event, proxy);
        return;
      }
      if (event.inputType === "insertLineBreak" || event.inputType === "insertParagraph") {
        forwardText("\r");
        stopHandledImeEvent(event, proxy);
      }
    });

    proxy.addEventListener("input", (event) => {
      if (!isImeProxyEvent(event) || isComposing) {
        if (isImeProxyEvent(event)) {
          debugIme(`input ignored composing value=${JSON.stringify(proxy.value)}`);
          setImeCompositionText(proxy.value || compositionText);
        }
        return;
      }
      debugIme(`input value=${JSON.stringify(proxy.value)}`);
      if (forwardText(proxy.value, true)) {
        stopHandledImeEvent(event, proxy);
      }
    });

    proxy.addEventListener("keydown", (event) => {
      if (isComposing || event.isComposing || event.keyCode === 229) {
        debugIme(`keydown composing key=${event.key} keyCode=${event.keyCode}`);
        return;
      }
      const sequence = terminalKeySequence(event) || printableAsciiFromKey(event);
      if (sequence) {
        debugIme(`keydown key=${event.key} seq=${JSON.stringify(sequence)}`);
        forwardText(sequence);
        stopHandledImeEvent(event, proxy);
      }
    });

    proxy.addEventListener("paste", (event) => {
      const text = event.clipboardData?.getData("text/plain") || "";
      if (forwardText(text)) {
        stopHandledImeEvent(event, proxy);
      }
    });

    container.addEventListener("pointerdown", () => {
      focusInput();
      setTimeout(focusInput, 0);
    }, true);

    terminal?.textarea?.addEventListener("focus", () => {
      setTimeout(focusInput, 0);
    });
  }

  function fit(options = {}) {
    if (!terminal) {
      return;
    }

    const notify = options.notify !== false;

    if (fitAddon) {
      fitAddon.fit();
      if (notify) {
        postResize(terminal.cols, terminal.rows);
      }
      moveImeSurface();
      return;
    }

    const container = document.getElementById("terminal");
    const fontSize = Number(terminal.options.fontSize) || 15;
    const cols = Math.floor(container.clientWidth / Math.max(1, fontSize * 0.62));
    const rows = Math.floor(container.clientHeight / Math.max(1, fontSize * 1.35));
    const next = normalizeDimensions(cols, rows);
    terminal.resize(next.cols, next.rows);
    if (notify) {
      postResize(next.cols, next.rows);
    }
    moveImeSurface();
  }

  function postCurrentResize(options = {}) {
    if (!terminal) {
      return;
    }
    fit({ notify: false });
    postResize(terminal.cols, terminal.rows, options);
  }

  function startResizeKeepalive() {
    if (resizeKeepaliveId || !terminal) {
      return;
    }
    resizeKeepaliveId = window.setInterval(() => {
      postCurrentResize({ force: true });
    }, RESIZE_KEEPALIVE_INTERVAL_MS);
  }

  function bytesFromBase64(base64) {
    const binary = atob(base64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i += 1) {
      bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
  }

  function debugTerminalBuffer(reason) {
    if (window.localStorage?.getItem("iosmacs-ime-debug") !== "1" || !terminal?.buffer?.active) {
      return;
    }

    const buffer = terminal.buffer.active;
    const row = buffer.baseY + buffer.cursorY;
    const line = buffer.getLine(row)?.translateToString(true) || "";
    post({
      type: "log",
      level: "debug",
      message: `xterm ${reason} row=${row} cursor=${buffer.cursorX},${buffer.cursorY} line=${JSON.stringify(line)}`,
    });
  }

  function setFontSize(fontSize) {
    if (!terminal || !Number.isFinite(fontSize)) {
      return;
    }
    terminal.options.fontSize = Math.max(10, Math.min(28, fontSize));
    document.getElementById("terminal")?.style.setProperty(
      "--iosmacs-terminal-font-size",
      `${terminal.options.fontSize}px`
    );
    requestAnimationFrame(fit);
  }

  function initialize() {
    if (initialized) {
      return;
    }
    initialized = true;
    try {
      initializeTerminal();
    } catch (error) {
      post({
        type: "log",
        level: "error",
        message: `${error?.name || "Error"}: ${error?.message || String(error)}`,
      });
    }
  }

  function initializeTerminal() {
    const container = document.getElementById("terminal");
    if (!container || typeof window.Terminal !== "function") {
      post({ type: "log", level: "error", message: "xterm.js Terminal global not found" });
      return;
    }

    terminal = new window.Terminal({
      allowProposedApi: false,
      convertEol: false,
      cursorBlink: true,
      cursorStyle: "block",
      fontFamily: "'Menlo', 'SF Mono', 'Hiragino Sans', 'Hiragino Kaku Gothic ProN', monospace, sans-serif",
      fontSize: 15,
      fontWeight: 400,
      fontWeightBold: 700,
      macOptionIsMeta: true,
      rows: DEFAULT_DIMENSIONS.rows,
      cols: DEFAULT_DIMENSIONS.cols,
      scrollback: 1000,
      customKeyEventHandler: captureEmacsKey,
      theme: {
        background: "#000000",
        foreground: "#d0d0d0",
        cursor: "#f5f5f5",
        cursorAccent: "#000000",
        selectionBackground: "#4a5568",
      },
    });

    const FitAddonClass = window.FitAddon?.FitAddon;
    if (typeof FitAddonClass === "function") {
      fitAddon = new FitAddonClass();
      terminal.loadAddon(fitAddon);
    }

    terminal.open(container);
    terminal.onData(handleTerminalData);
    terminal.onResize(({ cols, rows }) => postResize(cols, rows));
    attachAsciiInputFallback(container);
    attachImeProxy(document.getElementById("ime-proxy"), container);
    imeProxy?.addEventListener("focus", () => post({ type: "focus", focused: true }));
    imeProxy?.addEventListener("blur", () => post({ type: "focus", focused: false }));

    window.iosmacsTerminal = {
      focus() {
        focusInput();
      },
      fit,
      forceResize() {
        postCurrentResize({ force: true });
      },
      setFontSize,
      injectData(data) {
        const text = String(data ?? "");
        traceIo(`injectData text=${JSON.stringify(text)}`);
        postInput(text);
      },
      writeBase64(base64) {
        terminal.write(bytesFromBase64(base64));
        debugTerminalBuffer("writeBase64");
        moveImeSurface();
        focusInput();
      },
    };

    requestAnimationFrame(() => {
      fit();
      focusInput();
      post({ type: "ready", cols: terminal.cols, rows: terminal.rows });
      startResizeKeepalive();
    });
  }

  window.addEventListener("error", (event) => {
    post({
      type: "log",
      level: "error",
      message: event.message || String(event.error || "unknown script error"),
    });
  });
  window.addEventListener("unhandledrejection", (event) => {
    post({
      type: "log",
      level: "error",
      message: String(event.reason || "unhandled promise rejection"),
    });
  });
  window.addEventListener("resize", () => requestAnimationFrame(fit));
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) {
      requestAnimationFrame(() => {
        fit();
        focusInput();
      });
    }
  });
  if (document.readyState === "loading") {
    window.addEventListener("DOMContentLoaded", initialize);
  } else {
    initialize();
  }
}());
