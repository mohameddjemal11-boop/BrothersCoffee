import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'data/database/app_database.dart';
import 'data/repositories/drift_account_repository.dart';
import 'data/repositories/drift_business_day_repository.dart';
import 'data/repositories/drift_catalog_repositories.dart';
import 'data/repositories/drift_sale_repository.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase.defaults();
  final businessDays = DriftBusinessDayRepository(database);
  runApp(
    BrothersCoffeeApp(
      accounts: DriftAccountRepository(database),
      categories: DriftCategoryRepository(database),
      products: DriftProductRepository(database),
      sales: DriftSaleRepository(database),
      businessDays: businessDays,
      reports: businessDays,
    ),
  );
}
