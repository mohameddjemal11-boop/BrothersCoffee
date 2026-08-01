import 'package:brothers_coffee_pos/core/money.dart';
import 'package:brothers_coffee_pos/data/database/app_database.dart';
import 'package:brothers_coffee_pos/data/repositories/drift_account_repository.dart';
import 'package:brothers_coffee_pos/data/repositories/drift_catalog_repositories.dart';
import 'package:brothers_coffee_pos/data/repositories/drift_sale_repository.dart';
import 'package:brothers_coffee_pos/domain/entities/account.dart' as domain;
import 'package:brothers_coffee_pos/domain/entities/catalog.dart' as domain;
import 'package:brothers_coffee_pos/domain/entities/enums.dart';
import 'package:brothers_coffee_pos/domain/entities/sale.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftAccountRepository accounts;
  late DriftProductRepository products;
  late domain.Account manager;
  late domain.Account employee;
  late domain.Product espresso;
  var idCounter = 0;

  String nextId() => 'sale-test-${idCounter++}';

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    accounts = DriftAccountRepository(database);
    final categories = DriftCategoryRepository(database);
    products = DriftProductRepository(database);
    manager = await accounts.bootstrapManager(
      displayName: 'Responsable',
      pin: '1234',
    );
    employee = await accounts.createEmployee(
      managerAccountId: manager.id,
      displayName: 'Serveur',
      pin: '5678',
    );
    final coffees = await categories.create(name: 'Cafés');
    espresso = await products.create(
      categoryId: coffees.id,
      name: 'Espresso',
      price: const Money(2500),
    );
  });

  tearDown(() => database.close());

  test('confirmation opens a day and allocates sequential numbers', () async {
    final repository = DriftSaleRepository(
      database,
      now: () => DateTime(2026, 8, 1, 10, 30),
      newId: nextId,
    );

    final first = await repository.confirmCashSale(
      accountId: employee.id,
      lines: [SaleDraftLine(productId: espresso.id, quantity: 2)],
    );
    final second = await repository.confirmCashSale(
      accountId: employee.id,
      lines: [SaleDraftLine(productId: espresso.id, quantity: 1)],
    );

    expect(first.businessDate, '2026-08-01');
    expect(first.displayNumber, 1);
    expect(first.total, const Money(5000));
    expect(first.lines.single.productName, 'Espresso');
    expect(first.lines.single.unitPrice, const Money(2500));
    expect(second.displayNumber, 2);
    expect(await database.select(database.businessDays).get(), hasLength(1));
    expect(
      (await database.select(database.businessDayEvents).get()).single.type,
      BusinessDayEventType.opened.name,
    );
  });

  test('history keeps price snapshots after catalogue changes', () async {
    final repository = DriftSaleRepository(
      database,
      now: () => DateTime(2026, 8, 1, 11),
      newId: nextId,
    );
    await repository.confirmCashSale(
      accountId: employee.id,
      lines: [SaleDraftLine(productId: espresso.id, quantity: 1)],
    );
    await products.update(id: espresso.id, price: const Money(3000));

    final history = await repository.listForBusinessDate(
      managerAccountId: manager.id,
      businessDate: '2026-08-01',
    );

    expect(history, hasLength(1));
    expect(history.single.total, const Money(2500));
    expect(history.single.lines.single.unitPrice, const Money(2500));
    await expectLater(
      repository.listForBusinessDate(
        managerAccountId: employee.id,
        businessDate: '2026-08-01',
      ),
      throwsA(_saleFailure(SaleFailureCode.managerRequired)),
    );
  });

  test('manager cancellation requires a reason and preserves lines', () async {
    final repository = DriftSaleRepository(
      database,
      now: () => DateTime(2026, 8, 1, 12),
      newId: nextId,
    );
    final sale = await repository.confirmCashSale(
      accountId: employee.id,
      lines: [SaleDraftLine(productId: espresso.id, quantity: 1)],
    );

    await expectLater(
      repository.cancelSale(
        managerAccountId: manager.id,
        saleId: sale.id,
        reason: '  ',
      ),
      throwsA(_saleFailure(SaleFailureCode.cancellationReasonRequired)),
    );
    final cancelled = await repository.cancelSale(
      managerAccountId: manager.id,
      saleId: sale.id,
      reason: 'Erreur de saisie',
    );

    expect(cancelled.status, SaleStatus.cancelled);
    expect(cancelled.cancellationReason, 'Erreur de saisie');
    expect(cancelled.lines.single.productName, 'Espresso');
    await expectLater(
      repository.cancelSale(
        managerAccountId: manager.id,
        saleId: sale.id,
        reason: 'Encore',
      ),
      throwsA(_saleFailure(SaleFailureCode.saleNotCancellable)),
    );
  });

  test('an older open business day blocks new sales atomically', () async {
    final firstDay = DriftSaleRepository(
      database,
      now: () => DateTime(2026, 8, 1, 23, 59),
      newId: nextId,
    );
    await firstDay.confirmCashSale(
      accountId: employee.id,
      lines: [SaleDraftLine(productId: espresso.id, quantity: 1)],
    );
    final nextDay = DriftSaleRepository(
      database,
      now: () => DateTime(2026, 8, 2, 0, 1),
      newId: nextId,
    );

    await expectLater(
      nextDay.confirmCashSale(
        accountId: employee.id,
        lines: [SaleDraftLine(productId: espresso.id, quantity: 1)],
      ),
      throwsA(_saleFailure(SaleFailureCode.previousBusinessDayOpen)),
    );
    expect(await database.select(database.sales).get(), hasLength(1));
    expect(
      (await database.select(database.saleNumberSequences).get())
          .single
          .nextNumber,
      2,
    );
  });

  test('late line insertion into a confirmed sale is rejected', () async {
    final repository = DriftSaleRepository(
      database,
      now: () => DateTime(2026, 8, 1, 14),
      newId: nextId,
    );
    final sale = await repository.confirmCashSale(
      accountId: employee.id,
      lines: [SaleDraftLine(productId: espresso.id, quantity: 1)],
    );

    await expectLater(
      database
          .into(database.saleLines)
          .insert(
            SaleLinesCompanion.insert(
              id: 'late-line',
              saleId: sale.id,
              productId: espresso.id,
              productNameSnapshot: 'Espresso',
              unitPriceMillimes: 2500,
              quantity: 1,
              lineTotalMillimes: 2500,
              displayOrder: 1,
            ),
          ),
      throwsA(isA<Exception>()),
    );
  });
}

Matcher _saleFailure(SaleFailureCode code) =>
    isA<SaleFailure>().having((failure) => failure.code, 'code', code);
