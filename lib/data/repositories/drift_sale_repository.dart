import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/business_date.dart';
import '../../core/money.dart';
import '../../domain/entities/enums.dart';
import '../../domain/entities/sale.dart' as domain;
import '../../domain/repositories/sale_repository.dart';
import '../database/app_database.dart';

class DriftSaleRepository implements SaleRepository {
  DriftSaleRepository(
    this._database, {
    DateTime Function()? now,
    String Function()? newId,
  }) : _now = now ?? DateTime.now,
       _newId = newId ?? const Uuid().v4;

  final AppDatabase _database;
  final DateTime Function() _now;
  final String Function() _newId;

  @override
  Future<domain.SaleRecord> confirmCashSale({
    required String accountId,
    required List<domain.SaleDraftLine> lines,
  }) async {
    _validateDraft(lines);

    return _database.transaction(() async {
      final account = await _activeAccount(accountId);
      final localNow = _now();
      final nowUtc = localNow.toUtc();
      final businessDate = businessDateFor(localNow);
      final day = await _openOrCreateDay(
        accountId: account.id,
        businessDate: businessDate,
        nowUtc: nowUtc,
      );
      final productRows = await _loadProducts(lines);
      final total = lines.fold(
        const Money.zero(),
        (sum, line) =>
            sum +
            Money(productRows[line.productId]!.priceMillimes) * line.quantity,
      );
      final displayNumber = await _takeNextDisplayNumber(day.id);
      final saleId = _newId();

      await _database
          .into(_database.sales)
          .insert(
            SalesCompanion.insert(
              id: saleId,
              businessDayId: day.id,
              displayNumber: displayNumber,
              status: SaleStatus.draft.name,
              creatorAccountId: account.id,
              createdAt: nowUtc,
              totalMillimes: total.millimes,
            ),
          );

      for (var index = 0; index < lines.length; index++) {
        final draftLine = lines[index];
        final product = productRows[draftLine.productId]!;
        final lineTotal = product.priceMillimes * draftLine.quantity;
        await _database
            .into(_database.saleLines)
            .insert(
              SaleLinesCompanion.insert(
                id: _newId(),
                saleId: saleId,
                productId: product.id,
                productNameSnapshot: product.name,
                unitPriceMillimes: product.priceMillimes,
                quantity: draftLine.quantity,
                lineTotalMillimes: lineTotal,
                displayOrder: index,
              ),
            );
      }

      await (_database.update(
        _database.sales,
      )..where((row) => row.id.equals(saleId))).write(
        SalesCompanion(
          status: Value(SaleStatus.confirmed.name),
          confirmedAt: Value(nowUtc),
        ),
      );
      await _appendAudit(
        type: AuditEventType.saleConfirmed,
        entityId: saleId,
        actorAccountId: account.id,
        occurredAt: nowUtc,
        details: {
          'businessDate': businessDate,
          'displayNumber': displayNumber,
          'totalMillimes': total.millimes,
        },
      );

      return _loadSale(saleId);
    });
  }

