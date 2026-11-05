import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A short message under the step card ("Switched to Bus 35"), faded in
/// and out. Nothing when [message] is null.
class TripToast extends StatelessWidget {
  const TripToast({super.key, required this.message, this.icon, this.color});

  final String? message;
  final IconData? icon;

  /// Filled with this colour (white text) instead of the card colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: message != null
          ? Container(
              key: ValueKey(message),
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: color ?? context.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon ?? Icons.info_outline,
                    color: color != null ? Colors.white : AppColors.primaryTeal,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      message!,
                      style: TextStyle(
                        color: color != null ? Colors.white : context.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
