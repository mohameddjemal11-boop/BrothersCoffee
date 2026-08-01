import '../entities/account.dart';

abstract interface class AccountAdministrationRepository {
  Future<List<Account>> listForManagement({required String managerAccountId});

  Future<Account> createEmployee({
    required String managerAccountId,
    required String displayName,
    required String pin,
  });

  Future<Account> updateAccount({
    required String managerAccountId,
    required String accountId,
    String? displayName,
    String? pin,
  });

  Future<void> archiveEmployee({
    required String managerAccountId,
    required String accountId,
  });
}
