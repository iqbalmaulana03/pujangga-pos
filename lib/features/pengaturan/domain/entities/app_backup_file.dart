class AppBackupFile {
  const AppBackupFile({
    required this.filePath,
    required this.fileName,
    required this.generatedAt,
    required this.recordCounts,
    this.warnings = const [],
  });

  final String filePath;
  final String fileName;
  final DateTime generatedAt;
  final Map<String, int> recordCounts;
  final List<String> warnings;

  int get totalRecords =>
      recordCounts.values.fold(0, (sum, count) => sum + count);
}
