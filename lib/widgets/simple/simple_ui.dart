import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../screens/MainNavigator.dart';
import '../../services/simple_mode.dart';
import '../../theme/app_theme.dart';
import '../../theme/guidy_ui.dart';

/// Building blocks of simple mode (see [SimpleModeController]): every
/// control is at least [SimpleModeController.minTarget] dp tall, always
/// carries a word beside its icon, and never depends on a swipe or a long
/// press.
class SimpleUi {
  SimpleUi._();

  /// The main button's fill: the brand navy on light (white text, about
  /// 11:1), the brand blue on the app's own dark surface (dark text).
  static Color primaryFill(BuildContext c) => c.isDark ? AppColors.brandBlue : AppColors.brandNavy;

  static Color onPrimary(BuildContext c) => c.isDark ? AppColors.darkBackground : Colors.white;

  /// Back to the Home tab from anywhere, closing every screen on top.
  static void goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainNavigator.goToTab(2);
  }

  /// A yes/no question before something that can't be undone. Both answers
  /// are full-size buttons; "no" is on top and is the safe one.
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String yes,
    required String no,
  }) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(body, style: const TextStyle(fontSize: 18, height: 1.4)),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowDirection: VerticalDirection.down,
        actions: [
          SizedBox(
            width: double.infinity,
            child: SimpleButton(
              key: const ValueKey('simple_confirm_no'),
              icon: Icons.arrow_back_rounded,
              label: no,
              primary: true,
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: SimpleButton(
              key: const ValueKey('simple_confirm_yes'),
              icon: Icons.check_rounded,
              label: yes,
              onPressed: () => Navigator.pop(ctx, true),
            ),
          ),
        ],
      ),
    );
    return answer == true;
  }
}

/// A big button: icon, then the word, in one row. [primary] is the one
/// main action on a screen.
class SimpleButton extends StatelessWidget {
  const SimpleButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.subtitle,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final Color fill = primary ? SimpleUi.primaryFill(context) : context.surfaceCard;
    final Color ink = primary ? SimpleUi.onPrimary(context) : context.textPrimary;
    final Color edge = primary ? Colors.transparent : (context.isDark ? Colors.white54 : const Color(0xFF0B1B2B));
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(GuidyUi.radius),
      side: BorderSide(color: edge, width: 2),
    );
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: Material(
        color: onPressed == null ? fill.withValues(alpha: 0.5) : fill,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, size: 30, color: ink),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink, height: 1.2)),
                        if (subtitle != null)
                          Text(subtitle!, style: TextStyle(fontSize: 16, color: ink.withValues(alpha: 0.85), height: 1.2)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A quiet action for a side matter ("This walk is wrong"): an icon and a
/// word on the page background, at least [SimpleModeController.minTarget]
/// dp tall, so it never competes with the one main button.
class SimpleTextAction extends StatelessWidget {
  const SimpleTextAction({super.key, required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ink = onPressed == null ? context.textSecondary : context.textPrimary;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SimpleModeController.minTarget),
          child: Row(
            children: [
              Icon(icon, size: 26, color: ink),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ink, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Back to Home": the way out of every simple-mode screen.
class SimpleHomeButton extends StatelessWidget {
  const SimpleHomeButton({super.key});

  @override
  Widget build(BuildContext context) => SimpleButton(
        key: const ValueKey('simple_home_button'),
        icon: Icons.home_rounded,
        label: AppLocalizations.of(context).simpleBackHome,
        onPressed: () => SimpleUi.goHome(context),
      );
}
