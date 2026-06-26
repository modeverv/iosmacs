import 'package:flutter/material.dart';

import 'src/backend/backend_factory.dart';
import 'src/backend/emacs_backend.dart';
import 'src/ui/terminal_screen.dart';

void main() {
  runApp(
    const IOSMacsFlutterApp(
      autoStartBackend: bool.fromEnvironment(
        'IOSMACS_FLUTTER_AUTOSTART_NATIVE',
      ),
      mirrorTerminalOutputToLog: bool.fromEnvironment(
        'IOSMACS_FLUTTER_MIRROR_TERMINAL_OUTPUT',
      ),
      runWorkspaceSmoke: bool.fromEnvironment(
        'IOSMACS_FLUTTER_WORKSPACE_SMOKE',
      ),
      runCapabilitiesSmoke: bool.fromEnvironment(
        'IOSMACS_FLUTTER_CAPABILITIES_SMOKE',
      ),
      runInputSmoke: bool.fromEnvironment('IOSMACS_FLUTTER_INPUT_SMOKE'),
      runResizeSmoke: bool.fromEnvironment('IOSMACS_FLUTTER_RESIZE_SMOKE'),
      runRedrawSmoke: bool.fromEnvironment('IOSMACS_FLUTTER_REDRAW_SMOKE'),
      runStatusSmoke: bool.fromEnvironment('IOSMACS_FLUTTER_STATUS_SMOKE'),
      runStopSmoke: bool.fromEnvironment('IOSMACS_FLUTTER_STOP_SMOKE'),
      backendOverride: String.fromEnvironment('IOSMACS_FLUTTER_BACKEND'),
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
        runWorkspaceSmoke: widget.runWorkspaceSmoke,
        runCapabilitiesSmoke: widget.runCapabilitiesSmoke,
        runInputSmoke: widget.runInputSmoke,
        runResizeSmoke: widget.runResizeSmoke,
        runRedrawSmoke: widget.runRedrawSmoke,
        runStatusSmoke: widget.runStatusSmoke,
        runStopSmoke: widget.runStopSmoke,
      ),
    );
  }
}
