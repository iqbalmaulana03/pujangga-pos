import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/features/katalog/domain/entities/catalog_item.dart';
import 'package:pujangga_pos/features/katalog/presentation/models/katalog_state.dart';

void main() {
  const activeBarang = CatalogItem(
    id: 'barang-1',
    name: 'Kopi Literan',
    category: 'Minuman',
    itemType: 'barang',
    sellingPrice: 78000,
    isActive: true,
    sku: 'KOPI-01',
    stockQuantity: 10,
    unitLabel: 'Botol',
  );

  const inactiveBarang = CatalogItem(
    id: 'barang-2',
    name: 'Pomade',
    category: 'Produk Tambahan',
    itemType: 'barang',
    sellingPrice: 65000,
    isActive: false,
    stockQuantity: 4,
    unitLabel: 'Pcs',
  );

  const jasa = CatalogItem(
    id: 'jasa-1',
    name: 'Haircut Reguler',
    category: 'Layanan',
    itemType: 'jasa',
    sellingPrice: 35000,
    isActive: true,
    unitLabel: 'Layanan',
  );

  test('menghitung ringkasan item katalog', () {
    const state = KatalogState(
      allItems: [activeBarang, inactiveBarang, jasa],
      filteredItems: [activeBarang, inactiveBarang, jasa],
    );

    expect(state.activeCount, 2);
    expect(state.barangCount, 2);
    expect(state.jasaCount, 1);
  });
}
