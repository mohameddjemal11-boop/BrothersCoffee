import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'data/database/app_database.dart';
import 'data/repositories/drift_account_repository.dart';
import 'data/repositories/drift_business_day_repository.dart';
import 'data/repositories/drift_catalog_repositories.dart';
import 'data/repositories/drift_sale_repository.dart';
import 'data/media/image_picker_service.dart';
import 'data/media/local_media_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase.defaults();
  final accounts = DriftAccountRepository(database);
  final businessDays = DriftBusinessDayRepository(database);
  runApp(
    BrothersCoffeeApp(
      accounts: accounts,
      accountAdministration: accounts,
      categories: DriftCategoryRepository(database),
      products: DriftProductRepository(database),
      sales: DriftSaleRepository(database),
      businessDays: businessDays,
      reports: businessDays,
      mediaStore: LocalMediaStore(),
      imagePicker: DeviceImagePickerService(),
    ),
  );
}
