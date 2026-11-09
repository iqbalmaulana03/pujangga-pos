import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/core/utils/currency_formatter.dart';
import 'package:pujangga_pos/features/katalog/domain/entities/catalog_item.dart';
import 'package:pujangga_pos/features/katalog/domain/entities/catalog_item_draft.dart';
import 'package:pujangga_pos/features/katalog/domain/repositories/catalog_repository.dart';
import 'package:pujangga_pos/features/katalog/presentation/controllers/katalog_controller.dart';
import 'package:pujangga_pos/features/katalog/presentation/pages/item_form_page.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_settings.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'package:pujangga_pos/features/transaksi/domain/entities/transaksi_item.dart';
import 'package:pujangga_pos/features/transaksi/presentation/controllers/transaksi_controller.dart';

import 'transaksi_controller_test.dart' show MockTransactionRepository;

// The repository only stores a draft in memory. Any attempt to open the actual
// application database fails through the provider override in every test.
class _CatalogRepository implements CatalogRepository {
  _CatalogRepository(this.item);
  final CatalogItem item;
  CatalogItemDraft? saved;

  @override
  Future<CatalogItem?> getItemById(String itemId) async => item;
  @override
  Future<List<CatalogItem>> getItems() async => [item];
  @override
  Future<void> updateItem(String itemId, CatalogItemDraft draft) async {
    expect(itemId, item.id);
    saved = draft;
  }

  @override
  Future<void> createItem(CatalogItemDraft draft) => throw UnimplementedError();
  @override
  Future<void> updateItemStatus({
    required String itemId,
    required bool isActive,
  }) => throw UnimplementedError();
}

void main() {
  tearDown(
    () =>
        CurrencyFormatter.configure(currencyCode: 'IDR', currencySymbol: 'Rp'),
  );

  for (final currency in ['USD', 'SGD', 'IDR']) {
    final isIdr = currency == 'IDR';
    final symbol = isIdr ? 'Rp' : r'$';

    testWidgets('$currency name-only edit preserves all three prices', (
      tester,
    ) async {
      CurrencyFormatter.configure(
        currencyCode: currency,
        currencySymbol: symbol,
      );
      final repository = _CatalogRepository(
        CatalogItem(
          id: 'item-1',
          name: 'Kopi',
          category: 'Minuman',
          itemType: 'barang',
          sellingPrice: isIdr ? 1500 : 1.50,
          costPrice: isIdr ? 650 : 0.65,
          wholesalePrice: isIdr ? 1250 : 1.25,
          wholesaleMinQuantity: 2,
          stockQuantity: 0,
          isActive: true,
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Katalog')),
          ),
          GoRoute(
            path: '/edit',
            builder: (_, _) => const ItemFormPage(itemId: 'item-1'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(repository),
            appDatabaseProvider.overrideWith(
              (ref) => throw StateError('No database in this test'),
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      router.push('/edit');
      await tester.pumpAndSettle();
      for (final text
          in isIdr ? ['1500', '650', '1250'] : ['1.50', '0.65', '1.25']) {
        expect(find.text(text), findsOneWidget);
      }
      final name = find.byWidgetPredicate(
        (widget) =>
            widget is TextFormField && widget.controller?.text == 'Kopi',
      );
      await tester.enterText(name, 'Kopi Baru');
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();
      expect(repository.saved, isNotNull);
      expect(repository.saved!.name, 'Kopi Baru');
      expect(repository.saved!.sellingPrice, repository.item.sellingPrice);
      expect(repository.saved!.costPrice, repository.item.costPrice);
      expect(repository.saved!.wholesalePrice, repository.item.wholesalePrice);
      expect(find.text('Katalog'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test(
      '$currency default tax follows currency precision after cart edits',
      () async {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWith(
              (ref) => throw StateError('No database in this test'),
            ),
            transactionRepositoryProvider.overrideWithValue(
              MockTransactionRepository(),
            ),
            appSettingsProvider.overrideWith(
              (ref) async => AppSettings(
                currencyCode: currency,
                currencySymbol: symbol,
                defaultTaxPercent: 10,
                stockAllowNegative: false,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          transaksiControllerProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        await container.read(appSettingsProvider.future);
        await container.read(transaksiControllerProvider.future);
        final controller = container.read(transaksiControllerProvider.notifier);
        const item = TransaksiItem(
          id: 'item-1',
          name: 'Kopi',
          category: 'Minuman',
          itemType: 'barang',
          sellingPrice: 1,
          stockQuantity: 10,
          isActive: true,
        );
        controller.addItem(item);
        var state = container.read(transaksiControllerProvider).requireValue;
        expect(state.taxAmount, isIdr ? 0 : 0.10);
        expect(state.totalAmount, closeTo(isIdr ? 1 : 1.10, 1e-10));
        controller.setQuantity(item.id, 3);
        state = container.read(transaksiControllerProvider).requireValue;
        expect(state.taxAmount, isIdr ? 0 : 0.30);
        controller.updateItemDiscount(item.id, 0.45);
        state = container.read(transaksiControllerProvider).requireValue;
        expect(state.taxAmount, isIdr ? 0 : 0.26);
        controller.setQuantity(item.id, 6);
        state = container.read(transaksiControllerProvider).requireValue;
        expect(state.taxAmount, isIdr ? 1 : 0.56);
        controller.clearCart();
        expect(
          container.read(transaksiControllerProvider).requireValue.taxAmount,
          0,
        );
      },
    );

    test(
      '$currency input stays parseable and display retains currency decimals',
      () {
        CurrencyFormatter.configure(
          currencyCode: currency,
          currencySymbol: symbol,
        );
        expect(
          CurrencyFormatter.formatForInput(1234.5),
          isIdr ? '1235' : '1234.50',
        );
        expect(
          CurrencyFormatter.formatNoSymbol(1234.5),
          isIdr ? '1.235' : '1,234.50',
        );
      },
    );
  }
}
