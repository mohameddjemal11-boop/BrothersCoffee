import 'package:flutter/foundation.dart';

import '../domain/entities/account.dart';
import '../domain/repositories/account_repository.dart';

enum AppPhase { loading, setup, signIn, signedIn }

class AppController extends ChangeNotifier {
  AppController(this._accounts);

  final AccountRepository _accounts;
  AppPhase phase = AppPhase.loading;
  List<Account> accounts = const [];
  Account? activeAccount;
  String? error;

  Future<void> load() async {
    try {
      accounts = await _accounts.listActive();
      phase = accounts.isEmpty ? AppPhase.setup : AppPhase.signIn;
    } catch (_) {
      error = 'load';
      phase = AppPhase.signIn;
    }
    notifyListeners();
  }

  Future<bool> bootstrap(String name, String pin) async {
    error = null;
    try {
      activeAccount = await _accounts.bootstrapManager(
        displayName: name,
        pin: pin,
      );
      accounts = await _accounts.listActive();
      phase = AppPhase.signedIn;
      notifyListeners();
      return true;
    } catch (_) {
      error = 'setup';
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(Account account, String pin) async {
    error = null;
    final authenticated = await _accounts.authenticate(account.id, pin);
    if (authenticated == null) {
      error = 'pin';
      notifyListeners();
      return false;
    }
    activeAccount = authenticated;
    phase = AppPhase.signedIn;
    notifyListeners();
    return true;
  }

  void switchUser() {
    activeAccount = null;
    phase = AppPhase.loading;
    error = null;
    notifyListeners();
    load();
  }
}
