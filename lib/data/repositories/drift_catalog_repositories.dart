import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../domain/entities/catalog.dart' as domain;
import '../../domain/repositories/catalog_repositories.dart';
import '../database/app_database.dart';

class DriftCategoryRepository implements CategoryRepository {
  DriftCategoryRepository(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();
  final AppDatabase _database;
  final Uuid _uuid;

  @override
  Future<List<domain.Category>> listActive() async =>
      (await (_database.select(_database.categories)
                ..where((row) => row.isActive.equals(true))
                ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]))
              .get())
          .map(_mapCategory)
          .toList(growable: false);

  @override
  Future<domain.Category> create({
    required String name,
    String? imageRef,
  }) async {
    final existing = await listActive();
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            name: _validName(name),
            imageRef: Value(imageRef),
            sortOrder: existing.isEmpty ? 0 : existing.last.sortOrder + 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return _find(id);
  }

  @override
  Future<domain.Category> update({
    required String id,
    String? name,
    String? imageRef,
  }) async {
    final current = await _findRow(id);
    await (_database.update(
      _database.categories,
    )..where((row) => row.id.equals(id))).write(
      CategoriesCompanion(
        name: name == null ? const Value.absent() : Value(_validName(name)),
        imageRef: imageRef == null ? const Value.absent() : Value(imageRef),
        updatedAt: Value(DateTime.now().toUtc()),
        revision: Value(current.revision + 1),
      ),
    );
    return _find(id);
  }

  @override
  Future<void> archive(String id) async {
    await _database.transaction(() async {
      final current = await _findRow(id);
      final now = DateTime.now().toUtc();
      await (_database.update(
        _database.categories,
      )..where((row) => row.id.equals(id))).write(
        CategoriesCompanion(
          isActive: const Value(false),
          archivedAt: Value(now),
          updatedAt: Value(now),
          revision: Value(current.revision + 1),
        ),
      );
      final childProducts =
          await (_database.select(_database.products)..where(
                (row) => row.categoryId.equals(id) & row.isActive.equals(true),
              ))
              .get();
      for (final product in childProducts) {
        await (_database.update(
          _database.products,
        )..where((row) => row.id.equals(product.id))).write(
          ProductsCompanion(
            isActive: const Value(false),
            archivedAt: Value(now),
            updatedAt: Value(now),
            revision: Value(product.revision + 1),
          ),
        );
      }
    });
  }

  @override
  Future<void> reorder(List<String> orderedIds) async {
    await _database.transaction(() async {
      final active = await listActive();
      _requireExactIds(orderedIds, active.map((item) => item.id));
      for (var index = 0; index < orderedIds.length; index++) {
        final current = active.firstWhere(
          (item) => item.id == orderedIds[index],
        );
        await (_database.update(
          _database.categories,
        )..where((row) => row.id.equals(orderedIds[index]))).write(
          CategoriesCompanion(
            sortOrder: Value(index),
            updatedAt: Value(DateTime.now().toUtc()),
            revision: Value(current.revision + 1),
          ),
        );
      }
    });
  }

  Future<Category> _findRow(String id) async => (_database.select(
    _database.categories,
  )..where((row) => row.id.equals(id))).getSingle();
  Future<domain.Category> _find(String id) async =>
      _mapCategory(await _findRow(id));
}

