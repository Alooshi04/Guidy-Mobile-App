import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../l10n/app_localizations.dart';
import '../services/whats_new.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';

/// Every release's notes, newest first, from the same list as the one-time
/// "What's new" popup ([WhatsNew.entries]). The version riders are on is
/// marked.
class PatchNotesScreen extends StatefulWidget {
  const PatchNotesScreen({super.key, this.currentBuild});

  /// Which build is installed; read from the app itself when null (tests
  /// pass it).
  final int? currentBuild;

  @override
  State<PatchNotesScreen> createState() => _PatchNotesScreenState();
}

class _PatchNotesScreenState extends State<PatchNotesScreen> {
  int? _build;

  @override
  void initState() {
    super.initState();
    _build = widget.currentBuild;
    if (_build == null) {
      PackageInfo.fromPlatform().then((info) {
        if (mounted) setState(() => _build = int.tryParse(info.buildNumber));
      }).catchError((_) {});
    }
  }

  String _date(BuildContext context, String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return DateFormat.yMMMd(Localizations.localeOf(context).toString()).format(d);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      key: const ValueKey('patch_notes'),
      backgroundColor: context.surfaceCard,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: GuidyHeader(title: l10n.patchNotesTitle, showLanguageToggle: false),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                for (final e in WhatsNew.entries) _entry(context, l10n, e),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entry(BuildContext context, AppLocalizations l10n, WhatsNewEntry e) {
    final current = e.build == _build;
    return Container(
      key: ValueKey('patch_notes_${e.build}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: BorderRadius.circular(GuidyUi.radius),
        border: Border.all(color: current ? AppColors.brandBlue : GuidyUi.mist.withValues(alpha: 0.7), width: current ? 1.6 : 1),
        boxShadow: GuidyUi.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text('${e.version} (${e.build})',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: context.textPrimary)),
              if (current)
                Container(
                  key: const ValueKey('patch_notes_current'),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(l10n.patchNotesCurrent,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brandBlue)),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(_date(context, e.date), style: TextStyle(fontSize: 12.5, color: context.textSecondary)),
          const SizedBox(height: 10),
          for (final note in e.notesFor(l10n.localeName))
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(fontSize: 14.5, height: 1.4, color: context.textPrimary)),
                  Expanded(child: Text(note, style: TextStyle(fontSize: 14.5, height: 1.4, color: context.textPrimary))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
