import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/business_date.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/catalog.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/sale.dart';
import '../../../domain/repositories/catalog_repositories.dart';
import '../../../domain/repositories/account_administration_repository.dart';
import '../../../domain/repositories/business_day_repository.dart';
import '../../../domain/repositories/report_repository.dart';
import '../../../domain/repositories/sale_repository.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/presentation/catalog_admin_screen.dart';
import '../../accounts/presentation/account_management_screen.dart';
import '../../day_close/presentation/day_close_dialog.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../sales/presentation/sales_history_screen.dart';
import 'basket_controller.dart';

class PosShellScreen extends StatefulWidget {
  const PosShellScreen({
    super.key,
    required this.account,
    required this.accountAdministration,
    required this.categories,
    required this.products,
    required this.sales,
    required this.businessDays,
    required this.reports,
    required this.onSwitchUser,
  });
  final Account account;
  final AccountAdministrationRepository accountAdministration;
  final CategoryRepository categories;
  final ProductRepository products;
  final SaleRepository sales;
  final BusinessDayRepository businessDays;
  final ReportRepository reports;
  final VoidCallback onSwitchUser;
  @override
  State<PosShellScreen> createState() => _PosShellScreenState();
}

class _PosShellScreenState extends State<PosShellScreen> {
  final BasketController _basket = BasketController();
  String? _categoryId;
  bool _confirming = false;
  Future<void> _manage() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CatalogAdminScreen(
          categories: widget.categories,
          products: widget.products,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SalesHistoryScreen(manager: widget.account, sales: widget.sales),
      ),
    );
  }

  Future<void> _manageAccounts() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AccountManagementScreen(
          manager: widget.account,
          accounts: widget.accountAdministration,
        ),
      ),
    );
  }

  Future<void> _closeDay() async {
    await showDayCloseDialog(
      context: context,
      account: widget.account,
      businessDays: widget.businessDays,
    );
  }

  Future<void> _openReports() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportsScreen(
          manager: widget.account,
          businessDays: widget.businessDays,
          reports: widget.reports,
        ),
      ),
    );
  }

  Future<void> _confirmSale() async {
    if (_confirming || _basket.isEmpty) return;
    setState(() => _confirming = true);
    try {
      final sale = await widget.sales.confirmCashSale(
        accountId: widget.account.id,
        lines: _basket.draftLines,
      );
      if (!mounted) return;
      _basket.clear();
      setState(() => _confirming = false);
      await showDialog<void>(
        context: context,
        builder: (context) {
          final l10n = AppLocalizations.of(context);
          return AlertDialog(
            icon: const Icon(Icons.check_circle_outline, size: 46),
            title: Text(l10n.saleConfirmedTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.saleNumber),
                const SizedBox(height: 6),
                Text(
                  saleReference(sale.businessDate, sale.displayNumber),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Text(
                  sale.total.formatMillimes(
                    locale: Localizations.localeOf(context).toString(),
                    unit: l10n.millimesUnit,
                  ),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: Text(l10n.close),
              ),
            ],
          );
        },
      );
    } catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final message = switch (error) {
        SaleFailure(code: SaleFailureCode.previousBusinessDayOpen) =>
          l10n.previousDayOpenError,
        SaleFailure(code: SaleFailureCode.businessDayClosed) =>
          l10n.businessDayClosedError,
        SaleFailure(code: SaleFailureCode.unavailableProduct) =>
          l10n.unavailableProductError,
        _ => l10n.saleConfirmationError,
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted && _confirming) setState(() => _confirming = false);
    }
  }

  @override
  void dispose() {
    _basket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final landscape =
              constraints.maxWidth >= 700 &&
              constraints.maxWidth > constraints.maxHeight;
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _TopBar(
                  account: widget.account,
                  landscape: landscape,
                  onManage: _manage,
                  onManageAccounts: _manageAccounts,
                  onHistory: _openHistory,
                  onCloseDay: _closeDay,
                  onReports: _openReports,
                  onSwitchUser: widget.onSwitchUser,
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: landscape
                      ? Row(
                          children: [
                            Expanded(
                              flex: 7,
                              child: _CatalogPane(
                                categories: widget.categories,
                                products: widget.products,
                                selectedId: _categoryId,
                                onSelect: (id) =>
                                    setState(() => _categoryId = id),
                                basket: _basket,
                                isManager:
                                    widget.account.role == AccountRole.manager,
                                onManage: _manage,
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 360,
                              child: _BasketPane(
                                basket: _basket,
                                confirming: _confirming,
                                onConfirm: _confirmSale,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Expanded(
                              child: _CatalogPane(
                                categories: widget.categories,
                                products: widget.products,
                                selectedId: _categoryId,
                                onSelect: (id) =>
                                    setState(() => _categoryId = id),
                                basket: _basket,
                                isManager:
                                    widget.account.role == AccountRole.manager,
                                onManage: _manage,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 245,
                              child: _BasketPane(
                                basket: _basket,
                                confirming: _confirming,
                                onConfirm: _confirmSale,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 10),
                _OfflineReady(),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.account,
    required this.landscape,
    required this.onManage,
    required this.onManageAccounts,
    required this.onHistory,
    required this.onCloseDay,
    required this.onReports,
    required this.onSwitchUser,
  });
  final Account account;
  final bool landscape;
  final VoidCallback onManage;
  final VoidCallback onManageAccounts;
  final VoidCallback onHistory;
  final VoidCallback onCloseDay;
  final VoidCallback onReports;
  final VoidCallback onSwitchUser;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.coffee_rounded,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.appName, style: Theme.of(context).textTheme.titleLarge),
              Text(
                account.displayName,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onSwitchUser,
          icon: const Icon(Icons.switch_account_outlined),
          label: Text(landscape ? l.changeUser : l.switchLabel),
        ),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          tooltip: l.closeBusinessDay,
          onPressed: onCloseDay,
          icon: const Icon(Icons.point_of_sale_outlined),
        ),
        if (account.role == AccountRole.manager) ...[
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: l.salesHistory,
            onPressed: onHistory,
            icon: const Icon(Icons.receipt_long_outlined),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: l.reports,
            onPressed: onReports,
            icon: const Icon(Icons.assessment_outlined),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: l.management,
            onPressed: onManage,
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: l.accountManagement,
            onPressed: onManageAccounts,
            icon: const Icon(Icons.manage_accounts_outlined),
          ),
        ],
      ],
    );
  }
}

