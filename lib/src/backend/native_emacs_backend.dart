import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'backend_capabilities.dart';
import 'backend_diagnostics.dart';
import 'emacs_backend.dart';
import 'workspace_entry.dart';

class NativeEmacsBackend implements EmacsBackend {
  NativeEmacsBackend({
    MethodChannel? channel,
    String initialDiagnosticsMessage = 'native backend channel ready',
  })  : _channel = channel ?? const MethodChannel(channelName),
        _diagnostics = ValueNotifier<BackendDiagnostics>(
          BackendDiagnostics(
            message: initialDiagnosticsMessage,
            cols: 80,
            rows: 24,
            inputBytes: 0,
            outputBytes: 0,
            workspaceActions: 0,
          ),
        );

  static const String channelName = 'iosmacs/native_emacs';
  static const Duration _outputPollInterval = Duration(milliseconds: 16);
  static const int _maxDrainPasses = 64;
  static const bool _traceIo = bool.fromEnvironment('IOSMACS_FLUTTER_TRACE_IO');
  static const bool _workspaceSmoke =
      bool.fromEnvironment('IOSMACS_FLUTTER_WORKSPACE_SMOKE');

  final MethodChannel _channel;
  final StreamController<List<int>> _outputController =
      StreamController<List<int>>.broadcast();
  final ValueNotifier<String> _lifecycleState = ValueNotifier<String>('idle');
  final ValueNotifier<BackendDiagnostics> _diagnostics;
  Timer? _pollTimer;
  bool _isDrainingOutput = false;
  bool _drainAgain = false;

  @override
  BackendCapabilities get capabilities => const BackendCapabilities(
        id: 'platform-native-channel',
        displayName: 'Platform native channel backend',
        supportedFeatures: <String>[
          'Flutter MethodChannel transport',
          'iOS backend factory selection',
          'macOS backend factory selection',
          'Linux backend factory selection',
          'Linux child-process GNU Emacs session',
          'Linux direct PTY resize/ioctl bridge',
          'iOS simulator GNU Emacs core startup',
          'macOS native channel diagnostics',
          'macOS child-process GNU Emacs session',
          'bundled macOS GNU Emacs runtime packaging',
          'macOS direct PTY resize/ioctl bridge',
          'terminal byte stream from native Emacs',
          'terminal input and resize channel calls',
          'app-container workspace list/import/export',
          'iOS security-scoped /home/user folder selection',
          'iOS URLSession network bridge for Emacs url.el',
          'macOS Application Support workspace list/import/export',
          'diagnostic native channel fallback',
          'explicit unsupported diagnostics',
        ],
        unsupportedFeatures: <String>[
          'physical-device GNU Emacs core startup',
          'command-loop insertion marker proof',
        ],
      );

  @override
  Stream<List<int>> get outputStream => _outputController.stream;

  @override
  ValueListenable<String> get lifecycleState => _lifecycleState;

  @override
  ValueListenable<BackendDiagnostics> get diagnostics => _diagnostics;

  @override
  Future<void> start() async {
    _lifecycleState.value = 'starting';
    final ok = await _invokeNative('start');
    if (ok != null) {
      _lifecycleState.value = 'running';
      _applyNativeStatus(ok, fallbackMessage: 'native backend started');
      _startOutputPolling();
      await _drainOutput();
    }
  }

  @override
  Future<void> stop() async {
    final ok = await _invokeNative('stop');
    if (ok != null) {
      _lifecycleState.value = 'stopped';
      _applyNativeStatus(ok, fallbackMessage: 'native backend stopped');
      _stopOutputPolling();
      await _drainOutput();
    }
  }

  @override
  Future<void> resetOrRedraw() async {
    final ok = await _invokeNative('redraw');
    if (ok != null) {
      _applyNativeStatus(ok, fallbackMessage: 'native redraw reported');
      await _drainOutput();
    }
  }

  @override
  Future<void> sendBytes(List<int> bytes) async {
    final startedAt = DateTime.now();
    if (_traceIo) {
      debugPrint(
        'iosmacs-native-sendBytes: start bytes=${bytes.length} '
        'at=${startedAt.toIso8601String()}',
      );
    }
    final ok = await _invokeNative(
      'sendBytes',
      <String, Object>{'bytes': Uint8List.fromList(bytes)},
    );
    if (ok != null) {
      final elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
      if (_traceIo) {
        debugPrint(
          'iosmacs-native-sendBytes: accepted bytes=${bytes.length} '
          'elapsedMs=$elapsedMs',
        );
      }
      _applyNativeStatus(ok);
      _diagnostics.value = _diagnostics.value.copyWith(
        message: 'sent input bytes to native backend',
        inputBytes: _diagnostics.value.inputBytes + bytes.length,
      );
      unawaited(_drainOutput());
    }
  }

