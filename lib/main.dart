import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'src/backend/backend_factory.dart';
import 'src/backend/emacs_backend.dart';
import 'src/ui/terminal_screen.dart';

@visibleForTesting
bool defaultAutoStartBackend({
  bool isWeb = kIsWeb,
  TargetPlatform? platform,
  bool? environmentOverride,
}) {
  if (environmentOverride != null) {
    return environmentOverride;
  }
  if (const bool.hasEnvironment('IOSMACS_FLUTTER_AUTOSTART_NATIVE')) {
    return const bool.fromEnvironment('IOSMACS_FLUTTER_AUTOSTART_NATIVE');
  }
  final targetPlatform = platform ?? defaultTargetPlatform;
  return !isWeb &&
      (targetPlatform == TargetPlatform.iOS ||
          targetPlatform == TargetPlatform.macOS ||
          targetPlatform == TargetPlatform.android);
}

void main() {
  runApp(
    IOSMacsFlutterApp(
      autoStartBackend: defaultAutoStartBackend(),
      mirrorTerminalOutputToLog: const bool.fromEnvironment(
        'IOSMACS_FLUTTER_MIRROR_TERMINAL_OUTPUT',
      ),
      runWorkspaceSmoke: const bool.fromEnvironment(
        'IOSMACS_FLUTTER_WORKSPACE_SMOKE',
      ),
      runCapabilitiesSmoke: const bool.fromEnvironment(
        'IOSMACS_FLUTTER_CAPABILITIES_SMOKE',
      ),
      runInputSmoke: const bool.fromEnvironment('IOSMACS_FLUTTER_INPUT_SMOKE'),
      runAndroidFileOpsSmoke: const bool.fromEnvironment(
        'IOSMACS_FLUTTER_ANDROID_FILE_OPS_SMOKE',
      ),
      runAndroidJapaneseInputSmoke: const bool.fromEnvironment(
        'IOSMACS_FLUTTER_ANDROID_JAPANESE_INPUT_SMOKE',
      ),
      runPointerSmoke:
          const bool.fromEnvironment('IOSMACS_FLUTTER_POINTER_SMOKE'),
      runResizeSmoke:
          const bool.fromEnvironment('IOSMACS_FLUTTER_RESIZE_SMOKE'),
      runRedrawSmoke:
          const bool.fromEnvironment('IOSMACS_FLUTTER_REDRAW_SMOKE'),
      runStatusSmoke:
          const bool.fromEnvironment('IOSMACS_FLUTTER_STATUS_SMOKE'),
      runStopSmoke: const bool.fromEnvironment('IOSMACS_FLUTTER_STOP_SMOKE'),
      backendOverride: const String.fromEnvironment('IOSMACS_FLUTTER_BACKEND'),
    ),
  );
}

class IOSMacsFlutterApp extends StatefulWidget {
  const IOSMacsFlutterApp({
    this.autoStartBackend = false,
    this.mirrorTerminalOutputToLog = false,
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
    this.backendOverride = '',
    super.key,
  });

  final bool autoStartBackend;
  final bool mirrorTerminalOutputToLog;
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
  final String backendOverride;

  @override
  State<IOSMacsFlutterApp> createState() => _IOSMacsFlutterAppState();
}

class _IOSMacsFlutterAppState extends State<IOSMacsFlutterApp> {
  late final EmacsBackend _backend;

  @override
  void initState() {
    super.initState();
    _backend = createDefaultEmacsBackend(
      backendOverride: widget.backendOverride,
    );
  }

  @override
  void dispose() {
    _backend.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'iosmacs Flutter',
      theme: ThemeData.dark(useMaterial3: true),
      home: TerminalScreen(
        backend: _backend,
        autoStartBackend: widget.autoStartBackend,
        mirrorTerminalOutputToLog: widget.mirrorTerminalOutputToLog,
        mirrorTerminalInputToLog: const bool.fromEnvironment(
          'IOSMACS_FLUTTER_MIRROR_TERMINAL_INPUT',
        ),
        runWorkspaceSmoke: widget.runWorkspaceSmoke,
        runCapabilitiesSmoke: widget.runCapabilitiesSmoke,
        runInputSmoke: widget.runInputSmoke,
        runAndroidFileOpsSmoke: widget.runAndroidFileOpsSmoke,
        runAndroidJapaneseInputSmoke: widget.runAndroidJapaneseInputSmoke,
        runPointerSmoke: widget.runPointerSmoke,
        runResizeSmoke: widget.runResizeSmoke,
        runRedrawSmoke: widget.runRedrawSmoke,
        runStatusSmoke: widget.runStatusSmoke,
        runStopSmoke: widget.runStopSmoke,
      ),
    );
  }
}
