import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  /// No-signal by default; a failure that is not about the connection (a trip
  /// outside the network) passes its own so it is not read as "check your
  /// internet".
  final IconData icon;

  /// The backend's `nearest_hubs` for a coverage failure, or null. Naming
  /// the closest point the network actually reaches is the difference
  /// between "this app is broken" and "this app doesn't go there yet",
  /// and it gives the rider somewhere to aim for on their own.
  final Map<String, dynamic>? nearestHubs;

  /// Shown only where reporting makes sense (a failed route calculation).
  /// Retry alone is a dead end here: retrying an uncovered trip returns
  /// the identical failure, so the only useful action left is telling us
  /// what is missing.
  final VoidCallback? onReportMissing;

  /// The heading; "Something went wrong" when null. A trip we don't cover
  /// isn't something that went wrong (QA 2026-10-22).
  final String? title;

  const ErrorState({
    super.key,
    required this.message,
    this.icon = Icons.wifi_off_rounded,
    required this.onRetry,
    this.nearestHubs,
    this.onReportMissing,
    this.title,
  });

  String? _hubsLine(AppLocalizations l10n) {
    final hubs = nearestHubs;
    if (hubs == null) return null;
    final origin = _hub(l10n, hubs['from_origin']);
    final destination = _hub(l10n, hubs['from_destination']);
    if (origin == null || destination == null) return null;
    return l10n.nearestHubsHint(origin, destination);
  }

  /// A hub's name, with how far it is once that is more than a walk.
  static String? _hub(AppLocalizations l10n, Object? hub) {
    if (hub is! Map) return null;
    final name = hub['name'] as String?;
    final m = hub['distance_m'];
    if (name == null || m is! num || m < 1000) return name;
    return '$name (${l10n.distanceKm((m / 1000).toStringAsFixed(1))})';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: context.textSecondary),
            const SizedBox(height: 16),
            Text(
              title ?? l10n.somethingWentWrongTitle,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: context.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: TextStyle(fontSize: 13, color: context.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (_hubsLine(l10n) case final String hubs) ...[
              const SizedBox(height: 10),
              Text(
                hubs,
                style: TextStyle(fontSize: 13, color: context.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retryButton),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (onReportMissing != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onReportMissing,
                icon: const Icon(Icons.add_road_rounded, size: 18),
                label: Text(l10n.reportMissingRouteButton),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryTeal),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
