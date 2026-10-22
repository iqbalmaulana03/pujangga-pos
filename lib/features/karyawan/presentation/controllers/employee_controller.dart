import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/employee_repository.dart';
import '../../domain/entities/employee.dart';
import '../../../laporan/presentation/controllers/laporan_controller.dart';
import '../../../pengeluaran/data/repositories/expense_repository.dart';

final employeesProvider = FutureProvider.autoDispose<List<Employee>>((ref) {
  return ref.watch(employeeRepositoryProvider).getEmployees();
});

final activeEmployeesProvider = FutureProvider<List<Employee>>((ref) async {
  final employees = await ref.watch(employeeRepositoryProvider).getEmployees();
  return employees.where((employee) => employee.isActive).toList();
});

final employeeControllerProvider =
    AsyncNotifierProvider<EmployeeController, void>(EmployeeController.new);

class EmployeeController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

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
    state = const AsyncLoading();
    try {
      if (name.trim().isEmpty) {
        throw ArgumentError('Nama karyawan wajib diisi.');
      }
      if (compensationType == 'commission' &&
          (commissionPercent == null ||
              commissionPercent < 0 ||
              commissionPercent > 100)) {
        throw ArgumentError('Persentase komisi harus 0 sampai 100.');
      }
      if (compensationType == 'monthly_salary' &&
          (monthlySalary == null || monthlySalary <= 0)) {
        throw ArgumentError('Gaji bulanan harus lebih besar dari nol.');
      }
      await ref
          .read(employeeRepositoryProvider)
          .save(
            id: id,
            name: name,
            isActive: isActive,
            compensationType: compensationType,
            commissionPercent: commissionPercent,
            commissionScope: commissionScope,
            monthlySalary: monthlySalary,
            effectiveFrom: effectiveFrom,
            notes: notes,
          );
      ref.invalidate(dashboardSummaryProvider);
      ref.invalidate(salesReportSnapshotByPeriodProvider);
      ref.invalidate(salesReportSnapshotProvider);
      ref.invalidate(employeeReportProvider);
      ref.invalidate(expenseEntriesProvider);
      ref.invalidate(capitalMetricsProvider);
      state = const AsyncData(null);
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }
}
