import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/simple_mode.dart';
import '../services/walk_feedback_service.dart';
import '../theme/app_theme.dart';

String walkReasonLabel(AppLocalizations l10n, WalkReportReason r) => switch (r) {
      WalkReportReason.throughBuildings => l10n.walkReasonBuildings,
      WalkReportReason.tooLong => l10n.walkReasonTooLong,
      WalkReportReason.noPath => l10n.walkReasonNoPath,
      WalkReportReason.other => l10n.walkReasonOther,
    };

IconData _reasonIcon(WalkReportReason r) => switch (r) {
      WalkReportReason.throughBuildings => Icons.apartment_rounded,
      WalkReportReason.tooLong => Icons.straighten_rounded,
      WalkReportReason.noPath => Icons.block_rounded,
      WalkReportReason.other => Icons.more_horiz_rounded,
    };

/// Asks what is wrong with a walk. Null if dismissed. In [simple] mode the
/// reasons and the button are at least 56 dp tall with larger words.
Future<({WalkReportReason reason, String note})?> showWalkReportSheet(BuildContext context, {bool simple = false}) {
  return showModalBottomSheet<({WalkReportReason reason, String note})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _WalkReportSheet(simple: simple),
  );
}

class _WalkReportSheet extends StatefulWidget {
  const _WalkReportSheet({required this.simple});

  final bool simple;

  @override
  State<_WalkReportSheet> createState() => _WalkReportSheetState();
}

class _WalkReportSheetState extends State<_WalkReportSheet> {
  WalkReportReason? _reason;
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final simple = widget.simple;
    final double minH = simple ? SimpleModeController.minTarget : 48;
    final double font = simple ? 20 : 15;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.walkReportTitle,
              key: const ValueKey('walk_report_title'),
              style: TextStyle(fontSize: simple ? 24 : 17, fontWeight: FontWeight.bold, color: context.textPrimary),
            ),
            const SizedBox(height: 12),
            for (final r in WalkReportReason.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ReasonTile(
                  key: ValueKey('walk_reason_${r.wire}'),
                  icon: _reasonIcon(r),
                  label: walkReasonLabel(l10n, r),
                  selected: _reason == r,
                  minHeight: minH,
                  fontSize: font,
                  onTap: () => setState(() => _reason = r),
                ),
              ),
            const SizedBox(height: 4),
            TextField(
              key: const ValueKey('walk_report_note'),
              controller: _note,
              maxLength: WalkFeedbackService.maxNoteLength,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.done,
              style: TextStyle(fontSize: font),
              decoration: InputDecoration(labelText: l10n.walkReportNote),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              key: const ValueKey('walk_report_send'),
              onPressed: _reason == null ? null : () => Navigator.pop(context, (reason: _reason!, note: _note.text.trim())),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                disabledBackgroundColor: AppColors.primaryTeal.withValues(alpha: 0.35),
                minimumSize: Size.fromHeight(simple ? 64 : 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                l10n.walkReportSend,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: simple ? 20 : 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  const _ReasonTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.minHeight,
    required this.fontSize,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final double minHeight;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final edge = selected ? AppColors.primaryTeal : (context.isDark ? Colors.white30 : Colors.black26);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: edge, width: selected ? 2.5 : 1.5),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? AppColors.primaryTeal.withValues(alpha: context.isDark ? 0.22 : 0.12) : context.surfaceCard,
        shape: shape,
        child: InkWell(
          customBorder: shape,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: fontSize + 8, color: context.textPrimary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700, color: context.textPrimary)),
                  ),
                  if (selected) Icon(Icons.check_circle_rounded, size: fontSize + 8, color: AppColors.primaryTeal),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
