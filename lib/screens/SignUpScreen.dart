import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';
import '../services/analytics_service.dart';
import '../services/account_service.dart';
import '../services/legal_consent_service.dart';
import '../services/password_policy.dart';
import '../widgets/legal_consent.dart';
import '../widgets/password_strength_field.dart';
import '../widgets/social_auth_buttons.dart';
import '../utils/email.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    // Rebuild so Create Account enables the moment both fields are right.
    _passwordController.addListener(_refresh);
    _confirmPasswordController.addListener(_refresh);
  }

  void _refresh() => setState(() {});

  /// Passwords aren't trimmed: a space is a character like any other, and
  /// PasswordPolicy rejects one at either end rather than dropping it.
  bool get _passwordReady =>
      PasswordPolicy.check(_passwordController.text).isValid &&
      _passwordController.text == _confirmPasswordController.text;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    final l10n = AppLocalizations.of(context);
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    // 1. Check for empty fields
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.fillAllFields), backgroundColor: Colors.red));
      return;
    }

    // 2. Strict UI Validation
    if (!isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.invalidEmail), backgroundColor: Colors.orange));
      return;
    }
    if (!PasswordPolicy.check(password).isValid) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordRulesNotMet), backgroundColor: Colors.orange));
      return;
    }
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.passwordsDontMatch), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isLoading = true);
    // The box is ticked (the button is off until it is): the account
    // created below is recorded as agreeing.
    LegalConsentService.agreeBeforeSignIn(lang: Localizations.localeOf(context).languageCode);

    try {
      // 3. Talk to Firebase
      final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCred.user != null) {
        await AccountService.saveUserDisplayName(name);
        // EmailVerificationGate holds the app until the link is opened;
        // it has a Resend button if this one doesn't arrive.
        if (!mounted) return;
        await AccountService.sendEmailVerification(languageCode: Localizations.localeOf(context).languageCode);
      }
      
      // 4. Success! AuthGate will catch this automatically, but we pop to ensure smooth routing.
      if (mounted) {
        AnalyticsService.logSignUp('email');
        Navigator.pushReplacementNamed(context, '/home');
      }
      
    } on FirebaseAuthException catch (e) {
      LegalConsentService.forgetAgreementBeforeSignIn();
      // Catch specific Firebase errors
      String errorMsg = l10n.signUpFailed;
      if (e.code == 'email-already-in-use') {
        errorMsg = l10n.emailAlreadyRegistered;
      } else if (e.code == 'weak-password' || e.code == 'password-does-not-meet-requirements') {
        // Firebase's own password policy (console) refused it.
        errorMsg = l10n.passwordRulesNotMet;
      } else if (e.code == 'network-request-failed') {
        errorMsg = l10n.checkInternet;
      } else {
        errorMsg = e.message ?? errorMsg;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
      }
    } catch (e) {
      LegalConsentService.forgetAgreementBeforeSignIn();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        child: GuidyLanguageToggle.over(SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo and language switch share a row (the switch sits over
              // it, in the same place as on every other screen), and there's
              // no subtitle: the screen has to fit without scrolling.
              SizedBox(
                height: 44,
                child: Center(
                  child: Image.asset(
                    context.isDark ? 'assets/images/logo_dark.png' : 'assets/images/logo_light.png',
                    height: 40,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(l10n.createAccount, style: const TextStyle(color: AppColors.primaryTeal, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              _buildTextField(l10n.nameLabel, l10n.nameHint, Icons.person_outline, _nameController),
              const SizedBox(height: 12),
              _buildTextField(l10n.emailLabel, l10n.emailHint, Icons.email_outlined, _emailController),
              const SizedBox(height: 12),
              PasswordStrengthField(controller: _passwordController, label: l10n.passwordLabel, hint: l10n.passwordCreateHint),
              const SizedBox(height: 12),
              _buildTextField(l10n.confirmPasswordLabel, l10n.confirmPasswordHint, Icons.lock_outline, _confirmPasswordController,
                  isPassword: true,
                  errorText: _confirmPasswordController.text.isNotEmpty &&
                          _confirmPasswordController.text != _passwordController.text
                      ? l10n.passwordsDontMatch
                      : null),
              const SizedBox(height: 8),
              // Required for every way of signing up below.
              LegalConsentCheckbox(value: _agreed, onChanged: (v) => setState(() => _agreed = v)),
              const SizedBox(height: 8),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading || !_agreed || !_passwordReady ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(l10n.createAccount, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SocialAuthButtons(enabled: _agreed, agreed: _agreed),
              const SizedBox(height: 4),
              
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Text(l10n.hasAccountPrompt, style: TextStyle(color: context.textSecondary)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(l10n.signIn, style: const TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        )),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, IconData icon, TextEditingController controller, {bool isPassword = false, String? errorText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            errorText: errorText,
            prefixIcon: Icon(icon, color: context.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
