import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/route_report_service.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet allowing riders to submit 1-tap live transit condition updates.
class QuickCommuteReportSheet extends StatefulWidget {
  final Map<String, dynamic> routeData;
  final List<dynamic>? steps;
  final String? startName;
  final String? endName;

  const QuickCommuteReportSheet({
    super.key,
    required this.routeData,
    this.steps,
    this.startName,
    this.endName,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> routeData,
    List<dynamic>? steps,
    String? startName,
    String? endName,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickCommuteReportSheet(
        routeData: routeData,
        steps: steps,
        startName: startName,
        endName: endName,
      ),
    );
  }

  @override
  State<QuickCommuteReportSheet> createState() => _QuickCommuteReportSheetState();
}

class _QuickCommuteReportSheetState extends State<QuickCommuteReportSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  RouteReportReason? _selectedReason;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReport(RouteReportReason reason, String label) async {
    if (_isSubmitting) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _selectedReason = reason;
      _isSubmitting = true;
    });

    final l10n = AppLocalizations.of(context);
    final comment = _commentCtrl.text.trim().isNotEmpty
        ? '[$label] ${_commentCtrl.text.trim()}'
        : label;

    final opt = widget.routeData['option'] is Map
        ? Map<String, dynamic>.from(widget.routeData['option'] as Map)
        : Map<String, dynamic>.from(widget.routeData);
    if (widget.steps != null && opt['instructions'] == null) {
      opt['instructions'] = widget.steps;
    }
    final stepsCount = (widget.steps ?? opt['instructions'] as List?)?.length ?? 0;
    final stepIndexes = <int>{for (var i = 0; i < stepsCount; i++) i};
    final sName = widget.startName ?? widget.routeData['start_name']?.toString() ?? '';
    final eName = widget.endName ?? widget.routeData['end_name']?.toString() ?? '';
    final locale = Localizations.localeOf(context).languageCode;

    try {
      await RouteReportService.submit(
        option: opt,
        stepIndexes: stepIndexes,
        reason: reason,
        comment: comment,
        startName: sName,
        endName: eName,
        locale: locale,
      );
    } catch (_) {
      // Ignored: submit gracefully handles offline and unauthenticated states
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.reportThanksToast),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = context.isDark;

    final categories = [
      (
        Icons.traffic_rounded,
        const Color(0xFFE76F51),
        RouteReportReason.badTiming,
        l10n.reportCategoryTraffic,
      ),
      (
        Icons.timer_off_rounded,
        const Color(0xFFF4A261),
        RouteReportReason.routeDoesNotExist,
        l10n.reportCategoryMissing,
      ),
      (
        Icons.groups_rounded,
        const Color(0xFF2A9D8F),
        RouteReportReason.other,
        l10n.reportCategoryCrowd,
      ),
      (
        Icons.payments_rounded,
        const Color(0xFF457B9D),
        RouteReportReason.wrongFare,
        l10n.reportCategoryFare,
      ),
      (
        Icons.alt_route_rounded,
        const Color(0xFF9B5DE5),
        RouteReportReason.wrongStop,
        l10n.reportCategoryDiversion,
      ),
    ];

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: context.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.campaign_rounded, color: AppColors.primaryTeal, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.quickReportTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                    Text(
                      l10n.quickReportSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...categories.map((cat) {
            final icon = cat.$1;
            final color = cat.$2;
            final reason = cat.$3;
            final label = cat.$4;
            final isSelected = _selectedReason == reason && _isSubmitting;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _isSubmitting ? null : () => _submitReport(reason, label),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        if (isSelected)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryTeal),
                          )
                        else
                          Icon(Icons.arrow_forward_ios_rounded, size: 14, color: context.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          TextField(
            controller: _commentCtrl,
            maxLines: 2,
            style: TextStyle(fontSize: 13, color: context.textPrimary),
            decoration: InputDecoration(
              hintText: l10n.reportNotePlaceholder,
              hintStyle: TextStyle(fontSize: 12.5, color: context.textSecondary),
              filled: true,
              fillColor: context.fieldFill,
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
