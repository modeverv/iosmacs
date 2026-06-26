class BackendCapabilities {
  const BackendCapabilities({
    required this.id,
    required this.displayName,
    required this.supportedFeatures,
    required this.unsupportedFeatures,
  });

  final String id;
  final String displayName;
  final List<String> supportedFeatures;
  final List<String> unsupportedFeatures;
}
