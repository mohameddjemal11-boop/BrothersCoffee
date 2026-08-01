import 'package:brothers_coffee_pos/app/theme/app_theme.dart';
import 'package:brothers_coffee_pos/core/money.dart';
import 'package:brothers_coffee_pos/domain/entities/account.dart';
import 'package:brothers_coffee_pos/domain/entities/business_day.dart';
import 'package:brothers_coffee_pos/domain/entities/enums.dart';
import 'package:brothers_coffee_pos/domain/entities/report.dart';
import 'package:brothers_coffee_pos/domain/entities/sale.dart';
import 'package:brothers_coffee_pos/domain/repositories/business_day_repository.dart';
import 'package:brothers_coffee_pos/domain/repositories/report_repository.dart';
import 'package:brothers_coffee_pos/domain/repositories/sale_repository.dart';
import 'package:brothers_coffee_pos/features/reports/presentation/reports_screen.dart';
import 'package:brothers_coffee_pos/features/sales/presentation/sales_history_screen.dart';
import 'package:brothers_coffee_pos/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 1, 20);
  final manager = Account(
    id: 'manager',
    displayName: 'Responsable',
    role: AccountRole.manager,
    isActive: true,
    createdAt: now,
    updatedAt: now,
    revision: 1,
  );

  testWidgets('reopen reason controller lives through dialog dismissal', (
    tester,
  ) async {
    final repository = _Reports(now);
    await tester.pumpWidget(
      _localizedApp(
        ReportsScreen(
          manager: manager,
          businessDays: repository,
          reports: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Rouvrir la journée'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Correction de caisse');
    await tester.tap(find.text('Confirmer la réouverture'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.reopenReason, 'Correction de caisse');
    expect(find.text('La journée a été rouverte.'), findsOneWidget);
  });

  testWidgets('cancellation reason controller lives through dialog dismissal', (
    tester,
  ) async {
    final repository = _Sales(now);
    await tester.pumpWidget(
      _localizedApp(SalesHistoryScreen(manager: manager, sales: repository)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('V-20260801-001'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annuler la vente'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Erreur de saisie');
    await tester.tap(find.text('Confirmer l’annulation'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(repository.cancellationReason, 'Erreur de saisie');
  });
}

Widget _localizedApp(Widget home) => MaterialApp(
  locale: const Locale('fr'),
  theme: AppTheme.light,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

class _Reports implements BusinessDayRepository, ReportRepository {
  _Reports(this.now);

  final DateTime now;
  String? reopenReason;

  BusinessDayRecord get _day => BusinessDayRecord(
    id: 'day',
    businessDate: '2026-08-01',
    status: reopenReason == null
        ? BusinessDayStatus.closed
        : BusinessDayStatus.open,
    openedAt: now,
    openedByAccountId: 'manager',
    closedAt: reopenReason == null ? now : null,
    closedByAccountId: reopenReason == null ? 'manager' : null,
    canViewFinancials: true,
    expectedCash: const Money(2500),
  );

  @override
  Future<SalesReport> buildSalesReport({
    required String managerAccountId,
    required String startDate,
    required String endDate,
  }) async => SalesReport(
    startDate: startDate,
    endDate: endDate,
    grossSales: const Money(2500),
    cancellations: const Money.zero(),
    netSales: const Money(2500),
    confirmedSaleCount: 1,
    cancelledSaleCount: 0,
    days: [_day],
    products: const [],
    categories: const [],
    employees: const [],
  );

  @override
  Future<BusinessDayRecord?> getOpenDay({required String accountId}) async =>
      reopenReason == null ? null : _day;

  @override
  Future<BusinessDayRecord> closeOpenDay({
    required String accountId,
    Money? countedCash,
  }) => throw UnimplementedError();

  @override
  Future<BusinessDayRecord> reopenDay({
    required String managerAccountId,
    required String businessDayId,
    required String reason,
  }) async {
    reopenReason = reason;
    return _day;
  }
}

class _Sales implements SaleRepository {
  _Sales(this.now);

  final DateTime now;
  String? cancellationReason;

  SaleRecord get _sale => SaleRecord(
    id: 'sale',
    businessDayId: 'day',
    businessDate: '2026-08-01',
    displayNumber: 1,
    status: cancellationReason == null
        ? SaleStatus.confirmed
        : SaleStatus.cancelled,
    creatorAccountId: 'employee',
    creatorName: 'Serveur',
    confirmedAt: now,
    total: const Money(2500),
    lines: const [
      SaleLineSnapshot(
        id: 'line',
        productId: 'espresso',
        productName: 'Espresso',
        unitPrice: Money(2500),
        quantity: 1,
        lineTotal: Money(2500),
        displayOrder: 0,
      ),
    ],
    cancellationReason: cancellationReason,
  );

  @override
  Future<List<SaleRecord>> listForBusinessDate({
    required String managerAccountId,
    required String businessDate,
  }) async => [_sale];

  @override
  Future<SaleRecord> cancelSale({
    required String managerAccountId,
    required String saleId,
    required String reason,
  }) async {
    cancellationReason = reason;
    return _sale;
  }

  @override
  Future<SaleRecord> confirmCashSale({
    required String accountId,
    required List<SaleDraftLine> lines,
  }) => throw UnimplementedError();
}
