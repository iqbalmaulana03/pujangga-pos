import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_startup_service.dart';
import '../../../../core/services/dataset_generation.dart';
import '../../../../core/services/mutation_revision.dart';
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
  int? _datasetGeneration;

  @override
  Future<RiwayatState> build() async {
    final buildRef = ref;
    final generation = buildRef.watch(datasetGenerationProvider);
    ref.watch(mutationRevisionProvider.select((r) => r.financial));
    final previous = _datasetGeneration == generation
        ? state.value ?? const RiwayatState()
        : const RiwayatState();
    final transactions = await ref
        .watch(riwayatRepositoryProvider)
        .getTransactions();
    if (buildRef.mounted) _datasetGeneration = generation;
    return _buildState(previous, allTransactions: transactions);
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

  Future<void> refresh() => ref
      .refresh(riwayatControllerProvider.future)
      .then<void>((_) {}, onError: (Object _, StackTrace _) {});

  Future<void> voidTransaction(String invoiceNumber) async {
    final keepAlive = ref.keepAlive();
    try {
      final repository = ref.read(riwayatRepositoryProvider);
      await ref.read(mutationRevisionProvider.notifier).commit({
        MutationDomain.financial,
        MutationDomain.stock,
      }, () => repository.voidTransaction(invoiceNumber));
    } finally {
      keepAlive.close();
    }
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
