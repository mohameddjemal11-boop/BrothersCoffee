import '../../core/money.dart';
import '../entities/catalog.dart';

sealed class ImageRefChange {
  const ImageRefChange();
}

class KeepImageRef extends ImageRefChange {
  const KeepImageRef();
}

class RemoveImageRef extends ImageRefChange {
  const RemoveImageRef();
}

class SetImageRef extends ImageRefChange {
  const SetImageRef(this.imageRef);
  final String imageRef;
}

abstract interface class CategoryRepository {
  Future<List<Category>> listActive();
  Future<Category> create({required String name, String? imageRef});
  Future<Category> update({
    required String id,
    String? name,
    ImageRefChange image = const KeepImageRef(),
  });
  Future<void> archive(String id);
  Future<void> reorder(List<String> orderedIds);
  Future<bool> referencesImage(String imageRef, {String? excludingId});
}

abstract interface class ProductRepository {
  Future<List<Product>> listActive({String? categoryId});

  Future<Product> create({
    required String categoryId,
    required String name,
    required Money price,
    String? imageRef,
  });

  Future<Product> update({
    required String id,
    String? categoryId,
    String? name,
    Money? price,
    ImageRefChange image = const KeepImageRef(),
  });

  Future<void> archive(String id);
  Future<void> reorder(String categoryId, List<String> orderedIds);
  Future<bool> referencesImage(String imageRef, {String? excludingId});
}
