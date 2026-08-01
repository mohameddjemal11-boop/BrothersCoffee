import 'package:brothers_coffee_pos/core/money.dart';
import 'package:brothers_coffee_pos/data/database/app_database.dart';
import 'package:brothers_coffee_pos/data/repositories/drift_account_repository.dart';
import 'package:brothers_coffee_pos/data/repositories/drift_catalog_repositories.dart';
import 'package:brothers_coffee_pos/domain/entities/account.dart';
import 'package:brothers_coffee_pos/domain/repositories/catalog_repositories.dart';
import 'package:brothers_coffee_pos/domain/repositories/media_store.dart';
import 'package:brothers_coffee_pos/features/catalog/application/catalog_media_service.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase(NativeDatabase.memory()));
  tearDown(() => database.close());

  test(
    'version 3 schema creates metadata and enforces a single open day',
    () async {
      final accounts = DriftAccountRepository(database);
      final manager = await accounts.bootstrapManager(
        displayName: 'Gérant',
        pin: '1234',
      );
      final now = DateTime.now().toUtc();

      expect(database.schemaVersion, 3);
      expect(
        (await database.select(database.appMetadata).getSingle()).value,
        '3',
      );

      await database
          .into(database.businessDays)
          .insert(
            BusinessDaysCompanion.insert(
              id: 'day-1',
              businessDate: '2026-08-01',
              status: 'open',
              openedAt: now,
              openedByAccountId: manager.id,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await expectLater(
        database
            .into(database.businessDays)
            .insert(
              BusinessDaysCompanion.insert(
                id: 'day-2',
                businessDate: '2026-08-02',
                status: 'open',
                openedAt: now,
                openedByAccountId: manager.id,
                createdAt: now,
                updatedAt: now,
              ),
            ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'manager bootstrap is idempotent and authentication checks active state',
    () async {
      final repository = DriftAccountRepository(database);
      final first = await repository.bootstrapManager(
        displayName: 'Gérant',
        pin: '1234',
      );
      final second = await repository.bootstrapManager(
        displayName: 'Autre',
        pin: '9999',
      );

      expect(second.id, first.id);
      expect(await repository.authenticate(first.id, '1234'), isNotNull);
      expect(await repository.authenticate(first.id, '9999'), isNull);
      await expectLater(
        repository.archiveEmployee(
          managerAccountId: first.id,
          accountId: first.id,
        ),
        throwsA(isA<AccountFailure>()),
      );
    },
  );

  test('catalog supports ordered active lists and cascading archive', () async {
    final categories = DriftCategoryRepository(database);
    final products = DriftProductRepository(database);
    final drinks = await categories.create(name: 'Boissons');
    final food = await categories.create(name: 'Pâtisserie');
    final espresso = await products.create(
      categoryId: drinks.id,
      name: 'Espresso',
      price: const Money(2500),
    );
    final latte = await products.create(
      categoryId: drinks.id,
      name: 'Latte',
      price: const Money(4500),
    );

    await categories.reorder([food.id, drinks.id]);
    expect((await categories.listActive()).map((item) => item.id), [
      food.id,
      drinks.id,
    ]);

    await products.reorder(drinks.id, [latte.id, espresso.id]);
    expect(
      (await products.listActive(categoryId: drinks.id)).map((item) => item.id),
      [latte.id, espresso.id],
    );

    await categories.archive(drinks.id);
    expect(await products.listActive(categoryId: drinks.id), isEmpty);
  });

  test('catalog image references support keep, replace, and remove', () async {
    final categories = DriftCategoryRepository(database);
    final products = DriftProductRepository(database);
    final category = await categories.create(
      name: 'Boissons',
      imageRef: 'media/category.jpg',
    );
    final product = await products.create(
      categoryId: category.id,
      name: 'Espresso',
      price: const Money(2500),
      imageRef: 'media/product.jpg',
    );

    final kept = await products.update(id: product.id, name: 'Café');
    final replaced = await categories.update(
      id: category.id,
      image: const SetImageRef('media/replacement.png'),
    );
    final removed = await products.update(
      id: product.id,
      image: const RemoveImageRef(),
    );

    expect(kept.imageRef, 'media/product.jpg');
    expect(replaced.imageRef, 'media/replacement.png');
    expect(removed.imageRef, isNull);
    expect(await categories.referencesImage('media/replacement.png'), isTrue);
    expect(await products.referencesImage('media/product.jpg'), isFalse);
  });

  test('shared image references remain detectable when duplicated', () async {
    final categories = DriftCategoryRepository(database);
    final products = DriftProductRepository(database);
    final first = await categories.create(
      imageRef: 'media/shared.jpg',
      name: 'A',
    );
    await categories.create(imageRef: 'media/shared.jpg', name: 'B');
    await categories.create(imageRef: 'media/shared.jpg', name: 'C');
    final firstProduct = await products.create(
      categoryId: first.id,
      name: 'One',
      price: const Money(1000),
      imageRef: 'media/shared-product.jpg',
    );
    await products.create(
      categoryId: first.id,
      name: 'Two',
      price: const Money(1000),
      imageRef: 'media/shared-product.jpg',
    );
    await products.create(
      categoryId: first.id,
      name: 'Three',
      price: const Money(1000),
      imageRef: 'media/shared-product.jpg',
    );

    expect(
      await categories.referencesImage(
        'media/shared.jpg',
        excludingId: first.id,
      ),
      isTrue,
    );
    expect(
      await products.referencesImage(
        'media/shared-product.jpg',
        excludingId: firstProduct.id,
      ),
      isTrue,
    );
  });

  test('successful image update survives old-file cleanup failure', () async {
    final categories = DriftCategoryRepository(database);
    final products = DriftProductRepository(database);
    final category = await categories.create(
      name: 'Boissons',
      imageRef: 'media/old.jpg',
    );
    final service = CatalogMediaService(
      categories: categories,
      products: products,
      mediaStore: const _FailingDeleteMediaStore(),
    );

    await categories.update(
      id: category.id,
      image: const SetImageRef('media/new.jpg'),
    );
    await service.deleteIfOrphanBestEffort(
      category.imageRef,
      excludingCategoryId: category.id,
    );

    expect((await categories.listActive()).single.imageRef, 'media/new.jpg');
  });

  test('schema rejects non-product and invalid snapshot sale lines', () async {
    final accounts = DriftAccountRepository(database);
    final manager = await accounts.bootstrapManager(
      displayName: 'Gérant',
      pin: '1234',
    );
    final categories = DriftCategoryRepository(database);
    final category = await categories.create(name: 'Café');
    final products = DriftProductRepository(database);
    final product = await products.create(
      categoryId: category.id,
      name: 'Espresso',
      price: const Money(2000),
    );
    final now = DateTime.now().toUtc();
    await database
        .into(database.businessDays)
        .insert(
          BusinessDaysCompanion.insert(
            id: 'day',
            businessDate: '2026-08-01',
            status: 'closed',
            openedAt: now,
            openedByAccountId: manager.id,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database
        .into(database.sales)
        .insert(
          SalesCompanion.insert(
            id: 'sale',
            businessDayId: 'day',
            displayNumber: 1,
            status: 'confirmed',
            creatorAccountId: manager.id,
            createdAt: now,
            confirmedAt: Value(now),
            totalMillimes: 2000,
          ),
        );

    await expectLater(
      database
          .into(database.saleLines)
          .insert(
            SaleLinesCompanion.insert(
              id: 'line',
              saleId: 'sale',
              productId: product.id,
              productNameSnapshot: 'Espresso',
              unitPriceMillimes: 2000,
              quantity: 0,
              lineTotalMillimes: 0,
              displayOrder: 0,
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });
}

class _FailingDeleteMediaStore implements MediaStore {
  const _FailingDeleteMediaStore();

  @override
  Future<void> delete(String imageRef) => throw StateError('disk failure');

  @override
  Future<String> importImage(PickedImage image) => throw UnimplementedError();

  @override
  Future<Uint8List?> read(String imageRef) async => null;
}
