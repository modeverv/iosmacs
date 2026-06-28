class BackendDiagnostics {
  const BackendDiagnostics({
    required this.message,
    required this.cols,
    required this.rows,
    required this.inputBytes,
    required this.outputBytes,
    required this.workspaceActions,
  });

  const BackendDiagnostics.initial()
      : message = 'fake backend ready',
        cols = 80,
        rows = 24,
        inputBytes = 0,
        outputBytes = 0,
        workspaceActions = 0;

  final String message;
  final int cols;
  final int rows;
  final int inputBytes;
  final int outputBytes;
  final int workspaceActions;

  String get summary =>
      '$message; ${cols}x$rows; in:$inputBytes out:$outputBytes ws:$workspaceActions';

  BackendDiagnostics copyWith({
    String? message,
    int? cols,
    int? rows,
    int? inputBytes,
    int? outputBytes,
    int? workspaceActions,
  }) {
    return BackendDiagnostics(
      message: message ?? this.message,
      cols: cols ?? this.cols,
      rows: rows ?? this.rows,
      inputBytes: inputBytes ?? this.inputBytes,
      outputBytes: outputBytes ?? this.outputBytes,
      workspaceActions: workspaceActions ?? this.workspaceActions,
    );
  }
}
