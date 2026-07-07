import '../../domain/entities/stock_adjustment_request.dart';
import '../../domain/entities/stock_movement.dart';
import '../../domain/repositories/stock_repository.dart';
import '../datasources/stock_local_data_source.dart';

class StockRepositoryImpl implements StockRepository {
  const StockRepositoryImpl({required this.localDataSource});

  final StockLocalDataSource localDataSource;

  @override
  Future<void> adjustStock(StockAdjustmentRequest request) {
    return localDataSource.adjustStock(request);
  }

  @override
  Future<List<StockMovement>> getStockMovements(String itemId) async {
    final rows = await localDataSource.getStockMovements(itemId);
    return rows.map((row) => row.toEntity()).toList();
  }
}
