import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xterm/xterm.dart';

import '../backend/backend_capabilities.dart';
import '../backend/backend_diagnostics.dart';
import '../backend/emacs_backend.dart';
import '../backend/workspace_entry.dart';
import '../smoke/workspace_smoke_file.dart';
import 'terminal_input_bridge.dart';
import 'workspace_import_picker.dart';

typedef TerminalClipboardTextProvider = Future<String> Function();

Future<String> readClipboardText() async {
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  return data?.text ?? '';
}

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({
    required this.backend,
    this.autoStartBackend = false,
    this.mirrorTerminalOutputToLog = false,
    this.mirrorTerminalInputToLog = false,
    this.runWorkspaceSmoke = false,
    this.runCapabilitiesSmoke = false,
    this.runInputSmoke = false,
    this.runAndroidFileOpsSmoke = false,
    this.runAndroidJapaneseInputSmoke = false,
    this.runPointerSmoke = false,
    this.runResizeSmoke = false,
    this.runRedrawSmoke = false,
    this.runStatusSmoke = false,
    this.runStopSmoke = false,
    this.workspaceImportUriProvider = pickWorkspaceImportUris,
    this.workspaceSmokeImportUriProvider = createWorkspaceSmokeImportUri,
    this.clipboardTextProvider = readClipboardText,
    super.key,
  });

  final EmacsBackend backend;
  final bool autoStartBackend;
  final bool mirrorTerminalOutputToLog;
  final bool mirrorTerminalInputToLog;
  final bool runWorkspaceSmoke;
  final bool runCapabilitiesSmoke;
  final bool runInputSmoke;
  final bool runAndroidFileOpsSmoke;
  final bool runAndroidJapaneseInputSmoke;
  final bool runPointerSmoke;
  final bool runResizeSmoke;
  final bool runRedrawSmoke;
  final bool runStatusSmoke;
  final bool runStopSmoke;
  final WorkspaceImportUriProvider workspaceImportUriProvider;
  final Future<Uri?> Function() workspaceSmokeImportUriProvider;
  final TerminalClipboardTextProvider clipboardTextProvider;

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  static const double _minFontSize = 12;
  static const double _maxFontSize = 22;
  static const int _keyRepeatMultiplier = 3;

  final FocusNode _terminalFocusNode = FocusNode();
  final FocusNode _inputFocusNode = FocusNode();
  final TextEditingController _inputController = TextEditingController();
  final TerminalController _terminalController = TerminalController(
    pointerInputs: const PointerInputs.all(),
  );
  late final Terminal _terminal;
  late final TerminalInputBridge _inputBridge;

  StreamSubscription<List<int>>? _outputSubscription;
  double _fontSize = 15;
  String _terminalInputMirrorBuffer = '';
  bool _ctrlModifier = false;
  bool _metaModifier = false;
  bool _showInputRow = false;

  @override
  void initState() {
    super.initState();
    _inputBridge = TerminalInputBridge(widget.backend);
    _terminal = Terminal(
      onOutput: (String data) {
        _mirrorTerminalInput(data);
        unawaited(_handleTerminalOutput(data));
      },
      onResize: (int cols, int rows, int pixelWidth, int pixelHeight) {
        unawaited(widget.backend.resize(cols: cols, rows: rows));
      },
    );
    _outputSubscription = widget.backend.outputStream.listen(_appendOutput);
    widget.backend.resize(cols: 80, rows: 24);
    if (widget.autoStartBackend ||
        widget.runWorkspaceSmoke ||
        widget.runCapabilitiesSmoke ||
        widget.runInputSmoke ||
        widget.runAndroidFileOpsSmoke ||
        widget.runAndroidJapaneseInputSmoke ||
        widget.runPointerSmoke ||
        widget.runResizeSmoke ||
        widget.runRedrawSmoke ||
        widget.runStatusSmoke ||
        widget.runStopSmoke) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_runStartupSmokes());
      });
    }
  }

  @override
  void dispose() {
    _outputSubscription?.cancel();
    _terminalFocusNode.dispose();
    _inputFocusNode.dispose();
    _inputController.dispose();
    _terminalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: _shortcutBindings(),
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xff101214),
          body: SafeArea(
            child: Column(
              children: <Widget>[
                _StatusStrip(
                  lifecycle: widget.backend.lifecycleState,
                  diagnostics: widget.backend.diagnostics,
                  backendId: widget.backend.capabilities.id,
                  onDiagnostics: _openDiagnostics,
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: const Color(0xff101214),
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: _logTerminalPointerDown,
                      child: TerminalView(
                        _terminal,
                        autofocus: true,
                        controller: _terminalController,
                        focusNode: _terminalFocusNode,
                        keyboardType: TextInputType.text,
                        onKeyEvent: _handleTerminalKeyEvent,
                        padding: const EdgeInsets.all(12),
                        textStyle: TerminalStyle(fontSize: _fontSize),
                        theme: const TerminalTheme(
                          cursor: Color(0xffeceff4),
                          selection: Color(0xff4c566a),
                          foreground: Color(0xffd8dee9),
                          background: Color(0xff101214),
                          black: Color(0xff101214),
                          red: Color(0xffbf616a),
                          green: Color(0xffa3be8c),
                          yellow: Color(0xffebcb8b),
                          blue: Color(0xff81a1c1),
                          magenta: Color(0xffb48ead),
                          cyan: Color(0xff88c0d0),
                          white: Color(0xffeceff4),
                          brightBlack: Color(0xff4c566a),
                          brightRed: Color(0xffbf616a),
                          brightGreen: Color(0xffa3be8c),
                          brightYellow: Color(0xffebcb8b),
                          brightBlue: Color(0xff81a1c1),
                          brightMagenta: Color(0xffb48ead),
                          brightCyan: Color(0xff8fbcbb),
                          brightWhite: Color(0xffffffff),
                          searchHitBackground: Color(0xff5e81ac),
                          searchHitBackgroundCurrent: Color(0xffebcb8b),
                          searchHitForeground: Color(0xff101214),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_showInputRow)
                  _InputRow(
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    onSubmitted: _sendText,
                    ctrlActive: _ctrlModifier,
                    metaActive: _metaModifier,
                  ),
                _ControlKeyRow(
                  ctrlActive: _ctrlModifier,
                  metaActive: _metaModifier,
                  onCtrlToggle: () =>
                      setState(() => _ctrlModifier = !_ctrlModifier),
                  onMetaToggle: () =>
                      setState(() => _metaModifier = !_metaModifier),
                  onSendBytes: (List<int> bytes) =>
                      unawaited(widget.backend.sendBytes(bytes)),
                  onPaste: _pasteClipboardText,
                  onShowKeyboard: _showKeyboard,
                ),
                _Toolbar(
                  fontSize: _fontSize,
                  minFontSize: _minFontSize,
                  maxFontSize: _maxFontSize,
                  showInputRow: _showInputRow,
                  onStart: widget.backend.start,
                  onStop: widget.backend.stop,
                  onReset: widget.backend.resetOrRedraw,
                  onFontChanged: _setFontSize,
                  onWorkspace: _openWorkspace,
                  onCapabilities: _openCapabilities,
                  onToggleInputRow: () =>
                      setState(() => _showInputRow = !_showInputRow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Map<ShortcutActivator, VoidCallback> _shortcutBindings() {
    return <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.keyS,
          control: true, shift: true): () => unawaited(widget.backend.start()),
      const SingleActivator(LogicalKeyboardKey.keyS, meta: true, shift: true):
          () => unawaited(widget.backend.start()),
      const SingleActivator(LogicalKeyboardKey.keyX,
          control: true, shift: true): () => unawaited(widget.backend.stop()),
      const SingleActivator(LogicalKeyboardKey.keyX, meta: true, shift: true):
          () => unawaited(widget.backend.stop()),
      const SingleActivator(LogicalKeyboardKey.keyR,
          control: true,
          shift: true): () => unawaited(widget.backend.resetOrRedraw()),
      const SingleActivator(LogicalKeyboardKey.keyR, meta: true, shift: true):
          () => unawaited(widget.backend.resetOrRedraw()),
      const SingleActivator(LogicalKeyboardKey.keyW,
          control: true, shift: true): () => unawaited(_openWorkspace()),
      const SingleActivator(LogicalKeyboardKey.keyW, meta: true, shift: true):
          () => unawaited(_openWorkspace()),
      const SingleActivator(LogicalKeyboardKey.keyI,
          control: true, shift: true): _openCapabilities,
      const SingleActivator(LogicalKeyboardKey.keyI, meta: true, shift: true):
          _openCapabilities,
      const SingleActivator(LogicalKeyboardKey.keyD,
          control: true, shift: true): _openDiagnostics,
      const SingleActivator(LogicalKeyboardKey.keyD, meta: true, shift: true):
          _openDiagnostics,
      const SingleActivator(LogicalKeyboardKey.space, control: true): () =>
          unawaited(widget.backend.sendBytes(const <int>[0x00])),
      const SingleActivator(LogicalKeyboardKey.keyV, meta: true): () =>
          unawaited(_pasteClipboardText()),
      const SingleActivator(LogicalKeyboardKey.equal,
          control: true, shift: true): _increaseFontSize,
      const SingleActivator(LogicalKeyboardKey.equal, meta: true, shift: true):
          _increaseFontSize,
      const SingleActivator(LogicalKeyboardKey.minus,
          control: true, shift: true): _decreaseFontSize,
      const SingleActivator(LogicalKeyboardKey.minus, meta: true, shift: true):
          _decreaseFontSize,
    };
  }

  KeyEventResult _handleTerminalKeyEvent(FocusNode focusNode, KeyEvent event) {
    // Apply Ctrl/Meta modifier to key-down events for letter keys.
    // This covers hardware keyboards when a sticky modifier is active.
    // Software keyboard (IME) input is handled in _handleTerminalOutput instead.
    if (event is KeyDownEvent && (_ctrlModifier || _metaModifier)) {
      final controlByte = _controlByteForKey(event.logicalKey);
      if (controlByte != null) {
        if (_ctrlModifier) {
          final bytes = _metaModifier
              ? <int>[0x1b, controlByte]
              : <int>[controlByte];
          setState(() {
            _ctrlModifier = false;
            _metaModifier = false;
          });
          unawaited(widget.backend.sendBytes(bytes));
        } else {
          // Meta only: ESC + lowercase letter (keyId is the lowercase ASCII code).
          final lower = event.logicalKey.keyId & 0xff;
          setState(() => _metaModifier = false);
          unawaited(widget.backend.sendBytes(<int>[0x1b, lower]));
        }
        return KeyEventResult.handled;
      }
    }

    if (event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final bytes = _boostedRepeatBytes(event);
    if (bytes.isEmpty) {
      return KeyEventResult.ignored;
    }

    unawaited(widget.backend.sendBytes(bytes));
    return KeyEventResult.ignored;
  }

  List<int> _boostedRepeatBytes(KeyRepeatEvent event) {
    const extraRepeats = _keyRepeatMultiplier - 1;
    if (extraRepeats <= 0) {
      return const <int>[];
    }

    final sequence = _terminalRepeatSequence(event);
    if (sequence.isEmpty) {
      return const <int>[];
    }

    return List<int>.generate(
      sequence.length * extraRepeats,
      (int index) => sequence[index % sequence.length],
      growable: false,
    );
  }

  List<int> _terminalRepeatSequence(KeyRepeatEvent event) {
    final hardware = HardwareKeyboard.instance;
    if (hardware.isMetaPressed) {
      return const <int>[];
    }

    final key = event.logicalKey;
    switch (key) {
      case LogicalKeyboardKey.arrowUp:
        return const <int>[0x1b, 0x5b, 0x41];
      case LogicalKeyboardKey.arrowDown:
        return const <int>[0x1b, 0x5b, 0x42];
      case LogicalKeyboardKey.arrowRight:
        return const <int>[0x1b, 0x5b, 0x43];
      case LogicalKeyboardKey.arrowLeft:
        return const <int>[0x1b, 0x5b, 0x44];
      case LogicalKeyboardKey.backspace:
        return const <int>[0x7f];
      case LogicalKeyboardKey.delete:
        return const <int>[0x1b, 0x5b, 0x33, 0x7e];
      case LogicalKeyboardKey.enter:
        return const <int>[0x0d];
      case LogicalKeyboardKey.tab:
        return const <int>[0x09];
      case LogicalKeyboardKey.space:
        return hardware.isControlPressed
            ? const <int>[0x00]
            : const <int>[0x20];
    }

    if (hardware.isControlPressed) {
      final controlByte = _controlByteForKey(key);
      return controlByte == null ? const <int>[] : <int>[controlByte];
    }

    if (hardware.isAltPressed) {
      return const <int>[];
    }

    final character = event.character;
    if (character == null || character.isEmpty) {
      return const <int>[];
    }

    final codeUnits = character.codeUnits;
    if (codeUnits.length != 1 ||
        codeUnits.single < 0x20 ||
        codeUnits.single > 0x7e) {
      return const <int>[];
    }
    return codeUnits;
  }

  int? _controlByteForKey(LogicalKeyboardKey key) {
    final keyId = key.keyId;
    final keyA = LogicalKeyboardKey.keyA.keyId;
    final keyZ = LogicalKeyboardKey.keyZ.keyId;
    if (keyId >= keyA && keyId <= keyZ) {
      return (keyId - keyA + 1).toInt();
    }
    return null;
  }

  void _setFontSize(double value) {
    setState(() {
      _fontSize = value.clamp(_minFontSize, _maxFontSize);
    });
  }

  void _increaseFontSize() {
    _setFontSize(_fontSize + 1);
  }

  void _decreaseFontSize() {
    _setFontSize(_fontSize - 1);
  }

  Future<void> _openWorkspace() async {
    final entries = await widget.backend.listWorkspace();
    if (!mounted) {
      return;
    }
    unawaited(_showWorkspace(entries));
  }

  void _openCapabilities() {
    unawaited(_showCapabilities(widget.backend.capabilities));
  }

  void _openDiagnostics() {
    unawaited(_showDiagnostics());
  }

  void _appendOutput(List<int> bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    _terminal.write(text);
    if (widget.mirrorTerminalOutputToLog) {
      debugPrint('iosmacs-terminal-output: $text');
    }
  }

  void _mirrorTerminalInput(String data) {
    if (!widget.mirrorTerminalInputToLog || data.isEmpty) {
      return;
    }
    if (data.codeUnits.any((int unit) => unit < 0x20 || unit == 0x7f)) {
      final hex = utf8
          .encode(data)
          .take(80)
          .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      debugPrint('iosmacs-terminal-input-hex: bytes="$hex"');
    }
    final printable = data
        .replaceAll('\r', '<CR>')
        .replaceAll('\n', '<LF>')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');
    if (printable.isEmpty) {
      return;
    }
    _terminalInputMirrorBuffer += printable;
    if (_terminalInputMirrorBuffer.length > 256) {
      _terminalInputMirrorBuffer = _terminalInputMirrorBuffer.substring(
        _terminalInputMirrorBuffer.length - 256,
      );
    }
    debugPrint('iosmacs-terminal-input: text="$printable"');
    debugPrint(
        'iosmacs-terminal-input-buffer: text="$_terminalInputMirrorBuffer"');
  }

  void _logTerminalPointerDown(PointerDownEvent event) {
    if (!widget.mirrorTerminalInputToLog) {
      return;
    }
    debugPrint(
      'iosmacs-terminal-pointer: kind=${event.kind.name}; '
      'x=${event.localPosition.dx.toStringAsFixed(1)}; '
      'y=${event.localPosition.dy.toStringAsFixed(1)}',
    );
  }

  Future<void> _runStartupSmokes() async {
    if (widget.runCapabilitiesSmoke) {
      _logCapabilitiesSmoke(widget.backend.capabilities);
    }

    if (widget.autoStartBackend) {
      await widget.backend.start();
    }
    if (widget.runStatusSmoke) {
      _logStatusSmoke();
    }
    if (widget.runInputSmoke) {
      await _runInputSmoke();
    }
    if (widget.runAndroidJapaneseInputSmoke) {
      await _runAndroidJapaneseInputSmoke();
    }
    if (widget.runAndroidFileOpsSmoke) {
      await _runAndroidFileOpsSmoke();
    }
    if (widget.runPointerSmoke) {
      await _runPointerSmoke();
    }
    if (widget.runResizeSmoke) {
      await _runResizeSmoke();
    }
    if (widget.runRedrawSmoke) {
      await _runRedrawSmoke();
    }
    if (!widget.runWorkspaceSmoke) {
      if (widget.runStopSmoke) {
        await _runStopSmoke();
      }
      return;
    }

    final initialEntries = await widget.backend.listWorkspace();
    _logSmoke('workspace listed ${initialEntries.length} item(s)');

    try {
      final importUri = await widget.workspaceSmokeImportUriProvider();
      if (importUri == null) {
        _logSmoke('workspace import skipped: no smoke file URI');
      } else {
        final importedCount = await widget.backend.importToWorkspace(<Uri>[
          importUri,
        ]);
        _logSmoke('workspace imported $importedCount item(s)');
      }
    } catch (error) {
      _logSmoke('workspace import failed: $error');
    }

    final entries = await widget.backend.listWorkspace();
    _logSmoke('workspace listed after import ${entries.length} item(s)');
    if (entries.isNotEmpty) {
      final entry = entries.last;
      final byteCount = await _sendWorkspaceOpenCommand(entry);
      await Future<void>.delayed(Duration.zero);
      final diagnostics = widget.backend.diagnostics.value;
      _logSmoke(
        'workspace open requested: ${entry.path} '
        '($byteCount byte(s)); backend input total ${diagnostics.inputBytes}',
      );
    } else {
      _logSmoke('workspace open skipped: no workspace entries');
    }
    final exports = await widget.backend.exportWorkspaceSelection();
    _logSmoke('workspace export candidate(s): ${exports.length}');
    _logSmoke(
      'workspace export uri(s): '
      '${exports.map((Uri uri) => uri.toString()).join(', ')}',
    );
    if (widget.runStopSmoke) {
      await _runStopSmoke();
    }
  }

  void _logSmoke(String message) {
    if (widget.mirrorTerminalOutputToLog) {
      debugPrint('iosmacs-workspace-smoke: $message');
    }
  }

  void _logCapabilitiesSmoke(BackendCapabilities capabilities) {
    if (!widget.mirrorTerminalOutputToLog) {
      return;
    }
    debugPrint(
      'iosmacs-capabilities-smoke: id=${capabilities.id} '
      'supported=${capabilities.supportedFeatures.length} '
      'unsupported=${capabilities.unsupportedFeatures.length}',
    );
  }

  void _logStatusSmoke() {
    if (!widget.mirrorTerminalOutputToLog) {
      return;
    }
    final diagnostics = widget.backend.diagnostics.value;
    debugPrint(
      'iosmacs-status-smoke: id=${widget.backend.capabilities.id} '
      'lifecycle=${widget.backend.lifecycleState.value} '
      'geometry=${diagnostics.cols}x${diagnostics.rows}',
    );
  }

  Future<void> _runInputSmoke() async {
    const text = 'iosmacs input smoke';
    final byteCount = utf8.encode('$text\r').length;
    await _inputBridge.submitCommittedText(text);
    await Future<void>.delayed(Duration.zero);
    final diagnostics = widget.backend.diagnostics.value;
    _logInputSmoke(
      'committed $byteCount byte(s); backend input total '
      '${diagnostics.inputBytes}; text="$text"',
    );
  }

  void _logInputSmoke(String message) {
    if (widget.mirrorTerminalOutputToLog) {
      debugPrint('iosmacs-input-smoke: $message');
    }
  }

  Future<void> _runAndroidJapaneseInputSmoke() async {
    const text = '日本語';
    const elisp =
        '(let ((marker (expand-file-name "iosmacs-android-japanese-input.marker" "~"))) '
        '(write-region "iosmacs-android-japanese-input-ok:日本語\\n" nil marker nil nil) '
        '(message "iosmacs-android-japanese-input-ok:日本語"))';
    // Use LF (\n = C-j) to trigger eval-print-last-sexp in *scratch*, not CR.
    final bytes = utf8.encode('$elisp\n');
    await Future<void>.delayed(const Duration(milliseconds: 500));
    await widget.backend.sendBytes(bytes);
    await Future<void>.delayed(Duration.zero);
    final diagnostics = widget.backend.diagnostics.value;
    _logAndroidJapaneseInputSmoke(
      'submitted ${bytes.length} byte(s); backend input total '
      '${diagnostics.inputBytes}; text="$text"',
    );
  }

  void _logAndroidJapaneseInputSmoke(String message) {
    if (widget.mirrorTerminalOutputToLog) {
      debugPrint('iosmacs-android-japanese-input-smoke: $message');
    }
  }

  Future<void> _runAndroidFileOpsSmoke() async {
    const elisp = r'''(load "~/iosmacs-android-file-ops-smoke.el")''';
    await Future<void>.delayed(const Duration(seconds: 1));
    final bytes = utf8.encode('$elisp\n');
    await widget.backend.sendBytes(bytes);
    await Future<void>.delayed(Duration.zero);
    final diagnostics = widget.backend.diagnostics.value;
    _logAndroidFileOpsSmoke(
      'submitted ${bytes.length} byte(s); backend input total '
      '${diagnostics.inputBytes}',
    );
  }

  void _logAndroidFileOpsSmoke(String message) {
    if (widget.mirrorTerminalOutputToLog) {
      debugPrint('iosmacs-android-file-ops-smoke: $message');
    }
  }

  Future<void> _runPointerSmoke() async {
    for (var attempt = 0; attempt < 60; attempt += 1) {
      if (_terminal.mouseMode != MouseMode.none) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final down = _terminal.mouseInput(
      TerminalMouseButton.left,
      TerminalMouseButtonState.down,
      const CellOffset(2, 2),
    );
    final up = _terminal.mouseInput(
      TerminalMouseButton.left,
      TerminalMouseButtonState.up,
      const CellOffset(2, 2),
    );
    _logPointerSmoke(
      'mode=${_terminal.mouseMode.name}; down=$down; up=$up',
    );
  }

  void _logPointerSmoke(String message) {
    if (widget.mirrorTerminalOutputToLog) {
      debugPrint('iosmacs-pointer-smoke: $message');
    }
  }

  Future<void> _runResizeSmoke() async {
    final cols = _terminal.viewWidth;
    final rows = _terminal.viewHeight;
    await widget.backend.resize(cols: cols, rows: rows);
    await Future<void>.delayed(Duration.zero);
    final diagnostics = widget.backend.diagnostics.value;
    _logResizeSmoke(
      'requested ${cols}x$rows; backend geometry '
      '${diagnostics.cols}x${diagnostics.rows}',
    );
  }

  void _logResizeSmoke(String message) {
    if (widget.mirrorTerminalOutputToLog) {
      debugPrint('iosmacs-resize-smoke: $message');
    }
  }

  Future<void> _runRedrawSmoke() async {
    await widget.backend.resetOrRedraw();
    await Future<void>.delayed(Duration.zero);
    final diagnostics = widget.backend.diagnostics.value;
    _logRedrawSmoke('message="${diagnostics.message}"');
  }

  void _logRedrawSmoke(String message) {
    if (widget.mirrorTerminalOutputToLog) {
      debugPrint('iosmacs-redraw-smoke: $message');
    }
  }

  Future<void> _runStopSmoke() async {
    await widget.backend.stop();
    await Future<void>.delayed(Duration.zero);
    _logStopSmoke('lifecycle=${widget.backend.lifecycleState.value}');
  }

  void _logStopSmoke(String message) {
    if (widget.mirrorTerminalOutputToLog) {
      debugPrint('iosmacs-stop-smoke: $message');
    }
  }

  Future<void> _showCapabilities(BackendCapabilities capabilities) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(capabilities.displayName),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text('Backend id: ${capabilities.id}'),
                const SizedBox(height: 12),
                const Text(
                  'Supported',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text('${capabilities.supportedFeatures.length} item(s)'),
                const SizedBox(height: 6),
                ...capabilities.supportedFeatures.map(_CapabilityLine.new),
                const SizedBox(height: 12),
                const Text(
                  'Unsupported',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                Text('${capabilities.unsupportedFeatures.length} item(s)'),
                const SizedBox(height: 6),
                ...capabilities.unsupportedFeatures.map(_CapabilityLine.new),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDiagnostics() {
    final lifecycle = widget.backend.lifecycleState.value;
    final diagnostics = widget.backend.diagnostics.value;
    final backendId = widget.backend.capabilities.id;

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Backend diagnostics'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _DiagnosticsLine(label: 'Backend id', value: backendId),
                _DiagnosticsLine(label: 'Lifecycle', value: lifecycle),
                _DiagnosticsLine(
                  label: 'Geometry',
                  value: '${diagnostics.cols}x${diagnostics.rows}',
                ),
                _DiagnosticsLine(
                  label: 'Input bytes',
                  value: diagnostics.inputBytes.toString(),
                ),
                _DiagnosticsLine(
                  label: 'Output bytes',
                  value: diagnostics.outputBytes.toString(),
                ),
                _DiagnosticsLine(
                  label: 'Workspace actions',
                  value: diagnostics.workspaceActions.toString(),
                ),
                _DiagnosticsLine(
                  label: 'Message',
                  value: diagnostics.message,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showWorkspace(List<WorkspaceEntry> initialEntries) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        var entries = initialEntries;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Workspace'),
              content: SizedBox(
                width: 420,
                child: entries.isEmpty
                    ? const Text('No workspace entries')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, int index) {
                          final entry = entries[index];
                          return _WorkspaceEntryTile(
                            entry,
                            onOpen: () {
                              unawaited(_openWorkspaceEntry(entry, context));
                            },
                          );
                        },
                      ),
              ),
              actions: <Widget>[
                TextButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final uris = await widget.workspaceImportUriProvider();
                    if (!mounted) {
                      return;
                    }
                    if (uris.isEmpty) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Import canceled')),
                      );
                      return;
                    }

                    final importedCount =
                        await widget.backend.importToWorkspace(uris);
                    final refreshedEntries =
                        await widget.backend.listWorkspace();
                    if (!mounted) {
                      return;
                    }
                    setDialogState(() {
                      entries = refreshedEntries;
                    });
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('$importedCount imported item(s)'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.file_upload),
                  label: const Text('Import'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final message = await widget.backend.selectWorkspaceRoot();
                    final refreshedEntries =
                        await widget.backend.listWorkspace();
                    if (!mounted) {
                      return;
                    }
                    setDialogState(() {
                      entries = refreshedEntries;
                    });
                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  },
                  icon: const Icon(Icons.drive_folder_upload),
                  label: const Text('Choose /home/user'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final message =
                        await widget.backend.clearWorkspaceRootSelection();
                    final refreshedEntries =
                        await widget.backend.listWorkspace();
                    if (!mounted) {
                      return;
                    }
                    setDialogState(() {
                      entries = refreshedEntries;
                    });
                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      SnackBar(content: Text(message)),
                    );
                  },
                  icon: const Icon(Icons.folder_off),
                  label: const Text('Use Default'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final refreshedEntries =
                        await widget.backend.listWorkspace();
                    if (!mounted) {
                      return;
                    }
                    setDialogState(() {
                      entries = refreshedEntries;
                    });
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          'Workspace refreshed: ${refreshedEntries.length} item(s)',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final navigator = Navigator.of(dialogContext);
                    final exported =
                        await widget.backend.exportWorkspaceSelection();
                    if (!mounted) {
                      return;
                    }
                    navigator.pop();
                    unawaited(_showWorkspaceExportCandidates(exported));
                  },
                  icon: const Icon(Icons.ios_share),
                  label: const Text('Export'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showWorkspaceExportCandidates(List<Uri> exportedUris) {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Workspace export candidates'),
          content: SizedBox(
            width: 460,
            child: exportedUris.isEmpty
                ? const Text('No export candidates')
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('${exportedUris.length} export candidate(s)'),
                      const SizedBox(height: 8),
                      ListView.separated(
                        shrinkWrap: true,
                        itemCount: exportedUris.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, int index) {
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.ios_share),
                            title:
                                SelectableText(exportedUris[index].toString()),
                          );
                        },
                      ),
                    ],
                  ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendText(String text) async {
    if (text.isEmpty) {
      return;
    }
    _inputController.clear();

    final applyCtrl = _ctrlModifier;
    final applyMeta = _metaModifier;
    setState(() {
      _ctrlModifier = false;
      _metaModifier = false;
    });

    if (applyCtrl && text.length == 1) {
      final upper = text.toUpperCase().codeUnitAt(0);
      if (upper >= 0x41 && upper <= 0x5A) {
        final ctrlByte = upper - 0x40;
        final bytes = applyMeta ? <int>[0x1b, ctrlByte] : <int>[ctrlByte];
        await widget.backend.sendBytes(bytes);
        return;
      }
    }
    if (applyMeta) {
      await widget.backend.sendBytes(
        <int>[0x1b, ...utf8.encode(text)],
      );
      return;
    }
    await _inputBridge.submitCommittedText(text);
  }

  // Routes inline terminal output through Ctrl/Meta modifiers before forwarding.
  // Called from Terminal.onOutput for all keyboard and IME input typed in the
  // terminal view.  Ctrl/Meta only apply to single ASCII letters; multi-character
  // text (Japanese IME commits, escape sequences, etc.) is forwarded as-is.
  Future<void> _handleTerminalOutput(String data) async {
    if (data.isEmpty) return;

    if (_ctrlModifier) {
      if (data.length == 1) {
        final upper = data.toUpperCase().codeUnitAt(0);
        if (upper >= 0x41 && upper <= 0x5A) {
          final ctrlByte = upper - 0x40;
          if (_metaModifier) {
            setState(() {
              _ctrlModifier = false;
              _metaModifier = false;
            });
            await widget.backend.sendBytes(<int>[0x1b, ctrlByte]);
          } else {
            setState(() => _ctrlModifier = false);
            await widget.backend.sendBytes(<int>[ctrlByte]);
          }
          return;
        }
      }
      setState(() => _ctrlModifier = false);
    }

    if (_metaModifier) {
      setState(() => _metaModifier = false);
      if (data.length == 1) {
        final code = data.codeUnitAt(0);
        if (code >= 0x20 && code <= 0x7e) {
          await widget.backend.sendBytes(<int>[0x1b, code]);
          return;
        }
      }
    }

    await _inputBridge.sendTerminalOutput(data);
  }

  // Shows the input row (if hidden) and focuses the TextField so the
  // Android soft keyboard appears.  Reliable cross-device keyboard path.
  void _showKeyboard() {
    if (!_showInputRow) {
      setState(() => _showInputRow = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _inputFocusNode.requestFocus();
    });
  }

  Future<void> _pasteClipboardText() async {
    final messenger = ScaffoldMessenger.of(context);
    final text = await widget.clipboardTextProvider();
    if (!mounted) {
      return;
    }
    if (text.isNotEmpty) {
      await _inputBridge.pasteText(text);
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text('Pasted ${utf8.encode(text).length} byte(s)')),
      );
      return;
    }

    if (await widget.backend.pasteSystemClipboard()) {
      if (!mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Pasted from system clipboard')),
      );
      return;
    }

    if (mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Clipboard is empty')),
      );
    }
  }

  Future<void> _openWorkspaceEntry(
    WorkspaceEntry entry,
    BuildContext context,
  ) async {
    await _sendWorkspaceOpenCommand(entry);
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening ${entry.name}')),
    );
  }

  Future<int> _sendWorkspaceOpenCommand(WorkspaceEntry entry) async {
    final bytes = <int>[
      0x18,
      0x06,
      ...utf8.encode(entry.path),
      0x0d,
    ];
    await widget.backend.sendBytes(bytes);
    return bytes.length;
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.lifecycle,
    required this.diagnostics,
    required this.backendId,
    required this.onDiagnostics,
  });

  final ValueListenable<String> lifecycle;
  final ValueListenable<BackendDiagnostics> diagnostics;
  final String backendId;
  final VoidCallback onDiagnostics;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xff242933),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          if (constraints.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    _LifecycleText(lifecycle: lifecycle),
                    const SizedBox(width: 12),
                    Expanded(child: _BackendText(backendId: backendId)),
                    const SizedBox(width: 4),
                    _DiagnosticsButton(onPressed: onDiagnostics),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    _GeometryText(diagnostics: diagnostics),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DiagnosticsSummary(diagnostics: diagnostics),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: <Widget>[
              _LifecycleText(lifecycle: lifecycle),
              const SizedBox(width: 12),
              Flexible(child: _BackendText(backendId: backendId)),
              const SizedBox(width: 12),
              _GeometryText(diagnostics: diagnostics),
              const SizedBox(width: 4),
              _DiagnosticsButton(onPressed: onDiagnostics),
              const SizedBox(width: 12),
              Expanded(child: _DiagnosticsSummary(diagnostics: diagnostics)),
            ],
          );
        },
      ),
    );
  }
}

