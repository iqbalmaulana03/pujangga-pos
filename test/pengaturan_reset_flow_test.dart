import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:pujangga_pos/app/app.dart';
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/dashboard_summary.dart';
import 'package:pujangga_pos/features/laporan/presentation/controllers/laporan_controller.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_reset_service.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_settings.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_reset_controller.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/setup_usaha/domain/entities/business_profile.dart';

void main() {
  testWidgets(
    'reset data aplikasi menampilkan peringatan dan kembali ke flow setup',
    (tester) async {
      var resetCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStartupProvider.overrideWith((ref) async {
              return const AppStartupState(hasBusinessProfile: true);
            }),
            businessProfileProvider.overrideWith((ref) async {
              return const BusinessProfile(
                businessName: 'Kedai Pujangga',
                businessType: 'Kedai Kopi',
              );
            }),
            dashboardSummaryProvider.overrideWith((ref) async {
              return const DashboardSummary(
                revenueToday: 100000,
                transactionCountToday: 4,
                topItemName: 'Es Kopi Susu',
                topItemQuantity: 2,
                topPaymentMethod: 'Tunai',
                marginToday: 0,
                marginTodayIsComplete: true,
              );
            }),
            appSettingsProvider.overrideWith((ref) async {
              return const AppSettings(
                currencyCode: 'IDR',
                currencySymbol: 'Rp',
                defaultTaxPercent: 0,
                stockAllowNegative: false,
              );
            }),
            appResetServiceProvider.overrideWith((ref) {
              return _FakeAppResetService(
                onReset: () async {
                  resetCalled = true;
                },
              );
            }),
          ],
          child: const PujanggaPosApp(),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Pengaturan'));
      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;
      await tester.dragUntilVisible(
        find.text('Reset Data Aplikasi'),
        scrollable,
        const Offset(0, -400),
      );

      expect(find.text('Reset Data Aplikasi'), findsOneWidget);
      expect(
        find.text(
          'Tindakan destruktif. Cadangkan data terlebih dahulu jika masih dibutuhkan.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Reset Data Aplikasi'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Data Aplikasi?'), findsOneWidget);
      expect(
        find.textContaining('Sebaiknya cadangkan data terlebih dahulu'),
        findsOneWidget,
      );

      await tester.tap(find.text('Reset Semua Data'));
      await tester.pumpAndSettle();

      expect(resetCalled, isTrue);
      expect(
        find.textContaining('Semua data aplikasi berhasil dihapus'),
        findsOneWidget,
      );
    },
  );
}

class _FakeAppResetService extends AppResetService {
  _FakeAppResetService({required this._onReset})
    : super(database: AppDatabase.instance, logger: Logger.root);

  final Future<void> Function() _onReset;

  @override
  Future<void> resetAppData() => _onReset();
}