class DriftProductRepository implements ProductRepository {
  DriftProductRepository(this._database, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();
  final AppDatabase _database;
  final Uuid _uuid;

  @override
  Future<List<domain.Product>> listActive({String? categoryId}) async {
    final query = _database.select(_database.products)
      ..where((row) => row.isActive.equals(true))
      ..orderBy([(row) => OrderingTerm.asc(row.sortOrder)]);
    if (categoryId != null) {
      query.where((row) => row.categoryId.equals(categoryId));
    }
    return (await query.get()).map(_mapProduct).toList(growable: false);
  }

  @override
  Future<domain.Product> create({
    required String categoryId,
    required String name,
    required Money price,
    String? imageRef,
  }) async {
    if (price.millimes < 0) {
      throw ArgumentError.value(price, 'price', 'Must not be negative.');
    }
    await _requireActiveCategory(categoryId);
    final existing = await listActive(categoryId: categoryId);
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _database
        .into(_database.products)
        .insert(
          ProductsCompanion.insert(
            id: id,
            categoryId: categoryId,
            name: _validName(name),
            priceMillimes: price.millimes,
            imageRef: Value(imageRef),
            sortOrder: existing.isEmpty ? 0 : existing.last.sortOrder + 1,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return _find(id);
  }

  @override
  Future<domain.Product> update({
    required String id,
    String? categoryId,
    String? name,
    Money? price,
    String? imageRef,
  }) async {
    final current = await _findRow(id);
    if (categoryId != null) await _requireActiveCategory(categoryId);
    if (price != null && price.millimes < 0) {
      throw ArgumentError.value(price, 'price', 'Must not be negative.');
    }
    await (_database.update(
      _database.products,
    )..where((row) => row.id.equals(id))).write(
      ProductsCompanion(
        categoryId: categoryId == null
            ? const Value.absent()
            : Value(categoryId),
        name: name == null ? const Value.absent() : Value(_validName(name)),
        priceMillimes: price == null
            ? const Value.absent()
            : Value(price.millimes),
        imageRef: imageRef == null ? const Value.absent() : Value(imageRef),
        updatedAt: Value(DateTime.now().toUtc()),
        revision: Value(current.revision + 1),
      ),
    );
    return _find(id);
  }

  @override
  Future<void> archive(String id) async {
    final current = await _findRow(id);
    final now = DateTime.now().toUtc();
    await (_database.update(
      _database.products,
    )..where((row) => row.id.equals(id))).write(
      ProductsCompanion(
        isActive: const Value(false),
        archivedAt: Value(now),
        updatedAt: Value(now),
        revision: Value(current.revision + 1),
      ),
    );
  }

  @override
  Future<void> reorder(String categoryId, List<String> orderedIds) async {
    await _database.transaction(() async {
      final active = await listActive(categoryId: categoryId);
      _requireExactIds(orderedIds, active.map((item) => item.id));
      for (var index = 0; index < orderedIds.length; index++) {
        final current = active.firstWhere(
          (item) => item.id == orderedIds[index],
        );
        await (_database.update(
          _database.products,
        )..where((row) => row.id.equals(orderedIds[index]))).write(
          ProductsCompanion(
            sortOrder: Value(index),
            updatedAt: Value(DateTime.now().toUtc()),
            revision: Value(current.revision + 1),
          ),
        );
      }
    });
  }

  Future<void> _requireActiveCategory(String id) async {
    final row =
        await (_database.select(_database.categories)
              ..where((row) => row.id.equals(id) & row.isActive.equals(true)))
            .getSingleOrNull();
    if (row == null) throw StateError('Category is not active.');
  }

  Future<Product> _findRow(String id) async => (_database.select(
    _database.products,
  )..where((row) => row.id.equals(id))).getSingle();
  Future<domain.Product> _find(String id) async =>
      _mapProduct(await _findRow(id));
}

String _validName(String name) {
  final value = name.trim();
  if (value.isEmpty) {
    throw ArgumentError.value(name, 'name', 'Must not be empty.');
  }
  return value;
}

void _requireExactIds(List<String> requested, Iterable<String> expected) {
  if (requested.length != requested.toSet().length ||
      requested.toSet().difference(expected.toSet()).isNotEmpty ||
      expected.toSet().difference(requested.toSet()).isNotEmpty) {
    throw ArgumentError.value(
      requested,
      'orderedIds',
      'Must contain every active id exactly once.',
    );
  }
}

domain.Category _mapCategory(Category row) => domain.Category(
  id: row.id,
  name: row.name,
  imageRef: row.imageRef,
  isActive: row.isActive,
  sortOrder: row.sortOrder,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  revision: row.revision,
);

domain.Product _mapProduct(Product row) => domain.Product(
  id: row.id,
  categoryId: row.categoryId,
  name: row.name,
  price: Money(row.priceMillimes),
  imageRef: row.imageRef,
  isActive: row.isActive,
  sortOrder: row.sortOrder,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  revision: row.revision,
);
