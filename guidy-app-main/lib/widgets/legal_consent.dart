import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../services/account_service.dart';
import '../services/legal_consent_service.dart';
import '../theme/app_theme.dart';

/// The legal pages on guidyapp.com (Firebase Hosting), in the app's
/// language -- someone using Guidy in Arabic gets the Arabic page.
class LegalLinks {
  LegalLinks._();
  static String terms({required bool isAr}) => 'https://guidyapp.com/terms${isAr ? '-ar' : ''}';
  static String privacy({required bool isAr}) => 'https://guidyapp.com/privacy${isAr ? '-ar' : ''}';
  static String dataDeletion({required bool isAr}) => 'https://guidyapp.com/data-deletion${isAr ? '-ar' : ''}';
}

/// "I agree to the Terms and Conditions, the Privacy Policy and the Data
/// Deletion Policy", each name opening its page.
class LegalConsentCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const LegalConsentCheckbox({super.key, required this.value, required this.onChanged});

  @override
  State<LegalConsentCheckbox> createState() => _LegalConsentCheckboxState();
}

class _LegalConsentCheckboxState extends State<LegalConsentCheckbox> {
  final List<TapGestureRecognizer> _links = [];

  @override
  void dispose() {
    for (final r in _links) {
      r.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _open(String url) {
    final r = TapGestureRecognizer()
      ..onTap = () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    _links.add(r);
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    for (final r in _links) {
      r.dispose();
    }
    _links.clear();
    final link = TextStyle(
      color: AppColors.primaryTeal,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.primaryTeal,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: widget.value,
          activeColor: AppColors.primaryTeal,
          onChanged: (v) => widget.onChanged(v ?? false),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text.rich(
              TextSpan(
                style: TextStyle(color: context.textSecondary, fontSize: 13.5, height: 1.4),
                children: [
                  TextSpan(text: l10n.legalAgreePrefix),
                  TextSpan(text: l10n.legalTermsLink, style: link, recognizer: _open(LegalLinks.terms(isAr: isAr))),
                  TextSpan(text: l10n.legalAgreeSep1),
                  TextSpan(text: l10n.legalPrivacyLink, style: link, recognizer: _open(LegalLinks.privacy(isAr: isAr))),
                  TextSpan(text: l10n.legalAgreeSep2),
                  TextSpan(
                      text: l10n.legalDeletionLink, style: link, recognizer: _open(LegalLinks.dataDeletion(isAr: isAr))),
                  TextSpan(text: l10n.legalAgreeEnd),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows [child] once the signed-in account has agreed to the current
/// legal pages (LegalConsentService.currentVersion); until then, a
/// one-time screen asks for the agreement. Existing accounts meet it on
/// their next launch, and everyone again after a policy update. With no
/// signed-in account (or no Firebase, as in tests), [child] as it is.
class LegalConsentGate extends StatefulWidget {
  final Widget child;
  final String? uidForTesting;

  const LegalConsentGate({super.key, required this.child, this.uidForTesting});

  @override
  State<LegalConsentGate> createState() => _LegalConsentGateState();
}

class _LegalConsentGateState extends State<LegalConsentGate> {
  Future<bool>? _accepted;
  String? _uid;
  bool _ticked = false;
  bool _saving = false;

  String? get _currentUid {
    if (widget.uidForTesting != null) return widget.uidForTesting;
    if (Firebase.apps.isEmpty) return null;
    return FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  Widget build(BuildContext context) {
    final uid = _currentUid;
    if (uid == null) return widget.child;
    if (uid != _uid || _accepted == null) {
      _uid = uid;
      _ticked = false;
      _accepted = LegalConsentService.hasAccepted(uid);
    }
    return FutureBuilder<bool>(
      future: _accepted,
      builder: (context, snap) {
        if (!snap.hasData) {
          return Scaffold(
            backgroundColor: context.surfaceCard,
            body: const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal)),
          );
        }
        return snap.data! ? widget.child : _agreementScreen(context, uid);
      },
    );
  }

  Future<void> _agree(String uid) async {
    setState(() => _saving = true);
    await LegalConsentService.accept(uid, lang: Localizations.localeOf(context).languageCode);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _accepted = Future.value(true);
    });
  }

  Widget _agreementScreen(BuildContext context, String uid) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.gavel_rounded, size: 48, color: AppColors.primaryTeal),
              const SizedBox(height: 16),
              Text(l10n.legalConsentTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: context.textPrimary)),
              const SizedBox(height: 12),
              Text(l10n.legalConsentBody,
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: context.textSecondary)),
              const SizedBox(height: 28),
              LegalConsentCheckbox(value: _ticked, onChanged: (v) => setState(() => _ticked = v)),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _ticked && !_saving ? () => _agree(uid) : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l10n.legalConsentContinue, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving
                    ? null
                    : () async {
                        await FirebaseAuth.instance.signOut();
                        await AccountService.clearUserDataOnSignOut();
                      },
                child: Text(l10n.logOut, style: TextStyle(color: context.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
