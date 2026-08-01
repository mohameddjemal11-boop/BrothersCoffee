import 'package:flutter/material.dart';

import '../domain/repositories/account_repository.dart';
import '../domain/repositories/account_administration_repository.dart';
import '../domain/repositories/business_day_repository.dart';
import '../domain/repositories/catalog_repositories.dart';
import '../domain/repositories/report_repository.dart';
import '../domain/repositories/sale_repository.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../l10n/generated/app_localizations.dart';
import 'app_controller.dart';
import 'theme/app_theme.dart';

class BrothersCoffeeApp extends StatefulWidget {
  const BrothersCoffeeApp({
    super.key,
    required this.accounts,
    required this.accountAdministration,
    required this.categories,
    required this.products,
    required this.sales,
    required this.businessDays,
    required this.reports,
  });

  final AccountRepository accounts;
  final AccountAdministrationRepository accountAdministration;
  final CategoryRepository categories;
  final ProductRepository products;
  final SaleRepository sales;
  final BusinessDayRepository businessDays;
  final ReportRepository reports;

  @override
  State<BrothersCoffeeApp> createState() => _BrothersCoffeeAppState();
}

class _BrothersCoffeeAppState extends State<BrothersCoffeeApp> {
  late final AppController _controller = AppController(widget.accounts)..load();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (context) => AppLocalizations.of(context).appName,
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: AuthGate(
      controller: _controller,
      accountAdministration: widget.accountAdministration,
      categories: widget.categories,
      products: widget.products,
      sales: widget.sales,
      businessDays: widget.businessDays,
      reports: widget.reports,
    ),
  );
}
