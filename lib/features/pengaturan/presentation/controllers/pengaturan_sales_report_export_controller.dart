import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_startup_service.dart';
import '../../data/services/sales_report_csv_export_service.dart';
import '../../domain/entities/sales_report_export_file.dart';

final salesReportCsvExportServiceProvider =
    Provider<SalesReportCsvExportService>((ref) {
      return SalesReportCsvExportService(
        database: ref.watch(appDatabaseProvider),
        logger: ref.watch(appLoggerProvider),
      );
    });

final pengaturanSalesReportExportControllerProvider =
    AsyncNotifierProvider<
      PengaturanSalesReportExportController,
      SalesReportExportFile?
    >(PengaturanSalesReportExportController.new);

class PengaturanSalesReportExportController
    extends AsyncNotifier<SalesReportExportFile?> {
  @override
  Future<SalesReportExportFile?> build() async => null;

  Future<SalesReportExportFile> exportSalesReport() async {
    state = const AsyncLoading();

    try {
      final export = await ref
          .read(salesReportCsvExportServiceProvider)
          .exportSalesReport();
      state = AsyncData(export);
      return export;
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
      rethrow;
    }
  }
}
