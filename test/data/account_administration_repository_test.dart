import 'package:brothers_coffee_pos/data/database/app_database.dart';
import 'package:brothers_coffee_pos/data/repositories/drift_account_repository.dart';
import 'package:brothers_coffee_pos/domain/entities/account.dart';
import 'package:brothers_coffee_pos/domain/entities/enums.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DriftAccountRepository accounts;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    accounts = DriftAccountRepository(database);
  });

  tearDown(() => database.close());

  test('manager administers employees with authorization and audit', () async {
    final manager = await accounts.bootstrapManager(
      displayName: 'Responsable',
      pin: '1234',
    );
    final employee = await accounts.createEmployee(
      managerAccountId: manager.id,
      displayName: 'Serveur',
      pin: '5678',
    );

    expect(
      (await accounts.listForManagement(
        managerAccountId: manager.id,
      )).map((account) => account.id),
      containsAll([manager.id, employee.id]),
    );
    await expectLater(
      accounts.createEmployee(
        managerAccountId: employee.id,
        displayName: 'Interdit',
        pin: '9999',
      ),
      throwsA(_accountFailure(AccountFailureCode.managerRequired)),
    );

    final updated = await accounts.updateAccount(
      managerAccountId: manager.id,
      accountId: employee.id,
      displayName: 'Barista',
      pin: '8765',
    );
    expect(updated.displayName, 'Barista');
    expect(updated.revision, employee.revision + 1);
    expect(await accounts.authenticate(employee.id, '5678'), isNull);
    expect(await accounts.authenticate(employee.id, '8765'), isNotNull);

    await accounts.archiveEmployee(
      managerAccountId: manager.id,
      accountId: employee.id,
    );
    expect(await accounts.authenticate(employee.id, '8765'), isNull);
    expect(
      (await accounts.listActive()).map((account) => account.id),
      isNot(contains(employee.id)),
    );
    await expectLater(
      accounts.archiveEmployee(
        managerAccountId: manager.id,
        accountId: manager.id,
      ),
      throwsA(_accountFailure(AccountFailureCode.cannotArchiveManager)),
    );

    final auditTypes = (await database.select(database.auditEvents).get()).map(
      (event) => event.type,
    );
    expect(
      auditTypes,
      containsAll([
        AuditEventType.managerBootstrap.name,
        AuditEventType.accountCreated.name,
        AuditEventType.accountUpdated.name,
        AuditEventType.accountArchived.name,
      ]),
    );
  });
}

Matcher _accountFailure(AccountFailureCode code) =>
    isA<AccountFailure>().having((failure) => failure.code, 'code', code);
