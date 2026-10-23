import 'package:sqflite/sqflite.dart';

/// Compensation snapshots use half-open effective intervals [from, until).
class EmployeeCompensationHistory {
  static const table = 'employee_compensation_periods';

  static Map<String, Object?> snapshot(
    Map<String, Object?> employee, {
    required String validFrom,
  }) => {
    'employee_id': employee['id'],
    'employee_name': employee['name'],
    'is_active': employee['is_active'],
    'compensation_type': employee['compensation_type'],
    'monthly_salary': employee['monthly_salary'],
    'valid_from': validFrom,
    'valid_until': null,
  };

  static Future<void> createTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE $table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        employee_id INTEGER NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
        employee_name TEXT NOT NULL,
        is_active INTEGER NOT NULL CHECK(is_active IN (0, 1)),
        compensation_type TEXT NOT NULL CHECK(compensation_type IN ('commission', 'monthly_salary')),
        monthly_salary REAL,
        valid_from TEXT NOT NULL,
        valid_until TEXT,
        CHECK(valid_until IS NULL OR valid_until > valid_from),
        UNIQUE(employee_id, valid_from)
      )
    ''');
  }

  /// Legacy databases have no earlier snapshots to recover. Preserve their
  /// available master values once, without ever replacing existing periods.
  static Future<void> seedMissing(DatabaseExecutor db) async {
    await db.execute('''
      INSERT INTO $table
        (employee_id, employee_name, is_active, compensation_type,
         monthly_salary, valid_from, valid_until)
      SELECT id, name, is_active, compensation_type, monthly_salary,
             effective_from, NULL
      FROM employees e
      WHERE NOT EXISTS (SELECT 1 FROM $table p WHERE p.employee_id = e.id)
    ''');
  }

  static Future<void> recordChange(
    DatabaseExecutor db,
    Map<String, Object?> employee,
    DateTime changedAt,
  ) async {
    final stamp = changedAt.toIso8601String();
    // A scheduled period that has not started may still be corrected.
    await db.delete(
      table,
      where: 'employee_id = ? AND valid_from >= ?',
      whereArgs: [employee['id'], stamp],
    );
    await db.update(
      table,
      {'valid_until': stamp},
      where: 'employee_id = ? AND valid_until IS NULL',
      whereArgs: [employee['id']],
    );
    final effective = DateTime.parse(employee['effective_from'] as String);
    await db.insert(
      table,
      snapshot(
        employee,
        validFrom: (effective.isAfter(changedAt) ? effective : changedAt)
            .toIso8601String(),
      ),
    );
  }

  /// Full monthly salary is owed at the first active salary period in a month.
  /// Later edits in that month apply to the next month's accrual; no proration.
  static Future<Map<String, Object?>?> salaryForMonth(
    DatabaseExecutor db,
    int employeeId,
    DateTime month,
  ) async {
    final rows = await db.query(
      table,
      where: '''employee_id = ? AND is_active = 1
        AND compensation_type = 'monthly_salary'
        AND valid_from < ? AND (valid_until IS NULL OR valid_until > ?)''',
      whereArgs: [
        employeeId,
        DateTime(month.year, month.month + 1).toIso8601String(),
        DateTime(month.year, month.month).toIso8601String(),
      ],
      orderBy: 'valid_from ASC, id ASC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.single;
  }
}
