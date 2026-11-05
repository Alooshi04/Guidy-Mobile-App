import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/route_report_service.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet allowing riders to report issues with metro routes or stations.
class MetroReportSheet extends StatefulWidget {
  final Map<String, dynamic>? metroPlan;
  final Map<String, dynamic>? station;

  const MetroReportSheet({
    super.key,
    this.metroPlan,
    this.station,
  });

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? metroPlan,
    Map<String, dynamic>? station,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MetroReportSheet(
        metroPlan: metroPlan,
        station: station,
      ),
    );
  }

  @override
  State<MetroReportSheet> createState() => _MetroReportSheetState();
}

class _MetroReportSheetState extends State<MetroReportSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  MetroReportReason _selectedReason = MetroReportReason.stationClosed;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_isSubmitting) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSubmitting = true);

    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).languageCode;

    try {
      await RouteReportService.submitMetroReport(
        metroPlan: widget.metroPlan,
        station: widget.station,
        reason: _selectedReason,
        comment: _commentCtrl.text.trim(),
        locale: locale,
      );
    } catch (_) {
      // Handled gracefully in service
    }

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.reportLineSuccessToast),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _reasonTitle(AppLocalizations l10n, MetroReportReason reason) {
    switch (reason) {
      case MetroReportReason.stationClosed:
        return l10n.reportReasonMetroStationClosed;
      case MetroReportReason.wrongTransfer:
        return l10n.reportReasonMetroWrongTransfer;
      case MetroReportReason.wrongFare:
        return l10n.reportReasonMetroWrongFare;
      case MetroReportReason.delayOrDisruption:
        return l10n.reportReasonMetroDelay;
      case MetroReportReason.other:
        return l10n.reportCategoryOther;
    }
  }

  IconData _reasonIcon(MetroReportReason reason) {
    switch (reason) {
      case MetroReportReason.stationClosed:
        return Icons.do_not_disturb_on_outlined;
      case MetroReportReason.wrongTransfer:
        return Icons.swap_calls_rounded;
      case MetroReportReason.wrongFare:
        return Icons.payments_outlined;
      case MetroReportReason.delayOrDisruption:
        return Icons.warning_amber_rounded;
      case MetroReportReason.other:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    String heading = l10n.reportMetroTitle;
    String? subHeading;

    if (widget.metroPlan != null) {
      final from = widget.metroPlan!['from_station'] ?? widget.metroPlan!['from'] ?? '';
      final to = widget.metroPlan!['to_station'] ?? widget.metroPlan!['to'] ?? '';
      if (from.isNotEmpty && to.isNotEmpty) {
        subHeading = '$from ➔ $to';
      }
    } else if (widget.station != null) {
      subHeading = (widget.station!['name'] ?? widget.station!['station_name'] ?? '').toString();
    }

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: 20 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: context.surfaceCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: context.isDark ? Colors.white10 : Colors.black12)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.subway_rounded, color: AppColors.primaryTeal, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        heading,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: context.textPrimary,
                        ),
                      ),
                      if (subHeading != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subHeading,
                          style: TextStyle(fontSize: 12, color: context.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              l10n.reportReasonPrompt,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MetroReportReason.values.map((reason) {
                final isSelected = _selectedReason == reason;
                return ChoiceChip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _reasonIcon(reason),
                        size: 15,
                        color: isSelected ? Colors.white : context.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _reasonTitle(l10n, reason),
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? Colors.white : context.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primaryTeal,
                  backgroundColor: context.fieldFill,
                  showCheckmark: false,
                  onSelected: (val) {
                    if (val) setState(() => _selectedReason = reason);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commentCtrl,
              maxLength: 500,
              maxLines: 3,
              style: TextStyle(color: context.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: l10n.reportCommentHint,
                hintStyle: TextStyle(color: context.textSecondary, fontSize: 12),
                filled: true,
                fillColor: context.fieldFill,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.isDark ? Colors.white12 : Colors.black12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        l10n.reportActionSubmit,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
