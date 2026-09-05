import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/features/stok/domain/entities/stock_item.dart';
import 'package:pujangga_pos/features/stok/presentation/models/stok_state.dart';

void main() {
  final now = DateTime.now();

  final kopi = StockItem(
    id: '1',
    name: 'Kopi Literan',
    category: 'Minuman',
    sellingPrice: 78000,
    currentStock: 3,
    isActive: true,
    sku: 'KOPI-01',
    unitLabel: 'Botol',
    createdAt: now.subtract(const Duration(days: 60)),
    costPrice: 40000,
    lastSoldAt: now.subtract(const Duration(days: 2)), // Active
  );

  final gula = StockItem(
    id: '2',
    name: 'Gula Aren',
    category: 'Bahan Baku',
    sellingPrice: 24000,
    currentStock: 12,
    isActive: true,
    unitLabel: 'Pack',
    createdAt: now.subtract(const Duration(days: 60)),
    costPrice: 20000,
    lastSoldAt: now.subtract(const Duration(days: 40)), // Dead stock (>30 days)
  );

  final cup = StockItem(
    id: '3',
    name: 'Cup 16oz',
    category: 'Minuman',
    sellingPrice: 1500,
    currentStock: 0,
    isActive: false,
    unitLabel: 'Pcs',
    createdAt: now.subtract(const Duration(days: 60)),
    costPrice: 1000,
    lastSoldAt: now.subtract(const Duration(days: 45)), // Out of stock, not dead stock
  );

  final sirop = StockItem(
    id: '4',
    name: 'Sirop Vanilla',
    category: 'Bahan Baku',
    sellingPrice: 50000,
    currentStock: 5,
    isActive: true,
    unitLabel: 'Botol',
    createdAt: now.subtract(const Duration(days: 35)),
    costPrice: 35000,
    lastSoldAt: null, // Never sold, created > 30 days ago => Dead stock
  );

  test('menghitung ringkasan stok dasar dengan benar', () {
    final state = StokState(
      allItems: [kopi, gula, cup, sirop],
      filteredItems: [kopi, gula, cup, sirop],
    );

    expect(state.totalItems, 4);
    expect(state.lowStockCount, 3); // kopi(3), cup(0), sirop(5)
    expect(state.inactiveCount, 1);
    expect(state.totalUnits, 20); // 3 + 12 + 0 + 5
    expect(state.categories, ['semua', 'Bahan Baku', 'Minuman']);
  });

  test('mengurutkan item menipis dari stok terkecil', () {
    final state = StokState(
      allItems: [kopi, gula, cup, sirop],
      filteredItems: [kopi, gula, cup, sirop],
    );

    expect(state.lowStockItems.map((item) => item.id).toList(), ['3', '1', '4']);
  });

  test('StockItem: menghitung valuasi aset dan deteksi stok mati dengan benar', () {
    expect(kopi.totalAssetValue, 3 * 40000.0);
    expect(kopi.isDeadStock, false);

    expect(gula.totalAssetValue, 12 * 20000.0);
    expect(gula.isDeadStock, true);

    expect(cup.totalAssetValue, 0.0);
    expect(cup.isDeadStock, false); // Karena currentStock == 0

    expect(sirop.totalAssetValue, 5 * 35000.0);
    expect(sirop.isDeadStock, true); // Belum pernah terjual dan umur > 30 hari
  });

  test('StokState: menghitung valuasi Live Asset dan Dead Stock secara keseluruhan', () {
    final state = StokState(
      allItems: [kopi, gula, cup, sirop],
      filteredItems: [kopi, gula, cup, sirop],
    );

    final expectedLiveAssetValuation = (3 * 40000.0) + (12 * 20000.0) + (0 * 1000.0) + (5 * 35000.0);
    expect(state.liveAssetValuation, expectedLiveAssetValuation);

    expect(state.deadStockCount, 2); // gula, sirop
    
    final expectedDeadStockValuation = (12 * 20000.0) + (5 * 35000.0);
    expect(state.deadStockValuation, expectedDeadStockValuation);
  });
}
