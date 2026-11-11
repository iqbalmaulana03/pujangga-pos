import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/currency_formatter.dart';
import 'package:pujangga_pos/features/setup_usaha/domain/entities/business_profile.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_cart_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_receipt.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_submit_request.dart';
import 'package:pujangga_pos/features/transaksi/domain/repositories/transaction_repository.dart';
import 'package:pujangga_pos/features/transaksi/domain/services/receipt_text_formatter.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/receipt_share_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';
import 'package:pujangga_pos/features/transaksi/presentation/pages/transaksi_berhasil_page.dart';
import 'package:share_plus/share_plus.dart';

const profile = BusinessProfile(
  businessName: 'Toko Contoh',
  businessType: 'campuran',
  address: 'Jalan Contoh',
  contactNumber: '080000000',
  ownerName: 'INTERNAL OWNER',
  modalAwalUsaha: 987654321,
);

TransaksiReceipt receipt({
  String method = 'tunai',
  List<String> types = const ['barang', 'jasa'],
}) => TransaksiReceipt(
  invoiceNumber: 'INV-STORED-55',
  createdAt: DateTime(2026, 11, 11, 9, 30),
  paymentMethod: method,
  subtotalAmount: types.length * 15000,
  itemDiscountAmount: types.length * 1000,
  orderDiscountAmount: 2000,
  taxAmount: 500,
  totalAmount: types.length * 14000 - 1500,
  cashPaidAmount: 30000,
  changeAmount: 3500,
  employeeName: 'INTERNAL EMPLOYEE',
  compensationType: 'commission',
  commissionPercent: 17,
  commissionAmount: 7654321,
  items: [
    for (final type in types)
      TransaksiCartItem(
        item: TransaksiItem(
          id: type,
          name: 'Item $type',
          category: '',
          itemType: type,
          sellingPrice: 10000,
          isActive: true,
          unitLabel: 'unit',
        ),
        quantity: 1.5,
        itemDiscountAmount: 1000,
      ),
  ],
);

// Fully in-memory repository, counts all writes; runtime database is forbidden.
class ReceiptRepository implements TransactionRepository {
  TransaksiReceipt? stored = receipt();
  int writes = 0;
  final invoices = <String>[];
  @override
  Future<TransaksiReceipt?> getReceiptByInvoice(String invoiceNumber) async {
    invoices.add(invoiceNumber);
    return stored;
  }

  @override
  Future<List<TransaksiItem>> getCatalogItems() async => [];
  @override
  Future<TransaksiReceipt> saveTransaction(
    TransaksiSubmitRequest request,
  ) async {
    writes++;
    throw StateError('Sharing must never save a transaction');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => initializeDateFormatting('id_ID'));
  setUp(
    () =>
        CurrencyFormatter.configure(currencyCode: 'IDR', currencySymbol: 'Rp'),
  );

  for (final types in [
    ['barang'],
    ['jasa'],
    ['barang', 'jasa'],
  ]) {
    test('customer receipt formats $types with discounts and tax', () {
      final text = const ReceiptTextFormatter().format(
        receipt(types: types),
        profile,
      );
      for (final part in [
        'Toko Contoh',
        'Jalan Contoh',
        '080000000',
        'INV-STORED-55',
        '11 Nov 2026, 09:30',
        '1,5 unit x Rp10.000',
        'Diskon item: -Rp1.000',
        'Jumlah: Rp14.000',
        'Diskon transaksi: -Rp2.000',
        'Pajak: Rp500',
        'Bayar: Rp30.000',
        'Kembalian: Rp3.500',
        for (final type in types) 'Item $type',
      ]) {
        expect(text, contains(part));
      }
      expect(
        text,
        contains(
          'Total: ${CurrencyFormatter.format(types.length * 14000 - 1500)}',
        ),
      );
      for (final secret in [
        'INTERNAL',
        '987654321',
        '7654321',
        'modal',
        'margin',
        'gaji',
        'komisi',
        'commission',
      ]) {
        expect(text.toLowerCase(), isNot(contains(secret.toLowerCase())));
      }
    });
  }
  for (final method in ['qris', 'transfer', 'ewallet', 'kartu']) {
    test('$method receipt omits cash despite legacy paid amount', () {
      final text = const ReceiptTextFormatter().format(
        receipt(method: method),
        null,
      );
      expect(text, contains(ReceiptTextFormatter.paymentLabel(method)));
      expect(text, isNot(contains('Bayar:')));
      expect(text, isNot(contains('Kembalian:')));
    });
  }
  test('currency precision matches the app', () {
    CurrencyFormatter.configure(currencyCode: 'USD', currencySymbol: r'$');
    expect(
      const ReceiptTextFormatter().format(receipt(), null),
      contains(r'$26,500.00'),
    );
  });

