import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iosmacs_flutter/src/backend/fake_emacs_backend.dart';
import 'package:iosmacs_flutter/src/ui/terminal_screen.dart';
import 'package:xterm/xterm.dart';

import 'package:iosmacs_flutter/main.dart';

void main() {
  test('native platforms autostart backend by default', () {
    expect(
      defaultAutoStartBackend(platform: TargetPlatform.iOS, isWeb: false),
      isTrue,
    );
    expect(
      defaultAutoStartBackend(platform: TargetPlatform.macOS, isWeb: false),
      isTrue,
    );
  });

  test('web and placeholder platforms do not autostart by default', () {
    expect(
      defaultAutoStartBackend(platform: TargetPlatform.iOS, isWeb: true),
      isFalse,
    );
    expect(
      defaultAutoStartBackend(platform: TargetPlatform.android, isWeb: false),
      isFalse,
    );
    expect(
      defaultAutoStartBackend(platform: TargetPlatform.linux, isWeb: false),
      isFalse,
    );
    expect(
      defaultAutoStartBackend(platform: TargetPlatform.windows, isWeb: false),
      isFalse,
    );
  });

  test('autostart environment override wins over platform default', () {
    expect(
      defaultAutoStartBackend(
        platform: TargetPlatform.iOS,
        isWeb: false,
        environmentOverride: false,
      ),
      isFalse,
    );
    expect(
      defaultAutoStartBackend(
        platform: TargetPlatform.android,
        isWeb: false,
        environmentOverride: true,
      ),
      isTrue,
    );
  });

  testWidgets('app starts on the terminal screen', (WidgetTester tester) async {
    await tester.pumpWidget(const IOSMacsFlutterApp());
    await tester.pump();

    expect(find.text('idle'), findsOneWidget);
    expect(find.byType(TerminalView), findsOneWidget);
    expect(find.text('Backend android-placeholder'), findsOneWidget);
    expect(find.textContaining('android backend pending'), findsOneWidget);

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();

    expect(find.byType(TerminalView), findsOneWidget);
    expect(find.text('unsupported'), findsOneWidget);
    expect(find.text('Backend android-placeholder'), findsOneWidget);
  });

  testWidgets('app can force fake backend for runtime smoke builds', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const IOSMacsFlutterApp(backendOverride: 'fake'),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('Capabilities'));
    await tester.pumpAndSettle();

    expect(find.text('Fake backend'), findsOneWidget);
    expect(find.text('Backend id: fake'), findsOneWidget);
  });

  testWidgets('app keeps controls available on narrow mobile width', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const IOSMacsFlutterApp(backendOverride: 'fake'),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(TerminalView), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byTooltip('Start'), findsOneWidget);
    expect(find.byTooltip('Send'), findsOneWidget);

    await tester.tap(find.byTooltip('Start'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('running'), findsOneWidget);
  });

  testWidgets('terminal screen can run startup smokes deterministically', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalScreen(
          backend: backend,
          autoStartBackend: true,
          mirrorTerminalOutputToLog: true,
          runCapabilitiesSmoke: true,
          runInputSmoke: true,
          runResizeSmoke: true,
          runRedrawSmoke: true,
          runStatusSmoke: true,
          runStopSmoke: true,
          runWorkspaceSmoke: true,
          workspaceSmokeImportUriProvider: () async {
            return Uri.file('/tmp/iosmacs-workspace-smoke.txt');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.byType(TerminalView), findsOneWidget);
    expect(find.text('stopped'), findsOneWidget);
    expect(find.text('Backend fake'), findsOneWidget);
    expect(backend.diagnostics.value.inputBytes, greaterThan(0));
    expect(backend.diagnostics.value.inputBytes, greaterThan(30));
    expect(backend.diagnostics.value.cols, greaterThan(0));
    expect(backend.diagnostics.value.rows, greaterThan(0));
    expect(backend.lifecycleState.value, 'stopped');
    expect(backend.diagnostics.value.message, 'fake backend stopped');
    expect(backend.diagnostics.value.workspaceActions, 2);
  });

  testWidgets('terminal screen can run status smoke deterministically', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalScreen(
          backend: backend,
          autoStartBackend: true,
          mirrorTerminalOutputToLog: true,
          runStatusSmoke: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TerminalView), findsOneWidget);
    expect(find.text('Backend fake'), findsOneWidget);
    expect(backend.lifecycleState.value, 'running');
    expect(backend.diagnostics.value.cols, greaterThan(0));
    expect(backend.diagnostics.value.rows, greaterThan(0));
  });

  testWidgets('terminal screen can run stop smoke deterministically', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalScreen(
          backend: backend,
          autoStartBackend: true,
          mirrorTerminalOutputToLog: true,
          runStopSmoke: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TerminalView), findsOneWidget);
    expect(find.text('stopped'), findsOneWidget);
    expect(backend.lifecycleState.value, 'stopped');
    expect(backend.diagnostics.value.message, 'fake backend stopped');
  });

  testWidgets('terminal screen can run redraw smoke deterministically', (
    WidgetTester tester,
  ) async {
    final backend = FakeEmacsBackend();
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: TerminalScreen(
          backend: backend,
          autoStartBackend: true,
          mirrorTerminalOutputToLog: true,
          runRedrawSmoke: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TerminalView), findsOneWidget);
    expect(find.text('running'), findsOneWidget);
    expect(backend.diagnostics.value.message, 'redraw requested');
  });
}
