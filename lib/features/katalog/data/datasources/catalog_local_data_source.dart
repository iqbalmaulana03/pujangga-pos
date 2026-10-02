import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/catalog_item_draft.dart';
import '../models/catalog_item_db_model.dart';

class CatalogLocalDataSource {
  CatalogLocalDataSource({required this.database});

  final AppDatabase database;

  Future<List<CatalogItemDbModel>> getItems() async {
    final db = await database.database();
    final rows = await db.rawQuery('''
      SELECT
        items.*,
        categories.name AS category_name
      FROM items
      LEFT JOIN categories ON categories.id = items.category_id
      ORDER BY items.updated_at DESC
    ''');
    return rows.map(CatalogItemDbModel.fromMap).toList();
  }

  Future<CatalogItemDbModel?> getItemById(String itemId) async {
    final db = await database.database();
    final rows = await db.rawQuery(
      '''
      SELECT
        items.*,
        categories.name AS category_name
      FROM items
      LEFT JOIN categories ON categories.id = items.category_id
      WHERE items.id = ?
      LIMIT 1
      ''',
      [int.parse(itemId)],
    );

    if (rows.isEmpty) {
      return null;
    }

    return CatalogItemDbModel.fromMap(rows.first);
  }

  Future<void> createItem(CatalogItemDraft draft) async {
    final db = await database.database();
    final timestamp = DateTime.now().toIso8601String();
    final dbItemType = _mapUiItemTypeToDb(draft.itemType);
    await db.transaction((txn) async {
      final categoryId = await _ensureCategory(
        txn,
        categoryName: draft.category.trim(),
        itemType: dbItemType,
        timestamp: timestamp,
      );

      final stockQuantity = draft.isBarang ? (draft.stockQuantity ?? 0) : 0;
      final barcode = _normalizedBarcode(draft.barcode);
      await _ensureBarcodeAvailable(txn, barcode);
      final itemId = await txn.insert('items', {
        'category_id': categoryId,
        'name': draft.name.trim(),
        'item_type': dbItemType,
        'sale_price': draft.sellingPrice,
        'sku': _normalizedText(draft.sku),
        'barcode': barcode,
        'stock_qty': stockQuantity,
        'unit': _normalizedText(draft.unitLabel),
        'harga_modal': draft.isBarang ? draft.costPrice : null,
        'biaya_dasar': !draft.isBarang ? draft.costPrice : null,
        'is_active': draft.isActive ? 1 : 0,
        'wholesale_price': draft.wholesalePrice,
        'wholesale_min_quantity': draft.wholesaleMinQuantity,
        'notes': null,
        'created_at': timestamp,
        'updated_at': timestamp,
      });

      if (stockQuantity > 0) {
        await txn.insert('stock_movements', {
          'item_id': itemId,
          'movement_type': 'stock_in',
          'qty_change': stockQuantity,
          'qty_before': 0,
          'qty_after': stockQuantity,
          'reference_type': 'initial_stock',
          'reference_id': null,
          'notes': 'Stok awal dari katalog',
          'created_at': timestamp,
        });
      }
    });
  }

