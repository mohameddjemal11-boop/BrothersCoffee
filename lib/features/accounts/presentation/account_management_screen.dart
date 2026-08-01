import 'package:flutter/material.dart';

import '../../../domain/entities/account.dart';
import '../../../domain/entities/enums.dart';
import '../../../domain/repositories/account_administration_repository.dart';
import '../../../l10n/generated/app_localizations.dart';

class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({
    super.key,
    required this.manager,
    required this.accounts,
  });

  final Account manager;
  final AccountAdministrationRepository accounts;

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  late Future<List<Account>> _accounts = _load();

  Future<List<Account>> _load() =>
      widget.accounts.listForManagement(managerAccountId: widget.manager.id);

  Future<void> _reload() async {
    setState(() {
      _accounts = _load();
    });
    await _accounts;
  }

  Future<void> _createEmployee() async {
    final result = await showDialog<_AccountFormResult>(
      context: context,
      builder: (_) => const _AccountDialog(),
    );
    if (result == null || !mounted) return;
    await _runMutation(
      () => widget.accounts.createEmployee(
        managerAccountId: widget.manager.id,
        displayName: result.name,
        pin: result.pin!,
      ),
    );
  }

  Future<void> _edit(Account account) async {
    final result = await showDialog<_AccountFormResult>(
      context: context,
      builder: (_) => _AccountDialog(account: account),
    );
    if (result == null || !mounted) return;
    await _runMutation(
      () => widget.accounts.updateAccount(
        managerAccountId: widget.manager.id,
        accountId: account.id,
        displayName: result.name,
        pin: result.pin,
      ),
    );
  }

  Future<void> _archive(Account account) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.archiveAccount),
        content: Text(l10n.archiveAccountQuestion(account.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.archive),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _runMutation(
      () => widget.accounts.archiveEmployee(
        managerAccountId: widget.manager.id,
        accountId: account.id,
      ),
      archived: true,
    );
  }

  Future<void> _runMutation(
    Future<Object?> Function() mutation, {
    bool archived = false,
  }) async {
    final l10n = AppLocalizations.of(context);
    try {
      await mutation();
      await _reload();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.accountActionFailed)));
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(archived ? l10n.accountArchived : l10n.accountSaved),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.accountManagement),
        actions: [
          IconButton(
            tooltip: l10n.addEmployee,
            onPressed: _createEmployee,
            icon: const Icon(Icons.person_add_alt_1_outlined),
          ),
        ],
      ),
      body: FutureBuilder<List<Account>>(
        future: _accounts,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(l10n.accountLoadFailed));
          }
          final accounts = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: accounts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final account = accounts[index];
                final isManager = account.role == AccountRole.manager;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Icon(
                        isManager
                            ? Icons.admin_panel_settings_outlined
                            : Icons.person_outline,
                      ),
                    ),
                    title: Text(account.displayName),
                    subtitle: Text(
                      isManager ? l10n.managerRole : l10n.employeeRole,
                    ),
                    onTap: () => _edit(account),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: l10n.editAccount,
                          onPressed: () => _edit(account),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        if (!isManager)
                          IconButton(
                            tooltip: l10n.archiveAccount,
                            onPressed: () => _archive(account),
                            icon: const Icon(Icons.archive_outlined),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createEmployee,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: Text(l10n.addEmployee),
      ),
    );
  }
}

class _AccountDialog extends StatefulWidget {
  const _AccountDialog({this.account});

  final Account? account;

  @override
  State<_AccountDialog> createState() => _AccountDialogState();
}

class _AccountDialogState extends State<_AccountDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.account?.displayName,
  );
  final TextEditingController _pin = TextEditingController();
  final TextEditingController _confirmation = TextEditingController();
  String? _nameError;
  String? _pinError;

  bool get _creating => widget.account == null;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final name = _name.text.trim();
    final pin = _pin.text;
    final pinRequired = _creating || pin.isNotEmpty;
    final pinValid = RegExp(r'^\d{4,8}$').hasMatch(pin);
    setState(() {
      _nameError = name.isEmpty ? l10n.nameRequired : null;
      _pinError = pinRequired && !pinValid
          ? l10n.pinHint
          : pin != _confirmation.text
          ? l10n.pinMismatch
          : null;
    });
    if (_nameError != null || _pinError != null) return;
    Navigator.pop(context, _AccountFormResult(name, pin.isEmpty ? null : pin));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(_creating ? l10n.addEmployee : l10n.editAccount),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: l10n.name,
                  errorText: _nameError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: InputDecoration(
                  labelText: _creating ? l10n.pin : l10n.newPinOptional,
                  counterText: '',
                  errorText: _pinError,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirmation,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: InputDecoration(
                  labelText: l10n.confirmPin,
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.save)),
      ],
    );
  }
}

class _AccountFormResult {
  const _AccountFormResult(this.name, this.pin);

  final String name;
  final String? pin;
}
