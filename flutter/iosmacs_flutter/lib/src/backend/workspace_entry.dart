class WorkspaceEntry {
  const WorkspaceEntry({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.sizeBytes,
  });

  final String name;
  final String path;
  final bool isDirectory;
  final int sizeBytes;
}
