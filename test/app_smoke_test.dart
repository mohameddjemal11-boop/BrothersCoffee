import 'package:brothers_coffee_pos/app/app.dart';
import 'package:brothers_coffee_pos/core/money.dart';
import 'package:brothers_coffee_pos/domain/entities/account.dart';
import 'package:brothers_coffee_pos/domain/entities/catalog.dart';
import 'package:brothers_coffee_pos/domain/entities/enums.dart';
import 'package:brothers_coffee_pos/domain/repositories/account_repository.dart';
import 'package:brothers_coffee_pos/domain/repositories/catalog_repositories.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('first launch renders manager setup', (tester) async {
    await tester.pumpWidget(
      BrothersCoffeeApp(
        accounts: FakeAccounts(),
        categories: FakeCategories(),
        products: FakeProducts(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Configurer le responsable'), findsOneWidget);
    expect(find.text('Continuer'), findsOneWidget);
  });
}

class FakeAccounts implements AccountRepository {
  final List<Account> _accounts = [];
  @override
  Future<Account?> authenticate(String accountId, String pin) async => null;
  @override
  Future<Account> bootstrapManager({
    required String displayName,
    required String pin,
  }) async {
    final account = Account(
      id: 'm',
      displayName: displayName,
      role: AccountRole.manager,
      isActive: true,
      createdAt: DateTime(2020),
      updatedAt: DateTime(2020),
      revision: 1,
    );
    _accounts.add(account);
    return account;
  }

  @override
  Future<Account> create({
    required String displayName,
    required AccountRole role,
    required String pin,
  }) => throw UnimplementedError();
  @override
  Future<void> archive(String id) async {}
  @override
  Future<List<Account>> listActive() async => _accounts;
  @override
  Future<Account> update({
    required String id,
    String? displayName,
    AccountRole? role,
    String? pin,
  }) => throw UnimplementedError();
}

class FakeCategories implements CategoryRepository {
  @override
  Future<void> archive(String id) async {}
  @override
  Future<Category> create({required String name, String? imageRef}) =>
      throw UnimplementedError();
  @override
  Future<List<Category>> listActive() async => const [];
  @override
  Future<void> reorder(List<String> orderedIds) async {}
  @override
  Future<Category> update({
    required String id,
    String? name,
    String? imageRef,
  }) => throw UnimplementedError();
}

class FakeProducts implements ProductRepository {
  @override
  Future<void> archive(String id) async {}
  @override
  Future<Product> create({
    required String categoryId,
    required String name,
    required Money price,
    String? imageRef,
  }) => throw UnimplementedError();
  @override
  Future<List<Product>> listActive({String? categoryId}) async => const [];
  @override
  Future<void> reorder(String categoryId, List<String> orderedIds) async {}
  @override
  Future<Product> update({
    required String id,
    String? categoryId,
    String? name,
    Money? price,
    String? imageRef,
  }) => throw UnimplementedError();
}
