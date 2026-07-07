import '../entities/stock_adjustment_request.dart';
import '../entities/stock_movement.dart';

abstract class StockRepository {
  Future<List<StockMovement>> getStockMovements(String itemId);
  Future<void> adjustStock(StockAdjustmentRequest request);
}
