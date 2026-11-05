import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';
import '../services/analytics_service.dart';
import '../services/saved_places_service.dart';
import '../services/account_service.dart';
import '../widgets/social_auth_buttons.dart';
import '../utils/email.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final l10n = AppLocalizations.of(context);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.fillBothFields), backgroundColor: Colors.red));
      return;
    }

    if (!isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.invalidEmail), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCred.user != null) {
        final name = userCred.user!.displayName;
        if (name != null && name.trim().isNotEmpty) {
          await AccountService.saveUserDisplayName(name);
        } else {
          final fetched = await AccountService.getUserDisplayName();
          if (fetched != null && fetched.isNotEmpty) {
            try {
              await userCred.user!.updateDisplayName(fetched);
            } catch (_) {}
          }
        }
        SavedPlacesService.syncWithCloud(userCred.user!);
      }
      
      // Success! AuthGate takes over.
      if (mounted) {
        AnalyticsService.logSignIn('email');
        Navigator.pushReplacementNamed(context, '/home');
      }
      
    } on FirebaseAuthException catch (e) {
      String errorMsg = l10n.signInFailed;
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMsg = l10n.incorrectCredentials;
      } else if (e.code == 'network-request-failed') {
        errorMsg = l10n.checkInternet;
      } else if (e.code == 'too-many-requests') {
        errorMsg = l10n.tooManyRequests;
      } else {
        errorMsg = e.message ?? errorMsg;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Asks for the account email (pre-filled from the form) and sends a
  /// reset link. Firebase's hosted reset page applies the console password
  /// policy to the new password.
  Future<void> _showForgotPassword() async {
    final l10n = AppLocalizations.of(context);
    final controller = TextEditingController(text: _emailController.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.forgotPasswordTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.forgotPasswordBody),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(hintText: l10n.emailHint, prefixIcon: const Icon(Icons.email_outlined)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancelButton)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l10n.forgotPasswordSend),
          ),
        ],
      ),
    );
    // Not disposed here: the dialog's closing animation still uses it.
    if (email == null || email.isEmpty || !mounted) return;
    if (!isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.invalidEmail), backgroundColor: Colors.orange));
      return;
    }
    final result =
        await AccountService.sendPasswordReset(email, languageCode: Localizations.localeOf(context).languageCode);
    if (!mounted) return;
    final error = AccountService.authEmailErrorText(l10n, result);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? l10n.forgotPasswordSent),
      backgroundColor: error == null ? null : Colors.red,
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: SafeArea(
        // Sized to fit a phone screen (with the banner ad below it) without
        // scrolling; it still scrolls when the keyboard is up.
        child: GuidyLanguageToggle.over(SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Room for the language switch, which sits over this in the
              // same place as on every other screen.
              const SizedBox(height: 44),
              Image.asset(
                context.isDark ? 'assets/images/logo_dark.png' : 'assets/images/logo_light.png',
                height: 44,
              ),
              const SizedBox(height: 4),
              Text(l10n.appTagline, style: TextStyle(fontSize: 15, color: context.textSecondary)),
              const SizedBox(height: 14),

              _buildTextField(l10n.emailLabel, l10n.emailHint, Icons.email_outlined, _emailController),
              const SizedBox(height: 12),
              _buildPasswordField(l10n),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _isLoading ? null : _showForgotPassword,
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  child: Text(l10n.forgotPasswordLink, style: const TextStyle(color: AppColors.primaryTeal)),
                ),
              ),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(l10n.signIn, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 4),
              // No agreement box: signing in asks for nothing. If Google or
              // guest creates a new account here, LegalConsentGate asks it
              // to agree right after, as it does anyone who hasn't agreed to
              // the current version. Sign-up has the box.
              const SocialAuthButtons(),
              const SizedBox(height: 4),
              
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  Text(l10n.noAccountPrompt, style: TextStyle(color: context.textSecondary)),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/signup'),
                    child: Text(l10n.signUp, style: const TextStyle(color: AppColors.primaryTeal, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        )),
      ),
    );
  }

  Widget _buildTextField(String label, String hint, IconData icon, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: context.textSecondary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.passwordLabel, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            hintText: l10n.passwordHint,
            prefixIcon: Icon(Icons.lock_outline, color: context.textSecondary),
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: context.textSecondary),
              tooltip: _obscurePassword ? l10n.showPasswordTooltip : l10n.hidePasswordTooltip,
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
