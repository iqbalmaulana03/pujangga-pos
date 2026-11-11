import 'dart:async';

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
import 'package:pujangga_pos/features/pengaturan/data/services/app_recovery_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/app_recovery_provider.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_settings.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_reset_controller.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/setup_usaha/domain/entities/business_profile.dart';

void main() {
  testWidgets(
    'reset data aplikasi menampilkan peringatan dan kembali ke flow setup',
    (tester) async {
      var resetCalled = false;
      final finishReset = Completer<void>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appRecoveryServiceProvider.overrideWith(
              (ref) => _FakeRecoveryService(
                onReset: () async {
                  resetCalled = true;
                  await finishReset.future;
                },
              ),
            ),
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
      await tester.ensureVisible(find.text('Reset Data Aplikasi'));
      await tester.pumpAndSettle();
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
      expect(find.text('Cadangkan dan Ekspor Dulu'), findsOneWidget);
      expect(
        find.textContaining('Semua cadangan lokal aplikasi'),
        findsOneWidget,
      );
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(resetCalled, isFalse);
      await tester.tap(find.text('Reset Data Aplikasi'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Reset Semua Data'));
      await tester.pump();
      expect(
        find.byWidgetPredicate(
          (widget) => widget is AbsorbPointer && widget.absorbing,
        ),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate(
          (widget) => widget is PopScope && !widget.canPop,
        ),
        findsWidgets,
      );
      finishReset.complete();
      await tester.pumpAndSettle();

      expect(resetCalled, isTrue);
      expect(
        find.textContaining('Semua data aplikasi berhasil dihapus'),
        findsOneWidget,
      );
    },
  );
}

class _FakeRecoveryService extends AppRecoveryService {
  _FakeRecoveryService({required this.onReset})
    : super(
        backup: AppBackupService(
          database: AppDatabase.instance,
          logger: Logger.root,
        ),
        restore: AppRestoreService(
          database: AppDatabase.instance,
          logger: Logger.root,
        ),
        reset: AppResetService(
          database: AppDatabase.instance,
          logger: Logger.root,
        ),
      );
  final Future<void> Function() onReset;
  @override
  Future<void> resetAndDeleteLocalBackups() => onReset();
}

class _FakeAppResetService extends AppResetService {
  _FakeAppResetService({required this._onReset})
    : super(database: AppDatabase.instance, logger: Logger.root);

  final Future<void> Function() _onReset;

  @override
  Future<void> resetAppData() => _onReset();
}
