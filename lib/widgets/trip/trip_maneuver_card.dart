import 'package:flutter/material.dart';

import '../../screens/trip/trip_maneuver.dart';
import '../../services/transit_modes.dart';
import '../../theme/app_theme.dart';
import '../../theme/guidy_ui.dart';

/// The trip screen's top card: what to do now (see TripManeuver). Turns
/// orange for a stop coming up.
class TripManeuverCard extends StatelessWidget {
  const TripManeuverCard({super.key, required this.maneuver});

  final WalkManeuverInfo maneuver;

  @override
  Widget build(BuildContext context) {

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAlert = maneuver.isProximityAlert;

    // Compact: it shares the top of the map with the tool rail beside it.
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: isAlert ? const Color(0xFFE76F51) : (isDark ? const Color(0xFF1E2630) : Colors.white),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isAlert ? Colors.transparent : (isDark ? Colors.white12 : Colors.black12), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isAlert ? Colors.white.withValues(alpha: 0.25) : AppColors.primaryTeal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  TransitModes.icon(maneuver.iconKey ?? 'walk'),
                  color: isAlert ? Colors.white : AppColors.primaryTeal,
                  size: 19,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      maneuver.headline,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isAlert ? Colors.white : (isDark ? Colors.white : Colors.black87),
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        height: 1.25,
                      ),
                    ),
                    if (maneuver.subline.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      // "Then take minibus 66  10 EGP": the next ride's fare
                      // right after its number.
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              maneuver.subline,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isAlert
                                    ? Colors.white.withValues(alpha: 0.9)
                                    : (isDark ? Colors.white70 : Colors.black54),
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          if (maneuver.fare != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              maneuver.fare!,
                              key: const ValueKey('maneuver_fare'),
                              maxLines: 1,
                              style: TextStyle(
                                color: isAlert ? Colors.white : GuidyUi.greenText(context),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
