import '../entities/catalog_item.dart';
import '../entities/catalog_item_draft.dart';

abstract class CatalogRepository {
  Future<List<CatalogItem>> getItems();
  Future<CatalogItem?> getItemById(String itemId);
  Future<void> createItem(CatalogItemDraft draft);
  Future<void> updateItem(String itemId, CatalogItemDraft draft);
  Future<void> updateItemStatus({
    required String itemId,
    required bool isActive,
  });
}
