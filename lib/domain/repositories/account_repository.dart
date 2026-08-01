import '../entities/account.dart';
import '../entities/enums.dart';

abstract interface class AccountRepository {
  Future<Account> bootstrapManager({
    required String displayName,
    required String pin,
  });

  Future<Account?> authenticate(String accountId, String pin);
  Future<List<Account>> listActive();

  Future<Account> create({
    required String displayName,
    required AccountRole role,
    required String pin,
  });

  Future<Account> update({
    required String id,
    String? displayName,
    AccountRole? role,
    String? pin,
  });

  Future<void> archive(String id);
}
