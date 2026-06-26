import 'dart:io';

Future<Uri?> createWorkspaceSmokeImportUri() async {
  final directory = await Directory.systemTemp.createTemp(
    'iosmacs-flutter-workspace-smoke-',
  );
  final file = File('${directory.path}/workspace-smoke.txt');
  await file.writeAsString('iosmacs workspace smoke import\n');
  return file.uri;
}
