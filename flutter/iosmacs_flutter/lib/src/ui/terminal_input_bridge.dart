import 'dart:convert';

import '../backend/emacs_backend.dart';

class TerminalInputBridge {
  TerminalInputBridge(
    this.backend, {
    DateTime Function()? now,
    this.duplicateTerminalTextWindow = const Duration(milliseconds: 750),
  }) : _now = now ?? DateTime.now;

  final EmacsBackend backend;
  final Duration duplicateTerminalTextWindow;
  final DateTime Function() _now;

  String? _lastTerminalText;
  DateTime? _lastTerminalTextAt;

  Future<void> sendTerminalOutput(String data) {
    if (data.isEmpty) {
      return Future<void>.value();
    }
    if (_isDuplicateTerminalText(data)) {
      return Future<void>.value();
    }
    return backend.sendBytes(utf8.encode(data));
  }

  Future<void> submitCommittedText(String text) {
    if (text.isEmpty) {
      return Future<void>.value();
    }
    return backend.sendBytes(utf8.encode('${_normalizeTextInput(text)}\r'));
  }

  Future<void> pasteText(String text) {
    if (text.isEmpty) {
      return Future<void>.value();
    }
    return backend.sendBytes(utf8.encode(_normalizeTextInput(text)));
  }

  String _normalizeTextInput(String text) {
    return text.replaceAll('\r\n', '\n').replaceAll('\r', '\n').replaceAll(
          '\n',
          '\r',
        );
  }

  bool _isDuplicateTerminalText(String data) {
    if (!_isPrintableNonAsciiText(data)) {
      _lastTerminalText = null;
      _lastTerminalTextAt = null;
      return false;
    }

    final now = _now();
    final lastText = _lastTerminalText;
    final lastAt = _lastTerminalTextAt;
    _lastTerminalText = data;
    _lastTerminalTextAt = now;

    if (lastText != data || lastAt == null) {
      return false;
    }

    return now.difference(lastAt) <= duplicateTerminalTextWindow;
  }

  bool _isPrintableNonAsciiText(String data) {
    var hasNonAscii = false;
    for (final codeUnit in data.codeUnits) {
      if (codeUnit < 0x20 || codeUnit == 0x7f) {
        return false;
      }
      if (codeUnit > 0x7f) {
        hasNonAscii = true;
      }
    }
    return hasNonAscii;
  }
}
