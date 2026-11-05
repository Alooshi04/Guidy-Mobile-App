import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// A round map button down the trip screen's edge (re-centre, the stop
/// alarm), with an optional dot badge.
class TripRoundButton extends StatelessWidget {
  const TripRoundButton({
    super.key,
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
    this.backgroundColor,
    this.showBadge = false,
  });

  /// The width of the tool rail's column, which these continue.
  static const double size = 44;

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor ?? context.surfaceCard,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: AppColors.brandNavy.withValues(alpha: 0.35),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox.square(
            dimension: size,
            child: IconButton(
              icon: Icon(icon, size: 22),
              color: color,
              tooltip: tooltip,
              onPressed: onPressed,
              padding: EdgeInsets.zero,
              // Material's 48dp tap-target padding made these wider than
              // the compass beside them.
              style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              constraints: const BoxConstraints.tightFor(width: size, height: size),
            ),
          ),
          if (showBadge)
            Positioned(
              top: 7,
              right: 7,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: Color(0xFFE76F51), shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}
