import '../../../../core/database/app_database.dart';
import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/stock_adjustment_request.dart';
import '../models/stock_item_db_model.dart';
import '../models/stock_movement_db_model.dart';

class StockLocalDataSource {
  const StockLocalDataSource({required this.database});

  final AppDatabase database;

  Future<List<StockItemDbModel>> getStockItems() async {
    final db = await database.database();
    final rows = await db.rawQuery('''
      SELECT
        items.*,
        categories.name AS category_name
      FROM items
      LEFT JOIN categories ON categories.id = items.category_id
      WHERE items.item_type = 'product'
      ORDER BY items.stock_qty ASC, items.name ASC
    ''');

    return rows.map(StockItemDbModel.fromMap).toList();
  }

  Future<StockItemDbModel?> getStockItemById(String itemId) async {
    final db = await database.database();
    final rows = await db.rawQuery(
      '''
      SELECT
        items.*,
        categories.name AS category_name
      FROM items
      LEFT JOIN categories ON categories.id = items.category_id
      WHERE items.id = ? AND items.item_type = 'product'
      LIMIT 1
      ''',
      [int.parse(itemId)],
    );

    if (rows.isEmpty) {
      return null;
    }

    return StockItemDbModel.fromMap(rows.first);
  }

  Future<List<StockMovementDbModel>> getStockMovements(String itemId) async {
    final db = await database.database();
    final rows = await db.rawQuery(
      '''
      SELECT
        stock_movements.*,
        items.name AS item_name
      FROM stock_movements
      INNER JOIN items ON items.id = stock_movements.item_id
      WHERE stock_movements.item_id = ?
      ORDER BY stock_movements.created_at DESC, stock_movements.id DESC
      ''',
      [int.parse(itemId)],
    );

    return rows.map(StockMovementDbModel.fromMap).toList();
  }

  Future<void> adjustStock(StockAdjustmentRequest request) async {
    final db = await database.database();
    await db.transaction((txn) async {
      final itemId = int.parse(request.itemId);
      final rows = await txn.query(
        'items',
        columns: ['stock_qty', 'item_type', 'name'],
        where: 'id = ?',
        whereArgs: [itemId],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw const AppException('not_found', 'Item stok tidak ditemukan.');
      }

      final item = rows.first;
      if ((item['item_type'] as String) != 'product') {
        throw const AppException(
          'validation_error',
          'Penyesuaian stok hanya berlaku untuk item barang.',
        );
      }

      final currentQty = (item['stock_qty'] as num).toDouble();
      final nextQty = switch (request.adjustmentType) {
        'manual_add' => currentQty + request.quantity,
        'manual_reduce' => currentQty - request.quantity,
        'set_balance' => request.quantity,
        _ => throw const AppException(
          'validation_error',
          'Tipe penyesuaian stok tidak valid.',
        ),
      };

      if (nextQty < 0) {
        throw const AppException(
          'validation_error',
          'Stok akhir tidak boleh negatif.',
        );
      }

      final timestamp = DateTime.now().toIso8601String();
      await txn.update(
        'items',
        {'stock_qty': nextQty, 'updated_at': timestamp},
        where: 'id = ?',
        whereArgs: [itemId],
      );

      await txn.insert('stock_movements', {
        'item_id': itemId,
        'movement_type': request.adjustmentType,
        'qty_change': request.adjustmentType == 'set_balance'
            ? nextQty - currentQty
            : (request.adjustmentType == 'manual_reduce'
                  ? -request.quantity
                  : request.quantity),
        'qty_before': currentQty,
        'qty_after': nextQty,
        'reference_type': 'adjustment',
        'reference_id': null,
        'notes': request.notes,
        'created_at': timestamp,
      });
    });
  }
}
