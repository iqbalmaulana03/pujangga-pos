import '../../../../core/constants/app_constants.dart';

class AppBackupPayloadBuilder {
  const AppBackupPayloadBuilder();

  static const backupFormat = 'pujangga_pos_backup';
  static const backupFormatVersion = 1;

  Map<String, Object?> build({
    required DateTime generatedAt,
    required Map<String, List<Map<String, Object?>>> tables,
  }) {
    return {
      'format': backupFormat,
      'format_version': backupFormatVersion,
      'generated_at': generatedAt.toUtc().toIso8601String(),
      'database': {
        'name': AppConstants.databaseName,
        'schema_version': AppConstants.databaseVersion,
      },
      'table_counts': {
        for (final entry in tables.entries) entry.key: entry.value.length,
      },
      'tables': tables,
    };
  }
}
