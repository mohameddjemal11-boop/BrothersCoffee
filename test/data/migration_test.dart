import 'dart:io';

import 'package:brothers_coffee_pos/data/database/app_database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('version 1 database upgrades with finalized-line protection', () async {
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
    await versionOne.customStatement(
      'DROP TRIGGER immutable_final_sale_line_insert',
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

    expect(upgraded.schemaVersion, 2);
    expect(metadata.value, '2');
    expect(trigger?.read<String>('name'), 'immutable_final_sale_line_insert');
  });
}
