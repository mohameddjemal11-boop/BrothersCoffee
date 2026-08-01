import 'package:brothers_coffee_pos/app/theme/app_theme.dart';
import 'package:brothers_coffee_pos/domain/entities/account.dart';
import 'package:brothers_coffee_pos/domain/entities/enums.dart';
import 'package:brothers_coffee_pos/domain/repositories/account_administration_repository.dart';
import 'package:brothers_coffee_pos/features/accounts/presentation/account_management_screen.dart';
import 'package:brothers_coffee_pos/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('manager creates an employee from the localized account screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final now = DateTime(2026, 8, 1);
    final manager = Account(
      id: 'manager',
      displayName: 'Responsable',
      role: AccountRole.manager,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      revision: 1,
    );
    final repository = _Accounts(manager);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AccountManagementScreen(manager: manager, accounts: repository),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gestion des comptes'), findsOneWidget);
    expect(find.text('Responsable'), findsWidgets);
    await tester.tap(
      find.widgetWithText(FloatingActionButton, 'Ajouter un employé'),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(3));
    await tester.enterText(fields.at(0), 'Amine');
    await tester.enterText(fields.at(1), '5678');
    await tester.enterText(fields.at(2), '5678');
    await tester.tap(find.text('Enregistrer'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();

    expect(repository.createdName, 'Amine');
    expect(repository.createdPin, '5678');
    expect(find.text('Amine'), findsOneWidget);
  });
}

class _Accounts implements AccountAdministrationRepository {
  _Accounts(Account manager) : _accounts = [manager];

  final List<Account> _accounts;
  String? createdName;
  String? createdPin;

  @override
  Future<List<Account>> listForManagement({
    required String managerAccountId,
  }) async => List.unmodifiable(_accounts);

  @override
  Future<Account> createEmployee({
    required String managerAccountId,
    required String displayName,
    required String pin,
  }) async {
    createdName = displayName;
    createdPin = pin;
    final now = DateTime(2026, 8, 1);
    final employee = Account(
      id: 'employee',
      displayName: displayName,
      role: AccountRole.employee,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      revision: 1,
    );
    _accounts.add(employee);
    return employee;
  }

  @override
  Future<void> archiveEmployee({
    required String managerAccountId,
    required String accountId,
  }) async {}

  @override
  Future<Account> updateAccount({
    required String managerAccountId,
    required String accountId,
    String? displayName,
    String? pin,
  }) => throw UnimplementedError();
}
