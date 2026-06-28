import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fluttmacs/src/backend/android_emacs_backend.dart';
import 'package:fluttmacs/src/backend/desktop_emacs_backend.dart';
import 'package:fluttmacs/src/backend/emacs_backend.dart';
import 'package:fluttmacs/src/backend/fake_emacs_backend.dart';
import 'package:fluttmacs/src/ui/terminal_screen.dart';
import 'package:xterm/xterm.dart';

void main() {
  testWidgets('terminal screen starts fake backend and shows output', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();

    expect(find.byType(TerminalView), findsOneWidget);
    expect(find.text('running'), findsOneWidget);
    expect(find.text('Backend fake'), findsOneWidget);

    // Show the input row to test text entry through it.
    await tester.tap(find.byTooltip('Show input row'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'abc');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('received 4 input byte'), findsOneWidget);

    await tester.tap(find.byTooltip('Capabilities'));
    await tester.pumpAndSettle();

    expect(find.text('Fake backend'), findsOneWidget);
    expect(find.text('Backend id: fake'), findsOneWidget);
    expect(find.text('5 item(s)'), findsNWidgets(2));
    expect(find.text('native GNU Emacs runtime'), findsOneWidget);
  });

  testWidgets('status strip shows backend id without opening capabilities', (
    WidgetTester tester,
  ) async {
    final backend = AndroidEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backend android-native-channel'), findsOneWidget);
    expect(find.text('Android native channel backend'), findsNothing);
  });

  testWidgets('capabilities dialog shows Android backend identity', (
    WidgetTester tester,
  ) async {
    final backend = AndroidEmacsBackend();
    addTearDown(backend.dispose);

    await _pumpCapabilitiesDialog(tester, backend);

    expect(find.text('Android native channel backend'), findsOneWidget);
    expect(find.text('Backend id: android-native-channel'), findsOneWidget);
    expect(find.text('Android backend selection'), findsOneWidget);
    expect(
        find.text('Android GNU Emacs NW PTY terminal route'), findsOneWidget);
    expect(
      find.text('Android Japanese committed UTF-8 runtime proof'),
      findsOneWidget,
    );
    expect(
      find.text('Android xterm pointer/mouse runtime proof'),
      findsOneWidget,
    );
    expect(
      find.text('Android Ctrl/Meta modifier key row for terminal input'),
      findsOneWidget,
    );
    expect(
      find.text('Android fallback diagnostic frame renderer'),
      findsNothing,
    );
    expect(
      find.text('official --with-android interactive terminal bridge'),
      findsOneWidget,
    );
    expect(
      find.text(
          'Android fallback diagnostic frame renderer is diagnostic-only'),
      findsOneWidget,
    );
  });

  testWidgets('capabilities dialog shows desktop backend identity', (
    WidgetTester tester,
  ) async {
    final linuxBackend = DesktopEmacsBackend(
      platform: DesktopEmacsPlatform.linux,
    );
    addTearDown(linuxBackend.dispose);

    await _pumpCapabilitiesDialog(tester, linuxBackend);

    expect(find.text('Linux backend placeholder'), findsOneWidget);
    expect(find.text('Backend id: linux-placeholder'), findsOneWidget);
    expect(find.text('Linux backend selection'), findsOneWidget);
    expect(find.text('Linux GNU Emacs process/PTY bridge'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    final windowsBackend = DesktopEmacsBackend(
      platform: DesktopEmacsPlatform.windows,
    );
    addTearDown(windowsBackend.dispose);

    await _pumpCapabilitiesDialog(tester, windowsBackend);

    expect(find.text('Windows backend placeholder'), findsOneWidget);
    expect(find.text('Backend id: windows-placeholder'), findsOneWidget);
    expect(find.text('Windows backend selection'), findsOneWidget);
    expect(find.text('Windows GNU Emacs process/PTY bridge'), findsOneWidget);
  });

  testWidgets('workspace dialog lists entries and shows export candidates', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();

    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('scratch.el'), findsOneWidget);
    expect(find.textContaining('/workspace/scratch.el'), findsOneWidget);

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(find.text('Workspace export candidates'), findsOneWidget);
    expect(find.text('1 export candidate(s)'), findsOneWidget);
    expect(find.text('/workspace/scratch.el'), findsOneWidget);
    expect(find.textContaining('fake export requested'), findsOneWidget);
  });

  testWidgets('workspace dialog imports files and exports refreshed entries', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalScreen(
          backend: backend,
          workspaceImportUriProvider: () async => <Uri>[
            Uri(path: '/tmp/imported.el'),
          ],
        ),
      ),
    );

    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();
    expect(find.text('scratch.el'), findsOneWidget);
    expect(find.text('imported.el'), findsNothing);

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.text('1 imported item(s)'), findsOneWidget);
    expect(find.text('imported.el'), findsOneWidget);
    expect(find.textContaining('/workspace/imported.el'), findsOneWidget);

    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(find.text('Workspace export candidates'), findsOneWidget);
    expect(find.text('2 export candidate(s)'), findsOneWidget);
    expect(find.text('/workspace/scratch.el'), findsOneWidget);
    expect(find.text('/workspace/imported.el'), findsOneWidget);
  });

  testWidgets('workspace import cancel keeps dialog entries unchanged', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalScreen(
          backend: backend,
          workspaceImportUriProvider: () async => <Uri>[],
        ),
      ),
    );

    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('scratch.el'), findsOneWidget);

    await tester.tap(find.text('Import'));
    await tester.pumpAndSettle();

    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('scratch.el'), findsOneWidget);
    expect(find.text('Import canceled'), findsOneWidget);
    expect(find.text('imported.el'), findsNothing);
    expect(backend.diagnostics.value.workspaceActions, 0);
  });

  testWidgets('workspace dialog refresh reloads backend entries', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();
    expect(find.text('scratch.el'), findsOneWidget);
    expect(find.text('external.el'), findsNothing);

    await backend.importToWorkspace(<Uri>[Uri(path: '/tmp/external.el')]);

    await tester.tap(find.text('Refresh'));
    await tester.pumpAndSettle();

    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('Workspace refreshed: 2 item(s)'), findsOneWidget);
    expect(find.text('scratch.el'), findsOneWidget);
    expect(find.text('external.el'), findsOneWidget);
    expect(find.textContaining('/workspace/external.el'), findsOneWidget);
  });

  testWidgets('workspace dialog can choose and clear /home/user root', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Choose /home/user'));
    await tester.pumpAndSettle();

    expect(
      find.text('Fake workspace root selected for next launch'),
      findsOneWidget,
    );
    expect(
      backend.diagnostics.value.message,
      'fake workspace root selection requested',
    );

    await tester.tap(find.text('Use Default'));
    await tester.pumpAndSettle();

    expect(find.text('Fake default workspace set'), findsOneWidget);
    expect(
      backend.diagnostics.value.message,
      'fake default workspace requested',
    );
  });

  testWidgets('workspace dialog opens entries through terminal input', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Workspace'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Open scratch.el'));
    await tester.pumpAndSettle();

    final expectedByteCount = <int>[
      0x18,
      0x06,
      ...utf8.encode('/workspace/scratch.el'),
      0x0d,
    ].length;
    expect(find.text('Opening scratch.el'), findsOneWidget);
    expect(backend.diagnostics.value.inputBytes, expectedByteCount);
    expect(
      backend.diagnostics.value.message,
      'received $expectedByteCount input byte(s)',
    );
  });

  testWidgets('status strip shows updated backend terminal geometry', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    expect(find.text('TTY 80x24'), findsOneWidget);

    await backend.resize(cols: 100, rows: 30);
    await tester.pump();

    expect(find.text('TTY 100x30'), findsOneWidget);
  });

  testWidgets('diagnostics dialog shows current backend counters', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show input row'));
    await tester.pumpAndSettle();
    await backend.resize(cols: 100, rows: 30);
    await tester.enterText(find.byType(TextField).last, 'diag');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Diagnostics'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(
        find.descendant(of: dialog, matching: find.text('Backend diagnostics')),
        findsOneWidget);
    expect(
      find.descendant(of: dialog, matching: find.text('Backend id')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('fake')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Lifecycle')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('running')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Geometry')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('100x30')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Input bytes')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('5')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Output bytes')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Workspace actions')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Message')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: dialog,
        matching: find.textContaining('received 5 input byte'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('hardware keyboard shortcuts invoke terminal controls', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );
    await tester.pump();

    await _sendControlShiftShortcut(tester, LogicalKeyboardKey.keyS);
    expect(find.text('running'), findsOneWidget);

    await _sendControlShiftShortcut(tester, LogicalKeyboardKey.keyX);
    expect(find.text('stopped'), findsOneWidget);

    await _sendControlShiftShortcut(tester, LogicalKeyboardKey.keyS);
    expect(find.text('running'), findsOneWidget);

    await _sendControlShiftShortcut(tester, LogicalKeyboardKey.keyR);
    expect(find.textContaining('redraw requested'), findsOneWidget);

    await _sendControlShiftShortcut(tester, LogicalKeyboardKey.keyW);
    expect(find.text('Workspace'), findsOneWidget);
    expect(find.text('scratch.el'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await _sendControlShiftShortcut(tester, LogicalKeyboardKey.keyI);
    expect(find.text('Fake backend'), findsOneWidget);
    expect(find.text('Backend id: fake'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await _sendControlShiftShortcut(tester, LogicalKeyboardKey.keyD);
    expect(find.text('Backend diagnostics'), findsOneWidget);
    expect(find.text('Lifecycle'), findsOneWidget);

    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    expect(tester.widget<Slider>(find.byType(Slider)).value, 15);
    await _sendControlShiftShortcut(tester, LogicalKeyboardKey.equal);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 16);
    await _sendControlShiftShortcut(tester, LogicalKeyboardKey.minus);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 15);
  });

  testWidgets('toolbar Stop button shuts down the backend', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();
    expect(find.text('running'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop'));
    await tester.pumpAndSettle();
    expect(find.text('stopped'), findsOneWidget);
  });

  testWidgets('Ctrl+Space forwards NUL for Emacs set-mark-command', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();

    await _sendControlShortcut(tester, LogicalKeyboardKey.space);

    expect(backend.diagnostics.value.inputBytes, 1);
    expect(
      backend.diagnostics.value.message,
      'received 1 input byte(s)',
    );
  });

  testWidgets('input row Send button forwards committed terminal text', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show input row'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'send me');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(find.textContaining('received 8 input byte'), findsOneWidget);
    expect(find.text('send me'), findsNothing);
  });

  testWidgets('input row Send button forwards Japanese text once', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show input row'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, '日本語');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    final expectedByteCount = utf8.encode('日本語\r').length;
    expect(backend.diagnostics.value.inputBytes, expectedByteCount);
    expect(
      backend.diagnostics.value.message,
      'received $expectedByteCount input byte(s)',
    );
  });

  testWidgets(
      'terminal body keeps Japanese IME composing text inline until commit', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TerminalView));
    await tester.pump(const Duration(milliseconds: 350));

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'にほ',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 0, end: 2),
      ),
    );
    await tester.pump();

    expect(backend.diagnostics.value.inputBytes, 0);

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '日本語',
        selection: TextSelection.collapsed(offset: 3),
      ),
    );
    await tester.pumpAndSettle();

    final expectedByteCount = utf8.encode('日本語').length;
    expect(backend.diagnostics.value.inputBytes, expectedByteCount);
  });

  testWidgets('terminal overlay forwards ASCII once and ignores internal clear',
      (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TerminalView));
    await tester.pump(const Duration(milliseconds: 350));

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'k',
        selection: TextSelection.collapsed(offset: 1),
      ),
    );
    await tester.pump();

    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      ),
    );
    await tester.pumpAndSettle();

    expect(backend.diagnostics.value.inputBytes, 1);
    expect(backend.diagnostics.value.message, 'received 1 input byte(s)');
  });

  testWidgets('transparent terminal overlay leaves terminal hit testing active',
      (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    final overlayIgnorePointer = tester.widget<IgnorePointer>(
      find.byKey(
        const ValueKey<String>('iosmacs-terminal-overlay-hit-test-pass'),
      ),
    );
    expect(overlayIgnorePointer.ignoring, isTrue);
  });

  testWidgets('terminal body uses normal text keyboard for IME candidates', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    final terminalView = tester.widget<TerminalView>(find.byType(TerminalView));
    expect(terminalView.keyboardType, TextInputType.text);
  });

  testWidgets('terminal body forwards all pointer input for mouse reporting', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    final terminalView = tester.widget<TerminalView>(find.byType(TerminalView));
    expect(
      terminalView.controller?.pointerInput.inputs,
      <PointerInput>{
        PointerInput.tap,
        PointerInput.scroll,
        PointerInput.drag,
        PointerInput.move,
      },
    );
  });

  testWidgets('terminal key repeat is boosted for held hardware keys', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TerminalView));
    await tester.pump(const Duration(milliseconds: 350));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final beforeRepeat = backend.diagnostics.value.inputBytes;

    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);

    expect(
      backend.diagnostics.value.inputBytes - beforeRepeat,
      9,
    );
  });

  testWidgets('input row Paste button forwards normalized paste bytes', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);
    const pastedText = 'paste 日本語';

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalScreen(
          backend: backend,
          clipboardTextProvider: () async => pastedText,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show control key row'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Paste from clipboard'));
    await tester.pump();

    final displayByteCount = utf8.encode(pastedText).length;
    final expectedInputBytes = utf8.encode(pastedText).length;
    expect(find.text('Pasted $displayByteCount byte(s)'), findsOneWidget);
    expect(backend.diagnostics.value.inputBytes, expectedInputBytes);
    expect(
      backend.diagnostics.value.message,
      'received $expectedInputBytes input byte(s)',
    );
  });

  testWidgets('Cmd+V shortcut forwards normalized paste bytes', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);
    const pastedText = 'shortcut 日本語';

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalScreen(
          backend: backend,
          clipboardTextProvider: () async => pastedText,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();

    await _sendMetaShortcut(tester, LogicalKeyboardKey.keyV);

    final displayByteCount = utf8.encode(pastedText).length;
    final expectedInputBytes = utf8.encode(pastedText).length;
    expect(find.text('Pasted $displayByteCount byte(s)'), findsOneWidget);
    expect(backend.diagnostics.value.inputBytes, expectedInputBytes);
    expect(
      backend.diagnostics.value.message,
      'received $expectedInputBytes input byte(s)',
    );
  });

  testWidgets('input row Paste button normalizes multiline clipboard text', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);
    const pastedText = "(require 'url)\n\n(message \"ok\")";

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalScreen(
          backend: backend,
          clipboardTextProvider: () async => pastedText,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show control key row'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Paste from clipboard'));
    await tester.pump();

    final displayByteCount = utf8.encode(pastedText).length;
    final expectedInputBytes =
        utf8.encode("(require 'url)\r\r(message \"ok\")").length;
    expect(find.text('Pasted $displayByteCount byte(s)'), findsOneWidget);
    expect(backend.diagnostics.value.inputBytes, expectedInputBytes);
    expect(
      backend.diagnostics.value.message,
      'received $expectedInputBytes input byte(s)',
    );
  });

  testWidgets('input row Paste button ignores an empty clipboard', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalScreen(
          backend: backend,
          clipboardTextProvider: () async => '',
        ),
      ),
    );

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show control key row'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Paste from clipboard'));
    await tester.pump();

    expect(find.text('Clipboard is empty'), findsOneWidget);
    expect(backend.diagnostics.value.inputBytes, 0);
  });

  testWidgets('input row is hidden by default; toggle shows and hides it', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );
    await tester.pump();

    // Overlay TextField is always present (for inline/Japanese input).
    expect(
      find.byKey(const ValueKey<String>('iosmacs-terminal-overlay')),
      findsOneWidget,
    );
    // InputRow's Send button is absent when InputRow is hidden.
    expect(find.byTooltip('Send'), findsNothing);
    expect(find.byTooltip('Show input row'), findsOneWidget);

    await tester.tap(find.byTooltip('Show input row'));
    await tester.pumpAndSettle();

    // After toggle: overlay + InputRow → 2 TextFields, Send visible.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.byTooltip('Hide input row'), findsOneWidget);

    await tester.tap(find.byTooltip('Hide input row'));
    await tester.pumpAndSettle();

    // Overlay remains; InputRow hidden again.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Send'), findsNothing);
  });

  testWidgets('Ctrl modifier via terminal inline input sends control byte', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );
    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show control key row'));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byTooltip(
          'Sticky Ctrl — next letter typed in terminal becomes C-letter'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TerminalView));
    await tester.pump(const Duration(milliseconds: 350));

    // Hardware key 'x' routes through Terminal.onOutput, which calls
    // _handleTerminalOutput — the Ctrl modifier converts 'x' → C-x (0x18).
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyX);
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyX);

    // C-x = 0x18 = 24, 1 byte
    expect(backend.diagnostics.value.inputBytes, 1);
  });

  testWidgets('Meta modifier via terminal inline input sends ESC prefix', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );
    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show control key row'));
    await tester.pumpAndSettle();

    // Scroll the control key row to reveal the Meta button.
    await tester.drag(
      find.byKey(const ValueKey<String>('iosmacs-control-key-row')),
      const Offset(-800, 0),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byTooltip(
          'Sticky Meta — next letter typed in terminal becomes M-letter'),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(TerminalView));
    await tester.pump(const Duration(milliseconds: 350));

    // Hardware key 'x' is intercepted by _handleTerminalKeyEvent when Meta is
    // active: sends ESC (0x1b) + lowercase letter byte.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyX);
    await tester.pumpAndSettle();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyX);

    // ESC + 'x' = 2 bytes
    expect(backend.diagnostics.value.inputBytes, 2);
  });

  testWidgets('control key row is visible with ESC and modifier buttons', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );
    await tester.pump();

    // Control key row is hidden by default; show it first.
    await tester.tap(find.byTooltip('Show control key row'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Send ESC (\\x1b)'), findsOneWidget);
    expect(find.byTooltip('Cancel (C-g = \\x07)'), findsOneWidget);
    expect(
      find.byTooltip('C-x prefix — then type next key (e.g. C-f, C-s, C-c)'),
      findsOneWidget,
    );
    expect(find.byTooltip('M-x (execute-extended-command)'), findsOneWidget);
    expect(find.byTooltip('Paste from clipboard'), findsOneWidget);
    expect(find.byTooltip('Show input bar and keyboard'), findsOneWidget);
    expect(
      find.byTooltip(
          'Sticky Ctrl — next letter typed in terminal becomes C-letter'),
      findsOneWidget,
    );
    expect(
      find.byTooltip(
          'Sticky Meta — next letter typed in terminal becomes M-letter'),
      findsOneWidget,
    );
  });

  testWidgets('ESC control key button sends escape byte to backend', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );
    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Show control key row'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Send ESC (\\x1b)'));
    await tester.pumpAndSettle();

    expect(backend.diagnostics.value.inputBytes, 1);
    expect(backend.diagnostics.value.message, 'received 1 input byte(s)');
  });

  testWidgets('KB button shows input row so keyboard can appear', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );
    await tester.pump();

    // Overlay TextField is always present for inline input.
    expect(
      find.byKey(const ValueKey<String>('iosmacs-terminal-overlay')),
      findsOneWidget,
    );
    // InputRow is hidden by default (no Send button).
    expect(find.byTooltip('Send'), findsNothing);

    // Show control key row first so KB button is accessible.
    await tester.tap(find.byTooltip('Show control key row'));
    await tester.pumpAndSettle();

    // KB button focuses the overlay so keyboard appears (inline Japanese input).
    // It does NOT show the InputRow — use the toolbar toggle for that.
    await tester.tap(find.byTooltip('Show input bar and keyboard'));
    await tester.pumpAndSettle();

    // Overlay still present, InputRow still hidden.
    expect(
      find.byKey(const ValueKey<String>('iosmacs-terminal-overlay')),
      findsOneWidget,
    );
    expect(find.byTooltip('Send'), findsNothing);
  });

  testWidgets('Ctrl modifier converts letter to Ctrl byte', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );
    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();

    // Show control key row, then use C-g instant button.
    await tester.tap(find.byTooltip('Show control key row'));
    await tester.pumpAndSettle();

    // Use the C-g instant button directly — it's visible and sends the right byte.
    await tester.tap(find.byTooltip('Cancel (C-g = \\x07)'));
    await tester.pumpAndSettle();

    // C-g = 0x07, 1 byte
    expect(backend.diagnostics.value.inputBytes, 1);
    expect(backend.diagnostics.value.message, 'received 1 input byte(s)');
  });

  testWidgets('Meta modifier sends ESC prefix before text', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );
    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();

    // Show control key row first, then use the M-x instant button.
    await tester.tap(find.byTooltip('Show control key row'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('M-x (execute-extended-command)'));
    await tester.pumpAndSettle();

    // ESC + 'x' = 2 bytes
    expect(backend.diagnostics.value.inputBytes, 2);
    expect(backend.diagnostics.value.message, 'received 2 input byte(s)');
  });

  testWidgets('toolbar avoids overflow on narrow mobile width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Start'), findsOneWidget);
    expect(find.byTooltip('Diagnostics'), findsOneWidget);

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('running'), findsOneWidget);
  });

  testWidgets('toolbar scroll reaches font size control on narrow width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(home: TerminalScreen(backend: backend)),
    );
    await tester.pump();

    final sliderFinder = find.byType(Slider);
    expect(
      tester.getTopRight(sliderFinder).dx,
      greaterThan(tester.view.physicalSize.width),
    );

    await tester.drag(
      find.byKey(const ValueKey<String>('iosmacs-toolbar-scroll')),
      const Offset(-220, 0),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getCenter(sliderFinder).dx,
      lessThan(tester.view.physicalSize.width),
    );
  });
}

Future<void> _pumpCapabilitiesDialog(
  WidgetTester tester,
  EmacsBackend backend,
) async {
  await tester.pumpWidget(
    MaterialApp(home: TerminalScreen(backend: backend)),
  );
  await tester.tap(find.byTooltip('Capabilities'));
  await tester.pumpAndSettle();
}

Future<void> _sendControlShiftShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<void> _sendMetaShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pumpAndSettle();
}

Future<void> _sendControlShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}
