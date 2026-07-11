class AppBackupFile {
  const AppBackupFile({
    required this.filePath,
    required this.fileName,
    required this.generatedAt,
    required this.recordCounts,
  });

  final String filePath;
  final String fileName;
  final DateTime generatedAt;
  final Map<String, int> recordCounts;

  int get totalRecords =>
      recordCounts.values.fold(0, (sum, count) => sum + count);
}
