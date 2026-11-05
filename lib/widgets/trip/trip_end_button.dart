import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// "End trip", the last thing in the trip sheet: under every step, apart
/// from the other controls, and clear of the phone's navigation bar.
class TripEndButton extends StatelessWidget {
  const TripEndButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 24, 20, 16 + MediaQuery.of(context).viewPadding.bottom),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton.icon(
          key: const ValueKey('trip_end_button'),
          onPressed: onPressed,
          icon: const Icon(Icons.stop_circle_outlined, size: 20),
          label: Text(l10n.simpleEndTrip, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent, width: 1.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    );
  }
}
