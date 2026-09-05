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
    final categoryId = await _ensureCategory(
      db,
      categoryName: draft.category.trim(),
      itemType: dbItemType,
      timestamp: timestamp,
    );

    await db.insert('items', {
      'category_id': categoryId,
      'name': draft.name.trim(),
      'item_type': dbItemType,
      'sale_price': draft.sellingPrice,
      'sku': _normalizedText(draft.sku),
      'stock_qty': draft.isBarang ? (draft.stockQuantity ?? 0) : 0,
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
  }

  Future<void> updateItem(String itemId, CatalogItemDraft draft) async {
    final db = await database.database();
    final timestamp = DateTime.now().toIso8601String();
    final dbItemType = _mapUiItemTypeToDb(draft.itemType);
    final categoryId = await _ensureCategory(
      db,
      categoryName: draft.category.trim(),
      itemType: dbItemType,
      timestamp: timestamp,
    );
    final updatedRows = await db.update(
      'items',
      {
        'category_id': categoryId,
        'name': draft.name.trim(),
        'item_type': dbItemType,
        'sale_price': draft.sellingPrice,
        'sku': _normalizedText(draft.sku),
        'stock_qty': draft.isBarang ? (draft.stockQuantity ?? 0) : 0,
        'unit': _normalizedText(draft.unitLabel),
        'harga_modal': draft.isBarang ? draft.costPrice : null,
        'biaya_dasar': !draft.isBarang ? draft.costPrice : null,
        'is_active': draft.isActive ? 1 : 0,
        'wholesale_price': draft.wholesalePrice,
        'wholesale_min_quantity': draft.wholesaleMinQuantity,
        'updated_at': timestamp,
      },
      where: 'id = ?',
      whereArgs: [int.parse(itemId)],
    );

    if (updatedRows == 0) {
      throw const AppException('not_found', 'Item katalog tidak ditemukan.');
    }
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
}
