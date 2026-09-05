import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/expense_repository.dart';
import '../../../laporan/presentation/controllers/laporan_controller.dart';

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
  }) async {
    state = const AsyncLoading();
    try {
      final repository = ref.read(expenseRepositoryProvider);
      await repository.addExpense(
        amount: nominal,
        category: kategori,
        date: tanggal,
        notes: catatan,
      );
      
      ref.invalidate(salesReportSnapshotProvider);
      
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

