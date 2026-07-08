import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/features/stok/domain/entities/stock_item.dart';
import 'package:pujangga_pos/features/stok/presentation/models/stok_state.dart';

void main() {
  const kopi = StockItem(
    id: '1',
    name: 'Kopi Literan',
    category: 'Minuman',
    sellingPrice: 78000,
    currentStock: 3,
    isActive: true,
    sku: 'KOPI-01',
    unitLabel: 'Botol',
  );

  const gula = StockItem(
    id: '2',
    name: 'Gula Aren',
    category: 'Bahan Baku',
    sellingPrice: 24000,
    currentStock: 12,
    isActive: true,
    unitLabel: 'Pack',
  );

  const cup = StockItem(
    id: '3',
    name: 'Cup 16oz',
    category: 'Minuman',
    sellingPrice: 1500,
    currentStock: 0,
    isActive: false,
    unitLabel: 'Pcs',
  );

  test('menghitung ringkasan stok dengan benar', () {
    const state = StokState(
      allItems: [kopi, gula, cup],
      filteredItems: [kopi, gula, cup],
    );

    expect(state.totalItems, 3);
    expect(state.lowStockCount, 2);
    expect(state.inactiveCount, 1);
    expect(state.totalUnits, 15);
    expect(state.categories, ['semua', 'Bahan Baku', 'Minuman']);
  });

  test('mengurutkan item menipis dari stok terkecil', () {
    const state = StokState(
      allItems: [kopi, gula, cup],
      filteredItems: [kopi, gula, cup],
    );

    expect(state.lowStockItems.map((item) => item.id).toList(), ['3', '1']);
  });
}
