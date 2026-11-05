import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import 'trip_round_button.dart';

/// The round buttons down the map's edge, under the tool rail: the compass
/// (turns with the map; tap for north-up), re-centre, and the stop alarm.
class TripMapButtons extends StatelessWidget {
  const TripMapButtons({
    super.key,
    required this.cameraBearing,
    required this.onNorthUp,
    required this.following,
    required this.onRecenter,
    required this.alarmOn,
    required this.onToggleAlarm,
  });

  /// The map's bearing, which the compass needle counter-rotates.
  final ValueListenable<double> cameraBearing;
  final VoidCallback onNorthUp;

  /// The camera follows the rider (re-centre shows it's on).
  final bool following;
  final VoidCallback onRecenter;
  final bool alarmOn;
  final VoidCallback onToggleAlarm;

  static const Color _alarm = Color(0xFFE76F51);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ValueListenableBuilder<double>(
          valueListenable: cameraBearing,
          builder: (context, bearing, _) => Material(
            color: context.surfaceCard,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onNorthUp,
              child: Tooltip(
                message: l10n.navCompassTooltip,
                child: SizedBox(
                  width: TripRoundButton.size,
                  height: TripRoundButton.size,
                  child: Transform.rotate(
                    angle: -bearing * math.pi / 180,
                    child: const Icon(Icons.navigation_rounded, color: Color(0xFFE63946), size: 22),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        TripRoundButton(
          icon: following ? Icons.my_location_rounded : Icons.location_searching_rounded,
          color: following ? AppColors.primaryTeal : context.textSecondary,
          tooltip: following ? l10n.centerOnMyLocationTooltip : l10n.navRecenterTooltip,
          onPressed: onRecenter,
        ),
        const SizedBox(height: 10),
        TripRoundButton(
          icon: alarmOn ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
          color: alarmOn ? _alarm : context.textSecondary,
          backgroundColor: alarmOn ? _alarm.withValues(alpha: 0.14) : null,
          showBadge: alarmOn,
          tooltip: alarmOn ? l10n.navStopAlarmOn : l10n.navStopAlarmOff,
          onPressed: onToggleAlarm,
        ),
      ],
    );
  }
}
