import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/features/laporan/data/datasources/report_local_data_source.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/report_period.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _MemoryDatabase extends AppDatabase {
  @override
  Future<String> databasePath() async => inMemoryDatabasePath;
}

class _ReportDatabase extends AppDatabase {
  _ReportDatabase(this.db);

  final Database db;

  @override
  Future<Database> database() async => db;
}

class _CountingDatabase implements Database {
  _CountingDatabase(this.db);

  final Database db;
  int queryCount = 0;
  int expenseQueryCount = 0;
  (String, List<Object?>?)? firstExpenseQuery;

  void clearCounts() {
    queryCount = 0;
    expenseQueryCount = 0;
    firstExpenseQuery = null;
  }

  @override
  Future<List<Map<String, Object?>>> rawQuery(
    String sql, [
    List<Object?>? arguments,
  ]) {
    queryCount++;
    if (sql.contains('FROM expenses')) {
      expenseQueryCount++;
      firstExpenseQuery ??= (sql, arguments);
    }
    return db.rawQuery(sql, arguments);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) {
    queryCount++;
    return db.query(
      table,
      distinct: distinct,
      columns: columns,
      where: where,
      whereArgs: whereArgs,
      groupBy: groupBy,
      having: having,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Map<String, Object?> _employee(int id, {bool active = true}) => {
  'id': id,
  'name': 'Karyawan $id',
  'is_active': active ? 1 : 0,
  'compensation_type': 'commission',
  'effective_from': '2026-01-01T00:00:00.000',
  'created_at': '2026-01-01T00:00:00.000',
  'updated_at': '2026-01-01T00:00:00.000',
};

Map<String, Object?> _sale(
  int id,
  String date,
  double total, {
  String status = 'completed',
  int? employee,
  String? snapshot,
}) => {
  'id': id,
  'invoice_no': 'SALE-$id',
  'transaction_date': date,
  'subtotal_amount': total - 1,
  'discount_amount': 1,
  'tax_amount': 2,
  'total_amount': total,
  'payment_method': 'cash',
  'status': status,
  'employee_id': employee,
  'employee_name_snapshot': snapshot,
  'commission_amount': 9,
  'created_at': date,
  'updated_at': date,
};

Map<String, Object?> _expense(int? employee, DateTime date, double amount) => {
  'employee_id': employee,
  'expense_date': date.toIso8601String(),
  'amount': amount,
  'category': 'Operasional',
  'created_at': date.toIso8601String(),
  'updated_at': date.toIso8601String(),
};

void main() {
  final benchmark = Platform.environment['REPORT_QUERY_BENCHMARK'] == '1';
  final baseline = Platform.environment['REPORT_QUERY_BASELINE'] == '1';
  late Database db;
  late _CountingDatabase counted;
  late ReportLocalDataSource reports;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final memoryDatabase = _MemoryDatabase();
    expect(await memoryDatabase.databasePath(), inMemoryDatabasePath);
    db = await memoryDatabase.database();
    expect(db.path, inMemoryDatabasePath);
    addTearDown(db.close);
    counted = _CountingDatabase(db);
    reports = ReportLocalDataSource(database: _ReportDatabase(counted));
  });

  test('employee totals preserve sales, expenses, names, and order', () async {
    final start = DateTime(2026, 1, 1);
    final end = DateTime(2026, 2, 1);
    final stamp = start.toIso8601String();
    final before = start.subtract(const Duration(milliseconds: 1));
    final seed = db.batch()
      ..insert('employees', _employee(5))
      ..insert('employees', _employee(1, active: false))
      ..insert('employees', _employee(3))
      ..insert('employees', _employee(2))
      ..insert(
        'sales_transactions',
        _sale(1, stamp, 100, employee: 5, snapshot: 'Z Lama'),
      )
      ..insert(
        'sales_transactions',
        _sale(2, stamp, 50, employee: 5, snapshot: 'A Lama'),
      )
      ..insert(
        'sales_transactions',
        _sale(3, stamp, 30, employee: 4, snapshot: 'Historis'),
      )
      ..insert(
        'sales_transactions',
        _sale(4, stamp, 70, employee: 2, status: 'voided'),
      )
      ..insert(
        'sales_transactions',
        _sale(5, end.toIso8601String(), 60, employee: 1),
      )
      ..insert('sales_transactions', _sale(6, stamp, 40))
      ..insert('expenses', _expense(5, start, 10))
      ..insert('expenses', _expense(5, start, 12))
      ..insert('expenses', _expense(5, before, 99))
      ..insert('expenses', _expense(5, end, 99))
      ..insert('expenses', _expense(1, start, 8))
      ..insert('expenses', _expense(null, start, 99))
      ..insert('expenses', _expense(99, start, 99));
    await seed.commit(noResult: true);

    final result = await reports.getEmployeeReport(start: start, end: end);
    expect(
      [
        for (final row in result)
          (
            row.employeeId,
            row.employeeName,
            row.transactionCount,
            row.revenue,
            row.expense,
            row.compensation,
          ),
      ],
      [
        (4, 'Historis', 1, 28.0, 0.0, 0.0),
        (5, 'Z Lama', 2, 146.0, 22.0, 22.0),
        (1, 'Karyawan 1', 0, 0.0, 8.0, 8.0),
        (2, 'Karyawan 2', 0, 0.0, 0.0, 0.0),
        (3, 'Karyawan 3', 0, 0.0, 0.0, 0.0),
      ],
    );
    expect(counted.expenseQueryCount, baseline ? 5 : 1);
    expect(counted.queryCount, baseline ? 7 : 3);

    await db.insert('employees', _employee(6));
    counted.clearCounts();
    final expanded = await reports.getEmployeeReport(start: start, end: end);
    expect(expanded.last.employeeId, 6);
    expect(counted.expenseQueryCount, baseline ? 6 : 1);
    expect(counted.queryCount, baseline ? 8 : 3);
  });

  final reference = DateTime(2026, 1, 7);
  final customStart = DateTime(2026, 1, 20);
  final cases = [
    (
      ReportPeriod.harian,
      null,
      DateTime(2026, 1, 7, 1),
      24,
      '00:00',
      '01:00',
      '23:00',
    ),
    (ReportPeriod.mingguan, null, DateTime(2026, 1, 6), 7, 'Sen', 'Sel', 'Min'),
    (
      ReportPeriod.bulanan,
      null,
      DateTime(2026, 1, 2),
      31,
      '1/1',
      '2/1',
      '31/1',
    ),
    (ReportPeriod.tahunan, null, DateTime(2026, 2, 1), 12, 'Jan', 'Feb', 'Des'),
    (
      ReportPeriod.kustom,
      31,
      DateTime(2026, 1, 21),
      31,
      '20/1',
      '21/1',
      '19/2',
    ),
    (ReportPeriod.kustom, 32, DateTime(2026, 1, 27), 5, '20/1', '27/1', '17/2'),
    (
      ReportPeriod.kustom,
      180,
      DateTime(2026, 1, 27),
      26,
      '20/1',
      '27/1',
      '14/7',
    ),
    (ReportPeriod.kustom, 181, DateTime(2026, 2, 1), 7, 'Jan', 'Feb', 'Jul'),
  ];

  for (final (
        period,
        days,
        boundary,
        bucketCount,
        firstLabel,
        secondLabel,
        lastLabel,
      )
      in cases) {
    test(
      'sales chart for ${days == null ? period.name : "custom $days days"}',
      () async {
        final custom = days == null
            ? null
            : ReportRange(
                start: customStart,
                endExclusive: DateTime(2026, 1, 20 + days),
              );
        final range = custom ?? period.resolveRange(reference);
        final start = range.start.toIso8601String();
        final split = boundary.toIso8601String();
        final end = range.endExclusive.toIso8601String();
        final before = range.start.subtract(const Duration(milliseconds: 1));
        final last = range.endExclusive.subtract(
          const Duration(microseconds: 1),
        );
        final seed = db.batch()
          ..insert('sales_transactions', _sale(4, split, 23.37))
          ..insert('sales_transactions', _sale(3, split, 18.17))
          ..insert('sales_transactions', _sale(2, start, 57.05))
          ..insert('sales_transactions', _sale(5, split, 91, status: 'voided'))
          ..insert(
            'sales_transactions',
            _sale(6, before.toIso8601String(), 100),
          )
          ..insert('sales_transactions', _sale(7, end, 200))
          ..insert(
            'sales_transactions',
            _sale(8, last.toIso8601String(), 33.12),
          );
        await seed.commit(noResult: true);

        final report = await reports.getSalesReportSnapshot(
          period: period,
          reference: reference,
          customRange: custom,
        );
        expect(report.start, range.start);
        expect(report.endExclusive, range.endExclusive);
        expect(report.revenue, closeTo(131.71, 1e-9));
        expect(report.transactionCount, 4);
        expect(report.salesTrend, hasLength(bucketCount));
        expect(report.salesTrend.first.label, firstLabel);
        expect(report.salesTrend[1].label, secondLabel);
        expect(report.salesTrend.last.label, lastLabel);
        expect(report.salesTrend.first.value, 57.05);
        expect(report.salesTrend[1].value, closeTo(41.54, 1e-9));
        expect(
          report.salesTrend
              .skip(2)
              .take(bucketCount - 3)
              .map((point) => point.value),
          everyElement(0.0),
        );
        expect(report.salesTrend.last.value, 33.12);
        expect(
          [
            for (final candle in report.salesCandles)
              (
                candle.bucketIndex,
                candle.label,
                candle.open,
                candle.high,
                candle.low,
                candle.close,
                candle.transactionCount,
              ),
          ],
          [
            (0, firstLabel, 57.05, 57.05, 57.05, 57.05, 1),
            (1, secondLabel, 18.17, 23.37, 18.17, 23.37, 2),
            (bucketCount - 1, lastLabel, 33.12, 33.12, 33.12, 33.12, 1),
          ],
        );
        expect(counted.queryCount, baseline ? 11 + bucketCount : 11);
      },
    );
  }

  test('restored offset timestamps retain the two chart comparisons', () async {
    final start = DateTime(2026, 1, 1);
    final split = DateTime(2026, 1, 2);
    final range = ReportRange(start: start, endExclusive: DateTime(2026, 1, 3));
    final offset = split.timeZoneOffset.isNegative ? '+01:00' : '+23:00';
    final stamp = '${split.toIso8601String()}$offset';
    final instant = DateTime.parse(stamp);
    expect(instant.isBefore(split), isTrue);
    expect(instant.isBefore(start), isFalse);
    await db.insert('sales_transactions', _sale(1, stamp, 40));

    final report = await reports.getSalesReportSnapshot(
      period: ReportPeriod.kustom,
      customRange: range,
    );

    expect(report.salesTrend.map((point) => point.value), [0.0, 40.0]);
    expect(report.salesCandles.single.bucketIndex, 0);
    expect(report.salesCandles.single.open, 40);
  });

  if (benchmark) {
    for (final employees in [10, 500]) {
      test('synthetic query benchmark with $employees employees', () async {
        final seed = db.batch();
        for (var id = 1; id <= employees; id++) {
          seed.insert('employees', _employee(id));
          for (var i = 0; i < 4; i++) {
            seed.insert('expenses', _expense(id, DateTime(2026, 1, 5 + i), 50));
          }
        }
        for (var id = 1; id <= 6000; id++) {
          final day = 1 + id % 31;
          final stamp = DateTime(
            2026,
            1,
            day,
            10,
            0,
            id % 60,
          ).toIso8601String();
          seed.insert(
            'sales_transactions',
            _sale(
              id,
              stamp,
              100.15,
              employee: id.isEven ? 1 + (id ~/ 2) % employees : null,
            ),
          );
        }
        await seed.commit(noResult: true);

        final week = ReportPeriod.mingguan.resolveRange(reference);
        final month = ReportPeriod.bulanan.resolveRange(reference);
        await _measure(
          counted,
          'employee / week / $employees',
          () => reports.getEmployeeReport(
            start: week.start,
            end: week.endExclusive,
          ),
        );
        final (sql, arguments) = counted.firstExpenseQuery!;
        final explain = await db.rawQuery('EXPLAIN QUERY PLAN $sql', arguments);
        stdout.writeln(
          'expense plan: ${explain.map((row) => row['detail']).join(' | ')}',
        );
        await _measure(
          counted,
          'employee / month / $employees',
          () => reports.getEmployeeReport(
            start: month.start,
            end: month.endExclusive,
          ),
        );
        for (final period in [ReportPeriod.mingguan, ReportPeriod.bulanan]) {
          await _measure(
            counted,
            'sales / ${period.name} / $employees',
            () => reports.getSalesReportSnapshot(
              period: period,
              reference: reference,
            ),
          );
        }
      }, timeout: const Timeout(Duration(minutes: 3)));
    }
  }
}

Future<void> _measure(
  _CountingDatabase db,
  String scenario,
  Future<Object?> Function() report,
) async {
  final micros = <int>[];
  for (var i = 0; i < 35; i++) {
    db.clearCounts();
    final stopwatch = Stopwatch()..start();
    await report();
    stopwatch.stop();
    if (i >= 5) micros.add(stopwatch.elapsedMicroseconds);
  }
  micros.sort();
  final medianMs = (micros[14] + micros[15]) / 2000;
  final p95Ms = micros[28] / 1000;
  stdout.writeln(
    '$scenario: ${db.queryCount} queries (${db.expenseQueryCount} expenses), '
    'median ${medianMs.toStringAsFixed(3)} ms, p95 ${p95Ms.toStringAsFixed(3)} ms',
  );
}
