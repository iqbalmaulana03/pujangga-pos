import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/app_backup_restore_candidate.dart';
import 'app_backup_payload_builder.dart';
import 'app_backup_service.dart';

class AppRestoreService {
  AppRestoreService({required this.database, required this.logger});

  final AppDatabase database;
  final Logger logger;

  Future<AppBackupRestoreCandidate> inspectBackupFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const AppException(
        'backup_not_found',
        'File backup tidak ditemukan di perangkat.',
      );
    }

    final raw = await file.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const AppException(
        'backup_invalid',
        'Format file backup tidak valid.',
      );
    }

    final format = decoded['format'];
    final formatVersion = decoded['format_version'];
    final databaseInfo = decoded['database'];
    final schemaVersion = databaseInfo is Map<String, dynamic>
        ? databaseInfo['schema_version']
        : null;
    final backupSchemaVersion = schemaVersion is num
        ? schemaVersion.toInt()
        : null;
    final tablesData = decoded['tables'];
    final tableCountsData = decoded['table_counts'];
    final generatedAtRaw = decoded['generated_at'];

    if (format != AppBackupPayloadBuilder.backupFormat ||
        formatVersion != AppBackupPayloadBuilder.backupFormatVersion) {
      throw const AppException(
        'backup_incompatible',
        'File backup tidak kompatibel dengan aplikasi ini.',
      );
    }

    if (databaseInfo is! Map<String, dynamic> ||
        databaseInfo['name'] != AppConstants.databaseName ||
        backupSchemaVersion == null ||
        backupSchemaVersion < AppConstants.databaseVersion - 1 ||
        backupSchemaVersion > AppConstants.databaseVersion) {
      throw const AppException(
        'backup_incompatible',
        'Schema backup tidak kompatibel dengan versi aplikasi saat ini.',
      );
    }

    if (tablesData is! Map<String, dynamic>) {
      throw const AppException(
        'backup_invalid',
        'Data tabel pada file backup tidak valid.',
      );
    }

    final generatedAt = DateTime.tryParse(generatedAtRaw?.toString() ?? '');
    if (generatedAt == null) {
      throw const AppException(
        'backup_invalid',
        'Waktu pembuatan backup tidak valid.',
      );
    }

    final recordCounts = <String, int>{};
    final tables = <String, List<Map<String, Object?>>>{};

    for (final tableName in AppBackupService.backupTables) {
      final tableRows = tablesData[tableName];
      if (tableRows is! List) {
        throw AppException(
          'backup_invalid',
          'Tabel $tableName tidak ditemukan atau tidak valid pada file backup.',
        );
      }

      final normalizedRows = <Map<String, Object?>>[];
      for (final row in tableRows) {
        if (row is! Map) {
          throw AppException(
            'backup_invalid',
            'Data baris pada tabel $tableName tidak valid.',
          );
        }

        normalizedRows.add(
          row.map(
            (key, value) => MapEntry(key.toString(), _normalizeValue(value)),
          ),
        );
      }

      if (
        tableName == 'app_settings' &&
        backupSchemaVersion < AppConstants.databaseVersion
      ) {
        for (final row in normalizedRows) {
          row.putIfAbsent('auto_print_receipt', () => 1);
        }
      }

      tables[tableName] = normalizedRows;
      recordCounts[tableName] = normalizedRows.length;
    }

    if (tableCountsData is! Map) {
      throw const AppException(
        'backup_invalid',
        'Jumlah data tabel pada file backup tidak valid.',
      );
    }
    for (final tableName in AppBackupService.backupTables) {
      final expected = tableCountsData[tableName];
      if (expected is! num || expected.toInt() != recordCounts[tableName]) {
        throw AppException(
          'backup_invalid',
          'Jumlah data tabel $tableName tidak konsisten pada file backup.',
        );
      }
    }

    await _validateTables(await database.database(), tables);

    return AppBackupRestoreCandidate(
      filePath: file.path,
      fileName: file.uri.pathSegments.isNotEmpty
          ? file.uri.pathSegments.last
          : file.path,
      generatedAt: generatedAt.toLocal(),
      schemaVersion: AppConstants.databaseVersion,
      recordCounts: recordCounts,
      tables: tables,
    );
  }

  Future<void> restoreBackup(AppBackupRestoreCandidate candidate) async {
    logger.warning('Restoring backup from ${candidate.filePath}');

    final db = await database.database();
    await _validateTables(db, candidate.tables);
    for (final tableName in AppBackupService.backupTables) {
      if (candidate.recordCounts[tableName] !=
          candidate.tables[tableName]!.length) {
        throw AppException(
          'backup_invalid',
          'Jumlah data tabel $tableName pada kandidat restore tidak konsisten.',
        );
      }
    }

    // Keep the current database and replace its rows in one SQLite transaction.
    // Any constraint or insert failure rolls back the deletes as well, leaving
    // the active business data intact.
    await db.transaction((txn) async {
      for (final tableName in AppBackupService.backupTables.reversed) {
        await txn.delete(tableName);
      }

      for (final tableName in AppBackupService.backupTables) {
        final rows = candidate.tables[tableName] ?? const [];
        for (final row in rows) {
          await txn.insert(tableName, row);
        }
      }

      final foreignKeyErrors = await txn.rawQuery('PRAGMA foreign_key_check');
      if (foreignKeyErrors.isNotEmpty) {
        throw const AppException(
          'backup_invalid',
          'Relasi data pada file backup tidak valid.',
        );
      }
    });

    logger.info('Backup restore completed from ${candidate.filePath}');
  }

  Future<void> _validateTables(
    DatabaseExecutor db,
    Map<String, List<Map<String, Object?>>> tables,
  ) async {
    if (tables.length != AppBackupService.backupTables.length ||
        AppBackupService.backupTables.any(
          (name) => !tables.containsKey(name),
        )) {
      throw const AppException(
        'backup_invalid',
        'Daftar tabel pada file backup tidak lengkap.',
      );
    }

    for (final tableName in AppBackupService.backupTables) {
      final definitions = await db.rawQuery('PRAGMA table_info($tableName)');
      if (definitions.isEmpty) {
        throw AppException(
          'backup_invalid',
          'Skema tabel $tableName tidak tersedia.',
        );
      }
      final columns = <String, Map<String, Object?>>{
        for (final definition in definitions)
          definition['name'] as String: definition,
      };

      for (final row in tables[tableName]!) {
        if (row.length != columns.length ||
            row.keys.any((key) => !columns.containsKey(key))) {
          throw AppException(
            'backup_invalid',
            'Kolom pada data tabel $tableName tidak sesuai skema.',
          );
        }

        for (final entry in row.entries) {
          final definition = columns[entry.key]!;
          final value = entry.value;
          final isRequired =
              (definition['notnull'] as num).toInt() == 1 ||
              (definition['pk'] as num).toInt() > 0;
          if (value == null) {
            if (isRequired) {
              throw AppException(
                'backup_invalid',
                'Kolom wajib ${entry.key} pada tabel $tableName kosong.',
              );
            }
            continue;
          }

          final declaredType = (definition['type'] as String).toUpperCase();
          final validType = _matchesSqliteType(declaredType, value);
          if (!validType) {
            throw AppException(
              'backup_invalid',
              'Tipe nilai kolom ${entry.key} pada tabel $tableName tidak valid.',
            );
          }
        }
      }
    }
  }

  bool _matchesSqliteType(String declaredType, Object value) {
    if (value is num && !value.isFinite) return false;
    if (declaredType.contains('INT')) {
      return value is num && value == value.toInt();
    }
    if (declaredType.contains('REAL') ||
        declaredType.contains('FLOA') ||
        declaredType.contains('DOUB')) {
      return value is num;
    }
    if (declaredType.contains('CHAR') ||
        declaredType.contains('CLOB') ||
        declaredType.contains('TEXT')) {
      return value is String;
    }
    return value is num || value is String || value is List<int>;
  }

  Object? _normalizeValue(Object? value) {
    if (value is List) {
      return value.map(_normalizeValue).toList(growable: false);
    }
    if (value is Map) {
      return value.map(
        (key, nestedValue) =>
            MapEntry(key.toString(), _normalizeValue(nestedValue)),
      );
    }
    return value;
  }
}
