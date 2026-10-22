import 'package:sqflite/sqflite.dart';

import '../../../../core/database/app_database.dart';

/// Keeps scheduled employee costs consistent across all financial views.
class EmployeeExpenseService {
  const EmployeeExpenseService({required this.database});

  final AppDatabase database;

  Future<void> ensureMonthlySalaries(DateTime start, DateTime end) async {
    final db = await database.database();
    final employees = await db.query(
      'employees',
      where: "is_active = 1 AND compensation_type = 'monthly_salary'",
    );
    final now = DateTime.now();
    var cursor = DateTime(start.year, start.month);
    while (cursor.isBefore(end) && !cursor.isAfter(now)) {
      final period =
          '${cursor.year.toString().padLeft(4, '0')}-${cursor.month.toString().padLeft(2, '0')}';
      for (final employee in employees) {
        final salary = (employee['monthly_salary'] as num?)?.toDouble() ?? 0;
        if (!salary.isFinite || salary <= 0) continue;
        final effective = DateTime.parse(employee['effective_from'] as String);
        final date = cursor.isBefore(effective)
            ? DateTime(effective.year, effective.month, effective.day)
            : cursor;
        if (!date.isBefore(DateTime(cursor.year, cursor.month + 1)) ||
            !date.isBefore(end) ||
            date.isAfter(now)) {
          continue;
        }
        await db.insert('expenses', {
          'amount': salary,
          'category': 'Gaji Karyawan',
          'notes': 'Gaji ${employee['name']} - $period',
          'expense_date': date.toIso8601String(),
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
          'source_type': 'monthly_salary',
          'source_id': employee['id'],
          'employee_id': employee['id'],
          'period_key': period,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
  }
}