  @override
  Future<bool> pasteSystemClipboard() async {
    if (_traceIo) {
      debugPrint('iosmacs-native-pasteSystemClipboard: start');
    }
    final result = await _invokeNative<Map<Object?, Object?>>(
      'pasteSystemClipboard',
    );
    if (result == null) {
      if (_traceIo) {
        debugPrint('iosmacs-native-pasteSystemClipboard: unavailable');
      }
      return false;
    }
    final accepted = result['accepted'] as bool? ?? false;
    final byteCount = result['byteCount'] as int? ?? 0;
    if (_traceIo) {
      debugPrint(
        'iosmacs-native-pasteSystemClipboard: accepted=$accepted '
        'byteCount=$byteCount',
      );
    }
    if (accepted) {
      _diagnostics.value = _diagnostics.value.copyWith(
        message: 'pasted system clipboard through native text input',
        inputBytes: _diagnostics.value.inputBytes + byteCount,
      );
      unawaited(_drainOutput());
    }
    return accepted;
  }

  @override
  Future<void> resize({required int cols, required int rows}) async {
    final ok = await _invokeNative(
      'resize',
      <String, Object>{'cols': cols, 'rows': rows},
    );
    _diagnostics.value = _diagnostics.value.copyWith(cols: cols, rows: rows);
    if (ok != null) {
      _applyNativeStatus(ok, fallbackMessage: 'native resize reported');
      await _drainOutput();
    }
  }

  @override
  Future<List<WorkspaceEntry>> listWorkspace() async {
    final result = await _invokeNative<List<Object?>>('listWorkspace');
    if (result != null) {
      final entries = result
          .whereType<Map<Object?, Object?>>()
          .map(_workspaceEntryFromMap)
          .toList(growable: false);
      _diagnostics.value = _diagnostics.value.copyWith(
        message: 'native workspace listed ${entries.length} item(s)',
        workspaceActions: _diagnostics.value.workspaceActions + 1,
      );
      return entries;
    }
    return const <WorkspaceEntry>[];
  }

  @override
  Future<int> importToWorkspace(List<Uri> uris) async {
    final importedCount = await _invokeNative<int>(
      'importWorkspace',
      <String, Object>{'uris': uris.map((Uri uri) => uri.toString()).toList()},
    );
    if (importedCount != null) {
      _diagnostics.value = _diagnostics.value.copyWith(
        message: 'native workspace imported $importedCount item(s)',
        workspaceActions: _diagnostics.value.workspaceActions + 1,
      );
      return importedCount;
    }
    return 0;
  }

  @override
  Future<List<Uri>> exportWorkspaceSelection() async {
    final result = await _invokeNative<List<Object?>>(
      'exportWorkspace',
      <String, Object>{'nonInteractive': _workspaceSmoke},
    );
    if (result != null) {
      final uris =
          result.whereType<String>().map(Uri.parse).toList(growable: false);
      _diagnostics.value = _diagnostics.value.copyWith(
        message: 'native workspace exported ${uris.length} item(s)',
        workspaceActions: _diagnostics.value.workspaceActions + 1,
      );
      return uris;
    }
    return const <Uri>[];
  }

  @override
  Future<String> selectWorkspaceRoot() async {
    final result = await _invokeNative<Map<Object?, Object?>>(
      'selectWorkspaceRoot',
    );
    if (result != null) {
      final message =
          result['message'] as String? ?? 'native workspace root selected';
      _diagnostics.value = _diagnostics.value.copyWith(
        message: message,
        workspaceActions: _diagnostics.value.workspaceActions + 1,
      );
      return message;
    }
    return 'Workspace selection unavailable';
  }

  @override
  Future<String> clearWorkspaceRootSelection() async {
    final result = await _invokeNative<Map<Object?, Object?>>(
      'clearWorkspaceRoot',
    );
    if (result != null) {
      final message =
          result['message'] as String? ?? 'native workspace root cleared';
      _diagnostics.value = _diagnostics.value.copyWith(
        message: message,
        workspaceActions: _diagnostics.value.workspaceActions + 1,
      );
      return message;
    }
    return 'Default workspace selection unavailable';
  }

