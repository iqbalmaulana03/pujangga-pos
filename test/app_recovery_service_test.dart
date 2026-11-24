@Timeout(Duration(minutes: 2))
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/core/services/business_logo_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_recovery_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_reset_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_backup_restore_candidate.dart';
import 'package:pujangga_pos/features/pengeluaran/data/repositories/expense_repository.dart';
import 'package:pujangga_pos/features/setup_usaha/data/datasources/business_profile_local_data_source.dart';
import 'package:pujangga_pos/features/setup_usaha/data/repositories/business_profile_repository_impl.dart';
import 'package:pujangga_pos/features/setup_usaha/domain/entities/business_profile.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _PausedRestore extends AppRestoreService {
  _PausedRestore({required super.database, required super.logger});

  final entered = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<void> restoreBackup(
    AppBackupRestoreCandidate candidate, {
    DatabaseWriteScope? scope,
  }) async {
    entered.complete();
    await resume.future;
    await super.restoreBackup(candidate, scope: scope);
  }
}

class _PausedLogo extends BusinessLogoService {
  _PausedLogo(Directory root) : super(supportDirectory: () async => root);

  final entered = Completer<void>();
  final resume = Completer<void>();

  @override
  Future<String> write(Uint8List png, {bool draft = false}) async {
    entered.complete();
    await resume.future;
    return super.write(png, draft: draft);
  }
}

class _Database extends AppDatabase {
  _Database(this.file);
  final String file;
  @override
  Future<String> databasePath() async => file;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late Directory exports;
  late Directory recovery;
  late AppDatabase database;
  late AppBackupService backup;
  late AppRestoreService restore;
  const password = 'synthetic password 56';
  const barrierTimeout = Duration(seconds: 90);

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

  Future<void> addExpenseWithCategory(String category) => ExpenseRepository(
    database: database,
  ).addExpense(amount: 12345, category: category, date: DateTime(2026, 11, 12));

  Future<AppBackupRestoreCandidate> seedCandidateAndActive() async {
    final db = await database.database();
    await addExpenseWithCategory('Candidate C');
    final old = await backup.createBackup(password: null);
    final candidate = await restore.inspectBackupFile(old.filePath);
    await db.delete('expenses');
    await addExpenseWithCategory('Active A');
    return candidate;
  }

