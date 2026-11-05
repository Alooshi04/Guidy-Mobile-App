import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/ride_report_service.dart';
import '../services/transit_modes.dart';
import '../theme/app_theme.dart';

String rideVehicleLabel(AppLocalizations l10n, String v) => switch (v) {
      'tuktuk' => l10n.rideVehicleTuktuk,
      'taxi' => l10n.rideVehicleTaxi,
      'other' => l10n.rideVehicleOther,
      _ => TransitModes.label(l10n, v),
    };

/// Asks which vehicle the rider took and its fare. Null if dismissed.
Future<({String vehicle, num fare})?> showRideReportSheet(BuildContext context) {
  return showModalBottomSheet<({String vehicle, num fare})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _RideReportSheet(),
  );
}

class _RideReportSheet extends StatefulWidget {
  const _RideReportSheet();

  @override
  State<_RideReportSheet> createState() => _RideReportSheetState();
}

class _RideReportSheetState extends State<_RideReportSheet> {
  String? _vehicle;
  final _fare = TextEditingController();

  @override
  void dispose() {
    _fare.dispose();
    super.dispose();
  }

  num? get _fareValue {
    final n = num.tryParse(_fare.text.trim());
    return n != null && n >= 0 && n <= 500 ? n : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ready = _vehicle != null && _fareValue != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.rideReportTitle,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: context.textPrimary),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in RideReportService.vehicles)
                ChoiceChip(
                  label: Text(rideVehicleLabel(l10n, v)),
                  selected: _vehicle == v,
                  onSelected: (_) => setState(() => _vehicle = v),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fare,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(labelText: l10n.rideReportFare),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: ready ? () => Navigator.pop(context, (vehicle: _vehicle!, fare: _fareValue!)) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              l10n.rideReportStart,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
