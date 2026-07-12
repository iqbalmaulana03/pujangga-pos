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
        databaseInfo['schema_version'] != AppConstants.databaseVersion) {
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

      tables[tableName] = normalizedRows;
      recordCounts[tableName] = normalizedRows.length;
    }

    if (tableCountsData is Map) {
      for (final tableName in AppBackupService.backupTables) {
        final expected = tableCountsData[tableName];
        if (expected is num && expected.toInt() != recordCounts[tableName]) {
          throw AppException(
            'backup_invalid',
            'Jumlah data tabel $tableName tidak konsisten pada file backup.',
          );
        }
      }
    }

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

    await database.reset();
    final db = await database.database();

    await db.transaction((txn) async {
      for (final tableName in AppBackupService.backupTables.reversed) {
        await txn.delete(tableName);
      }

      for (final tableName in AppBackupService.backupTables) {
        final rows = candidate.tables[tableName] ?? const [];
        for (final row in rows) {
          await txn.insert(
            tableName,
            row,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    });

    logger.info('Backup restore completed from ${candidate.filePath}');
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
