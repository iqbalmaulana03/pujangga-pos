import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/features/laporan/data/datasources/report_local_data_source.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/report_period.dart';
import 'package:pujangga_pos/features/transaksi/data/datasources/transaction_local_data_source.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_cart_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:pujangga_pos/features/riwayat/data/datasources/riwayat_local_data_source.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:pujangga_pos/features/pengeluaran/data/repositories/expense_repository.dart';

void main() {
  late Directory tempDir;
  late AppDatabase database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('pujangga_employee_flow');
    await databaseFactory.setDatabasesPath(tempDir.path);
    database = AppDatabase();
  });

  tearDown(() async {
    await database.reset();
    await tempDir.delete(recursive: true);
  });

  test('commission transaction snapshots employee and creates/removes expense on void', () async {
    final db = await database.database();
    final now = DateTime.now().toIso8601String();
    final categoryId = await db.insert('categories', {
      'name': 'Jasa', 'item_type': 'service', 'created_at': now, 'updated_at': now,
    });
    final itemId = await db.insert('items', {
      'category_id': categoryId, 'name': 'Potong Rambut', 'item_type': 'service',
      'sale_price': 100000, 'stock_qty': 0, 'is_active': 1,
      'created_at': now, 'updated_at': now,
    });
    final employeeId = await db.insert('employees', {
      'name': 'Andi', 'is_active': 1, 'compensation_type': 'commission',
      'commission_percent': 10, 'effective_from': now,
      'created_at': now, 'updated_at': now,
    });

    final item = TransaksiItem(
      id: '$itemId', name: 'Potong Rambut', category: 'Jasa', itemType: 'jasa',
      sellingPrice: 100000, isActive: true,
    );
    final receipt = await TransactionLocalDataSource(database: database).saveTransaction(
      TransaksiSubmitRequest(
        items: [TransaksiCartItem(item: item, quantity: 1, itemDiscountAmount: 0)],
        orderDiscountAmount: 10000, taxAmount: 0, paymentMethod: 'tunai',
        cashPaidAmount: 90000, employeeId: employeeId,
      ),
    );

    final transaction = (await db.query('sales_transactions', where: 'invoice_no = ?', whereArgs: [receipt.invoiceNumber])).single;
    expect(transaction['employee_name_snapshot'], 'Andi');
    expect(transaction['commission_percent_snapshot'], 10);
    expect(transaction['commission_amount'], 9000);
    final savedReceipt = await TransactionLocalDataSource(database: database).getReceiptByInvoice(receipt.invoiceNumber);
    expect(savedReceipt!.employeeName, 'Andi');
    expect(savedReceipt.commissionPercent, 10);
    expect(savedReceipt.commissionAmount, 9000);
    final expenses = await ExpenseRepository(database: database).getExpenses(DateTime.now().subtract(const Duration(days: 1)), DateTime.now().add(const Duration(days: 1)));
    expect(expenses.single['amount'], 9000);
    expect((await db.query('expenses', where: 'source_type = ?', whereArgs: ['commission'])).length, 1);

    await RiwayatLocalDataSource(database: database).voidTransaction(receipt.invoiceNumber);
    expect((await db.query('expenses', where: 'source_type = ?', whereArgs: ['commission'])), isEmpty);
    expect((await db.query('sales_transactions', where: 'invoice_no = ?', whereArgs: [receipt.invoiceNumber])).single['status'], 'voided');
  });

  test('monthly salary is generated once when monthly report is opened', () async {
    final db = await database.database();
    final now = DateTime.now();
    final nowIso = now.toIso8601String();
    await db.insert('employees', {
      'name': 'Budi', 'is_active': 1, 'compensation_type': 'monthly_salary',
      'monthly_salary': 2500000, 'effective_from': DateTime(now.year, now.month, 1).toIso8601String(),
      'created_at': nowIso, 'updated_at': nowIso,
    });
    final source = ReportLocalDataSource(database: database);
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    await source.getSalesReportSnapshot(period: ReportPeriod.bulanan, reference: now);
    await source.getSalesReportSnapshot(period: ReportPeriod.bulanan, reference: now);
    final salaryExpenses = await db.query('expenses', where: 'source_type = ?', whereArgs: ['monthly_salary']);
    expect(salaryExpenses, hasLength(1));
    expect(salaryExpenses.single['amount'], 2500000);
    expect((await source.getEmployeeReport(start: start, end: end)).single.expense, 2500000);
    final employeeId = salaryExpenses.single['employee_id'] as int;
    await expectLater(
      ExpenseRepository(database: database).addExpense(
        amount: 2500000, category: 'Gaji Karyawan', date: now, employeeId: employeeId),
      throwsStateError,
    );
    expect(await db.query('expenses'), hasLength(1));
  });

  test('salary expense uses employee salary and cannot duplicate automatic monthly entry', () async {
    final db = await database.database();
    final now = DateTime.now();
    final stamp = now.toIso8601String();
    final id = await db.insert('employees', {
      'name': 'Sari', 'is_active': 1, 'compensation_type': 'monthly_salary',
      'monthly_salary': 3000000, 'effective_from': DateTime(now.year, now.month).toIso8601String(),
      'created_at': stamp, 'updated_at': stamp,
    });
    final repository = ExpenseRepository(database: database);
    await repository.addExpense(amount: 1, category: 'Gaji Karyawan', date: now, employeeId: id);
    expect((await db.query('expenses')).single['amount'], 3000000);
    expect((await db.query('expenses')).single['employee_id'], id);
    await expectLater(repository.addExpense(amount: 1, category: 'Gaji Karyawan', date: now, employeeId: id), throwsStateError);
    await ReportLocalDataSource(database: database).getSalesReportSnapshot(period: ReportPeriod.bulanan, reference: now);
    expect(await db.query('expenses'), hasLength(1));
    await expectLater(repository.addExpense(amount: 1, category: 'Gaji Karyawan', date: now), throwsArgumentError);
  });
}
