import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'data/database/app_database.dart';
import 'data/repositories/drift_account_repository.dart';
import 'data/repositories/drift_catalog_repositories.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase.defaults();
  runApp(
    BrothersCoffeeApp(
      accounts: DriftAccountRepository(database),
      categories: DriftCategoryRepository(database),
      products: DriftProductRepository(database),
    ),
  );
}
