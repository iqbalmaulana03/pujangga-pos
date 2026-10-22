import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/services/app_startup_service.dart';
import '../services/employee_expense_service.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(database: ref.watch(appDatabaseProvider));
});

class ExpenseRepository {
  const ExpenseRepository({required this.database});

  final AppDatabase database;

  Future<void> addExpense({
    required double amount,
    required String category,
    required DateTime date,
    String? notes,
    int? employeeId,
  }) async {
    final db = await database.database();
    final timestamp = DateTime.now().toIso8601String();
    if (category == 'Gaji Karyawan') {
      if (employeeId == null) throw ArgumentError('Pilih karyawan untuk pengeluaran gaji.');
      await db.transaction((txn) async {
        final employees = await txn.query('employees',
            where: "id = ? AND is_active = 1 AND compensation_type = 'monthly_salary'",
            whereArgs: [employeeId]);
        if (employees.isEmpty) throw StateError('Karyawan bergaji bulanan tidak tersedia.');
        final employee = employees.single;
        final salary = (employee['monthly_salary'] as num?)?.toDouble() ?? 0;
        if (!salary.isFinite || salary <= 0) throw StateError('Gaji karyawan belum valid.');
        final effective = DateTime.parse(employee['effective_from'] as String);
        if (date.isBefore(DateTime(effective.year, effective.month, effective.day))) {
          throw StateError('Tanggal pengeluaran mendahului tanggal mulai karyawan.');
        }
        final period = '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
        final existing = await txn.query('expenses',
            where: 'source_type = ? AND source_id = ? AND period_key = ?',
            whereArgs: ['monthly_salary', employeeId, period]);
        if (existing.isNotEmpty) throw StateError('Gaji karyawan untuk bulan ini sudah tercatat.');
        await txn.insert('expenses', {
          'amount': salary, 'category': category,
          'notes': 'Gaji ${employee['name']} - $period${notes == null ? '' : '\n$notes'}',
          'expense_date': date.toIso8601String(),
          'created_at': timestamp, 'updated_at': timestamp,
          'source_type': 'monthly_salary', 'source_id': employeeId,
          'employee_id': employeeId, 'period_key': period,
        });
      });
      return;
    }
    if (!amount.isFinite || amount <= 0) throw ArgumentError('Nominal tidak valid.');
    
    await db.insert('expenses', {
      'amount': amount,
      'category': category,
      'notes': notes,
      'expense_date': date.toIso8601String(),
      'created_at': timestamp,
      'updated_at': timestamp,
    });
  }

  Future<List<Map<String, Object?>>> getExpenses(DateTime start, DateTime end) async {
    await EmployeeExpenseService(database: database).ensureMonthlySalaries(start, end);
    final db = await database.database();
    return db.query('expenses', where: 'expense_date >= ? AND expense_date < ?',
        whereArgs: [start.toIso8601String(), end.toIso8601String()],
        orderBy: 'expense_date DESC, id DESC');
  }
}

final expenseEntriesProvider = FutureProvider.autoDispose.family<List<Map<String, Object?>>, (DateTime, DateTime)>((ref, range) {
  return ref.watch(expenseRepositoryProvider).getExpenses(range.$1, range.$2);
});
