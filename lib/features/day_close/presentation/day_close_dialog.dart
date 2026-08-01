import 'package:flutter/material.dart';

import '../../../core/money.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/entities/business_day.dart';
import '../../../domain/repositories/business_day_repository.dart';
import '../../../l10n/generated/app_localizations.dart';

Future<bool> showDayCloseDialog({
  required BuildContext context,
  required Account account,
  required BusinessDayRepository businessDays,
}) async {
  final l10n = AppLocalizations.of(context);
  BusinessDayRecord? day;
  try {
    day = await businessDays.getOpenDay(accountId: account.id);
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.dayLoadError)));
    }
    return false;
  }
  if (!context.mounted) return false;
  if (day == null) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.noOpenDay)));
    return false;
  }

  final result = await showDialog<_CloseSubmission>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _CloseDayDialog(day: day!),
  );
  if (result == null || !context.mounted) {
    return false;
  }

  try {
    await businessDays.closeOpenDay(
      accountId: account.id,
      countedCash: result.countedCash,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.dayClosedSuccess)));
    }
    return true;
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.dayCloseFailed)));
    }
    return false;
  }
}

class _CloseDayDialog extends StatefulWidget {
  const _CloseDayDialog({required this.day});

  final BusinessDayRecord day;

  @override
  State<_CloseDayDialog> createState() => _CloseDayDialogState();
}

class _CloseDayDialogState extends State<_CloseDayDialog> {
  final TextEditingController _counted = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _counted.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    return AlertDialog(
      icon: const Icon(Icons.point_of_sale_outlined),
      title: Text(l10n.closeBusinessDay),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.closeDayMessage(widget.day.businessDate)),
            if (widget.day.canViewFinancials &&
                widget.day.expectedCash != null) ...[
              const SizedBox(height: 16),
              Text(l10n.expectedCash),
              Text(
                widget.day.expectedCash!.formatMillimes(
                  locale: locale,
                  unit: l10n.millimesUnit,
                ),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _counted,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: l10n.countedCashOptional,
                hintText: l10n.cashAmountHint,
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () {
            final value = _counted.text.trim();
            if (value.isEmpty) {
              Navigator.pop(context, const _CloseSubmission(null));
              return;
            }
            final amount = parseMillimes(value);
            if (amount == null) {
              setState(() => _error = l10n.invalidCashAmount);
              return;
            }
            Navigator.pop(context, _CloseSubmission(amount));
          },
          child: Text(l10n.confirmCloseDay),
        ),
      ],
    );
  }
}

class _CloseSubmission {
  const _CloseSubmission(this.countedCash);

  final Money? countedCash;
}
