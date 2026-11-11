import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/app_backup_restore_candidate.dart';
import 'app_backup_service.dart';
import 'app_reset_service.dart';
import 'app_restore_service.dart';

/// Coordinates destructive operations. Passwords remain in memory only; every
/// recovery file uses the same authenticated encryption as a normal export.
class AppRecoveryService {
  AppRecoveryService({
    required this.backup,
    required this.restore,
    required this.reset,
    this.directoryProvider,
    this.exportDirectoryProvider,
    this.temporaryDirectoryProvider,
  });

  final AppBackupService backup;
  final AppRestoreService restore;
  final AppResetService reset;
  final BackupDirectoryProvider? directoryProvider;
  final BackupDirectoryProvider? exportDirectoryProvider;
  final BackupDirectoryProvider? temporaryDirectoryProvider;
  bool _busy = false;

  Future<Directory> _directory() async => directoryProvider != null
      ? directoryProvider!()
      : Directory(
          path.join((await getApplicationSupportDirectory()).path, 'recovery'),
        );

  Future<List<File>> snapshots() async {
    final directory = await _directory();
    if (!await directory.exists()) return [];
    final files = await directory
        .list()
        .where(
          (entry) =>
              entry is File &&
              RegExp(r'^pujangga_pos_backup_[0-9]{14}_[0-9]+_encrypted\.json$')
                  .hasMatch(path.basename(entry.path)),
        )
        .cast<File>()
        .toList();
    files.sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<T> _exclusive<T>(Future<T> Function() operation) async {
    if (_busy) {
      throw const AppException(
        'recovery_busy',
        'Operasi data lain masih berjalan. Tunggu sampai selesai.',
      );
    }
    _busy = true;
    try {
      return await operation();
    } finally {
      _busy = false;
    }
  }

  Future<void> restoreWithSnapshot(
    AppBackupRestoreCandidate candidate, {
    required String password,
  }) => _exclusive(() async {
    final directory = await _directory();
    await directory.create(recursive: true);
    final staging = await directory.createTemp('.pending-');
    final snapshotBackup = AppBackupService(
      database: backup.database,
      logger: backup.logger,
      logoService: backup.logoService,
      backupDirectoryProvider: () async => staging,
    );
    try {
      final snapshot = await snapshotBackup.createBackup(password: password);
      // Read the persisted encrypted bytes through the full restore validator.
      // A truncated, oversized, or invalid snapshot must block replacement.
      final verified = await restore.inspectBackupFile(
        snapshot.filePath,
        password: password,
      );
      if (snapshot.warnings.isNotEmpty ||
          verified.totalRecords != snapshot.totalRecords) {
        throw const AppException(
          'recovery_invalid',
          'Cadangan pemulihan tidak lengkap. Data aktif belum diganti.',
        );
      }
      // Publish only fully verified files. Interrupted writes remain encrypted
      // in staging and are never offered as a usable recovery point.
      await File(snapshot.filePath)
          .rename(path.join(directory.path, snapshot.fileName));
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
    // Keep this file even if replacement fails: it is a verified recovery point.
    await restore.restoreBackup(candidate);
  });

  /// Reset deliberately retains no hidden recovery data. An export must be
  /// saved outside app storage by the user before invoking this operation.
  Future<void> resetAndDeleteLocalBackups() => _exclusive(() async {
    final recovery = await _directory();
    if (await recovery.exists()) {
      // Only this dedicated app-owned directory is recursively removed.
      await recovery.delete(recursive: true);
    }
    final exports =
        await (exportDirectoryProvider?.call() ??
            getApplicationDocumentsDirectory());
    if (await exports.exists()) {
      await for (final entry in exports.list()) {
        if (entry is File &&
            (RegExp(r'^pujangga_pos_backup_[0-9_]+(?:_encrypted)?\.json$')
                    .hasMatch(path.basename(entry.path)) ||
                RegExp(r'^sales_report_[0-9]+\.csv$')
                    .hasMatch(path.basename(entry.path)))) {
          await entry.delete();
        }
      }
    }
    // Android's share and picker plugins keep their own app-private copies.
    // Clearing only Documents/recovery would leave business data in those caches.
    final temporary =
        await (temporaryDirectoryProvider?.call() ?? getTemporaryDirectory());
    for (final name in ['share_plus', 'file_picker']) {
      final cache = Directory(path.join(temporary.path, name));
      if (await cache.exists()) await cache.delete(recursive: true);
    }
    await reset.resetAppData();
  });
}
