import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/minutes_text.dart';
import '../../utils/fare_text.dart';

/// "You have arrived": the trip's ends, time and fare, then done or the
/// trip history.
class TripArrivalSheet extends StatelessWidget {
  const TripArrivalSheet({
    super.key,
    required this.startName,
    required this.endName,
    required this.durationMinutes,
    required this.fare,
    required this.onDone,
    required this.onHistory,
  });

  final String startName;
  final String endName;
  final int durationMinutes;
  final num fare;
  final VoidCallback onDone;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = context.isDark;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: context.textSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.primaryTeal.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.primaryTeal, size: 40),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.youHaveArrived,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: context.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            '$startName ➔ $endName',
            style: TextStyle(fontSize: 14, color: context.textSecondary, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(color: context.fieldFill, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      Icon(Icons.schedule_rounded, size: 20, color: context.accentAmber),
                      const SizedBox(height: 4),
                      Text(
                        l10n.minutes(num.tryParse('$durationMinutes')),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: context.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                  decoration: BoxDecoration(color: context.fieldFill, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      const Icon(Icons.savings_rounded, size: 20, color: Color(0xFF00B277)),
                      const SizedBox(height: 4),
                      Text(
                        '${fareAmount(fare)} ${isAr ? "ج.م" : "EGP"}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF00B277)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Text(
                MaterialLocalizations.of(context).okButtonLabel,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: TextButton.icon(
              onPressed: onHistory,
              icon: const Icon(Icons.history_rounded, size: 18, color: AppColors.primaryTeal),
              label: Text(
                l10n.navHistory,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primaryTeal),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