  @override
  Future<List<domain.SaleRecord>> listForBusinessDate({
    required String managerAccountId,
    required String businessDate,
  }) async {
    await _activeManager(managerAccountId);
    final days = await (_database.select(
      _database.businessDays,
    )..where((row) => row.businessDate.equals(businessDate))).get();
    if (days.isEmpty) return const [];

    final saleRows =
        await (_database.select(_database.sales)
              ..where(
                (row) =>
                    row.businessDayId.isIn(days.map((day) => day.id)) &
                    row.status.isIn([
                      SaleStatus.confirmed.name,
                      SaleStatus.cancelled.name,
                    ]),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.confirmedAt)]))
            .get();
    final records = <domain.SaleRecord>[];
    for (final sale in saleRows) {
      records.add(await _loadSale(sale.id));
    }
    return records;
  }

  @override
  Future<domain.SaleRecord> cancelSale({
    required String managerAccountId,
    required String saleId,
    required String reason,
  }) async {
    final normalizedReason = reason.trim();
    if (normalizedReason.isEmpty) {
      throw const domain.SaleFailure(
        domain.SaleFailureCode.cancellationReasonRequired,
      );
    }

    return _database.transaction(() async {
      final manager = await _activeManager(managerAccountId);
      final sale = await (_database.select(
        _database.sales,
      )..where((row) => row.id.equals(saleId))).getSingleOrNull();
      if (sale == null) {
        throw const domain.SaleFailure(domain.SaleFailureCode.saleNotFound);
      }
      if (sale.status != SaleStatus.confirmed.name) {
        throw const domain.SaleFailure(
          domain.SaleFailureCode.saleNotCancellable,
        );
      }

      final nowUtc = _now().toUtc();
      await (_database.update(
        _database.sales,
      )..where((row) => row.id.equals(saleId))).write(
        SalesCompanion(
          status: Value(SaleStatus.cancelled.name),
          cancelledByAccountId: Value(manager.id),
          cancelledAt: Value(nowUtc),
          cancellationReason: Value(normalizedReason),
        ),
      );
      await _appendAudit(
        type: AuditEventType.saleCancelled,
        entityId: saleId,
        actorAccountId: manager.id,
        occurredAt: nowUtc,
        details: {'reason': normalizedReason},
      );
      return _loadSale(saleId);
    });
  }

  void _validateDraft(List<domain.SaleDraftLine> lines) {
    if (lines.isEmpty) {
      throw const domain.SaleFailure(domain.SaleFailureCode.emptyBasket);
    }
    final productIds = <String>{};
    for (final line in lines) {
      if (line.quantity <= 0) {
        throw const domain.SaleFailure(domain.SaleFailureCode.invalidQuantity);
      }
      if (!productIds.add(line.productId)) {
        throw const domain.SaleFailure(domain.SaleFailureCode.duplicateProduct);
      }
    }
  }

  Future<Account> _activeAccount(String accountId) async {
    final account =
        await (_database.select(_database.accounts)..where(
              (row) => row.id.equals(accountId) & row.isActive.equals(true),
            ))
            .getSingleOrNull();
    if (account == null) {
      throw const domain.SaleFailure(domain.SaleFailureCode.inactiveAccount);
    }
    return account;
  }

  Future<Account> _activeManager(String accountId) async {
    final account = await _activeAccount(accountId);
    if (account.role != AccountRole.manager.name) {
      throw const domain.SaleFailure(domain.SaleFailureCode.managerRequired);
    }
    return account;
  }

  Future<BusinessDay> _openOrCreateDay({
    required String accountId,
    required String businessDate,
    required DateTime nowUtc,
  }) async {
    final openDay =
        await (_database.select(_database.businessDays)
              ..where((row) => row.status.equals(BusinessDayStatus.open.name)))
            .getSingleOrNull();
    if (openDay != null) {
      if (openDay.businessDate != businessDate) {
        throw domain.SaleFailure(
          domain.SaleFailureCode.previousBusinessDayOpen,
          openDay.businessDate,
        );
      }
      return openDay;
    }

    final dayId = _newId();
    await _database
        .into(_database.businessDays)
        .insert(
          BusinessDaysCompanion.insert(
            id: dayId,
            businessDate: businessDate,
            status: BusinessDayStatus.open.name,
            openedAt: nowUtc,
            openedByAccountId: accountId,
            createdAt: nowUtc,
            updatedAt: nowUtc,
          ),
        );
    await _database
        .into(_database.businessDayEvents)
        .insert(
          BusinessDayEventsCompanion.insert(
            id: _newId(),
            businessDayId: dayId,
            type: BusinessDayEventType.opened.name,
            actorAccountId: accountId,
            occurredAt: nowUtc,
          ),
        );
    return (_database.select(
      _database.businessDays,
    )..where((row) => row.id.equals(dayId))).getSingle();
  }

  Future<Map<String, Product>> _loadProducts(
    List<domain.SaleDraftLine> lines,
  ) async {
    final ids = lines.map((line) => line.productId).toList(growable: false);
    final products = await (_database.select(
      _database.products,
    )..where((row) => row.id.isIn(ids) & row.isActive.equals(true))).get();
    if (products.length != ids.length) {
      throw const domain.SaleFailure(domain.SaleFailureCode.unavailableProduct);
    }
    return {for (final product in products) product.id: product};
  }

  Future<int> _takeNextDisplayNumber(String businessDayId) async {
    final sequence =
        await (_database.select(_database.saleNumberSequences)
              ..where((row) => row.businessDayId.equals(businessDayId)))
            .getSingleOrNull();
    if (sequence == null) {
      await _database
          .into(_database.saleNumberSequences)
          .insert(
            SaleNumberSequencesCompanion.insert(
              businessDayId: businessDayId,
              nextNumber: 2,
            ),
          );
      return 1;
    }
    await (_database.update(
      _database.saleNumberSequences,
    )..where((row) => row.businessDayId.equals(businessDayId))).write(
      SaleNumberSequencesCompanion(nextNumber: Value(sequence.nextNumber + 1)),
    );
    return sequence.nextNumber;
  }

  Future<void> _appendAudit({
    required AuditEventType type,
    required String entityId,
    required String actorAccountId,
    required DateTime occurredAt,
    required Map<String, Object> details,
  }) => _database
      .into(_database.auditEvents)
      .insert(
        AuditEventsCompanion.insert(
          id: _newId(),
          type: type.name,
          entityType: 'sale',
          entityId: Value(entityId),
          actorAccountId: Value(actorAccountId),
          occurredAt: occurredAt,
          detailsJson: Value(jsonEncode(details)),
        ),
      );

  Future<domain.SaleRecord> _loadSale(String saleId) async {
    final sale = await (_database.select(
      _database.sales,
    )..where((row) => row.id.equals(saleId))).getSingle();
    final day = await (_database.select(
      _database.businessDays,
    )..where((row) => row.id.equals(sale.businessDayId))).getSingle();
    final creator = await (_database.select(
      _database.accounts,
    )..where((row) => row.id.equals(sale.creatorAccountId))).getSingle();
    final lineRows =
        await (_database.select(_database.saleLines)
              ..where((row) => row.saleId.equals(saleId))
              ..orderBy([(row) => OrderingTerm.asc(row.displayOrder)]))
            .get();

    return domain.SaleRecord(
      id: sale.id,
      businessDayId: sale.businessDayId,
      businessDate: day.businessDate,
      displayNumber: sale.displayNumber,
      status: SaleStatus.values.byName(sale.status),
      creatorAccountId: sale.creatorAccountId,
      creatorName: creator.displayName,
      confirmedAt: sale.confirmedAt!,
      total: Money(sale.totalMillimes),
      lines: lineRows
          .map(
            (line) => domain.SaleLineSnapshot(
              id: line.id,
              productId: line.productId,
              productName: line.productNameSnapshot,
              unitPrice: Money(line.unitPriceMillimes),
              quantity: line.quantity,
              lineTotal: Money(line.lineTotalMillimes),
              displayOrder: line.displayOrder,
            ),
          )
          .toList(growable: false),
      cancelledAt: sale.cancelledAt,
      cancelledByAccountId: sale.cancelledByAccountId,
      cancellationReason: sale.cancellationReason,
    );
  }
}