  late ReceiptRepository repository;
  late ProviderContainer container;
  late Completer<ShareResult> gate;
  final payloads = <ShareParams>[];
  void setup({bool realLauncher = false}) {
    repository = ReceiptRepository();
    gate = Completer<ShareResult>();
    payloads.clear();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWith(
          (ref) => throw StateError('No runtime DB'),
        ),
        transactionRepositoryProvider.overrideWithValue(repository),
        businessProfileProvider.overrideWith((ref) async => profile),
        if (!realLauncher)
          receiptShareLauncherProvider.overrideWithValue((params) {
            payloads.add(params);
            return gate.future;
          }),
      ],
    );
    addTearDown(container.dispose);
  }

  for (final status in ShareResultStatus.values) {
    test('sharing $status never mutates sale and allows retry', () async {
      setup();
      final controller = container.read(
        receiptShareControllerProvider.notifier,
      );
      final pending = controller.share('INV-STORED-55');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(receiptShareControllerProvider), isTrue);
      expect(await controller.share('INV-STORED-55'), isNull);
      expect(payloads, hasLength(1));
      expect(payloads.single.subject, 'Struk INV-STORED-55');
      expect(payloads.single.text, contains('Total: Rp26.500'));
      gate.complete(ShareResult('', status));
      expect((await pending)!.status, status);
      expect(container.read(receiptShareControllerProvider), isFalse);
      await controller.share('INV-STORED-55');
      expect(payloads, hasLength(2));
      expect(repository.writes, 0);
      expect(repository.stored!.totalAmount, 26500);
    });
  }
  test('missing saved receipt does not launch share', () async {
    setup();
    repository.stored = null;
    await expectLater(
      container.read(receiptShareControllerProvider.notifier).share('missing'),
      throwsStateError,
    );
    expect(payloads, isEmpty);
    expect(container.read(receiptShareControllerProvider), isFalse);
    expect(repository.writes, 0);
  });

  test(
    'production launcher sends saved text to share_plus platform channel',
    () async {
      setup(realLauncher: true);
      final calls = <MethodCall>[];
      const channel = MethodChannel('dev.fluttercommunity.plus/share');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return 'target';
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await container
          .read(receiptShareControllerProvider.notifier)
          .share('INV-STORED-55');
      expect(calls.single.method, 'share');
      expect(calls.single.arguments['text'], contains('INV-STORED-55'));
      expect(calls.single.arguments['text'], contains('Total: Rp26.500'));
      expect(repository.writes, 0);
    },
  );

  testWidgets(
    'share action handles failure, retries, cancellation, and truthful printing',
    (tester) async {
      setup();
      tester.view.physicalSize = const Size(480, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TransaksiBerhasilPage(invoiceNumber: 'INV-STORED-55'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Bagikan Struk'));
      await tester.tap(find.text('Bagikan Struk'));
      await tester.pumpAndSettle();
      gate.completeError(PlatformException(code: 'share_failed'));
      await tester.pumpAndSettle();
      expect(
        find.text('Gagal membagikan struk. Silakan coba lagi.'),
        findsOneWidget,
      );
      gate = Completer<ShareResult>();
      await tester.tap(find.text('Bagikan Struk'));
      await tester.pumpAndSettle();
      gate.complete(const ShareResult('', ShareResultStatus.dismissed));
      await tester.pumpAndSettle();
      expect(payloads, hasLength(2));
      expect(repository.writes, 0);
      expect(find.text('Pembayaran Berhasil'), findsOneWidget);
      // Let the earlier error snackbar expire before checking print feedback.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cetak Struk'));
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(
        find.textContaining('Cetak struk belum tersedia.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
