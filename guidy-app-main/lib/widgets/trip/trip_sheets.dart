import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../utils/fare_text.dart';

/// "Switch to this route?" for a faint alternative tapped mid-trip, with
/// its time ([minutes], already worded) and fare. True: switch.
Future<bool?> showSwitchRouteSheet(BuildContext context, {required String minutes, required num? fare}) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.navSwitchRouteTitle,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ctx.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              fare != null ? l10n.navSwitchRouteBody(minutes, l10n.fareEgp(fareAmount(fare))) : minutes,
              style: TextStyle(fontSize: 14, color: ctx.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                l10n.navSwitchRouteConfirm,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancelButton)),
          ],
        ),
      ),
    ),
  );
}

/// The trip is being shared: share the link again (false) or stop sharing
/// (true). Null: dismissed.
Future<bool?> showLiveShareActiveSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.shareLiveActive,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ctx.textPrimary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, false),
              icon: const Icon(Icons.share_rounded, color: Colors.white),
              label: Text(l10n.shareLiveTooltip, style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.shareLiveStop, style: const TextStyle(color: Colors.redAccent)),
            ),
          ],
        ),
      ),
    ),
  );
}
