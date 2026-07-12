class AppBackupRestoreCandidate {
  const AppBackupRestoreCandidate({
    required this.filePath,
    required this.fileName,
    required this.generatedAt,
    required this.schemaVersion,
    required this.recordCounts,
    required this.tables,
  });

  final String filePath;
  final String fileName;
  final DateTime generatedAt;
  final int schemaVersion;
  final Map<String, int> recordCounts;
  final Map<String, List<Map<String, Object?>>> tables;

  int get totalRecords =>
      recordCounts.values.fold(0, (sum, count) => sum + count);

  bool get hasBusinessProfile => (recordCounts['business_profile'] ?? 0) > 0;
}
