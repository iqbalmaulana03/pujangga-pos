import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/mutation_revision.dart';
import '../../data/repositories/expense_repository.dart';

final tambahPengeluaranControllerProvider =
    AsyncNotifierProvider<TambahPengeluaranController, void>(
  TambahPengeluaranController.new,
);

class TambahPengeluaranController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  Future<void> simpanPengeluaran({
    required double nominal,
    required String kategori,
    required DateTime tanggal,
    String? catatan,
    int? employeeId,
  }) async {
    state = const AsyncLoading();
    try {
      final repository = ref.read(expenseRepositoryProvider);
      await ref.read(mutationRevisionProvider.notifier).commit(
        {MutationDomain.financial},
        () => repository.addExpense(
          amount: nominal,
          category: kategori,
          date: tanggal,
          notes: catatan,
          employeeId: employeeId,
        ),
      );
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
