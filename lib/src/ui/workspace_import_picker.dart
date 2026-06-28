import 'package:file_selector/file_selector.dart';

typedef WorkspaceImportUriProvider = Future<List<Uri>> Function();

Future<List<Uri>> pickWorkspaceImportUris() async {
  final files = await openFiles(confirmButtonText: 'Import');
  return files
      .where((XFile file) => file.path.isNotEmpty)
      .map((XFile file) => Uri.file(file.path))
      .toList(growable: false);
}
