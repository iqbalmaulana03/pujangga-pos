import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/dataset_generation.dart';
import '../../../../core/services/mutation_revision.dart';
import '../../data/repositories/employee_repository.dart';
import '../../domain/entities/employee.dart';

final employeesProvider = FutureProvider.autoDispose<List<Employee>>((ref) {
  ref.watch(datasetGenerationProvider);
  ref.watch(mutationRevisionProvider.select((r) => r.financial));
  return ref.watch(employeeRepositoryProvider).getEmployees();
});

final activeEmployeesProvider = FutureProvider<List<Employee>>((ref) async {
  ref.watch(datasetGenerationProvider);
  ref.watch(mutationRevisionProvider.select((r) => r.financial));
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
      final repository = ref.read(employeeRepositoryProvider);
      await ref.read(mutationRevisionProvider.notifier).commit(
        {MutationDomain.financial},
        () => repository.save(
          id: id,
          name: name,
          isActive: isActive,
          compensationType: compensationType,
          commissionPercent: commissionPercent,
          commissionScope: commissionScope,
          monthlySalary: monthlySalary,
          effectiveFrom: effectiveFrom,
          notes: notes,
        ),
      );
      state = const AsyncData(null);
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }
}
