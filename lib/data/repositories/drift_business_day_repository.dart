import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/business_date.dart';
import '../../core/money.dart';
import '../../domain/entities/business_day.dart' as domain;
import '../../domain/entities/enums.dart';
import '../../domain/entities/report.dart' as domain;
import '../../domain/repositories/business_day_repository.dart';
import '../../domain/repositories/report_repository.dart';
import '../database/app_database.dart';

class DriftBusinessDayRepository
    implements BusinessDayRepository, ReportRepository {
  DriftBusinessDayRepository(
    this._database, {
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? const Uuid().v4;

  final AppDatabase _database;
  final DateTime Function() _now;
  final String Function() _newId;

  @override
  Future<domain.BusinessDayRecord?> getOpenDay({
    required String accountId,
  }) async {
    final account = await _activeAccount(accountId);
    final day =
        await (_database.select(_database.businessDays)
              ..where((row) => row.status.equals(BusinessDayStatus.open.name)))
            .getSingleOrNull();
    if (day == null) return null;
    final canViewFinancials = account.role == AccountRole.manager.name;
    final expected = canViewFinancials
        ? await _expectedCashForDay(day.id)
        : null;
    return _mapDay(
      day,
      canViewFinancials: canViewFinancials,
      expectedCash: expected,
    );
  }

  @override
  Future<domain.BusinessDayRecord> closeOpenDay({
    required String accountId,
    Money? countedCash,
  }) async {
    if (countedCash != null && countedCash.millimes < 0) {
      throw const domain.BusinessDayFailure(
        domain.BusinessDayFailureCode.invalidCashCount,
      );
    }

    return _database.transaction(() async {
      final account = await _activeAccount(accountId);
      final day =
          await (_database.select(
                _database.businessDays,
              )..where((row) => row.status.equals(BusinessDayStatus.open.name)))
              .getSingleOrNull();
      if (day == null) {
        throw const domain.BusinessDayFailure(
          domain.BusinessDayFailureCode.noOpenDay,
        );
      }

      final expectedCash = await _expectedCashForDay(day.id);
      final variance = countedCash == null ? null : countedCash - expectedCash;
      final nowUtc = _now().toUtc();
      await (_database.update(
        _database.businessDays,
      )..where((row) => row.id.equals(day.id))).write(
        BusinessDaysCompanion(
          status: Value(BusinessDayStatus.closed.name),
          closedAt: Value(nowUtc),
          closedByAccountId: Value(account.id),
          expectedCashMillimes: Value(expectedCash.millimes),
          countedCashMillimes: Value(countedCash?.millimes),
          varianceMillimes: Value(variance?.millimes),
          updatedAt: Value(nowUtc),
          revision: Value(day.revision + 1),
        ),
      );
      final details = <String, Object?>{
        'expectedCashMillimes': expectedCash.millimes,
        'countedCashMillimes': countedCash?.millimes,
        'varianceMillimes': variance?.millimes,
      };
      await _database
          .into(_database.businessDayEvents)
          .insert(
            BusinessDayEventsCompanion.insert(
              id: _newId(),
              businessDayId: day.id,
              type: BusinessDayEventType.closed.name,
              actorAccountId: account.id,
              occurredAt: nowUtc,
              note: Value(jsonEncode(details)),
            ),
          );
      await _appendAudit(
        type: AuditEventType.businessDayClosed,
        dayId: day.id,
        actorAccountId: account.id,
        occurredAt: nowUtc,
        details: details,
      );

      final closed = await _dayById(day.id);
      final canViewFinancials = account.role == AccountRole.manager.name;
      return _mapDay(
        closed,
        canViewFinancials: canViewFinancials,
        expectedCash: canViewFinancials ? expectedCash : null,
        variance: canViewFinancials ? variance : null,
      );
    });
  }

  @override
  Future<domain.BusinessDayRecord> reopenDay({
    required String managerAccountId,
    required String businessDayId,
    required String reason,
  }) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw const domain.BusinessDayFailure(
        domain.BusinessDayFailureCode.reopenReasonRequired,
      );
    }

    return _database.transaction(() async {
      final manager = await _activeManager(managerAccountId);
      final day = await (_database.select(
        _database.businessDays,
      )..where((row) => row.id.equals(businessDayId))).getSingleOrNull();
      if (day == null) {
        throw const domain.BusinessDayFailure(
          domain.BusinessDayFailureCode.dayNotFound,
        );
      }
      if (day.status != BusinessDayStatus.closed.name) {
        throw const domain.BusinessDayFailure(
          domain.BusinessDayFailureCode.dayNotClosed,
        );
      }
      final otherOpen =
          await (_database.select(
                _database.businessDays,
              )..where((row) => row.status.equals(BusinessDayStatus.open.name)))
              .getSingleOrNull();
      if (otherOpen != null) {
        throw domain.BusinessDayFailure(
          domain.BusinessDayFailureCode.anotherDayOpen,
          otherOpen.businessDate,
        );
      }

      final nowUtc = _now().toUtc();
      await (_database.update(
        _database.businessDays,
      )..where((row) => row.id.equals(day.id))).write(
        BusinessDaysCompanion(
          status: Value(BusinessDayStatus.open.name),
          closedAt: const Value(null),
          closedByAccountId: const Value(null),
          expectedCashMillimes: const Value(null),
          countedCashMillimes: const Value(null),
          varianceMillimes: const Value(null),
          updatedAt: Value(nowUtc),
          revision: Value(day.revision + 1),
        ),
      );
      await _database
          .into(_database.businessDayEvents)
          .insert(
            BusinessDayEventsCompanion.insert(
              id: _newId(),
              businessDayId: day.id,
              type: BusinessDayEventType.reopened.name,
              actorAccountId: manager.id,
              occurredAt: nowUtc,
              reason: Value(normalizedReason),
            ),
          );
      await _appendAudit(
        type: AuditEventType.businessDayReopened,
        dayId: day.id,
        actorAccountId: manager.id,
        occurredAt: nowUtc,
        details: {'reason': normalizedReason},
      );
      return _mapDay(
        await _dayById(day.id),
        canViewFinancials: true,
        expectedCash: await _expectedCashForDay(day.id),
      );
    });
  }

  @override
  Future<domain.SalesReport> buildSalesReport({
    required String managerAccountId,
    required String startDate,
    required String endDate,
  }) async {
    await _requireReportManager(managerAccountId);
    if (!_isBusinessDate(startDate) ||
        !_isBusinessDate(endDate) ||
        startDate.compareTo(endDate) > 0) {
      throw const domain.ReportFailure(
        domain.ReportFailureCode.invalidDateRange,
      );
    }

    final dayRows =
        await (_database.select(_database.businessDays)
              ..where(
                (row) =>
                    row.businessDate.isBiggerOrEqualValue(startDate) &
                    row.businessDate.isSmallerOrEqualValue(endDate),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.businessDate)]))
            .get();
    final dayIds = dayRows.map((day) => day.id).toList(growable: false);
    if (dayIds.isEmpty) {
      return domain.SalesReport(
        startDate: startDate,
        endDate: endDate,
        grossSales: const Money.zero(),
        cancellations: const Money.zero(),
        netSales: const Money.zero(),
        confirmedSaleCount: 0,
        cancelledSaleCount: 0,
        days: const [],
        products: const [],
        categories: const [],
        employees: const [],
      );
    }

    final saleRows =
        await (_database.select(_database.sales)..where(
              (row) =>
                  row.businessDayId.isIn(dayIds) &
                  row.status.isIn([
                    SaleStatus.confirmed.name,
                    SaleStatus.cancelled.name,
                  ]),
            ))
            .get();
    var grossMillimes = 0;
    var cancellationMillimes = 0;
    var confirmedCount = 0;
    var cancelledCount = 0;
    final confirmedSales = <String, Sale>{};
    for (final sale in saleRows) {
      grossMillimes += sale.totalMillimes;
      if (sale.status == SaleStatus.cancelled.name) {
        cancellationMillimes += sale.totalMillimes;
        cancelledCount++;
      } else {
        confirmedSales[sale.id] = sale;
        confirmedCount++;
      }
    }

    final productTotals = <String, _Aggregate>{};
    final categoryTotals = <String, _Aggregate>{};
    if (confirmedSales.isNotEmpty) {
      final lines = await (_database.select(
        _database.saleLines,
      )..where((row) => row.saleId.isIn(confirmedSales.keys))).get();
      final productIds = lines.map((line) => line.productId).toSet();
      final categoryIds = lines
          .map((line) => line.categoryIdSnapshot)
          .whereType<String>()
          .toSet();
      final productRows = productIds.isEmpty
          ? const <Product>[]
          : await (_database.select(
              _database.products,
            )..where((row) => row.id.isIn(productIds))).get();
      final categoryRows = categoryIds.isEmpty
          ? const <Category>[]
          : await (_database.select(
              _database.categories,
            )..where((row) => row.id.isIn(categoryIds))).get();
      final productNames = {
        for (final product in productRows) product.id: product.name,
      };
      final categoryNames = {
        for (final category in categoryRows) category.id: category.name,
      };
      for (final line in lines) {
        productTotals
            .putIfAbsent(
              line.productId,
              () => _Aggregate(
                productNames[line.productId] ?? line.productNameSnapshot,
              ),
            )
            .add(line.quantity, line.lineTotalMillimes);
        final categoryId = line.categoryIdSnapshot ?? '';
        categoryTotals
            .putIfAbsent(
              categoryId,
              () => _Aggregate(
                categoryNames[line.categoryIdSnapshot] ??
                    line.categoryNameSnapshot ??
                    '',
              ),
            )
            .add(line.quantity, line.lineTotalMillimes);
      }
    }

    final creatorIds = confirmedSales.values
        .map((sale) => sale.creatorAccountId)
        .toSet();
    final accountRows = creatorIds.isEmpty
        ? const <Account>[]
        : await (_database.select(
            _database.accounts,
          )..where((row) => row.id.isIn(creatorIds))).get();
    final accountNames = {
      for (final account in accountRows) account.id: account.displayName,
    };
    final employeeTotals = <String, _Aggregate>{};
    for (final sale in confirmedSales.values) {
      employeeTotals
          .putIfAbsent(
            sale.creatorAccountId,
            () => _Aggregate(accountNames[sale.creatorAccountId] ?? ''),
          )
          .add(1, sale.totalMillimes);
    }

    final days = <domain.BusinessDayRecord>[];
    for (final day in dayRows) {
      final expected = day.status == BusinessDayStatus.open.name
          ? await _expectedCashForDay(day.id)
          : Money(day.expectedCashMillimes ?? 0);
      days.add(_mapDay(day, canViewFinancials: true, expectedCash: expected));
    }

    return domain.SalesReport(
      startDate: startDate,
      endDate: endDate,
      grossSales: Money(grossMillimes),
      cancellations: Money(cancellationMillimes),
      netSales: Money(grossMillimes - cancellationMillimes),
      confirmedSaleCount: confirmedCount,
      cancelledSaleCount: cancelledCount,
      days: days,
      products: _rows(productTotals),
      categories: _rows(categoryTotals),
      employees: _rows(employeeTotals),
    );
  }

  Future<Account> _activeAccount(String accountId) async {
    final account =
        await (_database.select(_database.accounts)..where(
              (row) => row.id.equals(accountId) & row.isActive.equals(true),
            ))
            .getSingleOrNull();
    if (account == null) {
      throw const domain.BusinessDayFailure(
        domain.BusinessDayFailureCode.inactiveAccount,
      );
    }
    return account;
  }

  Future<Account> _activeManager(String accountId) async {
    final account = await _activeAccount(accountId);
    if (account.role != AccountRole.manager.name) {
      throw const domain.BusinessDayFailure(
        domain.BusinessDayFailureCode.managerRequired,
      );
    }
    return account;
  }

  Future<void> _requireReportManager(String accountId) async {
    final account =
        await (_database.select(_database.accounts)..where(
              (row) => row.id.equals(accountId) & row.isActive.equals(true),
            ))
            .getSingleOrNull();
    if (account == null) {
      throw const domain.ReportFailure(
        domain.ReportFailureCode.inactiveAccount,
      );
    }
    if (account.role != AccountRole.manager.name) {
      throw const domain.ReportFailure(
        domain.ReportFailureCode.managerRequired,
      );
    }
  }

  Future<BusinessDay> _dayById(String id) => (_database.select(
    _database.businessDays,
  )..where((row) => row.id.equals(id))).getSingle();

  Future<Money> _expectedCashForDay(String businessDayId) async {
    final sales =
        await (_database.select(_database.sales)..where(
              (row) =>
                  row.businessDayId.equals(businessDayId) &
                  row.status.equals(SaleStatus.confirmed.name),
            ))
            .get();
    return Money(sales.fold(0, (total, sale) => total + sale.totalMillimes));
  }

  domain.BusinessDayRecord _mapDay(
    BusinessDay day, {
    required bool canViewFinancials,
    Money? expectedCash,
    Money? variance,
  }) => domain.BusinessDayRecord(
    id: day.id,
    businessDate: day.businessDate,
    status: BusinessDayStatus.values.byName(day.status),
    openedAt: day.openedAt,
    openedByAccountId: day.openedByAccountId,
    closedAt: day.closedAt,
    closedByAccountId: day.closedByAccountId,
    canViewFinancials: canViewFinancials,
    expectedCash: canViewFinancials
        ? expectedCash ??
              (day.expectedCashMillimes == null
                  ? null
                  : Money(day.expectedCashMillimes!))
        : null,
    countedCash: day.countedCashMillimes == null
        ? null
        : Money(day.countedCashMillimes!),
    variance: canViewFinancials
        ? variance ??
              (day.varianceMillimes == null
                  ? null
                  : Money(day.varianceMillimes!))
        : null,
  );

  Future<void> _appendAudit({
    required AuditEventType type,
    required String dayId,
    required String actorAccountId,
    required DateTime occurredAt,
    required Map<String, Object?> details,
  }) => _database
      .into(_database.auditEvents)
      .insert(
        AuditEventsCompanion.insert(
          id: _newId(),
          type: type.name,
          entityType: 'business_day',
          entityId: Value(dayId),
          actorAccountId: Value(actorAccountId),
          occurredAt: occurredAt,
          detailsJson: Value(jsonEncode(details)),
        ),
      );

  bool _isBusinessDate(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final parsed = DateTime.tryParse(value);
    return parsed != null && businessDateFor(parsed) == value;
  }

  List<domain.ReportBreakdownRow> _rows(Map<String, _Aggregate> totals) {
    final rows = totals.entries
        .map(
          (entry) => domain.ReportBreakdownRow(
            id: entry.key,
            label: entry.value.label,
            quantity: entry.value.quantity,
            value: Money(entry.value.millimes),
          ),
        )
        .toList();
    rows.sort(
      (left, right) => right.value.millimes.compareTo(left.value.millimes),
    );
    return rows;
  }
}

class _Aggregate {
  _Aggregate(this.label);

  final String label;
  int quantity = 0;
  int millimes = 0;

  void add(int addedQuantity, int addedMillimes) {
    quantity += addedQuantity;
    millimes += addedMillimes;
  }
}
