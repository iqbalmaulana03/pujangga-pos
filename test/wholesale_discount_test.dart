import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
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
import 'package:pujangga_pos/features/transaksi/presentation/models/transaksi_state.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_page.dart';
import 'package:pujangga_pos/shared/widgets/barcode_scanner_page.dart';

const _item = TransaksiItem(
  id: 'wholesale',
  name: 'Barang Grosir',
  barcode: '123456789',
  category: 'Barang',
  itemType: 'barang',
  sellingPrice: 100,
  wholesalePrice: 20,
  wholesaleMinQuantity: 2,
  stockQuantity: 100,
  unitLabel: 'pcs',
  isActive: true,
);

class _Repository implements TransactionRepository {
  TransaksiSubmitRequest? saved;

  @override
  Future<List<TransaksiItem>> getCatalogItems() async => [_item];

  @override
  Future<TransaksiReceipt?> getReceiptByInvoice(String invoiceNumber) async =>
      null;

  @override
  Future<TransaksiReceipt> saveTransaction(
    TransaksiSubmitRequest request,
  ) async {
    saved = request;
    final subtotal = request.items.fold<double>(
      0,
      (v, i) => v + i.lineSubtotal,
    );
    final discount = request.items.fold<double>(
      0,
      (v, i) => v + i.itemDiscountAmount,
    );
    return TransaksiReceipt(
      invoiceNumber: 'TEST-76',
      createdAt: DateTime(2026),
      paymentMethod: request.paymentMethod,
      subtotalAmount: subtotal,
      itemDiscountAmount: discount,
      orderDiscountAmount: request.orderDiscountAmount,
      taxAmount: request.taxAmount,
      totalAmount:
          subtotal - discount - request.orderDiscountAmount + request.taxAmount,
      changeAmount: 0,
      items: request.items,
    );
  }
}

