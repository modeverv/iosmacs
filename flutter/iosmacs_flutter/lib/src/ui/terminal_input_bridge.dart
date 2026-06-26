import 'dart:convert';

import '../backend/emacs_backend.dart';

class TerminalInputBridge {
  const TerminalInputBridge(this.backend);

  final EmacsBackend backend;

  Future<void> sendTerminalOutput(String data) {
    if (data.isEmpty) {
      return Future<void>.value();
    }
    return backend.sendBytes(utf8.encode(data));
  }

  Future<void> submitCommittedText(String text) {
    if (text.isEmpty) {
      return Future<void>.value();
    }
    return backend.sendBytes(utf8.encode('$text\r'));
  }

  Future<void> pasteText(String text) {
    if (text.isEmpty) {
      return Future<void>.value();
    }
    return backend.sendBytes(utf8.encode(text));
  }
}
