import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../domain/entities/account.dart';
import '../../../domain/repositories/catalog_repositories.dart';
import '../../../domain/repositories/account_administration_repository.dart';
import '../../../domain/repositories/business_day_repository.dart';
import '../../../domain/repositories/report_repository.dart';
import '../../../domain/repositories/sale_repository.dart';
import '../../../features/pos/presentation/pos_shell_screen.dart';
import '../../../l10n/generated/app_localizations.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.controller,
    required this.accountAdministration,
    required this.categories,
    required this.products,
    required this.sales,
    required this.businessDays,
    required this.reports,
  });

  final AppController controller;
  final AccountAdministrationRepository accountAdministration;
  final CategoryRepository categories;
  final ProductRepository products;
  final SaleRepository sales;
  final BusinessDayRepository businessDays;
  final ReportRepository reports;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      switch (controller.phase) {
        case AppPhase.loading:
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        case AppPhase.setup:
          return _SetupScreen(controller: controller);
        case AppPhase.signIn:
          return _SignInScreen(controller: controller);
        case AppPhase.signedIn:
          return PosShellScreen(
            account: controller.activeAccount!,
            accountAdministration: accountAdministration,
            categories: categories,
            products: products,
            sales: sales,
            businessDays: businessDays,
            reports: reports,
            onSwitchUser: controller.switchUser,
          );
      }
    },
  );
}

class _SetupScreen extends StatefulWidget {
  const _SetupScreen({required this.controller});
  final AppController controller;
  @override
  State<_SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<_SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final ok = await widget.controller.bootstrap(_name.text, _pin.text);
    if (mounted && !ok) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _AuthScaffold(
      title: l.managerSetup,
      subtitle: l.managerSetupMessage,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.name),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? l.nameRequired : null,
            ),
            const SizedBox(height: 12),
            _PinField(controller: _pin, label: l.pin),
            const SizedBox(height: 12),
            _PinField(
              controller: _confirmation,
              label: l.confirmPin,
              validator: (v) =>
                  v != _pin.text ? l.pinMismatch : _pinValidator(l, v),
            ),
            const SizedBox(height: 20),
            if (widget.controller.error != null)
              Text(
                l.setupError,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (widget.controller.error != null) const SizedBox(height: 12),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: Text(l.continueLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignInScreen extends StatefulWidget {
  const _SignInScreen({required this.controller});
  final AppController controller;
  @override
  State<_SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<_SignInScreen> {
  Account? _selected;
  final _pin = TextEditingController();
  bool _submitting = false;
  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selected == null ||
        _pinValidator(AppLocalizations.of(context), _pin.text) != null) {
      setState(() {});
      return;
    }
    setState(() => _submitting = true);
    final ok = await widget.controller.signIn(_selected!, _pin.text);
    if (mounted && !ok) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accounts = widget.controller.accounts;
    return _AuthScaffold(
      title: l.welcomeBack,
      subtitle: l.chooseAccount,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<Account>(
            key: ValueKey(_selected?.id),
            initialValue: _selected,
            decoration: InputDecoration(labelText: l.account),
            items: accounts
                .map(
                  (a) => DropdownMenuItem(value: a, child: Text(a.displayName)),
                )
                .toList(),
            onChanged: (value) => setState(() {
              _selected = value;
              _pin.clear();
            }),
            validator: (v) => v == null ? l.accountRequired : null,
          ),
          const SizedBox(height: 12),
          _PinField(controller: _pin, label: l.pin),
          const SizedBox(height: 20),
          if (widget.controller.error == 'pin')
            Text(
              l.invalidPin,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (widget.controller.error == 'pin') const SizedBox(height: 12),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: Text(l.signIn),
          ),
        ],
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.coffee_rounded,
                      size: 52,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle),
                    const SizedBox(height: 24),
                    child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PinField extends StatelessWidget {
  const _PinField({
    required this.controller,
    required this.label,
    this.validator,
  });
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    obscureText: true,
    keyboardType: TextInputType.number,
    maxLength: 8,
    decoration: InputDecoration(labelText: label, counterText: ''),
    validator:
        validator ??
        (value) => _pinValidator(AppLocalizations.of(context), value),
    onFieldSubmitted: (_) {},
  );
}

String? _pinValidator(AppLocalizations l, String? value) =>
    RegExp(r'^\d{4,8}$').hasMatch(value ?? '') ? null : l.pinHint;
