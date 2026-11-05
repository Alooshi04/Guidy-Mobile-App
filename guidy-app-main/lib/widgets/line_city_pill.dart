import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

/// Which network a line belongs to. Guidy started as a Greater Cairo app,
/// so Cairo/Giza is the unmarked default; Alexandria lines (backend ids
/// `ALX_*`) and the Cairo/Giza <-> Alexandria microbuses (`ALX_IC_*`,
/// agency `ALX_INTERCITY`) are marked so APTA 290 isn't mistaken for CTA 290.
enum LineCity { cairo, alexandria, intercity }

LineCity lineCityOf(Map<String, dynamic> route) {
  final agency = (route['agency'] ?? route['agency_id'] ?? '').toString().toUpperCase();
  final id = (route['route_id'] ?? '').toString().toUpperCase();
  if (agency == 'ALX_INTERCITY' || id.startsWith('ALX_IC_')) return LineCity.intercity;
  if (agency.startsWith('ALX_') || id.startsWith('ALX_')) return LineCity.alexandria;
  return LineCity.cairo;
}

/// The city pill on a Lines-screen card. Nothing at all for Cairo/Giza
/// lines, which keep their existing look.
class LineCityPill extends StatelessWidget {
  final Map<String, dynamic> route;

  const LineCityPill({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    final city = lineCityOf(route);
    if (city == LineCity.cairo) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final intercity = city == LineCity.intercity;
    final ink = intercity ? AppColors.brandBlue : context.accentAmber;
    final fill = context.isDark
        ? AppColors.darkSurfaceElevated
        : (intercity ? AppColors.brandBlue.withValues(alpha: 0.12) : AppColors.brandAmberLight);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ink.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(intercity ? Icons.sync_alt_rounded : Icons.location_city_rounded, size: 12, color: ink),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              intercity ? l10n.lineCityIntercity : l10n.lineCityAlexandria,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ink),
            ),
          ),
        ],
      ),
    );
  }
}
