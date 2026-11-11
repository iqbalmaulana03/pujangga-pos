@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_recovery_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_reset_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _Database extends AppDatabase {
  _Database(this.file);
  final String file;
  @override
  Future<String> databasePath() async => file;
}

void main() {
  late Directory root;
  late Directory exports;
  late Directory recovery;
  late AppDatabase database;
  late AppBackupService backup;
  late AppRestoreService restore;
  const password = 'synthetic password 56';

  AppRecoveryService service({BackupDirectoryProvider? directory}) =>
      AppRecoveryService(
        backup: backup,
        restore: restore,
        reset: AppResetService(database: database, logger: Logger('test')),
        directoryProvider: directory ?? () async => recovery,
        exportDirectoryProvider: () async => exports,
        temporaryDirectoryProvider: () async =>
            Directory(p.join(root.path, 'cache')),
      );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    root = await Directory.systemTemp.createTemp('pujangga_recovery_56_');
    exports = await Directory(p.join(root.path, 'exports')).create();
    recovery = Directory(p.join(root.path, 'recovery'));
    database = _Database(p.join(root.path, 'active.sqlite'));
    // Effective SQLite path and every file directory are bounded to this fresh
    // disposable root; no platform/default database or real user data is used.
    expect(p.dirname(await database.databasePath()), root.path);
    backup = AppBackupService(
      database: database,
      logger: Logger('test'),
      backupDirectoryProvider: () async => exports,
    );
    restore = AppRestoreService(database: database, logger: Logger('test'));
  });
  tearDown(() async {
    await database.reset();
    expect(p.dirname(root.path), Directory.systemTemp.path);
    await root.delete(recursive: true);
  });

  Future<void> addExpense() async {
    final db = await database.database();
    await db.insert('expenses', {
      'category': 'Biaya sintetis',
      'amount': 12345,
      'expense_date': '2026-11-12',
      'created_at': DateTime(2026, 11, 12).toIso8601String(),
      'updated_at': DateTime(2026, 11, 12).toIso8601String(),
    });
  }

  test(
    'encrypted snapshot survives restart and restores the pre-restore dataset',
    () async {
      final old = await backup.createBackup(password: null);
      final candidate = await restore.inspectBackupFile(old.filePath);
      await addExpense();
      await service().restoreWithSnapshot(candidate, password: password);
      expect(await (await database.database()).query('expenses'), isEmpty);
      // Recreate the service and reopen the database, as after process restart.
      await (await database.database()).close();
      database = _Database(await database.databasePath());
      backup = AppBackupService(
        database: database,
        logger: Logger('restart'),
        backupDirectoryProvider: () async => exports,
      );
      restore = AppRestoreService(
        database: database,
        logger: Logger('restart'),
      );
      final files = await service().snapshots();
      expect(files, hasLength(1));
      expect(
        await files.single.readAsString(),
        isNot(contains('Biaya sintetis')),
      );
      await expectLater(
        restore.inspectBackupFile(
          files.single.path,
          password: 'wrong password',
        ),
        throwsException,
      );
      final saved = await restore.inspectBackupFile(
        files.single.path,
        password: password,
      );
      await service().restoreWithSnapshot(saved, password: password);
      expect(
        (await (await database.database()).query('expenses')).single['amount'],
        12345,
      );
      expect(
        await (await database.database()).rawQuery('PRAGMA foreign_key_check'),
        isEmpty,
      );
      expect(await service().snapshots(), hasLength(2));
    },
  );

  test('snapshot write failure leaves active data intact', () async {
    final old = await backup.createBackup(password: null);
    final candidate = await restore.inspectBackupFile(old.filePath);
    await addExpense();
    final blocked = File(p.join(root.path, 'not-a-directory'));
    await blocked.writeAsString('owned test file');
    await expectLater(
      service(directory: () async => Directory(blocked.path))
          .restoreWithSnapshot(candidate, password: password),
      throwsA(isA<FileSystemException>()),
    );
    expect(await (await database.database()).query('expenses'), hasLength(1));
  });

  test('invalid snapshot cannot replace active data', () async {
    final old = await backup.createBackup(password: null);
    final candidate = await restore.inspectBackupFile(old.filePath);
    // SQLite can contain legacy-invalid data; snapshot verification must reject it.
    final db = await database.database();
    await db.execute('PRAGMA ignore_check_constraints = ON');
    await db.update('app_settings', {'default_tax_percent': -1});
    await expectLater(
      service().restoreWithSnapshot(candidate, password: password),
      throwsException,
    );
    expect((await db.query('app_settings')).single['default_tax_percent'], -1);
    expect(await service().snapshots(), isEmpty);
  });

  test(
    'reset deletes local snapshots and exports, preserves external copy',
    () async {
      final old = await backup.createBackup(password: password);
      final external = await File(old.filePath)
          .copy(p.join(root.path, 'user-saved.json'));
      final unrelated = await File(p.join(exports.path, 'unrelated.txt'))
          .writeAsString('keep');
      final shareCache = await Directory(
        p.join(root.path, 'cache', 'share_plus'),
      ).create(recursive: true);
      final pickerCache = await Directory(
        p.join(root.path, 'cache', 'file_picker'),
      ).create(recursive: true);
      await File(p.join(shareCache.path, 'cached.json'))
          .writeAsString('synthetic');
      await File(p.join(pickerCache.path, 'cached.json'))
          .writeAsString('synthetic');
      final candidate = await restore.inspectBackupFile(
        old.filePath,
        password: password,
      );
      await service().restoreWithSnapshot(candidate, password: password);
      await addExpense();
      await service().resetAndDeleteLocalBackups();
      expect(await service().snapshots(), isEmpty);
      expect(await File(old.filePath).exists(), isFalse);
      expect(await external.exists(), isTrue);
      expect(await unrelated.exists(), isTrue);
      expect(await shareCache.exists(), isFalse);
      expect(await pickerCache.exists(), isFalse);
      expect(await (await database.database()).query('expenses'), isEmpty);
    },
  );
}
