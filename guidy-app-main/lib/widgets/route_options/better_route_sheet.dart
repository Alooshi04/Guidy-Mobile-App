import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/route_report_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/guidy_ui.dart';

/// The amber of the "Know a better route?" button and sheet: the brand's
/// warm accent, darkened on light surfaces so its words stay readable.
Color betterRouteInk(BuildContext context) => context.isDark ? AppColors.brandAmber : const Color(0xFFB45309);

/// What the rider sees once a report has gone, or hasn't.
String reportOutcomeText(AppLocalizations l10n, RouteReportOutcome outcome) => switch (outcome) {
      RouteReportOutcome.sent => l10n.reportSent,
      RouteReportOutcome.queuedOffline => l10n.reportQueued,
      RouteReportOutcome.notSignedIn => l10n.reportSignInRequired,
      RouteReportOutcome.failed => l10n.reportFailed,
    };

/// "Know a better route?" under the filters on Route Options. Full width
/// and amber, so it reads as its own thing next to the grey filter pills
/// and the blue list/compare switch: the beta reviewer missed a quieter
/// one (2026-11).
class BetterRouteButton extends StatelessWidget {
  const BetterRouteButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ink = betterRouteInk(context);
    final radius = BorderRadius.circular(GuidyUi.radius);
    return Semantics(
      button: true,
      child: Material(
        color: AppColors.brandAmber.withValues(alpha: context.isDark ? 0.14 : 0.16),
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: ink.withValues(alpha: 0.7), width: 1.2)),
        child: InkWell(
          key: const ValueKey('better-route-button'),
          borderRadius: radius,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 10, 10),
              child: Row(children: [
                Icon(Icons.tips_and_updates_outlined, size: 22, color: ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(AppLocalizations.of(context).betterRouteButton,
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: ink)),
                ),
                Icon(Icons.chevron_right_rounded, size: 22, color: ink),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the rider chose in [BetterRouteSheet].
sealed class BetterRouteChoice {
  const BetterRouteChoice();
}

/// They wrote the route in their own words.
class BetterRouteWritten extends BetterRouteChoice {
  const BetterRouteWritten(this.text);
  final String text;
}

/// They want to build it leg by leg (BetterRouteBuilderScreen).
class BetterRouteBuild extends BetterRouteChoice {
  const BetterRouteBuild();
}

/// The sheet "Know a better route?" opens: write it to us, or build it
/// from the transport network. Writing happens right in the sheet; it
/// returns the text, and the screen behind sends it.
class BetterRouteSheet extends StatefulWidget {
  const BetterRouteSheet({super.key});

  static Future<BetterRouteChoice?> show(BuildContext context) => showModalBottomSheet<BetterRouteChoice>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: context.surfaceCard,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(GuidyUi.radius))),
        builder: (_) => const BetterRouteSheet(),
      );

  @override
  State<BetterRouteSheet> createState() => _BetterRouteSheetState();
}

class _BetterRouteSheetState extends State<BetterRouteSheet> {
  final TextEditingController _text = TextEditingController();
  bool _writing = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ink = betterRouteInk(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: context.isDark ? Colors.white24 : GuidyUi.mist, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(children: [
              if (_writing)
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  color: ink,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: () => setState(() => _writing = false),
                )
              else
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 10),
                  child: Icon(Icons.tips_and_updates_outlined, color: ink, size: 26),
                ),
              Expanded(
                child: Text(_writing ? l10n.betterRouteWriteTitle : l10n.betterRouteButton,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GuidyUi.heading(context))),
              ),
            ]),
            const SizedBox(height: 6),
            if (!_writing) ...[
              Text(l10n.betterRouteSheetIntro, style: TextStyle(fontSize: 13.5, height: 1.35, color: context.textSecondary)),
              const SizedBox(height: 14),
              _choice(
                key: const ValueKey('better-route-write'),
                icon: Icons.edit_note_rounded,
                title: l10n.betterRouteWriteTitle,
                subtitle: l10n.betterRouteWriteSubtitle,
                onTap: () => setState(() => _writing = true),
              ),
              const SizedBox(height: 10),
              _choice(
                key: const ValueKey('better-route-build'),
                icon: Icons.alt_route_rounded,
                title: l10n.betterRouteBuildTitle,
                subtitle: l10n.betterRouteBuildSubtitle,
                onTap: () => Navigator.pop(context, const BetterRouteBuild()),
              ),
            ] else ...[
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('better-route-text'),
                controller: _text,
                autofocus: true,
                minLines: 3,
                maxLines: 6,
                maxLength: RouteReportService.maxCommentLength,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(hintText: l10n.betterRouteWriteHint, border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              GuidyGradientButton(
                key: const ValueKey('better-route-send'),
                icon: Icons.send_rounded,
                label: l10n.reportSubmit,
                onPressed: _text.text.trim().isEmpty ? null : () => Navigator.pop(context, BetterRouteWritten(_text.text)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _choice({
    required Key key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final ink = betterRouteInk(context);
    return GuidyCard(
      key: key,
      onTap: onTap,
      borderColor: ink.withValues(alpha: 0.5),
      padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 10, 14),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: AppColors.brandAmber.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: Icon(icon, color: ink, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(fontSize: 12.5, color: context.textSecondary)),
          ]),
        ),
        Icon(Icons.chevron_right_rounded, color: GuidyUi.mutedText(context)),
      ]),
    );
  }
}
