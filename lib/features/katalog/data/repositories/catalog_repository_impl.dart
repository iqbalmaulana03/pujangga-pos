import '../../domain/entities/catalog_item.dart';
import '../../domain/entities/catalog_item_draft.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../datasources/catalog_local_data_source.dart';

class CatalogRepositoryImpl implements CatalogRepository {
  CatalogRepositoryImpl({required this.localDataSource});

  final CatalogLocalDataSource localDataSource;

  @override
  Future<List<CatalogItem>> getItems() async {
    final items = await localDataSource.getItems();
    return items.map((item) => item.toEntity()).toList();
  }

  @override
  Future<CatalogItem?> getItemById(String itemId) async {
    final item = await localDataSource.getItemById(itemId);
    return item?.toEntity();
  }

  @override
  Future<void> createItem(CatalogItemDraft draft) {
    return localDataSource.createItem(draft);
  }

  @override
  Future<void> updateItem(String itemId, CatalogItemDraft draft) {
    return localDataSource.updateItem(itemId, draft);
  }

  @override
  Future<void> updateItemStatus({
    required String itemId,
    required bool isActive,
  }) {
    return localDataSource.updateItemStatus(itemId: itemId, isActive: isActive);
  }
}