class _LifecycleText extends StatelessWidget {
  const _LifecycleText({required this.lifecycle});

  final ValueListenable<String> lifecycle;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: lifecycle,
      builder: (_, String value, __) => Text(
        value,
        style: const TextStyle(
          color: Color(0xff88c0d0),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BackendText extends StatelessWidget {
  const _BackendText({required this.backendId});

  final String backendId;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Backend $backendId',
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xffa3be8c),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _GeometryText extends StatelessWidget {
  const _GeometryText({required this.diagnostics});

  final ValueListenable<BackendDiagnostics> diagnostics;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BackendDiagnostics>(
      valueListenable: diagnostics,
      builder: (_, BackendDiagnostics value, __) => Text(
        'TTY ${value.cols}x${value.rows}',
        style: const TextStyle(
          color: Color(0xffebcb8b),
          fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _DiagnosticsButton extends StatelessWidget {
  const _DiagnosticsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Diagnostics',
      onPressed: onPressed,
      icon: const Icon(Icons.info_outline),
      color: const Color(0xffd8dee9),
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
    );
  }
}

class _DiagnosticsSummary extends StatelessWidget {
  const _DiagnosticsSummary({required this.diagnostics});

  final ValueListenable<BackendDiagnostics> diagnostics;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BackendDiagnostics>(
      valueListenable: diagnostics,
      builder: (_, BackendDiagnostics value, __) => Text(
        value.summary,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Color(0xffd8dee9)),
      ),
    );
  }
}

class _DiagnosticsLine extends StatelessWidget {
  const _DiagnosticsLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.ctrlActive = false,
    this.metaActive = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final bool ctrlActive;
  final bool metaActive;

  String get _hintText {
    if (ctrlActive && metaActive) return 'C-M- key';
    if (ctrlActive) return 'C- key (Ctrl + letter)';
    if (metaActive) return 'M- key (Meta + text)';
    return 'compose and send';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xff1b1f26),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              minLines: 1,
              maxLines: 2,
              onSubmitted: onSubmitted,
              style: const TextStyle(
                color: Color(0xffeceff4),
                fontFamily: 'monospace',
              ),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: ctrlActive || metaActive
                    ? const Color(0xff1a2535)
                    : const Color(0xff101214),
                border: const OutlineInputBorder(),
                hintText: _hintText,
                hintStyle: TextStyle(
                  color: ctrlActive
                      ? const Color(0xff88c0d0)
                      : metaActive
                          ? const Color(0xffebcb8b)
                          : const Color(0xff6f7785),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Send',
            onPressed: () {
              onSubmitted(controller.text);
            },
            icon: const Icon(Icons.send),
            color: const Color(0xff88c0d0),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.fontSize,
    required this.minFontSize,
    required this.maxFontSize,
    required this.showInputRow,
    required this.onStart,
    required this.onStop,
    required this.onReset,
    required this.onFontChanged,
    required this.onWorkspace,
    required this.onCapabilities,
    required this.onToggleInputRow,
  });

  static const double _toolbarSliderWidth = 168;

  final double fontSize;
  final double minFontSize;
  final double maxFontSize;
  final bool showInputRow;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;
  final Future<void> Function() onReset;
  final ValueChanged<double> onFontChanged;
  final Future<void> Function() onWorkspace;
  final VoidCallback onCapabilities;
  final VoidCallback onToggleInputRow;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xff242933),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SingleChildScrollView(
        key: const ValueKey<String>('iosmacs-toolbar-scroll'),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            IconButton(
              tooltip: 'Start',
              onPressed: () {
                unawaited(onStart());
              },
              icon: const Icon(Icons.play_arrow),
              color: const Color(0xffa3be8c),
            ),
            IconButton(
              tooltip: 'Stop',
              onPressed: () {
                unawaited(onStop());
              },
              icon: const Icon(Icons.stop),
              color: const Color(0xffbf616a),
            ),
            IconButton(
              tooltip: 'Reset',
              onPressed: () {
                unawaited(onReset());
              },
              icon: const Icon(Icons.refresh),
              color: const Color(0xffebcb8b),
            ),
            IconButton(
              tooltip: 'Workspace',
              onPressed: () {
                unawaited(onWorkspace());
              },
              icon: const Icon(Icons.folder_open),
              color: const Color(0xff88c0d0),
            ),
            IconButton(
              tooltip: 'Capabilities',
              onPressed: onCapabilities,
              icon: const Icon(Icons.info_outline),
              color: const Color(0xffd8dee9),
            ),
            IconButton(
              tooltip: showInputRow ? 'Hide input row' : 'Show input row',
              onPressed: onToggleInputRow,
              icon: Icon(showInputRow ? Icons.keyboard_hide : Icons.keyboard),
              color: showInputRow
                  ? const Color(0xff88c0d0)
                  : const Color(0xff4c566a),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.text_fields, color: Color(0xffd8dee9)),
            SizedBox(
              width: _toolbarSliderWidth,
              child: Slider(
                value: fontSize,
                min: minFontSize,
                max: maxFontSize,
                divisions: 10,
                label: fontSize.toStringAsFixed(0),
                onChanged: onFontChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityLine extends StatelessWidget {
  const _CapabilityLine(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('- '),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}

class _ControlKeyRow extends StatelessWidget {
  const _ControlKeyRow({
    required this.ctrlActive,
    required this.metaActive,
    required this.onCtrlToggle,
    required this.onMetaToggle,
    required this.onSendBytes,
    required this.onPaste,
    required this.onShowKeyboard,
  });

  final bool ctrlActive;
  final bool metaActive;
  final VoidCallback onCtrlToggle;
  final VoidCallback onMetaToggle;
  final void Function(List<int>) onSendBytes;
  final Future<void> Function() onPaste;
  final VoidCallback onShowKeyboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('iosmacs-control-key-row'),
      color: const Color(0xff1a2030),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _ModifierKeyButton(
              label: 'KB',
              tooltip: 'Show input bar and keyboard',
              onPressed: onShowKeyboard,
              active: false,
              activeColor: const Color(0xffd8dee9),
            ),
            _ModifierKeyButton(
              label: 'ESC',
              tooltip: 'Send ESC (\\x1b)',
              onPressed: () => onSendBytes(const <int>[0x1b]),
              active: false,
              activeColor: const Color(0xffb48ead),
            ),
            _ModifierKeyButton(
              label: 'C-g',
              tooltip: 'Cancel (C-g = \\x07)',
              onPressed: () => onSendBytes(const <int>[0x07]),
              active: false,
              activeColor: const Color(0xffbf616a),
            ),
            _ModifierKeyButton(
              label: 'C-x',
              tooltip: 'C-x prefix — then type next key (e.g. C-f, C-s, C-c)',
              onPressed: () => onSendBytes(const <int>[0x18]),
              active: false,
              activeColor: const Color(0xff88c0d0),
            ),
            _ModifierKeyButton(
              label: 'C-c',
              tooltip: 'C-c prefix (\\x03)',
              onPressed: () => onSendBytes(const <int>[0x03]),
              active: false,
              activeColor: const Color(0xff88c0d0),
            ),
            _ModifierKeyButton(
              label: 'M-x',
              tooltip: 'M-x (execute-extended-command)',
              onPressed: () => onSendBytes(const <int>[0x1b, 0x78]),
              active: false,
              activeColor: const Color(0xffebcb8b),
            ),
            _ModifierKeyButton(
              label: 'C-s',
              tooltip: 'isearch-forward / save (C-s = \\x13)',
              onPressed: () => onSendBytes(const <int>[0x13]),
              active: false,
              activeColor: const Color(0xffa3be8c),
            ),
            _ModifierKeyButton(
              label: 'C-r',
              tooltip: 'isearch-backward (C-r = \\x12)',
              onPressed: () => onSendBytes(const <int>[0x12]),
              active: false,
              activeColor: const Color(0xffa3be8c),
            ),
            _ModifierKeyButton(
              label: 'C-/',
              tooltip: 'Undo (C-/ = \\x1f)',
              onPressed: () => onSendBytes(const <int>[0x1f]),
              active: false,
              activeColor: const Color(0xffebcb8b),
            ),
            _ModifierKeyButton(
              label: 'TAB',
              tooltip: 'Tab / indent / complete (\\x09)',
              onPressed: () => onSendBytes(const <int>[0x09]),
              active: false,
              activeColor: const Color(0xffa3be8c),
            ),
            _ModifierKeyButton(
              label: 'DEL',
              tooltip: 'Delete backward (\\x7f)',
              onPressed: () => onSendBytes(const <int>[0x7f]),
              active: false,
              activeColor: const Color(0xffbf616a),
            ),
            _ModifierKeyButton(
              label: 'Paste',
              tooltip: 'Paste from clipboard',
              onPressed: () => unawaited(onPaste()),
              active: false,
              activeColor: const Color(0xffa3be8c),
            ),
            _ModifierKeyButton(
              label: 'Ctrl',
              tooltip: ctrlActive
                  ? 'Ctrl ON — type a letter in terminal to send C-letter'
                  : 'Sticky Ctrl — next letter typed in terminal becomes C-letter',
              onPressed: onCtrlToggle,
              active: ctrlActive,
              activeColor: const Color(0xff88c0d0),
            ),
            _ModifierKeyButton(
              label: 'Meta',
              tooltip: metaActive
                  ? 'Meta ON — type a letter in terminal to send M-letter'
                  : 'Sticky Meta — next letter typed in terminal becomes M-letter',
              onPressed: onMetaToggle,
              active: metaActive,
              activeColor: const Color(0xffebcb8b),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModifierKeyButton extends StatelessWidget {
  const _ModifierKeyButton({
    required this.label,
    required this.tooltip,
    required this.onPressed,
    required this.active,
    required this.activeColor,
  });

  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final bool active;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Tooltip(
        message: tooltip,
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            backgroundColor:
                active ? activeColor.withValues(alpha: 0.25) : Colors.transparent,
            foregroundColor: active ? activeColor : const Color(0xffd8dee9),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: const Size(36, 28),
            side: active
                ? BorderSide(color: activeColor, width: 1)
                : BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkspaceEntryTile extends StatelessWidget {
  const _WorkspaceEntryTile(this.entry, {required this.onOpen});

  final WorkspaceEntry entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final sizeLabel = entry.isDirectory ? 'directory' : '${entry.sizeBytes} B';
    return ListTile(
      dense: true,
      leading: Icon(entry.isDirectory ? Icons.folder : Icons.description),
      title: Text(entry.name.isEmpty ? entry.path : entry.name),
      subtitle: Text(
        '${entry.path}\n$sizeLabel',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        tooltip: 'Open ${entry.name}',
        onPressed: onOpen,
        icon: const Icon(Icons.open_in_new),
      ),
    );
  }
}
