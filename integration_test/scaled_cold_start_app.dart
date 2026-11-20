// Test-only entrypoint. Render the real app against a verified device snapshot.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pujangga_pos/app/app.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/app_date_formatting.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/transaksi/data/datasources/transaction_local_data_source.dart';

class _Database extends AppDatabase {
  _Database(this.file);
  final String file;
  @override
  Future<String> databasePath() async => file;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initializeAppDateFormatting();
  const package = 'com.pujanggapos.pujangga_pos.pr82e2e';
  const revision = String.fromEnvironment('E2E_SOURCE_REVISION');
  final cache = await getTemporaryDirectory();
  if (!cache.path.contains('/$package/')) throw StateError('Wrong package');
  final output = File(p.join(cache.path, 'pr82-cold', 'result.json'));
  try {
    final file = File(p.join(cache.path, 'pr82-cold', 'source.sqlite'));
    if (!await file.exists()) throw StateError('Verified snapshot is missing');
    final database = _Database(file.path);
    final db = await database.database();
    final identity = (await db.rawQuery('PRAGMA database_list'))
        .singleWhere((row) => row['name'] == 'main');
    if (identity['file'] != file.path) throw StateError('Wrong database');
    Future<Map<String, Object?>> snapshot() async => {
      for (final table in AppBackupService.backupTables)
        table: await db.query(table, orderBy: 'id'),
    };
    final before = await snapshot();
    final headers = await db.query('sales_transactions', orderBy: 'id');
    if (headers.length != 7 ||
        headers[1]['total_amount'] != 0.3 ||
        headers[1]['paid_amount'] != 0.3 ||
        headers[1]['change_amount'] != 0) {
      throw StateError('Exact payment did not survive process startup');
    }
    final legacy = await TransactionLocalDataSource(database: database)
        .getReceiptByInvoice(headers.last['invoice_no'] as String);
    if (legacy!.items.single.lineTotal != 0.015) {
      throw StateError('Historical snapshot changed');
    }
    final key = GlobalKey();
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: PujanggaPosApp(key: key),
      ),
    );
    await container.read(appStartupProvider.future);
    await container.read(appSettingsProvider.future);
    GoRouter? router;
    void inspect(Element element) {
      final widget = element.widget;
      if (widget is MaterialApp && widget.routerConfig is GoRouter) {
        router = widget.routerConfig as GoRouter;
      }
      element.visitChildElements(inspect);
    }

    for (var attempt = 0; attempt < 300 && router == null; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      (key.currentContext as Element?)?.visitChildElements(inspect);
    }
    if (router == null) {
      throw StateError('Real application router did not mount');
    }
    final invoice = headers[1]['invoice_no'] as String;
    router!.go('/history/$invoice');
    var rendered = false;
    void text(Element element) {
      final widget = element.widget;
      if (widget is Text && widget.data == '#$invoice') rendered = true;
      element.visitChildElements(text);
    }

    for (var attempt = 0; attempt < 300 && !rendered; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      (key.currentContext as Element?)?.visitChildElements(text);
    }
    if (!rendered) throw StateError('Persisted receipt did not render');
    if (jsonEncode(await snapshot()) != jsonEncode(before)) {
      throw StateError('Cold startup or receipt read rewrote business rows');
    }
    if ((await db.rawQuery('PRAGMA integrity_check')).single.values.single !=
            'ok' ||
        (await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
      throw StateError('SQLite integrity failed');
    }
    await output.writeAsString(
      jsonEncode({
        'status': 'passed',
        'package': package,
        'revision': revision,
        'pid': pid,
        'invoice_rendered': invoice,
        'transaction_count': headers.length,
        'total': 0.3,
        'paid': 0.3,
        'change': 0,
        'legacy_line_total': 0.015,
        'rows_unchanged': true,
        'integrity': 'ok',
        'verified_at_utc': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  } catch (error) {
    await output.writeAsString(
      jsonEncode({'status': 'failed', 'pid': pid, 'error': error.toString()}),
    );
    rethrow;
  }
}
