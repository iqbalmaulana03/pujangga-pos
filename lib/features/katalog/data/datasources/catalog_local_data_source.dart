import 'dart:math';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/catalog_item_draft.dart';
import '../models/catalog_item_db_model.dart';

class CatalogLocalDataSource {
  CatalogLocalDataSource({required this.database});

  final AppDatabase database;

  Future<List<CatalogItemDbModel>> getItems() async {
    final db = await database.database();
    final rows = await db.query('catalog_items', orderBy: 'updated_at DESC');
    return rows.map(CatalogItemDbModel.fromMap).toList();
  }

  Future<CatalogItemDbModel?> getItemById(String itemId) async {
    final db = await database.database();
    final rows = await db.query(
      'catalog_items',
      where: 'id = ?',
      whereArgs: [itemId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return CatalogItemDbModel.fromMap(rows.first);
  }

  Future<void> createItem(CatalogItemDraft draft) async {
    final db = await database.database();
    final timestamp = DateTime.now().toIso8601String();

    await db.insert('catalog_items', {
      'id': _generateItemId(draft.name),
      'name': draft.name.trim(),
      'category': draft.category.trim(),
      'item_type': draft.itemType,
      'selling_price': draft.sellingPrice,
      'sku': _normalizedText(draft.sku),
      'stock_quantity': draft.isBarang ? (draft.stockQuantity ?? 0) : null,
      'unit_label': _normalizedText(draft.unitLabel),
      'is_active': draft.isActive ? 1 : 0,
      'created_at': timestamp,
      'updated_at': timestamp,
    });
  }

  Future<void> updateItem(String itemId, CatalogItemDraft draft) async {
    final db = await database.database();
    final updatedRows = await db.update(
      'catalog_items',
      {
        'name': draft.name.trim(),
        'category': draft.category.trim(),
        'item_type': draft.itemType,
        'selling_price': draft.sellingPrice,
        'sku': _normalizedText(draft.sku),
        'stock_quantity': draft.isBarang ? (draft.stockQuantity ?? 0) : null,
        'unit_label': _normalizedText(draft.unitLabel),
        'is_active': draft.isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [itemId],
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
      'catalog_items',
      {
        'is_active': isActive ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [itemId],
    );

    if (updatedRows == 0) {
      throw const AppException('not_found', 'Item katalog tidak ditemukan.');
    }
  }

  String _generateItemId(String name) {
    final normalized = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final fallback = normalized.isEmpty ? 'item' : normalized;
    final millis = DateTime.now().millisecondsSinceEpoch;
    final suffix = Random().nextInt(9999).toString().padLeft(4, '0');
    return '$fallback-$millis-$suffix';
  }

  String? _normalizedText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}
