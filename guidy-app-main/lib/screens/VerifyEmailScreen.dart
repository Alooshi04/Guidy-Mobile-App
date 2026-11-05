import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_localizations.dart';
import '../services/account_service.dart';
import '../theme/app_theme.dart';

/// Shows [child] once the signed-in account doesn't need to verify its
/// email (AccountService.needsEmailVerification); until then,
/// [VerifyEmailScreen]. With no signed-in account (or no Firebase, as in
/// tests), [child] as it is.
class EmailVerificationGate extends StatefulWidget {
  final Widget child;
  const EmailVerificationGate({super.key, required this.child});

  @override
  State<EmailVerificationGate> createState() => _EmailVerificationGateState();
}

class _EmailVerificationGateState extends State<EmailVerificationGate> {
  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) return widget.child;
    final user = FirebaseAuth.instance.currentUser;
    if (!AccountService.needsEmailVerification(user)) return widget.child;
    return VerifyEmailScreen(
      email: user!.email ?? '',
      onResend: () =>
          AccountService.sendEmailVerification(languageCode: Localizations.localeOf(context).languageCode),
      onCheck: AccountService.reloadAndCheckEmailVerified,
      onVerified: () {
        if (mounted) setState(() {});
      },
      onSignOut: () async {
        final navigator = Navigator.of(context);
        await FirebaseAuth.instance.signOut();
        await AccountService.clearUserDataOnSignOut();
        navigator.pushNamedAndRemoveUntil('/signin', (_) => false);
      },
    );
  }
}

/// "Check your inbox" screen for an email account that hasn't opened its
/// verification link yet. Re-checks on its own when the app comes back to
/// the foreground -- the usual path is: switch to the mail app, tap the
/// link, switch back.
class VerifyEmailScreen extends StatefulWidget {
  final String email;
  final Future<AuthEmailResult> Function() onResend;

  /// Whether the address is verified now.
  final Future<bool> Function() onCheck;
  final VoidCallback onVerified;
  final Future<void> Function() onSignOut;

  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.onResend,
    required this.onCheck,
    required this.onVerified,
    required this.onSignOut,
  });

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> with WidgetsBindingObserver {
  static const int resendCooldownSeconds = 60;

  int _cooldown = 0;
  Timer? _cooldownTimer;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check(quiet: true);
  }

  void _snack(String text, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), backgroundColor: color));
  }

  Future<void> _check({bool quiet = false}) async {
    if (_checking) return;
    setState(() => _checking = true);
    final verified = await widget.onCheck();
    if (!mounted) return;
    setState(() => _checking = false);
    if (verified) {
      widget.onVerified();
    } else if (!quiet) {
      _snack(AppLocalizations.of(context).verifyEmailNotYet, color: Colors.orange);
    }
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    final l10n = AppLocalizations.of(context);
    _startCooldown();
    final result = await widget.onResend();
    final error = AccountService.authEmailErrorText(l10n, result);
    _snack(error ?? l10n.verifyEmailSent, color: error == null ? null : Colors.red);
  }

  void _startCooldown() {
    setState(() => _cooldown = resendCooldownSeconds);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown--);
      if (_cooldown <= 0) t.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.surfaceCard,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.mark_email_unread_outlined, size: 64, color: AppColors.primaryTeal),
                const SizedBox(height: 20),
                Text(
                  l10n.verifyEmailTitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.primaryTeal, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.verifyEmailBody(widget.email),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: context.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _checking ? null : () => _check(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _checking
                      ? const SizedBox(
                          height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(l10n.verifyEmailCheck, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _cooldown > 0 ? null : _resend,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(_cooldown > 0 ? l10n.verifyEmailResendIn(_cooldown) : l10n.verifyEmailResend),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: widget.onSignOut,
                  child: Text(l10n.verifyEmailUseOther, style: TextStyle(color: context.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