  test(
    'restore holds writes and rejects a request for the old dataset',
    () async {
      final candidate = await seedCandidateAndActive();
      final db = await database.database();
      final paused = _PausedRestore(database: database, logger: Logger('test'));
      restore = paused;
      final recoveryService = service();
      final recoveryFuture = recoveryService.restoreWithSnapshot(
        candidate,
        password: password,
      );
      try {
        await paused.entered.future.timeout(barrierTimeout);
        var completed = false;
        final write = addExpenseWithCategory('Concurrent B').whenComplete(() {
          completed = true;
        });
        final rejected = expectLater(
          write,
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              'dataset_changed',
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect((await db.query('expenses')).single['category'], 'Active A');
        expect(completed, isFalse);
        paused.resume.complete();
        await recoveryFuture;
        await rejected;
      } finally {
        if (!paused.resume.isCompleted) paused.resume.complete();
        await recoveryFuture;
      }
      expect((await db.query('expenses')).single['category'], 'Candidate C');
      final files = await recoveryService.snapshots();
      final snapshot = await restore.inspectBackupFile(
        files.single.path,
        password: password,
      );
      expect(snapshot.tables['expenses']!.single['category'], 'Active A');
      await addExpenseWithCategory('Concurrent B');
      expect(
        (await db.query('expenses')).map((row) => row['category']),
        unorderedEquals(['Candidate C', 'Concurrent B']),
      );
    },
  );

  test('failed replacement rolls back and allows the waiting write', () async {
    final candidate = await seedCandidateAndActive();
    final db = await database.database();
    await db.execute("""
      CREATE TRIGGER reject_candidate BEFORE INSERT ON expenses
      WHEN NEW.category = 'Candidate C'
      BEGIN SELECT RAISE(ABORT, 'synthetic restore failure'); END
      """);
    final paused = _PausedRestore(database: database, logger: Logger('test'));
    restore = paused;
    final recoveryService = service();
    final failed = expectLater(
      recoveryService.restoreWithSnapshot(candidate, password: password),
      throwsA(isA<DatabaseException>()),
    );
    late Future<void> write;
    try {
      await paused.entered.future.timeout(barrierTimeout);
      write = addExpenseWithCategory('Concurrent B');
      await Future<void>.delayed(Duration.zero);
      expect((await db.query('expenses')).single['category'], 'Active A');
    } finally {
      paused.resume.complete();
      await failed;
    }
    await write;
    expect(
      (await db.query('expenses')).map((row) => row['category']),
      unorderedEquals(['Active A', 'Concurrent B']),
    );
    expect(await db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
    final snapshot = await restore.inspectBackupFile(
      (await recoveryService.snapshots()).single.path,
      password: password,
    );
    expect(snapshot.tables['expenses']!.single['category'], 'Active A');
  });

  test(
    'a profile logo write ahead of recovery is included in the snapshot',
    () async {
      final candidate = await seedCandidateAndActive();
      final logo = _PausedLogo(root);
      final repository = BusinessProfileRepositoryImpl(
        localDataSource: BusinessProfileLocalDataSource(database: database),
        logger: Logger('test'),
        logoService: logo,
      );
      backup = AppBackupService(
        database: database,
        logger: Logger('test'),
        logoService: logo,
      );
      restore = AppRestoreService(
        database: database,
        logger: Logger('test'),
        logoService: logo,
      );
      final recoveryService = service();
      final save = repository.saveProfile(
        BusinessProfile(
          businessName: 'Concurrent profile',
          businessType: 'retail',
          logoPath: p.absolute('test/fixtures/logo-jpeg.jpg'),
        ),
      );
      late Future<void> replacement;
      try {
        await logo.entered.future.timeout(barrierTimeout);
        replacement = recoveryService.restoreWithSnapshot(
          candidate,
          password: password,
        );
      } finally {
        logo.resume.complete();
        await save;
      }
      await replacement;
      final snapshot = await restore.inspectBackupFile(
        (await recoveryService.snapshots()).single.path,
        password: password,
      );
      expect(
        snapshot.tables['business_profile']!.single['business_name'],
        'Concurrent profile',
      );
      expect(snapshot.businessLogoBytes, isNotEmpty);
    },
  );

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
      throwsA(
        isA<AppException>()
            .having((e) => e.code, 'code', 'recovery_invalid')
            .having(
              (e) => e.message,
              'message',
              contains('Data aktif belum diganti'),
            ),
      ),
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
    'oversized snapshot cancels restore and preserves earlier recovery point',
    () async {
      final old = await backup.createBackup(password: null);
      final candidate = await restore.inspectBackupFile(old.filePath);
      await service().restoreWithSnapshot(candidate, password: password);
      final earlier = (await service().snapshots()).single;
      final savedBytes = await earlier.readAsBytes();
      final db = await database.database();
      await db.update('app_settings', {'receipt_footer': 'a' * 65537});
      final before = <String, Object?>{
        for (final table in AppBackupService.backupTables)
          table: await db.query(table),
        'sequence': await db.query('sqlite_sequence'),
      };
      await expectLater(
        service().restoreWithSnapshot(candidate, password: password),
        throwsA(
          isA<AppException>()
              .having((e) => e.code, 'code', 'recovery_invalid')
              .having(
                (e) => e.message,
                'message',
                allOf(
                  contains('panjang nilai'),
                  contains('Data aktif belum diganti'),
                ),
              ),
        ),
      );
      for (final table in AppBackupService.backupTables) {
        expect(await db.query(table), before[table], reason: table);
      }
      expect(await db.query('sqlite_sequence'), before['sequence']);
      expect(await earlier.readAsBytes(), savedBytes);
      expect(await recovery.list().length, 1);
    },
  );

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
      final resetEntered = Completer<void>();
      final resumeReset = Completer<void>();
      final resetting = service(
        directory: () async {
          resetEntered.complete();
          await resumeReset.future;
          return recovery;
        },
      ).resetAndDeleteLocalBackups();
      try {
        await resetEntered.future.timeout(barrierTimeout);
        final rejected = expectLater(
          addExpenseWithCategory('Concurrent reset write'),
          throwsA(
            isA<AppException>().having(
              (e) => e.code,
              'code',
              'dataset_changed',
            ),
          ),
        );
        await Future<void>.delayed(Duration.zero);
        final db = await database.database();
        expect(
          (await db.query('expenses')).single['category'],
          'Biaya sintetis',
        );
        resumeReset.complete();
        await rejected;
      } finally {
        if (!resumeReset.isCompleted) resumeReset.complete();
        await resetting;
      }
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