  @override
  Future<void> showKeyboard() async {
    await _invokeNative<bool>('showKeyboard');
  }

  @override
  void dispose() {
    _stopOutputPolling();
    _lifecycleState.dispose();
    _diagnostics.dispose();
    unawaited(_outputController.close());
  }

  void _startOutputPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_outputPollInterval, (_) {
      unawaited(_drainOutput());
    });
  }

  void _stopOutputPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _drainOutput() async {
    if (_isDrainingOutput) {
      _drainAgain = true;
      return;
    }
    _isDrainingOutput = true;
    var reachedPassLimit = false;
    try {
      final chunks = <Uint8List>[];
      var totalBytes = 0;
      for (var pass = 0; pass < _maxDrainPasses; pass++) {
        final bytes = await _channel.invokeMethod<Uint8List>('drainOutput');
        if (bytes == null || bytes.isEmpty) {
          break;
        }
        if (totalBytes == 0 && _traceIo) {
          debugPrint(
            'iosmacs-native-drainOutput: first bytes=${bytes.length} '
            'pass=$pass at=${DateTime.now().toIso8601String()}',
          );
        }
        chunks.add(bytes);
        totalBytes += bytes.length;
        reachedPassLimit = pass == _maxDrainPasses - 1;
      }
      if (totalBytes == 0) {
        return;
      }
      if (_traceIo) {
        debugPrint(
          'iosmacs-native-drainOutput: chunks=${chunks.length} '
          'bytes=$totalBytes at=${DateTime.now().toIso8601String()}',
        );
      }
      _outputController.add(_combineChunks(chunks, totalBytes));
      _diagnostics.value = _diagnostics.value.copyWith(
        outputBytes: _diagnostics.value.outputBytes + totalBytes,
      );
    } on MissingPluginException {
      _recordUnsupported('drainOutput missing native channel handler');
    } on PlatformException catch (error) {
      _recordUnsupported('drainOutput ${error.message ?? error.code}');
    } finally {
      _isDrainingOutput = false;
      if (_drainAgain || reachedPassLimit) {
        _drainAgain = false;
        scheduleMicrotask(() => unawaited(_drainOutput()));
      }
    }
  }

  Uint8List _combineChunks(List<Uint8List> chunks, int totalBytes) {
    if (chunks.length == 1) {
      return chunks.single;
    }
    final combined = Uint8List(totalBytes);
    var offset = 0;
    for (final chunk in chunks) {
      combined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    return combined;
  }

  Future<T?> _invokeNative<T extends Object>(String method,
      [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      _recordUnsupported('$method missing native channel handler');
    } on PlatformException catch (error) {
      _recordUnsupported('$method ${error.message ?? error.code}');
    }
    return null;
  }

  WorkspaceEntry _workspaceEntryFromMap(Map<Object?, Object?> map) {
    return WorkspaceEntry(
      name: map['name'] as String? ?? '',
      path: map['path'] as String? ?? '',
      isDirectory: map['isDirectory'] as bool? ?? false,
      sizeBytes: map['sizeBytes'] as int? ?? 0,
    );
  }

  void _applyNativeStatus(Object status, {String? fallbackMessage}) {
    if (status is! Map<Object?, Object?>) {
      if (fallbackMessage != null) {
        _setMessage(fallbackMessage);
      }
      return;
    }

    final nativeLifecycleState = status['lifecycleState'] as String?;
    final cols = status['cols'] as int?;
    final rows = status['rows'] as int?;
    _diagnostics.value = _diagnostics.value.copyWith(
      message: nativeLifecycleState ?? fallbackMessage,
      cols: cols ?? _diagnostics.value.cols,
      rows: rows ?? _diagnostics.value.rows,
    );
  }

  void _setMessage(String message) {
    _diagnostics.value = _diagnostics.value.copyWith(message: message);
  }

  void _recordUnsupported(String detail) {
    final message = 'native backend unsupported: $detail';
    _lifecycleState.value = 'unsupported';
    _diagnostics.value = _diagnostics.value.copyWith(message: message);
    _outputController.add(utf8.encode('$message\r\n'));
  }
}
