import 'package:brothers_coffee_pos/core/money.dart';
import 'package:brothers_coffee_pos/data/database/app_database.dart';
import 'package:brothers_coffee_pos/data/repositories/drift_account_repository.dart';
import 'package:brothers_coffee_pos/data/repositories/drift_business_day_repository.dart';
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
  late domain.Account manager;
  late domain.Account employee;
  late domain.Product espresso;
  late domain.Category coffeeCategory;
  late DriftCategoryRepository categories;
  late DriftProductRepository products;
  late DriftSaleRepository sales;
  late DriftBusinessDayRepository businessDays;
  var idCounter = 0;

  String nextId() => 'day-test-${idCounter++}';

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    final accounts = DriftAccountRepository(database);
    categories = DriftCategoryRepository(database);
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
    coffeeCategory = await categories.create(name: 'Cafés');
    espresso = await products.create(
      categoryId: coffeeCategory.id,
      name: 'Espresso',
      price: const Money(2500),
    );
    sales = DriftSaleRepository(
      database,
      now: () => DateTime(2026, 8, 1, 12),
      newId: nextId,
    );
    businessDays = DriftBusinessDayRepository(
      database,
      now: () => DateTime(2026, 8, 1, 18),
      newId: nextId,
    );
  });

  tearDown(() => database.close());

  test(
    'employee close stores exact reconciliation but redacts totals',
    () async {
      await sales.confirmCashSale(
        accountId: employee.id,
        lines: [SaleDraftLine(productId: espresso.id, quantity: 2)],
      );

      final preview = await businessDays.getOpenDay(accountId: employee.id);
      expect(preview, isNotNull);
      expect(preview!.expectedCash, isNull);
      final closed = await businessDays.closeOpenDay(
        accountId: employee.id,
        countedCash: const Money(4500),
      );

      expect(closed.status, BusinessDayStatus.closed);
      expect(closed.expectedCash, isNull);
      expect(closed.variance, isNull);
      expect(closed.countedCash, const Money(4500));
      final stored = await database.select(database.businessDays).getSingle();
      expect(stored.expectedCashMillimes, 5000);
      expect(stored.countedCashMillimes, 4500);
      expect(stored.varianceMillimes, -500);
      expect(
        (await database.select(database.businessDayEvents).get()).map(
          (event) => event.type,
        ),
        [BusinessDayEventType.opened.name, BusinessDayEventType.closed.name],
      );

      await expectLater(
        sales.confirmCashSale(
          accountId: employee.id,
          lines: [SaleDraftLine(productId: espresso.id, quantity: 1)],
        ),
        throwsA(_saleFailure(SaleFailureCode.businessDayClosed)),
      );
    },
  );

  test(
    'report uses current catalogue labels across renamed sale snapshots',
    () async {
      await sales.confirmCashSale(
        accountId: employee.id,
        lines: [SaleDraftLine(productId: espresso.id, quantity: 1)],
      );
      await products.update(id: espresso.id, name: 'Double Espresso');
      await categories.update(id: coffeeCategory.id, name: 'Boissons chaudes');
      await sales.confirmCashSale(
        accountId: employee.id,
        lines: [SaleDraftLine(productId: espresso.id, quantity: 2)],
      );

      final report = await businessDays.buildSalesReport(
        managerAccountId: manager.id,
        startDate: '2026-08-01',
        endDate: '2026-08-01',
      );

      expect(report.products.single.label, 'Double Espresso');
      expect(report.products.single.quantity, 3);
      expect(report.categories.single.label, 'Boissons chaudes');
      expect(report.categories.single.quantity, 3);
    },
  );

  test(
    'manager report is inclusive and excludes cancellations from net',
    () async {
      await sales.confirmCashSale(
        accountId: employee.id,
        lines: [SaleDraftLine(productId: espresso.id, quantity: 2)],
      );
      final cancelled = await sales.confirmCashSale(
        accountId: manager.id,
        lines: [SaleDraftLine(productId: espresso.id, quantity: 1)],
      );
      await sales.cancelSale(
        managerAccountId: manager.id,
        saleId: cancelled.id,
        reason: 'Erreur',
      );
      await businessDays.closeOpenDay(
        accountId: manager.id,
        countedCash: const Money(4500),
      );
      final secondDaySales = DriftSaleRepository(
        database,
        now: () => DateTime(2026, 8, 2, 10),
        newId: nextId,
      );
      await secondDaySales.confirmCashSale(
        accountId: employee.id,
        lines: [SaleDraftLine(productId: espresso.id, quantity: 1)],
      );
      final secondDay = DriftBusinessDayRepository(
        database,
        now: () => DateTime(2026, 8, 2, 18),
        newId: nextId,
      );
      await secondDay.closeOpenDay(accountId: manager.id);

      final report = await businessDays.buildSalesReport(
        managerAccountId: manager.id,
        startDate: '2026-08-01',
        endDate: '2026-08-02',
      );

      expect(report.grossSales, const Money(10000));
      expect(report.cancellations, const Money(2500));
      expect(report.netSales, const Money(7500));
      expect(report.confirmedSaleCount, 2);
      expect(report.cancelledSaleCount, 1);
      expect(report.products.single.quantity, 3);
      expect(report.products.single.value, const Money(7500));
      expect(report.categories.single.label, 'Cafés');
      expect(report.employees.single.label, 'Serveur');
      expect(report.days, hasLength(2));
      expect(
        report.days
            .firstWhere((day) => day.businessDate == '2026-08-01')
            .variance,
        const Money(-500),
      );
      await expectLater(
        businessDays.buildSalesReport(
          managerAccountId: employee.id,
          startDate: '2026-08-01',
          endDate: '2026-08-02',
        ),
        throwsA(isA<Exception>()),
      );
    },
  );

  test(
    'manager reopen requires a reason and preserves the audit trail',
    () async {
      await sales.confirmCashSale(
        accountId: employee.id,
        lines: [SaleDraftLine(productId: espresso.id, quantity: 1)],
      );
      final closed = await businessDays.closeOpenDay(accountId: employee.id);

      await expectLater(
        businessDays.reopenDay(
          managerAccountId: manager.id,
          businessDayId: closed.id,
          reason: ' ',
        ),
        throwsA(isA<Exception>()),
      );
      final reopened = await businessDays.reopenDay(
        managerAccountId: manager.id,
        businessDayId: closed.id,
        reason: 'Vente oubliée',
      );
      final nextSale = await sales.confirmCashSale(
        accountId: employee.id,
        lines: [SaleDraftLine(productId: espresso.id, quantity: 1)],
      );

      expect(reopened.status, BusinessDayStatus.open);
      expect(reopened.closedAt, isNull);
      expect(nextSale.displayNumber, 2);
      final events = await database.select(database.businessDayEvents).get();
      expect(events.map((event) => event.type), [
        BusinessDayEventType.opened.name,
        BusinessDayEventType.closed.name,
        BusinessDayEventType.reopened.name,
      ]);
      expect(events.last.reason, 'Vente oubliée');
    },
  );
}

Matcher _saleFailure(SaleFailureCode code) =>
    isA<SaleFailure>().having((failure) => failure.code, 'code', code);