class _CatalogPane extends StatelessWidget {
  const _CatalogPane({
    required this.categories,
    required this.products,
    required this.selectedId,
    required this.onSelect,
    required this.basket,
    required this.isManager,
    required this.onManage,
  });
  final CategoryRepository categories;
  final ProductRepository products;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final BasketController basket;
  final bool isManager;
  final VoidCallback onManage;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: FutureBuilder<List<Category>>(
          future: categories.listActive(),
          builder: (context, cats) {
            if (!cats.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return FutureBuilder<List<Product>>(
              future: products.listActive(categoryId: selectedId),
              builder: (context, items) {
                if (!items.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.catalog,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          FilterChip(
                            selected: selectedId == null,
                            onSelected: (_) => onSelect(null),
                            label: Text(l.allProducts),
                          ),
                          ...cats.data!.map(
                            (category) => Padding(
                              padding: const EdgeInsetsDirectional.only(
                                start: 8,
                              ),
                              child: FilterChip(
                                selected: selectedId == category.id,
                                onSelected: (_) => onSelect(category.id),
                                label: Text(category.name),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: items.data!.isEmpty
                          ? _CatalogEmpty(
                              isManager: isManager,
                              onManage: onManage,
                            )
                          : GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 180,
                                    mainAxisExtent: 155,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount: items.data!.length,
                              itemBuilder: (context, index) {
                                final product = items.data![index];
                                return InkWell(
                                  onTap: () => basket.add(product),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Card(
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.local_cafe_outlined),
                                          const Spacer(),
                                          Text(
                                            product.name,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            product.price.formatMillimes(
                                              locale: Localizations.localeOf(
                                                context,
                                              ).toString(),
                                              unit: l.millimesUnit,
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelLarge,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CatalogEmpty extends StatelessWidget {
  const _CatalogEmpty({required this.isManager, required this.onManage});
  final bool isManager;
  final VoidCallback onManage;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_cafe_outlined,
              size: 68,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 18),
            Text(
              l.emptyCatalogTitle,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(l.emptyCatalogMessage, textAlign: TextAlign.center),
            if (isManager) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onManage,
                icon: const Icon(Icons.add_rounded),
                label: Text(l.openManagement),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BasketPane extends StatelessWidget {
  const _BasketPane({
    required this.basket,
    required this.confirming,
    required this.onConfirm,
  });
  final BasketController basket;
  final bool confirming;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: AnimatedBuilder(
          animation: basket,
          builder: (context, child) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l.currentOrder,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: basket.lines.isEmpty
                    ? Center(
                        child: Text(l.emptyBasket, textAlign: TextAlign.center),
                      )
                    : ListView.separated(
                        itemCount: basket.lines.length,
                        separatorBuilder: (_, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final line = basket.lines[index];
                          return Row(
                            children: [
                              Expanded(
                                child: Text(
                                  line.product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: () => basket.decrement(line.product),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('${line.quantity}'),
                              IconButton(
                                onPressed: () => basket.add(line.product),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                              IconButton(
                                onPressed: () => basket.remove(line.product.id),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l.total, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: Text(
                        basket.total.formatMillimes(
                          locale: Localizations.localeOf(context).toString(),
                          unit: l.millimesUnit,
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: basket.isEmpty || confirming ? null : onConfirm,
                icon: confirming
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(confirming ? l.processing : l.confirmSale),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OfflineReady extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.cloud_off_rounded,
          size: 16,
          color: Theme.of(context).extension<AppStatusColors>()!.success,
        ),
        const SizedBox(width: 6),
        Text(
          l.offlineReady,
          style: TextStyle(
            color: Theme.of(context).extension<AppStatusColors>()!.success,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
