import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../services/banner_hide_service.dart';
import '../services/rewarded_ad_service.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';

/// Settings row: watch a short ad to hide the top banner for 24 hours. A plain
/// settings row (never styled like an ad); absent when the build has no
/// rewarded unit.
class HideBannerTile extends StatefulWidget {
  const HideBannerTile({super.key});

  @override
  State<HideBannerTile> createState() => _HideBannerTileState();
}

class _HideBannerTileState extends State<HideBannerTile> {
  // The ad is loaded on tap; this keeps a second tap from asking again.
  bool _loading = false;

  Future<void> _onTap() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    final result = await RewardedAdService.instance.watchToHideBanner();
    if (mounted) setState(() => _loading = false);
    final text = switch (result) {
      RewardedResult.rewarded => l10n.removeBannerDone,
      RewardedResult.notWatched => l10n.removeBannerNotWatched,
      RewardedResult.unavailable => l10n.removeBannerUnavailable,
    };
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    if (!RewardedAdService.isOffered) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return ValueListenableBuilder<bool>(
      valueListenable: BannerHideService.instance.hidden,
      builder: (context, hidden, _) {
        final until = BannerHideService.instance.hiddenUntil;
        final subtitle = hidden && until != null
            ? l10n.removeBannerActive(DateFormat.jm(Localizations.localeOf(context).toString()).format(until))
            : l10n.removeBannerSubtitle;
        return Column(children: [
          ListTile(
            leading: const Icon(Icons.timer_outlined, color: AppColors.brandBlue),
            title: Text(
              l10n.removeBannerTitle.toUpperCase(),
              style: const TextStyle(color: AppColors.brandBlue, fontSize: 13.5, fontWeight: FontWeight.w600, letterSpacing: 0.2),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: context.textSecondary)),
            trailing: _loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
            enabled: !hidden,
            onTap: hidden || _loading ? null : _onTap,
          ),
          Divider(height: 1, thickness: 1, color: context.isDark ? Colors.white10 : GuidyUi.mist.withValues(alpha: 0.35)),
        ]);
      },
    );
  }
}
