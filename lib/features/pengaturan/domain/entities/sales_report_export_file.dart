class SalesReportExportFile {
  const SalesReportExportFile({
    required this.filePath,
    required this.fileName,
    required this.generatedAt,
    required this.transactionCount,
  });

  final String filePath;
  final String fileName;
  final DateTime generatedAt;
  final int transactionCount;
}
