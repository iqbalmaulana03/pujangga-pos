import '../entities/stock_adjustment_request.dart';
import '../entities/stock_item.dart';
import '../entities/stock_movement.dart';

abstract class StockRepository {
  Future<List<StockItem>> getStockItems();
  Future<StockItem?> getStockItemById(String itemId);
  Future<List<StockMovement>> getStockMovements(String itemId);
  Future<void> adjustStock(StockAdjustmentRequest request);
}
