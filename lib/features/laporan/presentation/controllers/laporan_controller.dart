import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_startup_service.dart';
import '../../data/datasources/report_local_data_source.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/entities/report_period.dart';
import '../../domain/entities/sales_report_snapshot.dart';
import '../../domain/repositories/report_repository.dart';

final reportLocalDataSourceProvider = Provider<ReportLocalDataSource>((ref) {
  return ReportLocalDataSource(database: ref.watch(appDatabaseProvider));
});

final reportRepositoryProvider = Provider<ReportRepository>((ref) {
  return ReportRepositoryImpl(
    localDataSource: ref.watch(reportLocalDataSourceProvider),
  );
});

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) {
  return ref.watch(reportRepositoryProvider).getDashboardSummary();
});

final selectedReportPeriodProvider =
    NotifierProvider<SelectedReportPeriodController, ReportPeriod>(
      SelectedReportPeriodController.new,
    );

final salesReportSnapshotByPeriodProvider =
    FutureProvider.family<SalesReportSnapshot, ReportPeriod>((ref, period) {
      return ref
          .watch(reportRepositoryProvider)
          .getSalesReportSnapshot(period: period);
    });

final salesReportSnapshotProvider = FutureProvider<SalesReportSnapshot>((ref) {
  final period = ref.watch(selectedReportPeriodProvider);
  return ref.watch(salesReportSnapshotByPeriodProvider(period).future);
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
