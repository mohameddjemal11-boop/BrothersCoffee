// Drift's table DSL intentionally refers to a column getter from within that
// getter to define CHECK constraints. The generator rewrites these references.
// ignore_for_file: recursive_getters

import 'package:drift/drift.dart';

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get displayName => text().withLength(min: 1, max: 80)();
  TextColumn get role =>
      text().check(role.isIn(const ['employee', 'manager']))();
  TextColumn get pinHash => text()();
  TextColumn get pinSalt => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get revision => integer()
      .withDefault(const Constant(1))
      .check(revision.isBiggerThanValue(0))();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'categories_active_order', columns: {#isActive, #sortOrder})
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get imageRef => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder =>
      integer().check(sortOrder.isBiggerOrEqualValue(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get revision => integer()
      .withDefault(const Constant(1))
      .check(revision.isBiggerThanValue(0))();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'products_catalog_order',
  columns: {#categoryId, #isActive, #sortOrder},
)
class Products extends Table {
  TextColumn get id => text()();
  TextColumn get categoryId =>
      text().references(Categories, #id, onDelete: KeyAction.restrict)();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get priceMillimes =>
      integer().check(priceMillimes.isBiggerOrEqualValue(0))();
  TextColumn get imageRef => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder =>
      integer().check(sortOrder.isBiggerOrEqualValue(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get revision => integer()
      .withDefault(const Constant(1))
      .check(revision.isBiggerThanValue(0))();
  DateTimeColumn get archivedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(name: 'business_days_date', columns: {#businessDate})
class BusinessDays extends Table {
  TextColumn get id => text()();
  TextColumn get businessDate => text().withLength(min: 10, max: 10)();
  TextColumn get status =>
      text().check(status.isIn(const ['open', 'closed']))();
  DateTimeColumn get openedAt => dateTime()();
  @ReferenceName('daysOpenedByAccount')
  TextColumn get openedByAccountId =>
      text().references(Accounts, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get closedAt => dateTime().nullable()();
  @ReferenceName('daysClosedByAccount')
  TextColumn get closedByAccountId => text().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.restrict,
  )();
  IntColumn get expectedCashMillimes => integer().nullable().check(
    expectedCashMillimes.isBiggerOrEqualValue(0),
  )();
  IntColumn get countedCashMillimes =>
      integer().nullable().check(countedCashMillimes.isBiggerOrEqualValue(0))();
  IntColumn get varianceMillimes => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get revision => integer()
      .withDefault(const Constant(1))
      .check(revision.isBiggerThanValue(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {businessDate},
  ];
}

@TableIndex(
  name: 'business_day_events_day_time',
  columns: {#businessDayId, #occurredAt},
)
class BusinessDayEvents extends Table {
  TextColumn get id => text()();
  TextColumn get businessDayId =>
      text().references(BusinessDays, #id, onDelete: KeyAction.restrict)();
  TextColumn get type =>
      text().check(type.isIn(const ['opened', 'closed', 'reopened']))();
  TextColumn get actorAccountId =>
      text().references(Accounts, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get reason => text().nullable()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@TableIndex(
  name: 'sales_day_status_time',
  columns: {#businessDayId, #status, #confirmedAt},
)
class Sales extends Table {
  TextColumn get id => text()();
  TextColumn get businessDayId =>
      text().references(BusinessDays, #id, onDelete: KeyAction.restrict)();
  IntColumn get displayNumber =>
      integer().check(displayNumber.isBiggerThanValue(0))();
  TextColumn get status =>
      text().check(status.isIn(const ['draft', 'confirmed', 'cancelled']))();
  TextColumn get paymentMethod => text()
      .withDefault(const Constant('cash'))
      .check(paymentMethod.equals('cash'))();
  @ReferenceName('salesCreatedByAccount')
  TextColumn get creatorAccountId =>
      text().references(Accounts, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get confirmedAt => dateTime().nullable()();
  IntColumn get totalMillimes =>
      integer().check(totalMillimes.isBiggerOrEqualValue(0))();
  @ReferenceName('salesCancelledByAccount')
  TextColumn get cancelledByAccountId => text().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.restrict,
  )();
  DateTimeColumn get cancelledAt => dateTime().nullable()();
  TextColumn get cancellationReason => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {businessDayId, displayNumber},
  ];

  @override
  List<String> get customConstraints => [
    "CHECK (status = 'draft' OR confirmed_at IS NOT NULL)",
    "CHECK (status != 'cancelled' OR "
        "(cancelled_by_account_id IS NOT NULL AND cancelled_at IS NOT NULL "
        "AND length(trim(cancellation_reason)) > 0))",
  ];
}

@TableIndex(name: 'sale_lines_sale', columns: {#saleId})
class SaleLines extends Table {
  TextColumn get id => text()();
  TextColumn get saleId =>
      text().references(Sales, #id, onDelete: KeyAction.restrict)();
  TextColumn get productId =>
      text().references(Products, #id, onDelete: KeyAction.restrict)();
  TextColumn get productNameSnapshot => text().withLength(min: 1, max: 120)();
  TextColumn get categoryIdSnapshot => text().nullable()();
  TextColumn get categoryNameSnapshot => text().nullable()();
  IntColumn get unitPriceMillimes =>
      integer().check(unitPriceMillimes.isBiggerOrEqualValue(0))();
  IntColumn get quantity => integer().check(quantity.isBiggerThanValue(0))();
  IntColumn get lineTotalMillimes =>
      integer().check(lineTotalMillimes.isBiggerOrEqualValue(0))();
  IntColumn get displayOrder =>
      integer().check(displayOrder.isBiggerOrEqualValue(0))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (line_total_millimes = unit_price_millimes * quantity)',
  ];
}

class SaleNumberSequences extends Table {
  TextColumn get businessDayId =>
      text().references(BusinessDays, #id, onDelete: KeyAction.restrict)();
  IntColumn get nextNumber =>
      integer().check(nextNumber.isBiggerThanValue(0))();

  @override
  Set<Column<Object>> get primaryKey => {businessDayId};
}

@TableIndex(
  name: 'audit_events_entity_time',
  columns: {#entityType, #entityId, #occurredAt},
)
class AuditEvents extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text().nullable()();
  TextColumn get actorAccountId => text().nullable().references(
    Accounts,
    #id,
    onDelete: KeyAction.restrict,
  )();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get detailsJson => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AppMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