ProviderContainer _container(
  _Repository repository, {
  String currency = 'IDR',
}) {
  final container = ProviderContainer(
    overrides: [
      // No device storage or application database is permitted in these tests.
      appDatabaseProvider.overrideWith(
        (ref) => throw StateError('Runtime database forbidden in #76 tests'),
      ),
      businessProfileProvider.overrideWith((ref) async => null),
      activeEmployeesProvider.overrideWith((ref) async => []),
      transactionRepositoryProvider.overrideWithValue(repository),
      appSettingsProvider.overrideWith(
        (ref) async => AppSettings(
          currencyCode: currency,
          currencySymbol: currency == 'IDR' ? 'Rp' : r'$',
          defaultTaxPercent: 10,
          stockAllowNegative: false,
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  final subscription = container.listen(transaksiControllerProvider, (_, _) {});
  addTearDown(subscription.close);
  return container;
}

Future<TransaksiController> _ready(ProviderContainer container) async {
  await container.read(appSettingsProvider.future);
  await container.read(transaksiControllerProvider.future);
  return container.read(transaksiControllerProvider.notifier);
}

TransaksiState _current(ProviderContainer container) =>
    container.read(transaksiControllerProvider).requireValue;

void _increase(
  TransaksiController controller,
  String path,
  TransaksiItem item,
) {
  switch (path) {
    case 'card/scanner':
      controller.addItem(item);
    case 'plus':
      controller.increaseQuantity(item.id);
    case 'direct':
      controller.setQuantity(item.id, 2);
  }
}

void main() {
  for (final currency in ['IDR', 'USD', 'SGD']) {
    for (final path in ['card/scanner', 'plus', 'direct']) {
      for (final discount in [0.0, 20.0, 40.0, 80.0]) {
        for (final manualTax in <double?>[null, 0, 7]) {
          test(
            '$currency $path discount=$discount manualTax=$manualTax',
            () async {
              final repository = _Repository();
              final container = _container(repository, currency: currency);
              final controller = await _ready(container);
              controller.addItem(_item);
              controller.updateItemDiscount(_item.id, discount);
              if (manualTax != null) controller.updateTaxAmount(manualTax);
              _increase(controller, path, _item);

              final state = _current(container);
              final line = state.cartItems.single;
              final capped = discount > 40 ? 40.0 : discount;
              final tax = manualTax ?? (40 - capped) * 0.1;
              expect(line.quantity, 2);
              expect(line.unitPrice, 20);
              expect(line.lineSubtotal, 40);
              expect(line.itemDiscountAmount, capped);
              expect(line.lineTotal, 40 - capped);
              expect(line.currencyCode, currency);
              expect(
                state.taxMode,
                manualTax == null ? TaxMode.automatic : TaxMode.manual,
              );
              expect(state.taxAmount, tax);
              expect(state.totalAmount, 40 - capped + tax);

              controller.updateCashPaid(100);
              expect(_current(container).canSubmit, isTrue);
              await controller.submit();
              expect(repository.saved!.items.single.itemDiscountAmount, capped);
              expect(repository.saved!.taxAmount, tax);
            },
          );
        }
      }
    }
  }

  test(
    'below threshold restores retail price without restoring trimmed discount',
    () async {
      final container = _container(_Repository());
      final controller = await _ready(container);
      controller.addItem(_item);
      controller.updateItemDiscount(_item.id, 80);
      controller.addItem(_item);
      controller.decreaseQuantity(_item.id);
      var line = _current(container).cartItems.single;
      expect(line.quantity, 1);
      expect(line.unitPrice, 100);
      expect(line.itemDiscountAmount, 40);
      expect(line.lineTotal, 60);
      expect(_current(container).taxAmount, 6);
      controller.decreaseQuantity(_item.id);
      expect(_current(container).cartItems, isEmpty);
      expect(_current(container).taxAmount, 0);
      for (final quantity in [0.0, -1.0]) {
        controller.addItem(_item);
        controller.setQuantity(_item.id, quantity);
        expect(_current(container).cartItems, isEmpty);
      }
      controller.addItem(_item);
      line = _current(container).cartItems.single;
      expect(line.itemDiscountAmount, 0);
      controller.removeItem(_item.id);
      expect(_current(container).cartItems, isEmpty);
    },
  );

  test(
    'quantity decrease also caps discount on an item without wholesale pricing',
    () async {
      const retail = TransaksiItem(
        id: 'retail',
        name: 'Retail',
        category: '',
        itemType: 'jasa',
        sellingPrice: 100,
        isActive: true,
      );
      final container = _container(_Repository());
      final controller = await _ready(container);
      controller.addItem(retail);
      controller.increaseQuantity(retail.id);
      controller.updateItemDiscount(retail.id, 180);
      controller.decreaseQuantity(retail.id);
      expect(_current(container).cartItems.single.itemDiscountAmount, 100);
      expect(_current(container).cartItems.single.lineTotal, 0);
    },
  );

  for (final currency in ['IDR', 'USD', 'SGD']) {
    for (final path in ['card/scanner', 'plus', 'direct']) {
      test(
        '$currency $path fractional threshold and currency precision',
        () async {
          const fractional = TransaksiItem(
            id: 'fractional',
            name: 'Timbang',
            category: '',
            itemType: 'barang',
            unitLabel: 'kg',
            sellingPrice: 100,
            wholesalePrice: 0.28,
            wholesaleMinQuantity: 2,
            stockQuantity: 100,
            isActive: true,
          );
          final container = _container(_Repository(), currency: currency);
          final controller = await _ready(container);
          controller.addItem(fractional);
          controller.setQuantity(fractional.id, 1.999);
          expect(_current(container).cartItems.single.unitPrice, 100);
          controller.setQuantity(fractional.id, 1.9);
          controller.updateItemDiscount(fractional.id, 80);
          switch (path) {
            case 'card/scanner':
              controller.addItem(fractional);
            case 'plus':
              controller.increaseQuantity(fractional.id);
            case 'direct':
              controller.setQuantity(fractional.id, 2);
          }
          var line = _current(container).cartItems.single;
          expect(line.quantity, 2);
          expect(line.unitPrice, 0.28);
          final subtotal = currency == 'IDR' ? 1.0 : 0.56;
          expect(line.lineSubtotal, subtotal);
          expect(line.itemDiscountAmount, subtotal);
          expect(line.lineTotal, 0);
          controller.decreaseQuantity(fractional.id);
          line = _current(container).cartItems.single;
          expect(line.quantity, 1.9);
          expect(line.unitPrice, 100);
          expect(line.itemDiscountAmount, subtotal);
        },
      );
    }
  }

  test(
    'overflow stays invalid and editable; invalid precision is rejected',
    () async {
      final repository = _Repository();
      final container = _container(repository);
      final controller = await _ready(container);
      controller.addItem(_item);
      controller.updateItemDiscount(_item.id, 80);
      controller.updatePaymentMethod('qris');
      controller.setQuantity(_item.id, 1e100);
      expect(_current(container).cartItems.single.itemDiscountAmount, 80);
      expect(_current(container).canSubmit, isFalse);
      for (final path in ['card/scanner', 'plus']) {
        _increase(controller, path, _item);
        expect(_current(container).cartItems.single.quantity, 1e100);
        expect(_current(container).canSubmit, isFalse);
      }
      controller.setQuantity(_item.id, 2);
      expect(_current(container).cartItems.single.itemDiscountAmount, 40);
      expect(_current(container).canSubmit, isTrue);
      for (final invalid in [double.nan, double.infinity, 1.0001]) {
        expect(
          () => controller.setQuantity(_item.id, invalid),
          throwsA(isA<AppException>()),
        );
      }
      expect(repository.saved, isNull);
    },
  );

  for (final wide in [false, true]) {
    for (final scan in [false, true]) {
      testWidgets(
        '${wide ? 'wide' : 'mobile'} ${scan ? 'scanner' : 'card'} caps discount',
        (tester) async {
          tester.view.physicalSize = Size(wide ? 1400 : 430, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final container = _container(_Repository());
          final controller = await _ready(container);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(home: Scaffold(body: TransaksiPage())),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text(_item.name).first);
          await tester.pumpAndSettle();
          controller.updateItemDiscount(_item.id, 80);
          controller.updateCashPaid(100);
          await tester.pumpAndSettle();
          if (scan) {
            _mockScanner(tester);
            await tester.tap(find.byTooltip('Pindai barcode untuk transaksi'));
            await tester.pumpAndSettle();
            expect(find.byType(BarcodeScannerPage), findsOneWidget);
            tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
              BarcodeCapture(barcodes: [Barcode(rawValue: _item.barcode)]),
            );
            await tester.pumpAndSettle();
            expect(find.byType(BarcodeScannerPage), findsNothing);
          } else {
            await tester.tap(find.text(_item.name).first);
            await tester.pumpAndSettle();
          }
          final state = _current(container);
          expect(state.cartItems.single.quantity, 2);
          expect(state.cartItems.single.unitPrice, 20);
          expect(state.cartItems.single.lineSubtotal, 40);
          expect(state.itemDiscountAmount, 40);
          expect(state.totalAmount, 0);
          expect(state.canSubmit, isTrue);
          if (!wide) {
            tester
                .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
                .clearSnackBars();
            await tester.pumpAndSettle();
            await tester.tap(find.text('Keranjang'));
            await tester.pumpAndSettle();
          }
          expect(
            tester
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Proses Pembayaran'),
                )
                .onPressed,
            isNotNull,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }

  testWidgets('cancelled scan and unknown barcode preserve the cart', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = _container(_Repository());
    final controller = await _ready(container);
    controller.addItem(_item);
    controller.updateItemDiscount(_item.id, 80);
    final before = _current(container).cartItems;
    _mockScanner(tester);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: TransaksiPage())),
      ),
    );
    await tester.pumpAndSettle();
    for (final barcode in <String?>[null, 'unknown']) {
      await tester.tap(find.byTooltip('Pindai barcode untuk transaksi'));
      await tester.pumpAndSettle();
      if (barcode == null) {
        Navigator.of(tester.element(find.byType(BarcodeScannerPage))).pop();
      } else {
        tester.widget<MobileScanner>(find.byType(MobileScanner)).onDetect!(
          BarcodeCapture(barcodes: [Barcode(rawValue: barcode)]),
        );
      }
      await tester.pumpAndSettle();
      expect(_current(container).cartItems, same(before));
      expect(find.byType(BarcodeScannerPage), findsNothing);
    }
    expect(
      find.text('Barcode unknown belum terdaftar di katalog.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

void _mockScanner(WidgetTester tester) {
  const channel = MethodChannel(
    'dev.steenbakker.mobile_scanner/scanner/method',
  );
  final messenger = tester.binding.defaultBinaryMessenger;
  // The route and detection callback are real; no physical camera is accessed.
  messenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'state') return 0;
    if (call.method == 'request') return false;
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
}
