import 'dart:async';

import 'package:brothers_coffee_pos/app/theme/app_theme.dart';
import 'package:brothers_coffee_pos/core/money.dart';
import 'package:brothers_coffee_pos/domain/entities/account.dart';
import 'package:brothers_coffee_pos/domain/entities/catalog.dart';
import 'package:brothers_coffee_pos/domain/entities/enums.dart';
import 'package:brothers_coffee_pos/domain/entities/sale.dart';
import 'package:brothers_coffee_pos/domain/repositories/catalog_repositories.dart';
import 'package:brothers_coffee_pos/domain/repositories/sale_repository.dart';
import 'package:brothers_coffee_pos/features/pos/presentation/pos_shell_screen.dart';
import 'package:brothers_coffee_pos/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('persists a sale once and clears the basket after success', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 8, 1, 10);
    final category = Category(
      id: 'coffee',
      name: 'Cafés',
      isActive: true,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      revision: 1,
    );
    final product = Product(
      id: 'espresso',
      categoryId: category.id,
      name: 'Espresso',
      price: const Money(2500),
      isActive: true,
      sortOrder: 0,
      createdAt: now,
      updatedAt: now,
      revision: 1,
    );
    final sales = _RecordingSales();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PosShellScreen(
          account: Account(
            id: 'employee',
            displayName: 'Serveur',
            role: AccountRole.employee,
            isActive: true,
            createdAt: now,
            updatedAt: now,
            revision: 1,
          ),
          categories: _Categories(category),
          products: _Products(product),
          sales: sales,
          onSwitchUser: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Espresso').first);
    await tester.pump();
    await tester.tap(find.text('Confirmer la vente'));
    await tester.pump();

    expect(sales.confirmCalls, 1);
    expect(sales.lines.single.productId, 'espresso');
    expect(sales.lines.single.quantity, 1);
    final processingButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Enregistrement…'),
    );
    expect(processingButton.onPressed, isNull);

    sales.complete(
      SaleRecord(
        id: 'sale',
        businessDayId: 'day',
        businessDate: '2026-08-01',
        displayNumber: 1,
        status: SaleStatus.confirmed,
        creatorAccountId: 'employee',
        creatorName: 'Serveur',
        confirmedAt: now,
        total: const Money(2500),
        lines: const [],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Vente confirmée'), findsOneWidget);
    expect(find.text('V-20260801-001'), findsOneWidget);
    await tester.tap(find.text('Fermer'));
    await tester.pumpAndSettle();
    expect(find.text('Touchez un produit pour l’ajouter'), findsOneWidget);
  });
}

class _RecordingSales implements SaleRepository {
  final _confirmation = Completer<SaleRecord>();
  var confirmCalls = 0;
  List<SaleDraftLine> lines = const [];

  void complete(SaleRecord sale) => _confirmation.complete(sale);

  @override
  Future<SaleRecord> confirmCashSale({
    required String accountId,
    required List<SaleDraftLine> lines,
  }) {
    confirmCalls++;
    this.lines = lines;
    return _confirmation.future;
  }

  @override
  Future<SaleRecord> cancelSale({
    required String managerAccountId,
    required String saleId,
    required String reason,
  }) => throw UnimplementedError();

  @override
  Future<List<SaleRecord>> listForBusinessDate({
    required String managerAccountId,
    required String businessDate,
  }) async => const [];
}

class _Categories implements CategoryRepository {
  _Categories(this.category);
  final Category category;

  @override
  Future<List<Category>> listActive() async => [category];

  @override
  Future<void> archive(String id) => throw UnimplementedError();
  @override
  Future<Category> create({required String name, String? imageRef}) =>
      throw UnimplementedError();
  @override
  Future<void> reorder(List<String> orderedIds) => throw UnimplementedError();
  @override
  Future<Category> update({
    required String id,
    String? name,
    String? imageRef,
  }) => throw UnimplementedError();
}

class _Products implements ProductRepository {
  _Products(this.product);
  final Product product;

  @override
  Future<List<Product>> listActive({String? categoryId}) async => [product];

  @override
  Future<void> archive(String id) => throw UnimplementedError();
  @override
  Future<Product> create({
    required String categoryId,
    required String name,
    required Money price,
    String? imageRef,
  }) => throw UnimplementedError();
  @override
  Future<void> reorder(String categoryId, List<String> orderedIds) =>
      throw UnimplementedError();
  @override
  Future<Product> update({
    required String id,
    String? categoryId,
    String? name,
    Money? price,
    String? imageRef,
  }) => throw UnimplementedError();
}
