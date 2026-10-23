import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/features/laporan/data/datasources/report_local_data_source.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/report_period.dart';
import 'package:pujangga_pos/features/pengeluaran/data/repositories/expense_repository.dart';
import 'package:pujangga_pos/features/riwayat/data/datasources/riwayat_local_data_source.dart';
import 'package:pujangga_pos/features/transaksi/data/datasources/transaction_local_data_source.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_cart_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory temporary;
  late AppDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    temporary = await Directory.systemTemp.createTemp(
      'pujangga_financial_expenses_',
    );
    await databaseFactory.setDatabasesPath(temporary.path);
    database = AppDatabase();
    expect(await database.databasePath(), startsWith(temporary.path));
  });
  tearDown(() async {
    await database.reset();
    await temporary.delete(recursive: true);
  });

  test(
    'home and daily report include salaries, commission and operations exactly once, excluding tax from profit',
    () async {
      final db = await database.database();
      final now = DateTime.now();
      final stamp = now.toIso8601String();
      final day = DateTime(now.year, now.month, now.day);
      final category = await db.insert('categories', {
        'name': 'Jasa',
        'item_type': 'service',
        'created_at': stamp,
        'updated_at': stamp,
      });
      final itemId = await db.insert('items', {
        'category_id': category,
        'name': 'Jasa',
        'item_type': 'service',
        'sale_price': 100000,
        'biaya_dasar': 40000,
        'stock_qty': 0,
        'created_at': stamp,
        'updated_at': stamp,
      });
      final employeeId = await db.insert('employees', {
        'name': 'Komisi',
        'is_active': 1,
        'compensation_type': 'commission',
        'commission_percent': 10,
        'effective_from': stamp,
        'created_at': stamp,
        'updated_at': stamp,
      });
      await db.insert('employees', {
        'name': 'Gaji',
        'is_active': 1,
        'compensation_type': 'monthly_salary',
        'monthly_salary': 15000,
        'effective_from': day.toIso8601String(),
        'created_at': stamp,
        'updated_at': stamp,
      });
      final receipt = await TransactionLocalDataSource(database: database)
          .saveTransaction(
            TransaksiSubmitRequest(
              items: [
                TransaksiCartItem(
                  item: TransaksiItem(
                    id: '$itemId',
                    name: 'Jasa',
                    category: 'Jasa',
                    itemType: 'jasa',
                    sellingPrice: 100000,
                    isActive: true,
                  ),
                  quantity: 2,
                  itemDiscountAmount: 10000,
                ),
              ],
              orderDiscountAmount: 10000,
              taxAmount: 18000,
              paymentMethod: 'tunai',
              cashPaidAmount: 198000,
              employeeId: employeeId,
            ),
          );
      final expenses = ExpenseRepository(database: database);
      await expenses.addExpense(
        amount: 12000,
        category: 'Operasional',
        date: now,
      );
      await expenses.addExpense(
        amount: 99999,
        category: 'Operasional',
        date: day.subtract(const Duration(days: 1)),
      );
      final reports = ReportLocalDataSource(database: database);
      // Home must work before any monthly report or expense list has been opened.
      final home = await reports.getDashboardSummary(reference: now);
      expect(home.marginToday, 100000); // 200k - 20k discounts - 80k COGS
      expect(
        home.totalExpensesToday,
        45000,
      ); // 18k commission + 15k salary + 12k operations
      expect(home.netProfitToday, 55000);
      expect(home.marginTodayIsComplete, isTrue);
      final report = await reports.getSalesReportSnapshot(
        period: ReportPeriod.harian,
        reference: now,
      );
      expect(report.revenue, 198000);
      expect(report.revenueBeforeTax, 180000);
      expect(report.netProfit, home.netProfitToday);
      expect(report.netMarginPercent, closeTo(55000 / 180000 * 100, 0.00001));
      final entries = await expenses.getExpenses(
        day,
        DateTime(day.year, day.month, day.day + 1),
      );
      expect(entries, hasLength(3));
      expect(
        entries.fold<double>(0, (sum, row) => sum + (row['amount'] as num)),
        home.totalExpensesToday,
      );
      expect(
        (await reports.getDashboardSummary(reference: now)).totalExpensesToday,
        45000,
      );
      await RiwayatLocalDataSource(
        database: database,
      ).voidTransaction(receipt.invoiceNumber);
      final afterVoid = await reports.getDashboardSummary(reference: now);
      expect(afterVoid.marginToday, 0);
      expect(afterVoid.totalExpensesToday, 27000);
      expect(afterVoid.netProfitToday, -27000);
      expect(
        (await reports.getSalesReportSnapshot(
          period: ReportPeriod.harian,
          reference: now,
        )).netMarginPercent,
        isNull,
      );
    },
  );

  test(
    'missing cost keeps profit incomplete while preserving known expense total',
    () async {
      final db = await database.database();
      final now = DateTime.now();
      final stamp = now.toIso8601String();
      final transactionId = await db.insert('sales_transactions', {
        'invoice_no': 'MISSING-COST',
        'transaction_date': stamp,
        'subtotal_amount': 100000,
        'total_amount': 100000,
        'payment_method': 'cash',
        'created_at': stamp,
        'updated_at': stamp,
      });
      // A restored historical row can have no cost snapshot; do not fabricate a zero cost.
      final category = await db.insert('categories', {
        'name': 'Jasa',
        'item_type': 'service',
        'created_at': stamp,
        'updated_at': stamp,
      });
      final item = await db.insert('items', {
        'category_id': category,
        'name': 'Jasa',
        'item_type': 'service',
        'sale_price': 100000,
        'created_at': stamp,
        'updated_at': stamp,
      });
      await db.insert('sales_transaction_items', {
        'transaction_id': transactionId,
        'item_id': item,
        'item_name_snapshot': 'Jasa',
        'item_type_snapshot': 'service',
        'price_snapshot': 100000,
        'qty': 1,
        'line_subtotal': 100000,
        'line_total': 100000,
        'created_at': stamp,
      });
      await ExpenseRepository(
        database: database,
      ).addExpense(amount: 10000, category: 'Operasional', date: now);
      final reports = ReportLocalDataSource(database: database);
      final home = await reports.getDashboardSummary(reference: now);
      final report = await reports.getSalesReportSnapshot(
        period: ReportPeriod.harian,
        reference: now,
      );
      expect(home.marginTodayIsComplete, isFalse);
      expect(home.totalExpensesToday, 10000);
      expect(report.marginIsComplete, isFalse);
      expect(report.totalExpenses, home.totalExpensesToday);
      expect(report.netMarginPercent, isNull);
    },
  );
}
