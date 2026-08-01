import 'dart:io';

import 'package:brothers_coffee_pos/core/money.dart';
import 'package:brothers_coffee_pos/data/database/app_database.dart';
import 'package:brothers_coffee_pos/data/repositories/drift_account_repository.dart';
import 'package:brothers_coffee_pos/data/repositories/drift_catalog_repositories.dart';
import 'package:brothers_coffee_pos/data/repositories/drift_sale_repository.dart';
import 'package:brothers_coffee_pos/domain/entities/sale.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('version 1 database upgrades through schema version 3', () async {
    final directory = await Directory.systemTemp.createTemp(
      'brothers-coffee-migration-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    final file = File('${directory.path}${Platform.pathSeparator}app.sqlite');

    final versionOne = AppDatabase(NativeDatabase(file));
    await versionOne.customSelect('SELECT 1').getSingle();
    final accounts = DriftAccountRepository(versionOne);
    final categories = DriftCategoryRepository(versionOne);
    final products = DriftProductRepository(versionOne);
    final manager = await accounts.bootstrapManager(
      displayName: 'Responsable',
      pin: '1234',
    );
    final category = await categories.create(name: 'Cafés');
    final product = await products.create(
      categoryId: category.id,
      name: 'Espresso',
      price: const Money(2500),
    );
    var idCounter = 0;
    await DriftSaleRepository(
      versionOne,
      now: () => DateTime(2026, 8, 1, 10),
      newId: () => 'migration-${idCounter++}',
    ).confirmCashSale(
      accountId: manager.id,
      lines: [SaleDraftLine(productId: product.id, quantity: 1)],
    );
    await versionOne.customStatement(
      'DROP TRIGGER immutable_final_sale_line_insert',
    );
    await versionOne.customStatement('DROP TRIGGER business_day_state_guard');
    await versionOne.customStatement(
      'ALTER TABLE sale_lines DROP COLUMN category_name_snapshot',
    );
    await versionOne.customStatement(
      'ALTER TABLE sale_lines DROP COLUMN category_id_snapshot',
    );
    await (versionOne.update(
      versionOne.appMetadata,
    )..where((row) => row.key.equals('schema_version'))).write(
      AppMetadataCompanion(
        value: const Value('1'),
        updatedAt: Value(DateTime.utc(2026, 8, 1)),
      ),
    );
    await versionOne.customStatement('PRAGMA user_version = 1');
    await versionOne.close();

    final upgraded = AppDatabase(NativeDatabase(file));
    addTearDown(upgraded.close);
    final metadata = await upgraded.select(upgraded.appMetadata).getSingle();
    final trigger = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' "
          "AND name = 'immutable_final_sale_line_insert'",
        )
        .getSingleOrNull();
    final dayTrigger = await upgraded
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' "
          "AND name = 'business_day_state_guard'",
        )
        .getSingleOrNull();
    final lineColumns = await upgraded
        .customSelect('PRAGMA table_info(sale_lines)')
        .get();
    final migratedLine = await upgraded
        .customSelect(
          'SELECT category_id_snapshot, category_name_snapshot '
          'FROM sale_lines',
        )
        .getSingle();

    expect(upgraded.schemaVersion, 3);
    expect(metadata.value, '3');
    expect(trigger?.read<String>('name'), 'immutable_final_sale_line_insert');
    expect(dayTrigger?.read<String>('name'), 'business_day_state_guard');
    expect(
      lineColumns.map((row) => row.read<String>('name')),
      containsAll(['category_id_snapshot', 'category_name_snapshot']),
    );
    expect(migratedLine.read<String>('category_id_snapshot'), category.id);
    expect(migratedLine.read<String>('category_name_snapshot'), 'Cafés');
  });
}
