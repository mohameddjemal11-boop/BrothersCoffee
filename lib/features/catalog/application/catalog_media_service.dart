import '../../../domain/repositories/catalog_repositories.dart';
import '../../../domain/repositories/media_store.dart';

class CatalogMediaService {
  const CatalogMediaService({
    required this.categories,
    required this.products,
    required this.mediaStore,
  });

  final CategoryRepository categories;
  final ProductRepository products;
  final MediaStore mediaStore;

  Future<String?> import(PickedImage? image) =>
      image == null ? Future.value() : mediaStore.importImage(image);

  Future<void> discard(String? imageRef) async {
    if (imageRef != null) await mediaStore.delete(imageRef);
  }

  Future<void> deleteIfOrphan(
    String? imageRef, {
    String? excludingCategoryId,
    String? excludingProductId,
  }) async {
    if (imageRef == null) return;
    final categoryReference = await categories.referencesImage(
      imageRef,
      excludingId: excludingCategoryId,
    );
    final productReference = await products.referencesImage(
      imageRef,
      excludingId: excludingProductId,
    );
    if (!categoryReference && !productReference) {
      await mediaStore.delete(imageRef);
    }
  }

  Future<void> deleteIfOrphanBestEffort(
    String? imageRef, {
    String? excludingCategoryId,
    String? excludingProductId,
  }) async {
    try {
      await deleteIfOrphan(
        imageRef,
        excludingCategoryId: excludingCategoryId,
        excludingProductId: excludingProductId,
      );
    } catch (_) {
      // Database state is already authoritative; cleanup can be retried later.
    }
  }
}
