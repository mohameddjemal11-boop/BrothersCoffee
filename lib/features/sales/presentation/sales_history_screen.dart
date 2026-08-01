import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/business_date.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/sale.dart';
import '../../../domain/repositories/sale_repository.dart';
import '../../../l10n/generated/app_localizations.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({
    super.key,
    required this.manager,
    required this.sales,
  });

  final Account manager;
  final SaleRepository sales;

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  late Future<List<SaleRecord>> _history = _load();

  Future<List<SaleRecord>> _load() => widget.sales.listForBusinessDate(
    managerAccountId: widget.manager.id,
    businessDate: businessDateFor(DateTime.now()),
  );

  Future<void> _reload() async {
    setState(() {
      _history = _load();
    });
    await _history;
  }

  Future<void> _showDetails(SaleRecord sale) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => _SaleDetailsDialog(sale: sale),
    );
    if (shouldCancel == true && mounted) {
      await _cancel(sale);
    }
  }

  Future<void> _cancel(SaleRecord sale) async {
    final reason = await _cancellationReason(context);
    if (reason == null || !mounted) return;
    try {
      await widget.sales.cancelSale(
        managerAccountId: widget.manager.id,
        saleId: sale.id,
        reason: reason,
      );
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).cancellationFailed),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.salesHistory)),
      body: FutureBuilder<List<SaleRecord>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _HistoryMessage(
              icon: Icons.error_outline,
              message: l10n.historyLoadError,
              onRefresh: _reload,
            );
          }
          final sales = snapshot.data!;
          if (sales.isEmpty) {
            return _HistoryMessage(
              icon: Icons.receipt_long_outlined,
              message: l10n.noSalesToday,
              onRefresh: _reload,
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: sales.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final sale = sales[index];
                final cancelled = sale.status == SaleStatus.cancelled;
                return Card(
                  child: ListTile(
                    onTap: () => _showDetails(sale),
                    leading: CircleAvatar(
                      child: Icon(
                        cancelled ? Icons.block : Icons.receipt_outlined,
                      ),
                    ),
                    title: Text(
                      saleReference(sale.businessDate, sale.displayNumber),
                    ),
                    subtitle: Text(
                      '${DateFormat.Hm(Localizations.localeOf(context).toString()).format(sale.confirmedAt.toLocal())} · '
                      '${sale.creatorName} · '
                      '${cancelled ? l10n.cancelledStatus : l10n.confirmedStatus}',
                    ),
                    trailing: Text(
                      sale.total.formatMillimes(
                        locale: Localizations.localeOf(context).toString(),
                        unit: l10n.millimesUnit,
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        decoration: cancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.message,
    required this.onRefresh,
  });

  final IconData icon;
  final String message;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 54, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        IconButton.filledTonal(
          onPressed: onRefresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
  );
}

class _SaleDetailsDialog extends StatelessWidget {
  const _SaleDetailsDialog({required this.sale});

  final SaleRecord sale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    return AlertDialog(
      title: Text(l10n.saleDetails),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                saleReference(sale.businessDate, sale.displayNumber),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text('${l10n.soldBy} ${sale.creatorName}'),
              const Divider(height: 28),
              ...sale.lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(child: Text(line.productName)),
                      Text('${line.quantity} × '),
                      Text(
                        line.unitPrice.formatMillimes(
                          locale: locale,
                          unit: l10n.millimesUnit,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.total),
                  Text(
                    sale.total.formatMillimes(
                      locale: locale,
                      unit: l10n.millimesUnit,
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              if (sale.cancellationReason != null) ...[
                const SizedBox(height: 16),
                Text(
                  '${l10n.cancellationReason}: ${sale.cancellationReason}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l10n.close),
        ),
        if (sale.status == SaleStatus.confirmed)
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.block),
            label: Text(l10n.cancelSale),
          ),
      ],
    );
  }
}

Future<String?> _cancellationReason(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      String? error;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.cancelSale),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.cancellationReason,
              errorText: error,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.isEmpty) {
                  setState(() => error = l10n.reasonRequired);
                  return;
                }
                Navigator.pop(context, reason);
              },
              child: Text(l10n.confirmCancellation),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
  return result;
}
