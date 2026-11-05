import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/password_policy.dart';
import '../theme/app_theme.dart';

/// Password field for choosing a new password (sign-up, change password):
/// a strength meter and a live checklist of [PasswordPolicy] rules under it.
///
/// The checklist only takes room while it's useful: while the field has
/// focus, or while what's typed still breaks a rule. Empty and untouched,
/// or once the password passes, it folds away (the meter stays), which is
/// what keeps sign-up on one screen.
///
/// The parent decides whether to allow submitting; it listens to
/// [controller] and asks `PasswordPolicy.check(controller.text).isValid`.
class PasswordStrengthField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const PasswordStrengthField({super.key, required this.controller, required this.label, required this.hint});

  @override
  State<PasswordStrengthField> createState() => _PasswordStrengthFieldState();
}

class _PasswordStrengthFieldState extends State<PasswordStrengthField> {
  bool _obscure = true;
  final FocusNode _focus = FocusNode();

  /// Listed whenever the checklist shows, so the rules are known as soon as
  /// the field is tapped, before typing starts.
  static const _baseRules = [
    PasswordRule.minLength,
    PasswordRule.upper,
    PasswordRule.lower,
    PasswordRule.digit,
    PasswordRule.symbol,
  ];

  /// Listed only once broken -- they rarely are, and would just be noise.
  static const _conditionalRules = [PasswordRule.noEdgeSpaces, PasswordRule.notCommon];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focus.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(PasswordStrengthField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() => setState(() {});

  String _ruleText(AppLocalizations l10n, PasswordRule rule) => switch (rule) {
        PasswordRule.minLength => l10n.pwRuleMinLength,
        PasswordRule.upper => l10n.pwRuleUpper,
        PasswordRule.lower => l10n.pwRuleLower,
        PasswordRule.digit => l10n.pwRuleDigit,
        PasswordRule.symbol => l10n.pwRuleSymbol,
        PasswordRule.noEdgeSpaces => l10n.pwRuleNoEdgeSpaces,
        PasswordRule.notCommon => l10n.pwRuleNotCommon,
      };

  static Color _strengthColor(PasswordStrength s) => switch (s) {
        PasswordStrength.none || PasswordStrength.weak => AppColors.errorRed,
        PasswordStrength.fair => AppColors.brandAmberDark,
        PasswordStrength.good => AppColors.brandBlue,
        PasswordStrength.strong => AppColors.supportingGreen,
      };

  String _strengthText(AppLocalizations l10n, PasswordStrength s) => switch (s) {
        PasswordStrength.none || PasswordStrength.weak => l10n.pwStrengthWeak,
        PasswordStrength.fair => l10n.pwStrengthFair,
        PasswordStrength.good => l10n.pwStrengthGood,
        PasswordStrength.strong => l10n.pwStrengthStrong,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final password = widget.controller.text;
    final check = PasswordPolicy.check(password);
    final strength = PasswordPolicy.strength(password);
    final rules = [..._baseRules, ..._conditionalRules.where((r) => !check.passes(r))];
    final showRules = _focus.hasFocus || (password.isNotEmpty && !check.isValid);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          obscureText: _obscure,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint,
            prefixIcon: Icon(Icons.lock_outline, color: context.textSecondary),
            suffixIcon: IconButton(
              tooltip: _obscure ? l10n.showPasswordTooltip : l10n.hidePasswordTooltip,
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: context.textSecondary),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (strength != PasswordStrength.none) ...[
          const SizedBox(height: 10),
          Row(
            key: const Key('password-strength-meter'),
            children: [
              for (var i = 1; i <= 4; i++) ...[
                if (i > 1) const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    height: 5,
                    decoration: BoxDecoration(
                      color: i <= strength.index ? _strengthColor(strength) : context.fieldFill,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Semantics(
                label: l10n.pwStrengthLabel,
                child: Text(
                  _strengthText(l10n, strength),
                  style: TextStyle(color: _strengthColor(strength), fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
        if (showRules) ...[
          const SizedBox(height: 8),
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    check.passes(rule) ? Icons.check_rounded : Icons.close_rounded,
                    size: 16,
                    color: check.passes(rule) ? AppColors.supportingGreen : context.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _ruleText(l10n, rule),
                      style: TextStyle(
                        fontSize: 12,
                        color: check.passes(rule) ? context.textPrimary : context.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
