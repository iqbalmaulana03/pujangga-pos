import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/features/karyawan/presentation/controllers/employee_controller.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_settings.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_receipt.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:pujangga_pos/features/transaksi/domain/repositories/transaction_repository.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_page.dart';

const _item = TransaksiItem(
  id: '1',
  name: 'Jasa sintetis',
  category: 'Jasa',
  itemType: 'jasa',
  sellingPrice: 10000,
  isActive: true,
);

class _Repository implements TransactionRepository {
  final saved = <TransaksiSubmitRequest>[];
  @override
  Future<List<TransaksiItem>> getCatalogItems() async => [_item];
  @override
  Future<TransaksiReceipt?> getReceiptByInvoice(String invoiceNumber) async =>
      null;
  @override
  Future<TransaksiReceipt> saveTransaction(
    TransaksiSubmitRequest request,
  ) async {
    saved.add(request);
    return TransaksiReceipt(
      invoiceNumber: 'TEST-70',
      createdAt: DateTime(2026),
      paymentMethod: request.paymentMethod,
      subtotalAmount: 10000,
      itemDiscountAmount: 0,
      orderDiscountAmount: 0,
      taxAmount: 0,
      totalAmount: 10000,
      changeAmount: 0,
      items: request.items,
    );
  }
}

List<Override> _overrides(_Repository repository) => [
  // Fail closed if a new dependency attempts to open the runtime database.
  appDatabaseProvider.overrideWith(
    (ref) => throw StateError('Runtime DB forbidden'),
  ),
  businessProfileProvider.overrideWith((ref) async => null),
  activeEmployeesProvider.overrideWith((ref) async => []),
  transactionRepositoryProvider.overrideWithValue(repository),
  appSettingsProvider.overrideWith(
    (ref) async => const AppSettings(
      currencyCode: 'USD',
      currencySymbol: r'$',
      defaultTaxPercent: 10,
      stockAllowNegative: false,
    ),
  ),
];

void main() {
  test(
    'controller rejects invalid cash, resets previous amount, and recovers',
    () async {
      final repository = _Repository();
      final container = ProviderContainer(overrides: _overrides(repository));
      addTearDown(container.dispose);
      final subscription = container.listen(
        transaksiControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(appSettingsProvider.future);
      await container.read(transaksiControllerProvider.future);
      final controller = container.read(transaksiControllerProvider.notifier);
      controller.clearCart();
      controller.addItem(
        const TransaksiItem(
          id: 'free',
          name: 'Gratis',
          category: '',
          itemType: 'jasa',
          sellingPrice: 0,
          isActive: true,
        ),
      );
      expect(
        container.read(transaksiControllerProvider).requireValue.canSubmit,
        isFalse,
      );
      controller.updateCashPaid(0);
      expect(
        container.read(transaksiControllerProvider).requireValue.canSubmit,
        isTrue,
      );
      controller.clearCart();
      controller.addItem(_item);
      for (final amount in <double?>[
        double.infinity,
        double.negativeInfinity,
        double.nan,
        double.parse('1e309'),
        -1,
        null,
        9999,
      ]) {
        controller.updateCashPaid(20000);
        expect(
          container.read(transaksiControllerProvider).requireValue.canSubmit,
          isTrue,
        );
        controller.updateCashPaid(amount);
        expect(
          container.read(transaksiControllerProvider).requireValue.canSubmit,
          isFalse,
        );
        await expectLater(controller.submit(), throwsA(isA<AppException>()));
        expect(repository.saved, isEmpty);
      }
      controller.updateCashPaid(20000);
      await controller.submit();
      expect(repository.saved, hasLength(1));
    },
  );

  test(
    'controller rejects nonfinite setters and handles automatic-tax overflow',
    () async {
      final repository = _Repository();
      final container = ProviderContainer(overrides: _overrides(repository));
      addTearDown(container.dispose);
      final subscription = container.listen(
        transaksiControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      await container.read(appSettingsProvider.future);
      await container.read(transaksiControllerProvider.future);
      final controller = container.read(transaksiControllerProvider.notifier);
      controller.addItem(_item);
      for (final bad in [
        double.infinity,
        double.negativeInfinity,
        double.nan,
      ]) {
        expect(
          () => controller.updateOrderDiscount(bad),
          throwsA(isA<AppException>()),
        );
        expect(
          () => controller.updateItemDiscount('1', bad),
          throwsA(isA<AppException>()),
        );
        expect(
          () => controller.updateTaxAmount(bad),
          throwsA(isA<AppException>()),
        );
        expect(
          () => controller.setQuantity('1', bad),
          throwsA(isA<AppException>()),
        );
      }
      controller.updatePaymentMethod('qris');
      controller.addItem(
        const TransaksiItem(
          id: '2',
          name: 'Extreme',
          category: '',
          itemType: 'jasa',
          sellingPrice: 1e308,
          isActive: true,
        ),
      );
      expect(
        container.read(transaksiControllerProvider).requireValue.canSubmit,
        isFalse,
      );
      controller.removeItem('2');
      expect(
        container.read(transaksiControllerProvider).requireValue.canSubmit,
        isTrue,
      );
    },
  );

  for (final wide in [false, true]) {
    testWidgets(
      'invalid pasted cash and overflowing totals render safely (${wide ? 'wide' : 'mobile'})',
      (tester) async {
        tester.view.physicalSize = Size(wide ? 1400 : 430, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = _Repository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: _overrides(repository),
            child: const MaterialApp(home: Scaffold(body: TransaksiPage())),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Jasa sintetis'));
        await tester.pumpAndSettle();
        if (!wide) {
          await tester.tap(find.text('Keranjang'));
          await tester.pumpAndSettle();
        }
        final cash = find.byWidgetPredicate(
          (w) => w is TextField && w.textAlign == TextAlign.right,
        );
        final submit = find.widgetWithText(FilledButton, 'Proses Pembayaran');
        for (final text in [
          'Infinity',
          '-Infinity',
          'NaN',
          '1e309',
          '-1',
          '',
          '1',
        ]) {
          await tester.enterText(cash, text);
          await tester.pumpAndSettle();
          final container = ProviderScope.containerOf(
            tester.element(find.byType(TransaksiPage)),
          );
          expect(
            container.read(transaksiControllerProvider).requireValue.canSubmit,
            isFalse,
          );
          expect(repository.saved, isEmpty);
          expect(tester.widget<FilledButton>(submit).onPressed, isNull);
          expect(tester.takeException(), isNull);
        }
        await tester.enterText(cash, '20000');
        await tester.pumpAndSettle();
        final container = ProviderScope.containerOf(
          tester.element(find.byType(TransaksiPage)),
        );
        expect(
          container.read(transaksiControllerProvider).requireValue.canSubmit,
          isTrue,
        );
        final controller = container.read(transaksiControllerProvider.notifier);
        controller.setQuantity('1', 1e308);
        await tester.pumpAndSettle();
        expect(
          container.read(transaksiControllerProvider).requireValue.canSubmit,
          isFalse,
        );
        expect(find.textContaining('Nominal tidak valid'), findsWidgets);
        expect(tester.takeException(), isNull);
        controller.setQuantity('1', 1);
        await tester.pumpAndSettle();
        expect(
          container.read(transaksiControllerProvider).requireValue.canSubmit,
          isTrue,
        );
        // The submit control follows canSubmit on both layouts.
        expect(submit, findsOneWidget);
        expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      },
    );
  }
}
