import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/business_date.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/business_day.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/entities/report.dart';
import '../../../domain/repositories/business_day_repository.dart';
import '../../../domain/repositories/report_repository.dart';
import '../../../l10n/generated/app_localizations.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.manager,
    required this.businessDays,
    required this.reports,
  });

  final Account manager;
  final BusinessDayRepository businessDays;
  final ReportRepository reports;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTimeRange _range = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );
  late Future<SalesReport> _report = _load();

  Future<SalesReport> _load() => widget.reports.buildSalesReport(
    managerAccountId: widget.manager.id,
    startDate: businessDateFor(_range.start),
    endDate: businessDateFor(_range.end),
  );

  Future<void> _reload() async {
    setState(() {
      _report = _load();
    });
    await _report;
  }

  Future<void> _selectRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: _range,
    );
    if (selected == null || !mounted) return;
    setState(() {
      _range = selected;
      _report = _load();
    });
  }

  Future<void> _reopen(BusinessDayRecord day) async {
    final reason = await _reasonDialog(context);
    if (reason == null || !mounted) return;
    try {
      await widget.businessDays.reopenDay(
        managerAccountId: widget.manager.id,
        businessDayId: day.id,
        reason: reason,
      );
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).dayReopened)),
        );
      }
    } on BusinessDayFailure catch (error) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context);
      final message = error.code == BusinessDayFailureCode.anotherDayOpen
          ? l10n.anotherDayOpen
          : l10n.dayReopenFailed;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).dayReopenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dateFormat = DateFormat.yMd(locale);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.reports),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<SalesReport>(
        future: _report,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.reportLoadError));
          }
          final report = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: _selectRange,
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      l10n.dateRange(
                        dateFormat.format(_range.start),
                        dateFormat.format(_range.end),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _MetricCard(
                      label: l10n.grossSales,
                      value: report.grossSales.formatMillimes(
                        locale: locale,
                        unit: l10n.millimesUnit,
                      ),
                    ),
                    _MetricCard(
                      label: l10n.cancellations,
                      value: report.cancellations.formatMillimes(
                        locale: locale,
                        unit: l10n.millimesUnit,
                      ),
                    ),
                    _MetricCard(
                      label: l10n.netSales,
                      value: report.netSales.formatMillimes(
                        locale: locale,
                        unit: l10n.millimesUnit,
                      ),
                      emphasized: true,
                    ),
                    _MetricCard(
                      label: l10n.saleCount,
                      value: '${report.confirmedSaleCount}',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.businessDays,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                if (report.days.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(l10n.noReportData),
                    ),
                  )
                else
                  ...report.days.map(
                    (day) => _DayCard(
                      day: day,
                      locale: locale,
                      onReopen: () => _reopen(day),
                    ),
                  ),
                const SizedBox(height: 12),
                _Breakdown(
                  title: l10n.byProduct,
                  rows: report.products,
                  locale: locale,
                ),
                _Breakdown(
                  title: l10n.byCategory,
                  rows: report.categories,
                  locale: locale,
                ),
                _Breakdown(
                  title: l10n.byEmployee,
                  rows: report.employees,
                  locale: locale,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 210,
    child: Card(
      color: emphasized ? Theme.of(context).colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    ),
  );
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.locale,
    required this.onReopen,
  });

  final BusinessDayRecord day;
  final String locale;
  final VoidCallback onReopen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isClosed = day.status == BusinessDayStatus.closed;
    return Card(
      child: ListTile(
        leading: Icon(isClosed ? Icons.lock_outline : Icons.lock_open_outlined),
        title: Text(day.businessDate),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isClosed ? l10n.closedStatus : l10n.openStatus),
            if (day.expectedCash != null)
              Text(
                '${l10n.expectedCash}: '
                '${day.expectedCash!.formatMillimes(locale: locale, unit: l10n.millimesUnit)}',
              ),
            if (day.countedCash != null)
              Text(
                '${l10n.countedCash}: '
                '${day.countedCash!.formatMillimes(locale: locale, unit: l10n.millimesUnit)}',
              ),
            if (day.variance != null)
              Text(
                '${l10n.variance}: '
                '${day.variance!.formatMillimes(locale: locale, unit: l10n.millimesUnit)}',
              ),
          ],
        ),
        trailing: isClosed
            ? IconButton.filledTonal(
                tooltip: l10n.reopenDay,
                onPressed: onReopen,
                icon: const Icon(Icons.lock_open_outlined),
              )
            : null,
      ),
    );
  }
}

class _Breakdown extends StatelessWidget {
  const _Breakdown({
    required this.title,
    required this.rows,
    required this.locale,
  });

  final String title;
  final List<ReportBreakdownRow> rows;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      child: ExpansionTile(
        title: Text(title),
        children: rows.isEmpty
            ? [ListTile(title: Text(l10n.noReportData))]
            : rows
                  .map(
                    (row) => ListTile(
                      title: Text(
                        row.label.isEmpty ? l10n.unknownLabel : row.label,
                      ),
                      subtitle: Text(l10n.quantityValue(row.quantity)),
                      trailing: Text(
                        row.value.formatMillimes(
                          locale: locale,
                          unit: l10n.millimesUnit,
                        ),
                      ),
                    ),
                  )
                  .toList(),
      ),
    );
  }
}

Future<String?> _reasonDialog(BuildContext context) async {
  final controller = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context);
      String? error;
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.reopenDay),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: l10n.reopenReason,
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
              child: Text(l10n.confirmReopen),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
  return result;
}
