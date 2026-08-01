import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Accounts,
    Categories,
    Products,
    BusinessDays,
    BusinessDayEvents,
    Sales,
    SaleLines,
    SaleNumberSequences,
    AuditEvents,
    AppMetadata,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.defaults() : super(driftDatabase(name: 'brothers_coffee'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await customStatement(
        "CREATE UNIQUE INDEX business_days_single_open "
        "ON business_days(status) WHERE status = 'open'",
      );
      await customStatement('''
        CREATE TRIGGER immutable_final_sale_delete
        BEFORE DELETE ON sales
        WHEN OLD.status IN ('confirmed', 'cancelled')
        BEGIN SELECT RAISE(ABORT, 'final sales cannot be deleted'); END
      ''');
      await customStatement('''
        CREATE TRIGGER immutable_final_sale_update
        BEFORE UPDATE ON sales
        WHEN OLD.status IN ('confirmed', 'cancelled') AND NOT (
          OLD.status = 'confirmed' AND NEW.status = 'cancelled'
          AND NEW.id IS OLD.id
          AND NEW.business_day_id IS OLD.business_day_id
          AND NEW.display_number IS OLD.display_number
          AND NEW.payment_method IS OLD.payment_method
          AND NEW.creator_account_id IS OLD.creator_account_id
          AND NEW.created_at IS OLD.created_at
          AND NEW.confirmed_at IS OLD.confirmed_at
          AND NEW.total_millimes IS OLD.total_millimes
        )
        BEGIN SELECT RAISE(ABORT, 'final sale fields are immutable'); END
      ''');
      await customStatement('''
        CREATE TRIGGER immutable_final_sale_line_update
        BEFORE UPDATE ON sale_lines
        WHEN EXISTS (SELECT 1 FROM sales WHERE sales.id = OLD.sale_id
          AND sales.status IN ('confirmed', 'cancelled'))
        BEGIN SELECT RAISE(ABORT, 'final sale lines are immutable'); END
      ''');
      await customStatement('''
        CREATE TRIGGER immutable_final_sale_line_delete
        BEFORE DELETE ON sale_lines
        WHEN EXISTS (SELECT 1 FROM sales WHERE sales.id = OLD.sale_id
          AND sales.status IN ('confirmed', 'cancelled'))
        BEGIN SELECT RAISE(ABORT, 'final sale lines are immutable'); END
      ''');
      await _createFinalSaleLineInsertTrigger();
      await into(appMetadata).insert(
        AppMetadataCompanion.insert(
          key: 'schema_version',
          value: schemaVersion.toString(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );
    },
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await _createFinalSaleLineInsertTrigger();
        await (update(
          appMetadata,
        )..where((row) => row.key.equals('schema_version'))).write(
          AppMetadataCompanion(
            value: Value(schemaVersion.toString()),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
      }
    },
    beforeOpen: (_) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createFinalSaleLineInsertTrigger() => customStatement('''
    CREATE TRIGGER immutable_final_sale_line_insert
    BEFORE INSERT ON sale_lines
    WHEN EXISTS (SELECT 1 FROM sales WHERE sales.id = NEW.sale_id
      AND sales.status IN ('confirmed', 'cancelled'))
    BEGIN SELECT RAISE(ABORT, 'final sale lines are immutable'); END
  ''');
}
