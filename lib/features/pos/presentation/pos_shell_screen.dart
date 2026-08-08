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
import '../../../domain/repositories/media_store.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../catalog/presentation/catalog_admin_screen.dart';
import '../../catalog/presentation/managed_image.dart';
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
    this.mediaStore = const NoopMediaStore(),
    this.imagePicker = const NoopImagePickerService(),
    required this.onSwitchUser,
  });
  final Account account;
  final AccountAdministrationRepository accountAdministration;
  final CategoryRepository categories;
  final ProductRepository products;
  final SaleRepository sales;
  final BusinessDayRepository businessDays;
  final ReportRepository reports;
  final MediaStore mediaStore;
  final ImagePickerService imagePicker;
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
          mediaStore: widget.mediaStore,
          imagePicker: widget.imagePicker,
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
          final phone = constraints.maxWidth < 600;
          final sideBySide =
              constraints.maxWidth >= 700 &&
              constraints.maxWidth > constraints.maxHeight;
          final compactHeader = constraints.maxWidth < 850;
          return Padding(
            padding: EdgeInsets.all(phone ? 10 : 16),
            child: Column(
              children: [
                _TopBar(
                  account: widget.account,
                  compact: compactHeader,
                  onManage: _manage,
                  onManageAccounts: _manageAccounts,
                  onHistory: _openHistory,
                  onCloseDay: _closeDay,
                  onReports: _openReports,
                  onSwitchUser: widget.onSwitchUser,
                ),
                SizedBox(height: phone ? 10 : 16),
                Expanded(
                  child: sideBySide
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
                                mediaStore: widget.mediaStore,
                              ),
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: constraints.maxWidth >= 1200
                                  ? 380
                                  : constraints.maxWidth >= 900
                                  ? 340
                                  : 280,
                              key: const ValueKey('side-basket'),
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
                                mediaStore: widget.mediaStore,
                              ),
                            ),
                            SizedBox(height: phone ? 8 : 12),
                            SizedBox(
                              height: phone ? 220 : 260,
                              key: const ValueKey('bottom-basket'),
                              child: _BasketPane(
                                basket: _basket,
                                confirming: _confirming,
                                onConfirm: _confirmSale,
                              ),
                            ),
                          ],
                        ),
                ),
                SizedBox(height: phone ? 6 : 10),
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
    required this.compact,
    required this.onManage,
    required this.onManageAccounts,
    required this.onHistory,
    required this.onCloseDay,
    required this.onReports,
    required this.onSwitchUser,
  });
  final Account account;
  final bool compact;
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
              Text(
                l.appName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                account.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (compact)
          PopupMenuButton<_TopAction>(
            tooltip: l.management,
            icon: const Icon(Icons.more_vert),
            onSelected: (action) {
              switch (action) {
                case _TopAction.switchUser:
                  onSwitchUser();
                  break;
                case _TopAction.closeDay:
                  onCloseDay();
                  break;
                case _TopAction.history:
                  onHistory();
                  break;
                case _TopAction.reports:
                  onReports();
                  break;
                case _TopAction.catalog:
                  onManage();
                  break;
                case _TopAction.accounts:
                  onManageAccounts();
                  break;
              }
            },
            itemBuilder: (context) => [
              _topActionItem(
                _TopAction.switchUser,
                Icons.switch_account_outlined,
                l.changeUser,
              ),
              _topActionItem(
                _TopAction.closeDay,
                Icons.point_of_sale_outlined,
                l.closeBusinessDay,
              ),
              if (account.role == AccountRole.manager) ...[
                _topActionItem(
                  _TopAction.history,
                  Icons.receipt_long_outlined,
                  l.salesHistory,
                ),
                _topActionItem(
                  _TopAction.reports,
                  Icons.assessment_outlined,
                  l.reports,
                ),
                _topActionItem(
                  _TopAction.catalog,
                  Icons.settings_outlined,
                  l.management,
                ),
                _topActionItem(
                  _TopAction.accounts,
                  Icons.manage_accounts_outlined,
                  l.accountManagement,
                ),
              ],
            ],
          )
        else ...[
          TextButton.icon(
            onPressed: onSwitchUser,
            icon: const Icon(Icons.switch_account_outlined),
            label: Text(l.changeUser),
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
      ],
    );
  }
}

enum _TopAction { switchUser, closeDay, history, reports, catalog, accounts }

PopupMenuItem<_TopAction> _topActionItem(
  _TopAction value,
  IconData icon,
  String label,
) => PopupMenuItem(
  value: value,
  child: Row(
    children: [
      Icon(icon),
      const SizedBox(width: 12),
      Flexible(child: Text(label)),
    ],
  ),
);

class _CatalogPane extends StatelessWidget {
  const _CatalogPane({
    required this.categories,
    required this.products,
    required this.selectedId,
    required this.onSelect,
    required this.basket,
    required this.isManager,
    required this.onManage,
    required this.mediaStore,
  });
  final CategoryRepository categories;
  final ProductRepository products;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final BasketController basket;
  final bool isManager;
  final VoidCallback onManage;
  final MediaStore mediaStore;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 12 : 18,
        ),
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
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 600;
                                final columns = compact
                                    ? (constraints.maxWidth >= 300 ? 2 : 1)
                                    : (constraints.maxWidth / 190)
                                          .floor()
                                          .clamp(2, 6);
                                return GridView.builder(
                                  key: const ValueKey('product-grid'),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: columns,
                                        mainAxisExtent: compact ? 190 : 210,
                                        crossAxisSpacing: compact ? 8 : 12,
                                        mainAxisSpacing: compact ? 8 : 12,
                                      ),
                                  itemCount: items.data!.length,
                                  itemBuilder: (context, index) => _ProductCard(
                                    product: items.data![index],
                                    basket: basket,
                                    mediaStore: mediaStore,
                                    compact: compact,
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

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.basket,
    required this.mediaStore,
    required this.compact,
  });

  final Product product;
  final BasketController basket;
  final MediaStore mediaStore;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => basket.add(product),
        child: Padding(
          padding: EdgeInsets.all(compact ? 8 : 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: compact ? 100 : 116,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: ManagedImage(
                  imageRef: product.imageRef,
                  mediaStore: mediaStore,
                  fallback: Icon(
                    Icons.local_cafe_outlined,
                    color: colors.primary,
                  ),
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                product.price.formatMillimes(
                  locale: Localizations.localeOf(context).toString(),
                  unit: l.millimesUnit,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ],
          ),
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
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight > 16
                ? constraints.maxHeight - 16
                : 0,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
          ),
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
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 12 : 18,
        ),
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