  Future<void> updateItem(String itemId, CatalogItemDraft draft) async {
    final db = await database.database();
    final timestamp = DateTime.now().toIso8601String();
    final dbItemType = _mapUiItemTypeToDb(draft.itemType);
    await db.transaction((txn) async {
      final id = int.parse(itemId);
      final existingItems = await txn.query(
        'items',
        columns: ['item_type', 'stock_qty'],
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (existingItems.isEmpty) {
        throw const AppException('not_found', 'Item katalog tidak ditemukan.');
      }

      final existing = existingItems.first;
      final previousType = existing['item_type'] as String;
      final previousStock = (existing['stock_qty'] as num).toDouble();
      if (previousType != dbItemType) {
        final hasMovements = await txn.query(
          'stock_movements',
          columns: ['id'],
          where: 'item_id = ?',
          whereArgs: [id],
          limit: 1,
        );
        final hasSales = await txn.query(
          'sales_transaction_items',
          columns: ['id'],
          where: 'item_id = ?',
          whereArgs: [id],
          limit: 1,
        );
        if (previousStock != 0 ||
            hasMovements.isNotEmpty ||
            hasSales.isNotEmpty) {
          throw const AppException(
            'item_type_locked',
            'Tipe item tidak dapat diubah karena item ini sudah memiliki histori stok atau transaksi.',
          );
        }
      }

      final categoryId = await _ensureCategory(
        txn,
        categoryName: draft.category.trim(),
        itemType: dbItemType,
        timestamp: timestamp,
      );
      final barcode = _normalizedBarcode(draft.barcode);
      await _ensureBarcodeAvailable(txn, barcode, excludingItemId: id);
      final nextStock = draft.isBarang ? (draft.stockQuantity ?? 0) : 0;
      final updatedRows = await txn.update(
        'items',
        {
          'category_id': categoryId,
          'name': draft.name.trim(),
          'item_type': dbItemType,
          'sale_price': draft.sellingPrice,
          'sku': _normalizedText(draft.sku),
          'barcode': barcode,
          'stock_qty': nextStock,
          'unit': _normalizedText(draft.unitLabel),
          'harga_modal': draft.isBarang ? draft.costPrice : null,
          'biaya_dasar': !draft.isBarang ? draft.costPrice : null,
          'is_active': draft.isActive ? 1 : 0,
          'wholesale_price': draft.wholesalePrice,
          'wholesale_min_quantity': draft.wholesaleMinQuantity,
          'updated_at': timestamp,
        },
        where: 'id = ?',
        whereArgs: [id],
      );

      if (updatedRows == 0) {
        throw const AppException('not_found', 'Item katalog tidak ditemukan.');
      }

      final stockDelta = nextStock - previousStock;
      if (stockDelta != 0) {
        await txn.insert('stock_movements', {
          'item_id': id,
          'movement_type': stockDelta > 0 ? 'stock_in' : 'stock_out',
          'qty_change': stockDelta,
          'qty_before': previousStock,
          'qty_after': nextStock,
          'reference_type': 'catalog_edit',
          'reference_id': null,
          'notes': 'Perubahan stok dari katalog',
          'created_at': timestamp,
        });
      }
    });
  }

  Future<void> updateItemStatus({
    required String itemId,
    required bool isActive,
  }) async {
    final db = await database.database();
    final updatedRows = await db.update(
      'items',
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [int.parse(itemId)],
    );

    if (updatedRows == 0) {
      throw const AppException('not_found', 'Item katalog tidak ditemukan.');
    }
  }

  Future<int> _ensureCategory(
    dynamic db, {
    required String categoryName,
    required String itemType,
    required String timestamp,
  }) async {
    final normalizedCategory = categoryName.isEmpty ? 'Umum' : categoryName;
    final rows = await db.query(
      'categories',
      columns: ['id'],
      where: 'name = ? AND item_type = ?',
      whereArgs: [normalizedCategory, itemType],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return (rows.first['id'] as num).toInt();
    }

    return db.insert('categories', {
      'name': normalizedCategory,
      'item_type': itemType,
      'is_active': 1,
      'created_at': timestamp,
      'updated_at': timestamp,
    });
  }

  String _mapUiItemTypeToDb(String value) {
    return value == 'jasa' ? 'service' : 'product';
  }

  String? _normalizedText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  String? _normalizedBarcode(String? value) {
    final normalized = value?.replaceAll(RegExp(r'\s+'), '') ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  Future<void> _ensureBarcodeAvailable(
    dynamic db,
    String? barcode, {
    int? excludingItemId,
  }) async {
    if (barcode == null) return;
    final rows = await db.query(
      'items',
      columns: ['id'],
      where: excludingItemId == null
          ? 'barcode = ?'
          : 'barcode = ? AND id != ?',
      whereArgs: excludingItemId == null
          ? [barcode]
          : [barcode, excludingItemId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      throw const AppException(
        'barcode_duplicate',
        'Barcode ini sudah digunakan oleh barang lain.',
      );
    }
  }
}
