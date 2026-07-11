import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pujangga_pos/app/app.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_settings.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/laporan/domain/entities/dashboard_summary.dart';
import 'package:pujangga_pos/features/laporan/presentation/controllers/laporan_controller.dart';
import 'package:pujangga_pos/features/setup_usaha/domain/entities/business_profile.dart';

void main() {
  testWidgets('menampilkan setup usaha saat profil bisnis belum ada', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStartupProvider.overrideWith((ref) async {
            return const AppStartupState(hasBusinessProfile: false);
          }),
        ],
        child: const PujanggaPosApp(),
      ),
    );

    await tester.pumpAndSettle();

    final scrollable = find.byType(SingleChildScrollView);

    expect(find.text('Pujangga-POS'), findsWidgets);
    await tester.dragUntilVisible(
      find.text('Nama Toko / Bisnis'),
      scrollable,
      const Offset(0, -250),
    );
    expect(find.text('Nama Toko / Bisnis'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Kategori Bisnis'),
      scrollable,
      const Offset(0, -300),
    );
    expect(find.text('Kategori Bisnis'), findsOneWidget);
    expect(find.text('Mata Uang'), findsOneWidget);
  });

  testWidgets('menampilkan beranda saat profil bisnis sudah ada', (
    tester,
  ) async {
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
              revenueToday: 275000,
              transactionCountToday: 12,
              topItemName: 'Es Kopi Susu',
              topItemQuantity: 6,
              topPaymentMethod: 'QRIS',
              marginToday: 0.0,
              marginTodayIsComplete: true,
            );
          }),
          appSettingsProvider.overrideWith((ref) async {
            return const AppSettings(
              currencyCode: 'IDR',
              currencySymbol: 'Rp',
              defaultTaxPercent: 11,
              stockAllowNegative: false,
              receiptHeader: 'Terima kasih',
              receiptFooter: 'Simpan struk ini',
            );
          }),
        ],
        child: const PujanggaPosApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Penjualan Hari Ini'), findsOneWidget);
    expect(find.text('Buat Transaksi'), findsWidgets);
  });

  testWidgets('menampilkan pengaturan dengan data profil yang bisa diedit', (
    tester,
  ) async {
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
              ownerName: 'Iqbal',
              contactNumber: '08123456789',
              address: 'Jl. Melati No. 8',
            );
          }),
          dashboardSummaryProvider.overrideWith((ref) async {
            return const DashboardSummary(
              revenueToday: 275000,
              transactionCountToday: 12,
              topItemName: 'Es Kopi Susu',
              topItemQuantity: 6,
              topPaymentMethod: 'QRIS',
              marginToday: 0.0,
              marginTodayIsComplete: true,
            );
          }),
          appSettingsProvider.overrideWith((ref) async {
            return const AppSettings(
              currencyCode: 'IDR',
              currencySymbol: 'Rp',
              defaultTaxPercent: 11,
              stockAllowNegative: false,
              receiptHeader: 'Terima kasih',
              receiptFooter: 'Simpan struk ini',
            );
          }),
        ],
        child: const PujanggaPosApp(),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Penjualan Hari Ini'), findsOneWidget);

    await tester.tap(find.byTooltip('Pengaturan'));
    await tester.pumpAndSettle();

    expect(find.text('Pengaturan'), findsOneWidget);
    expect(find.text('Kedai Pujangga'), findsOneWidget);
    expect(find.text('Kedai Kopi'), findsOneWidget);
    expect(find.text('Iqbal'), findsOneWidget);
    final scrollable = find.byType(Scrollable).first;
    await tester.dragUntilVisible(
      find.text('PREFERENSI OPERASIONAL'),
      scrollable,
      const Offset(0, -300),
    );
    expect(find.text('PREFERENSI OPERASIONAL'), findsOneWidget);
    expect(find.text('Rupiah (IDR)'), findsOneWidget);
  });
}
