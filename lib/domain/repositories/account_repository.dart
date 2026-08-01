import '../entities/account.dart';

abstract interface class AccountRepository {
  Future<Account> bootstrapManager({
    required String displayName,
    required String pin,
  });

  Future<Account?> authenticate(String accountId, String pin);
  Future<List<Account>> listActive();
}
