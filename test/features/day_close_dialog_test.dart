import 'package:brothers_coffee_pos/app/theme/app_theme.dart';
import 'package:brothers_coffee_pos/core/money.dart';
import 'package:brothers_coffee_pos/domain/entities/account.dart';
import 'package:brothers_coffee_pos/domain/entities/business_day.dart';
import 'package:brothers_coffee_pos/domain/entities/enums.dart';
import 'package:brothers_coffee_pos/domain/repositories/business_day_repository.dart';
import 'package:brothers_coffee_pos/features/day_close/presentation/day_close_dialog.dart';
import 'package:brothers_coffee_pos/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('employee close dialog hides expected cash and variance', (
    tester,
  ) async {
    final now = DateTime(2026, 8, 1, 18);
    final account = Account(
      id: 'employee',
      displayName: 'Serveur',
      role: AccountRole.employee,
      isActive: true,
      createdAt: now,
      updatedAt: now,
      revision: 1,
    );
    final repository = _BusinessDays(
      BusinessDayRecord(
        id: 'day',
        businessDate: '2026-08-01',
        status: BusinessDayStatus.open,
        openedAt: now,
        openedByAccountId: account.id,
        canViewFinancials: false,
        expectedCash: const Money(5000),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDayCloseDialog(
                context: context,
                account: account,
                businessDays: repository,
              ),
              child: const Text('ouvrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();
    expect(find.text('Espèces attendues'), findsNothing);
    expect(find.text('Écart'), findsNothing);
    expect(
      find.text('Espèces comptées en millimes (facultatif)'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), '4500');
    await tester.tap(find.text('Confirmer la clôture'));
    await tester.pumpAndSettle();

    expect(repository.countedCash, const Money(4500));
    expect(find.text('La journée a été clôturée.'), findsOneWidget);
  });
}

class _BusinessDays implements BusinessDayRepository {
  _BusinessDays(this.day);

  final BusinessDayRecord day;
  Money? countedCash;

  @override
  Future<BusinessDayRecord?> getOpenDay({required String accountId}) async =>
      day;

  @override
  Future<BusinessDayRecord> closeOpenDay({
    required String accountId,
    Money? countedCash,
  }) async {
    this.countedCash = countedCash;
    return day;
  }

  @override
  Future<BusinessDayRecord> reopenDay({
    required String managerAccountId,
    required String businessDayId,
    required String reason,
  }) => throw UnimplementedError();
}
