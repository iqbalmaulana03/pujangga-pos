import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/employee_compensation_history.dart';

/// Keeps scheduled employee costs consistent across all financial views.
class EmployeeExpenseService {
  const EmployeeExpenseService({required this.database});

  final AppDatabase database;

  Future<void> ensureMonthlySalaries(DateTime start, DateTime end) async {
    final db = await database.database();
    await db.transaction((txn) => _ensureMonthlySalaries(txn, start, end));
  }

  Future<void> _ensureMonthlySalaries(
    DatabaseExecutor db,
    DateTime start,
    DateTime end,
  ) async {
    await EmployeeCompensationHistory.seedMissing(db);
    final employees = await db.rawQuery(
      'SELECT DISTINCT employee_id FROM ${EmployeeCompensationHistory.table}',
    );
    final now = DateTime.now();
    var cursor = DateTime(start.year, start.month);
    while (cursor.isBefore(end) && !cursor.isAfter(now)) {
      final period =
          '${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}';
      for (final employee in employees) {
        final employeeId = (employee['employee_id'] as num).toInt();
        final periodData = await EmployeeCompensationHistory.salaryForMonth(
          db,
          employeeId,
          cursor,
        );
        if (periodData == null) continue;
        final salary = (periodData['monthly_salary'] as num?)?.toDouble() ?? 0;
        if (!salary.isFinite || salary <= 0) continue;
        final effective = DateTime.parse(periodData['valid_from'] as String);
        final date = cursor.isBefore(effective) ? effective : cursor;
        if (!date.isBefore(DateTime(cursor.year, cursor.month + 1)) ||
            !date.isBefore(end) ||
            date.isAfter(now)) {
          continue;
        }
        await db.insert('expenses', {
          'amount': salary,
          'category': 'Gaji Karyawan',
          'notes': 'Gaji ${periodData['employee_name']} - $period',
          'expense_date': date.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'source_type': 'monthly_salary',
          'source_id': employeeId,
          'employee_id': employeeId,
          'period_key': period,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
  }
}
