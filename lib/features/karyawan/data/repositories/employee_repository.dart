import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/employee_compensation_history.dart';
import '../../../../core/services/app_startup_service.dart';
import '../../domain/entities/employee.dart';

final employeeRepositoryProvider = Provider<EmployeeRepository>((ref) {
  return EmployeeRepository(database: ref.watch(appDatabaseProvider));
});

class EmployeeRepository {
  const EmployeeRepository({required this.database});
  final AppDatabase database;

  Future<List<Employee>> getEmployees({bool activeOnly = false}) async {
    final db = await database.database();
    final rows = await db.query(
      'employees',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'is_active DESC, name ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<Employee?> getById(int id) async {
    final db = await database.database();
    final rows = await db.query(
      'employees',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  Future<void> save({
    int? id,
    required String name,
    required bool isActive,
    required String compensationType,
    double? commissionPercent,
    String commissionScope = 'all',
    double? monthlySalary,
    required DateTime effectiveFrom,
    String? notes,
  }) async {
    if (!['all', 'service', 'product'].contains(commissionScope)) {
      throw ArgumentError('Cakupan komisi tidak valid.');
    }
    if (name.trim().isEmpty ||
        !['commission', 'monthly_salary'].contains(compensationType)) {
      throw ArgumentError('Nama dan skema kompensasi tidak valid.');
    }
    if (compensationType == 'commission' &&
        (commissionPercent == null ||
            !commissionPercent.isFinite ||
            commissionPercent < 0 ||
            commissionPercent > 100)) {
      throw ArgumentError('Komisi harus 0 sampai 100 persen.');
    }
    if (compensationType == 'monthly_salary' &&
        (monthlySalary == null ||
            !monthlySalary.isFinite ||
            monthlySalary <= 0)) {
      throw ArgumentError('Gaji harus berupa nominal positif.');
    }
    final db = await database.database();
    final changedAt = DateTime.now();
    final now = changedAt.toIso8601String();
    final values = <String, Object?>{
      'name': name.trim(),
      'is_active': isActive ? 1 : 0,
      'compensation_type': compensationType,
      'commission_percent': compensationType == 'commission'
          ? commissionPercent
          : null,
      'commission_scope': commissionScope,
      'monthly_salary': compensationType == 'monthly_salary'
          ? monthlySalary
          : null,
      'effective_from': effectiveFrom.toIso8601String(),
      'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      'updated_at': now,
    };
    await db.transaction((txn) async {
      if (id == null) {
        values['created_at'] = now;
        final employeeId = await txn.insert('employees', values);
        await txn.insert(
          EmployeeCompensationHistory.table,
          EmployeeCompensationHistory.snapshot({
            ...values,
            'id': employeeId,
          }, validFrom: effectiveFrom.toIso8601String()),
        );
      } else {
        final existing = await txn.query(
          'employees',
          where: 'id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (existing.isEmpty) throw StateError('Karyawan tidak ditemukan.');
        await EmployeeCompensationHistory.seedMissing(txn);
        final previous = existing.single;
        if ([
          'name',
          'is_active',
          'compensation_type',
          'monthly_salary',
          'effective_from',
        ].any((key) => previous[key] != values[key])) {
          await EmployeeCompensationHistory.recordChange(txn, {
            ...values,
            'id': id,
          }, changedAt);
        }
        await txn.update('employees', values, where: 'id = ?', whereArgs: [id]);
      }
    });
  }

  Employee _fromRow(Map<String, Object?> row) => Employee(
    id: (row['id'] as num).toInt(),
    name: row['name'] as String,
    isActive: (row['is_active'] as num).toInt() == 1,
    compensationType: row['compensation_type'] as String,
    commissionPercent: (row['commission_percent'] as num?)?.toDouble(),
    commissionScope: row['commission_scope'] as String? ?? 'all',
    monthlySalary: (row['monthly_salary'] as num?)?.toDouble(),
    effectiveFrom: DateTime.parse(row['effective_from'] as String),
    notes: row['notes'] as String?,
  );
}
