import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/account_service.dart';
import '../services/password_policy.dart';
import '../theme/app_theme.dart';
import 'password_strength_field.dart';

typedef ChangePasswordSubmit = Future<ChangePasswordResult> Function(String currentPassword, String newPassword);

/// Bottom sheet for an email account to change its password. Resolves to
/// true once the password has been changed, null if dismissed.
/// [onSubmit] defaults to AccountService.changePassword.
Future<bool?> showChangePasswordSheet(BuildContext context, {ChangePasswordSubmit? onSubmit}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => ChangePasswordSheet(
      onSubmit: onSubmit ??
          (current, next) => AccountService.changePassword(currentPassword: current, newPassword: next),
    ),
  );
}

class ChangePasswordSheet extends StatefulWidget {
  final ChangePasswordSubmit onSubmit;
  const ChangePasswordSheet({super.key, required this.onSubmit});

  @override
  State<ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_current, _next, _confirm]) {
      c.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    for (final c in [_current, _next, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _refresh() => setState(() {});

  bool get _ready =>
      _current.text.isNotEmpty && PasswordPolicy.check(_next.text).isValid && _next.text == _confirm.text;

  String _errorText(AppLocalizations l10n, ChangePasswordResult r) => switch (r) {
        ChangePasswordResult.wrongCurrent => l10n.currentPasswordWrong,
        ChangePasswordResult.sameAsOld => l10n.newPasswordSameAsOld,
        ChangePasswordResult.weakPassword => l10n.passwordRulesNotMet,
        ChangePasswordResult.tooManyRequests => l10n.tooManyRequests,
        ChangePasswordResult.network => l10n.checkInternet,
        ChangePasswordResult.success || ChangePasswordResult.failed => l10n.changePasswordFailed,
      };

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await widget.onSubmit(_current.text, _next.text);
    if (!mounted) return;
    if (result == ChangePasswordResult.success) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _saving = false;
      _error = _errorText(l10n, result);
    });
  }

  Widget _plainPasswordField(String label, TextEditingController controller, {String? errorText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            errorText: errorText,
            prefixIcon: Icon(Icons.lock_outline, color: context.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mismatch = _confirm.text.isNotEmpty && _confirm.text != _next.text;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.changePasswordButton, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _plainPasswordField(l10n.currentPasswordLabel, _current),
              const SizedBox(height: 16),
              PasswordStrengthField(controller: _next, label: l10n.newPasswordLabel, hint: l10n.passwordCreateHint),
              const SizedBox(height: 16),
              _plainPasswordField(l10n.confirmNewPasswordLabel, _confirm,
                  errorText: mismatch ? l10n.passwordsDontMatch : null),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: AppColors.errorRed)),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving || !_ready ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(l10n.changePasswordSave, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
