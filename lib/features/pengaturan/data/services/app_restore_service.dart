import 'dart:typed_data';

import 'package:logging/logging.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/business_logo_service.dart';
import '../../domain/entities/app_backup_restore_candidate.dart';
import 'app_backup_service.dart';
import 'backup_inspector.dart';

class AppRestoreService {
  AppRestoreService({
    required this.database,
    required this.logger,
    this.logoService,
  });

  final AppDatabase database;
  final Logger logger;
  final BusinessLogoService? logoService;

  Future<AppBackupRestoreCandidate> inspectBackupFile(
    String filePath, {
    String? password,
  }) => BackupInspector(
    database: database,
    logoService: logoService,
  ).inspectBackupFile(filePath, password: password);

  Future<void> restoreBackup(
    AppBackupRestoreCandidate candidate, {
    DatabaseWriteScope? scope,
  }) => database.runScopedWrite(
    (active) => (logoService ?? BusinessLogoService()).synchronized(
      () => _restoreBackup(candidate, active),
    ),
    requireCurrentDataset: false,
    scope: scope,
  );

  Future<void> _restoreBackup(
    AppBackupRestoreCandidate candidate,
    DatabaseWriteScope scope,
  ) async {
    logger.warning('Restoring backup from ${candidate.filePath}');

    final db = await database.database();
    final tables = {
      for (final entry in candidate.tables.entries)
        entry.key: [
          for (final row in entry.value) Map<String, Object?>.from(row),
        ],
    };
    final logos = logoService ?? BusinessLogoService();
    final bytes = candidate.businessLogoBytes;
    Uint8List? png;
    if (bytes != null) {
      if (tables['business_profile']?.length != 1) {
        throw const AppException(
          'backup_invalid',
          'Logo harus terkait satu profil usaha.',
        );
      }
      png = await logos.normalize(Uint8List.fromList(bytes), backup: true);
    }
    for (final profile
        in tables['business_profile'] ?? <Map<String, Object?>>[]) {
      profile['logo_path'] = null;
    }
    await BackupInspector(database: database).validateTables(db, tables);
    for (final tableName in AppBackupService.backupTables) {
      if (candidate.recordCounts[tableName] != tables[tableName]!.length) {
        throw AppException(
          'backup_invalid',
          'Jumlah data tabel $tableName pada kandidat restore tidak konsisten.',
        );
      }
    }

    final previous = await db.query('business_profile', columns: ['logo_path']);
    String? created;
    if (png != null) {
      created = await logos.write(png);
      tables['business_profile']!.single['logo_path'] = created;
    }
    try {
      // Keep the current database and replace its rows in one SQLite transaction.
      // Any constraint or insert failure rolls back the deletes as well, leaving
      // the active business data intact.
      await db.transaction((txn) async {
        for (final tableName in AppBackupService.backupTables.reversed) {
          await txn.delete(tableName);
        }

        for (final tableName in AppBackupService.backupTables) {
          final rows = tables[tableName] ?? const [];
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
    } catch (_) {
      await logos.deleteOwned(created);
      rethrow;
    }
    database.markDatasetReplaced(scope);
    for (final profile in previous) {
      await logos.deleteOwned(profile['logo_path'] as String?);
    }

    logger.info('Backup restore completed from ${candidate.filePath}');
  }
}
