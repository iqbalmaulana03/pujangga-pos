import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_startup_service.dart';
import '../../../transaksi/presentation/controllers/transaksi_controller.dart';
import '../../../laporan/presentation/controllers/laporan_controller.dart';
import '../../../stok/presentation/controllers/stok_controller.dart';
import '../../data/datasources/riwayat_local_data_source.dart';
import '../../data/repositories/riwayat_repository_impl.dart';
import '../../domain/entities/riwayat_transaksi_summary.dart';
import '../../domain/repositories/riwayat_repository.dart';
import '../models/riwayat_state.dart';

final riwayatLocalDataSourceProvider = Provider<RiwayatLocalDataSource>((ref) {
  return RiwayatLocalDataSource(database: ref.watch(appDatabaseProvider));
});

final riwayatRepositoryProvider = Provider<RiwayatRepository>((ref) {
  return RiwayatRepositoryImpl(
    localDataSource: ref.watch(riwayatLocalDataSourceProvider),
  );
});

final riwayatControllerProvider =
    AsyncNotifierProvider.autoDispose<RiwayatController, RiwayatState>(
      RiwayatController.new,
    );

class RiwayatController extends AsyncNotifier<RiwayatState> {
  @override
  Future<RiwayatState> build() async {
    final transactions = await ref
        .read(riwayatRepositoryProvider)
        .getTransactions();
    return _buildState(const RiwayatState(), allTransactions: transactions);
  }

  void updateSearch(String value) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(_buildState(current, searchQuery: value));
  }

  void updatePaymentFilter(String value) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(_buildState(current, paymentFilter: value));
  }

  void updateDateFilter(String value) {
    final current = _currentState;
    if (current == null) {
      return;
    }

    state = AsyncData(_buildState(current, dateFilter: value));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final transactions = await ref
          .read(riwayatRepositoryProvider)
          .getTransactions();
      return _buildState(const RiwayatState(), allTransactions: transactions);
    });
    ref.invalidate(transaksiControllerProvider);
  }

  Future<void> voidTransaction(String invoiceNumber) async {
    final current = _currentState;
    if (current == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(riwayatRepositoryProvider).voidTransaction(invoiceNumber);
      final transactions = await ref.read(riwayatRepositoryProvider).getTransactions();
      return _buildState(
        const RiwayatState(),
        allTransactions: transactions,
        searchQuery: current.searchQuery,
        paymentFilter: current.paymentFilter,
        dateFilter: current.dateFilter,
      );
    });

    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(salesReportSnapshotProvider);
    ref.invalidate(capitalMetricsProvider);
    ref.invalidate(stokControllerProvider);
  }



  RiwayatState? get _currentState {
    final current = state;
    return current is AsyncData<RiwayatState> ? current.value : null;
  }

  RiwayatState _buildState(
    RiwayatState current, {
    List<RiwayatTransaksiSummary>? allTransactions,
    String? searchQuery,
    String? paymentFilter,
    String? dateFilter,
  }) {
    final nextState = current.copyWith(
      allTransactions: allTransactions,
      searchQuery: searchQuery,
      paymentFilter: paymentFilter,
      dateFilter: dateFilter,
    );

    final normalizedQuery = nextState.searchQuery.trim().toLowerCase();
    final now = DateTime.now();
    final filtered = nextState.allTransactions.where((transaction) {
      final matchesQuery =
          normalizedQuery.isEmpty ||
          transaction.invoiceNumber.toLowerCase().contains(normalizedQuery) ||
          transaction.itemNames.any(
            (itemName) => itemName.toLowerCase().contains(normalizedQuery),
          );

      final matchesPayment =
          nextState.paymentFilter == 'semua' ||
          transaction.paymentMethod == nextState.paymentFilter;

      final matchesDate = switch (nextState.dateFilter) {
        'hari_ini' => _isSameDay(transaction.createdAt, now),
        '7_hari' => !transaction.createdAt.isBefore(
          DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 6)),
        ),
        '30_hari' => !transaction.createdAt.isBefore(
          DateTime(
            now.year,
            now.month,
            now.day,
          ).subtract(const Duration(days: 29)),
        ),
        _ => true,
      };

      return matchesQuery && matchesPayment && matchesDate;
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return nextState.copyWith(filteredTransactions: filtered);
  }

  bool _isSameDay(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }
}
