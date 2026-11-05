import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_localizations.dart';
import '../services/route_report_service.dart';
import '../theme/app_theme.dart';

/// Modal bottom sheet allowing riders to report inaccuracies or issues on transit lines.
class LineReportSheet extends StatefulWidget {
  final String routeId;
  final String? routeNumber;
  final String? routeDescription;
  final String? vehicleType;
  final int directionIndex;
  final String? directionTerminus;
  final List<Map<String, dynamic>> stops;
  final Map<String, dynamic>? initialSelectedStop;

  const LineReportSheet({
    super.key,
    required this.routeId,
    this.routeNumber,
    this.routeDescription,
    this.vehicleType,
    required this.directionIndex,
    this.directionTerminus,
    required this.stops,
    this.initialSelectedStop,
  });

  static Future<void> show(
    BuildContext context, {
    required String routeId,
    String? routeNumber,
    String? routeDescription,
    String? vehicleType,
    required int directionIndex,
    String? directionTerminus,
    required List<Map<String, dynamic>> stops,
    Map<String, dynamic>? selectedStop,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LineReportSheet(
        routeId: routeId,
        routeNumber: routeNumber,
        routeDescription: routeDescription,
        vehicleType: vehicleType,
        directionIndex: directionIndex,
        directionTerminus: directionTerminus,
        stops: stops,
        initialSelectedStop: selectedStop,
      ),
    );
  }

  @override
  State<LineReportSheet> createState() => _LineReportSheetState();
}

class _LineReportSheetState extends State<LineReportSheet> {
  final TextEditingController _commentCtrl = TextEditingController();
  LineReportReason _selectedReason = LineReportReason.wrongStop;
  Map<String, dynamic>? _selectedStop;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedStop = widget.initialSelectedStop;
  }

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
      await RouteReportService.submitLineReport(
        routeId: widget.routeId,
        routeNumber: widget.routeNumber,
        routeDescription: widget.routeDescription,
        vehicleType: widget.vehicleType,
        directionIndex: widget.directionIndex,
        directionTerminus: widget.directionTerminus,
        stops: widget.stops,
        selectedStop: _selectedStop,
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

  String _reasonTitle(AppLocalizations l10n, LineReportReason reason) {
    switch (reason) {
      case LineReportReason.routeDoesNotExist:
        return l10n.reportReasonLineDoesNotExist;
      case LineReportReason.wrongPath:
        return l10n.reportReasonLineWrongPath;
      case LineReportReason.wrongStop:
        return l10n.reportReasonLineWrongStop;
      case LineReportReason.wrongFare:
        return l10n.reportReasonLineWrongFare;
      case LineReportReason.badTiming:
        return l10n.reportReasonLineBadTiming;
      case LineReportReason.other:
        return l10n.reportCategoryOther;
    }
  }

  IconData _reasonIcon(LineReportReason reason) {
    switch (reason) {
      case LineReportReason.routeDoesNotExist:
        return Icons.cancel_outlined;
      case LineReportReason.wrongPath:
        return Icons.alt_route_rounded;
      case LineReportReason.wrongStop:
        return Icons.wrong_location_outlined;
      case LineReportReason.wrongFare:
        return Icons.payments_outlined;
      case LineReportReason.badTiming:
        return Icons.access_time_rounded;
      case LineReportReason.other:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final displayName = widget.routeNumber ?? widget.routeDescription ?? widget.routeId;

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
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTeal.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.reportLineTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.directionTerminus != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.directionTerminus!,
                style: TextStyle(fontSize: 12, color: context.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
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
              children: LineReportReason.values.map((reason) {
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
            if (widget.stops.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n.reportPickStopOptional,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: context.fieldFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.isDark ? Colors.white12 : Colors.black12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<Map<String, dynamic>?>(
                    value: _selectedStop,
                    isExpanded: true,
                    dropdownColor: context.surfaceCard,
                    hint: Text(
                      l10n.reportAllStopsOption,
                      style: TextStyle(fontSize: 13, color: context.textSecondary),
                    ),
                    items: [
                      DropdownMenuItem<Map<String, dynamic>?>(
                        value: null,
                        child: Text(
                          l10n.reportAllStopsOption,
                          style: TextStyle(fontSize: 13, color: context.textPrimary),
                        ),
                      ),
                      ...widget.stops.map((s) {
                        final stopName = (s['name'] ?? s['station'] ?? s['stop_id'] ?? '').toString();
                        return DropdownMenuItem<Map<String, dynamic>?>(
                          value: s,
                          child: Text(
                            stopName,
                            style: TextStyle(fontSize: 13, color: context.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) => setState(() => _selectedStop = val),
                  ),
                ),
              ),
            ],
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
