import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/core/services/business_logo_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_payload_builder.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/backup_input_limits.dart';

const _package = 'com.pujanggapos.pujangga_pos.pr81e2e';
const _password = 'Synthetic PR81 export password';
typedef _Tables = Map<String, List<Map<String, Object?>>>;

class _Database extends AppDatabase {
  _Database(this.file);
  final String file;
  @override
  Future<String> databasePath() async => file;
}

class _PayloadBuilder extends AppBackupPayloadBuilder {
  _PayloadBuilder(this.change);
  final void Function(Map<String, Object?>) change;
  @override
  Map<String, Object?> build({
    required DateTime generatedAt,
    required _Tables tables,
    Uint8List? businessLogoBytes,
  }) {
    final payload = super.build(
      generatedAt: generatedAt,
      tables: tables,
      businessLogoBytes: businessLogoBytes,
    );
    change(payload);
    return payload;
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Android export contract: both formats, budgets and atomic failures',
    (tester) async {
      final cache = await getTemporaryDirectory();
      expect(cache.path, contains('/$_package/'));
      final root = await cache.createTemp('pr81-contract-');
      final evidence = Directory(p.join(cache.path, 'pr81-contract-evidence'));
      expect(await evidence.exists(), isFalse, reason: 'Refuse stale evidence');
      await evidence.create();
      final source = _Database(p.join(root.path, 'source.sqlite'));
      var destination = _Database(p.join(root.path, 'destination.sqlite'));
      final exports = await Directory(p.join(root.path, 'exports')).create();
      final logos = BusinessLogoService(supportDirectory: () async => root);
      final events = <String>[];
      void passed(String event) {
        events.add(event);
        debugPrint('PR81_CONTRACT_PASS: $event');
      }

      for (final database in [source, destination]) {
        final file = await database.databasePath();
        expect(p.isWithin(root.path, file), isTrue);
        final effective = await (await database.database()).rawQuery(
          'PRAGMA database_list',
        );
        expect(effective.singleWhere((r) => r['name'] == 'main')['file'], file);
      }
      expect(
        await source.databasePath(),
        isNot(await destination.databasePath()),
      );
      debugPrint('PR81_CONTRACT_ISOLATION: ${root.path}');
      final db = await source.database();
      const stamp = '2026-11-20';
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 16, 16),
        ui.Paint()..color = const ui.Color(0xff008080),
      );
      final picture = recorder.endRecording();
      final image = await picture.toImage(16, 16);
      final imageData = (await image.toByteData(
        format: ui.ImageByteFormat.png,
      ))!;
      final png = imageData.buffer.asUint8List(
        imageData.offsetInBytes,
        imageData.lengthInBytes,
      );
      image.dispose();
      picture.dispose();
      final logo = await logos.write(png);
      await db.insert('business_profile', {
        'business_name': 'Synthetic PR81',
        'business_type': 'retail',
        'logo_path': logo,
        'created_at': stamp,
        'updated_at': stamp,
      });
      await db.insert('categories', {
        'name': 'Synthetic PR81 category',
        'item_type': 'product',
        'created_at': stamp,
        'updated_at': stamp,
      });
      Future<_Tables> snapshot() async => {
        for (final table in AppBackupService.backupTables)
          table: await db.query(table, orderBy: 'id'),
      };
      AppBackupService backup([void Function(Map<String, Object?>)? change]) =>
          AppBackupService(
            database: source,
            logger: Logger('pr81-contract'),
            logoService: logos,
            backupDirectoryProvider: () async => exports,
            payloadBuilder: change == null ? null : _PayloadBuilder(change),
          );
      final sourceRows = await snapshot();
      try {
        for (final password in <String?>[null, _password]) {
          final format = password == null ? 'plaintext' : 'encrypted';
          final file = await backup().createBackup(password: password);
          final restore = AppRestoreService(
            database: destination,
            logger: Logger('pr81-contract'),
            logoService: logos,
          );
          final candidate = await restore.inspectBackupFile(
            file.filePath,
            password: password,
          );
          expect(candidate.businessLogoBytes, png);
          await restore.restoreBackup(candidate);
          await (await destination.database()).close();
          destination = _Database(await destination.databasePath());
          final restored = await destination.database();
          for (final table in AppBackupService.backupTables) {
            final actual = await restored.query(table, orderBy: 'id');
            if (table == 'business_profile') {
              final row = Map<String, Object?>.from(actual.single);
              expect(await File(row['logo_path'] as String).readAsBytes(), png);
              row['logo_path'] = logo;
              expect([row], sourceRows[table]);
            } else {
              expect(actual, sourceRows[table], reason: table);
            }
          }
          expect(await restored.rawQuery('PRAGMA integrity_check'), [
            {'integrity_check': 'ok'},
          ]);
          expect(await restored.rawQuery('PRAGMA foreign_key_check'), isEmpty);
          await File(p.join(evidence.path, '$format.json'))
              .writeAsBytes(await File(file.filePath).readAsBytes());
          passed('$format round-trip, logo, all tables and reopen');
          final previous = await File(file.filePath).readAsBytes();
          final existing =
              (await exports.list().map((e) => p.basename(e.path)).toList())
                ..sort();
          final sequence = await db.query('sqlite_sequence', orderBy: 'name');
          final failures = <String, void Function(Map<String, Object?>)>{
            'rows': (payload) => payload['tables'] = {
              'a': List.filled(25000, {}),
              'b': List.filled(25001, {}),
            },
            'string': (payload) => payload['extra'] =
                'a' * (BackupInputLimits.maxStringLength + 1),
            'depth': (payload) => payload['extra'] = List.generate(
              12,
              (_) => 0,
            ).fold<Object>(0, (v, _) => [v]),
            'tokens': (payload) => payload['extra'] = List.filled(
              BackupInputLimits.maxTokens ~/ 2,
              0,
            ),
            'bytes': (payload) =>
                payload['extra'] = List.filled(350, 'a' * 60000),
            if (password != null)
              'envelope-overhead': (payload) =>
                  payload['extra'] = List.filled(270, 'a' * 60000),
          };
          for (final entry in failures.entries) {
            await expectLater(
              backup(entry.value).createBackup(password: password),
              throwsA(
                isA<AppException>().having(
                  (e) => e.code,
                  'code',
                  'backup_limit_exceeded',
                ),
              ),
            );
            expect(await snapshot(), sourceRows);
            expect(
              await db.query('sqlite_sequence', orderBy: 'name'),
              sequence,
            );
            expect(await File(file.filePath).readAsBytes(), previous);
            expect(
              (await exports.list().map((e) => p.basename(e.path)).toList())
                ..sort(),
              existing,
            );
            passed('$format rejects ${entry.key}, no data/file changes');
          }
          for (final fault in ['write', 'inspect', 'rename']) {
            final overrides = _FaultOverrides(
              fault,
              encrypted: password != null,
            );
            await expectLater(
              IOOverrides.runWithIOOverrides(
                () => backup().createBackup(password: password),
                overrides,
              ),
              throwsA(isA<Exception>()),
            );
            expect(overrides.observed, isTrue);
            expect(await snapshot(), sourceRows);
            expect(
              await db.query('sqlite_sequence', orderBy: 'name'),
              sequence,
            );
            expect(await File(file.filePath).readAsBytes(), previous);
            expect(
              (await exports.list().map((e) => p.basename(e.path)).toList())
                ..sort(),
              existing,
            );
            passed(
              '$format $fault failure, no partial file; encrypted staging contains ciphertext only',
            );
          }
        }
        // Real SQLite dataset above 50,000 aggregate rows and below 20 MiB.
        await db.transaction((txn) async {
          for (var offset = 0; offset < 50000; offset += 1000) {
            final batch = txn.batch();
            for (var i = offset; i < offset + 1000; i++) {
              batch.insert('categories', {
                'name': 'PR81-$i',
                'item_type': 'product',
                'created_at': stamp,
                'updated_at': stamp,
              });
            }
            await batch.commit(noResult: true);
          }
        });
        final large = await snapshot();
        expect(
          large.values.fold<int>(0, (n, rows) => n + rows.length),
          greaterThan(50000),
        );
        final encoded = const JsonEncoder.withIndent('  ').convert(
          const AppBackupPayloadBuilder().build(
            generatedAt: DateTime.now(),
            tables: large,
            businessLogoBytes: png,
          ),
        );
        expect(
          utf8.encode(encoded).length,
          lessThan(BackupInputLimits.maxBytes),
        );
        final files =
            (await exports.list().map((e) => p.basename(e.path)).toList())
              ..sort();
        for (final password in <String?>[null, _password]) {
          await expectLater(
            backup().createBackup(password: password),
            throwsA(
              isA<AppException>().having(
                (e) => e.code,
                'code',
                'backup_limit_exceeded',
              ),
            ),
          );
          expect(await snapshot(), large);
          expect(
            (await exports.list().map((e) => p.basename(e.path)).toList())
              ..sort(),
            files,
          );
        }
        passed('real dataset >50000 rows and <20MiB rejected in both formats');
        await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
        await (await destination.database()).rawQuery(
          'PRAGMA wal_checkpoint(FULL)',
        );
        await (await destination.database()).close();
        await File(await destination.databasePath())
            .copy(p.join(evidence.path, 'restored.sqlite'));
        await File(p.join(evidence.path, 'logo.png')).writeAsBytes(png);
        await File(p.join(evidence.path, 'result.json')).writeAsString(
          jsonEncode({
            'status': 'passed',
            'revision': const String.fromEnvironment('E2E_SOURCE_REVISION'),
            'package': _package,
            'events': events,
            'large_rows': large.values.fold<int>(0, (n, r) => n + r.length),
            'large_plaintext_bytes': utf8.encode(encoded).length,
          }),
        );
        passed('persisted evidence ready');
      } finally {
        await source.reset();
        await destination.reset();
        expect(p.isWithin(cache.path, root.path), isTrue);
        await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

final class _FaultOverrides extends IOOverrides {
  _FaultOverrides(this.fault, {required this.encrypted});
  final String fault;
  final bool encrypted;
  bool observed = false;
  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return path.contains('.pending-') ? _FaultFile(file, this) : file;
  }
}

class _FaultFile implements File {
  _FaultFile(this.file, this.owner);
  final File file;
  final _FaultOverrides owner;
  @override
  String get path => file.path;
  @override
  Uri get uri => file.uri;
  @override
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  }) async {
    owner.observed = true;
    if (owner.encrypted) {
      expect(contents, isNot(contains('Synthetic PR81')));
      expect(jsonDecode(contents)['ciphertext'], isA<String>());
    }
    await file.writeAsString(
      contents,
      mode: mode,
      encoding: encoding,
      flush: flush,
    );
    if (owner.fault == 'write') {
      throw const FileSystemException('synthetic write failure');
    }
    if (owner.fault == 'inspect') {
      await file.writeAsString('{');
    }
    return this;
  }

  @override
  Future<File> rename(String newPath) async {
    if (owner.fault == 'rename') {
      throw const FileSystemException('synthetic rename failure');
    }
    return file.rename(newPath);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
