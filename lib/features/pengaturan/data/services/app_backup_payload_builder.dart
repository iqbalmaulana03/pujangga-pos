import '../../../../core/constants/app_constants.dart';

import 'dart:convert';
import 'dart:typed_data';

class AppBackupPayloadBuilder {
  const AppBackupPayloadBuilder();

  static const backupFormat = 'pujangga_pos_backup';
  static const backupFormatVersion = 3;

  Map<String, Object?> build({
    required DateTime generatedAt,
    required Map<String, List<Map<String, Object?>>> tables,
    Uint8List? businessLogoBytes,
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
      'assets': {
        'business_logo': businessLogoBytes == null
            ? null
            : {
                'mime_type': 'image/png',
                'data_base64': base64Encode(businessLogoBytes),
              },
      },
      'tables': {
        for (final entry in tables.entries)
          entry.key: [
            for (final row in entry.value)
              {
                ...row,
                if (entry.key == 'business_profile' &&
                    row.containsKey('logo_path'))
                  'logo_path': null,
              },
          ],
      },
    };
  }
}
