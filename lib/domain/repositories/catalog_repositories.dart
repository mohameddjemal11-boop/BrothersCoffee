import '../../core/money.dart';
import '../entities/catalog.dart';

abstract interface class CategoryRepository {
  Future<List<Category>> listActive();
  Future<Category> create({required String name, String? imageRef});
  Future<Category> update({required String id, String? name, String? imageRef});
  Future<void> archive(String id);
  Future<void> reorder(List<String> orderedIds);
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
    String? imageRef,
  });

  Future<void> archive(String id);
  Future<void> reorder(String categoryId, List<String> orderedIds);
}
