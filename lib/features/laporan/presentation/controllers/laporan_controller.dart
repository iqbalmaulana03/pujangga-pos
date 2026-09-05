import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_startup_service.dart';
import '../../data/datasources/report_local_data_source.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/report_period.dart';
import '../../domain/entities/sales_report_snapshot.dart';
import '../../domain/entities/capital_metrics.dart';
import '../../domain/repositories/report_repository.dart';

final reportLocalDataSourceProvider = Provider<ReportLocalDataSource>((ref) {
  return ReportLocalDataSource(database: ref.watch(appDatabaseProvider));
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepositoryImpl(
    localDataSource: ref.watch(reportLocalDataSourceProvider),
  );
});

final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardSummary>((ref) {
  return ref.watch(reportRepositoryProvider).getDashboardSummary();
});

final selectedReportPeriodProvider =
    NotifierProvider<SelectedReportPeriodController, ReportPeriod>(
      SelectedReportPeriodController.new,
    );

final customReportRangeProvider =
    NotifierProvider<CustomReportRangeController, ReportRange?>(
      CustomReportRangeController.new,
    );

final salesReportSnapshotByPeriodProvider =
    FutureProvider.autoDispose.family<SalesReportSnapshot, ReportPeriod>((ref, period) {
      final customRange = ref.watch(customReportRangeProvider);
      return ref
          .watch(reportRepositoryProvider)
          .getSalesReportSnapshot(period: period, customRange: customRange);
    });

final salesReportSnapshotProvider = FutureProvider.autoDispose<SalesReportSnapshot>((ref) {
  final period = ref.watch(selectedReportPeriodProvider);
  return ref.watch(salesReportSnapshotByPeriodProvider(period).future);
});

final capitalMetricsProvider = FutureProvider.autoDispose<CapitalMetrics>((ref) {
  return ref.watch(reportRepositoryProvider).getCapitalMetrics();
});

class SelectedReportPeriodController extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() {
    return ReportPeriod.harian;
  }

  void select(ReportPeriod period) {
    state = period;
  }
}

class CustomReportRangeController extends Notifier<ReportRange?> {
  @override
  ReportRange? build() => null;

  void setRange(ReportRange? range) {
    state = range;
  }
}
