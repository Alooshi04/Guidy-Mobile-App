import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/guidy_ui.dart';

/// One place that knows what each vehicle_type looks like.
///
/// This exists because adding the monorail, the LRT and the airport
/// shuttle meant touching FOUR separate copies of the same switch --
/// TripRecapScreen._vehicleIcon, TripRecapScreen._stepIcon,
/// MapScreen._stepIcon and RouteOptionsScreen's inline one -- each of
/// which silently fell through to a bus icon for anything it didn't
/// recognise. Three of the four would have kept showing a bus for the
/// monorail and nobody would have seen an error, because a `default:`
/// branch is not a compile failure.
///
/// The backend is the source of these strings; they arrive as
/// `vehicle_type` on every instruction and route. Keep this list in step
/// with AGENCY_VEHICLE_TYPES / ROUTE_TYPE_VEHICLE_TYPES in
/// raptor_engine.py.
class TransitModes {
  TransitModes._();

  /// Rail modes, in the order they should appear in a filter row.
  static const List<String> rail = ['metro', 'monorail', 'lrt'];

  /// Every mode the Lines browser offers as a filter chip, `null` first
  /// for "all". The airport shuttle is deliberately absent: it is four
  /// stops inside one airport, and giving it equal billing with the metro
  /// in a city-wide browser would be misleading about what it is.
  static const List<String?> browsableFilters = [
    null, 'bus', 'minibus', 'microbus', 'brt', 'metro', 'monorail', 'lrt',
  ];

  static IconData icon(String? vehicleType) {
    switch (vehicleType) {
      case 'metro':
        return Icons.directions_subway;
      // Flutter's stable channel has no `Icons.monorail` -- verified
      // against packages/flutter/lib/src/material/icons.dart, where every
      // other icon named here is present and that one is not. `tram` is
      // used instead: a single elevated car is the closest available
      // reading of a straddle-beam monorail, and it stays visually
      // distinct from the metro's `directions_subway`, which matters
      // because the two meet at Cairo Stadium. `directions_transit` was
      // the obvious alternative and was rejected -- Material draws it as
      // the same train front as `directions_subway`, so the metro and the
      // monorail would have been indistinguishable in an itinerary.
      case 'monorail':
        return Icons.tram;
      case 'lrt':
        return Icons.train;
      case 'tram':
        return Icons.directions_railway;
      case 'apm':
        return Icons.local_airport;
      case 'minibus':
        return Icons.directions_bus_filled;
      case 'microbus':
        return Icons.airport_shuttle;
      // Ring Road bus rapid transit. A bus, so a bus glyph -- the rounded
      // variant plus its own red keeps it apart from a CTA bus leg.
      case 'brt':
        return Icons.directions_bus_rounded;
      case 'walk':
        return Icons.directions_walk;
      case 'transfer':
        return Icons.swap_horiz;
      case 'arrive':
        return Icons.flag;
      default:
        return Icons.directions_bus;
    }
  }

  /// The colour of a trip step by its icon key (see
  /// InstructionFormatter.iconKey), for callers without the step itself.
  /// Prefer GuidyModeStyle.forStep, which knows the metro line.
  static Color stepColor(String iconKey) {
    switch (iconKey) {
      case 'walk':
        return GuidyModeStyle.walkStep;
      case 'transfer':
        return GuidyModeStyle.changeStep;
      case 'arrive':
        return GuidyModeStyle.arriveStep;
      default:
        return GuidyModeStyle.color(iconKey);
    }
  }

  /// A mode's colour: GuidyModeStyle.color, the one palette in the app.
  /// Prefer GuidyModeStyle.forRide, which gives each metro line its own.
  static Color color(String? vehicleType) => GuidyModeStyle.color(vehicleType);

  static String label(AppLocalizations l10n, String? vehicleType) {
    switch (vehicleType) {
      case 'bus':
        return l10n.vehicleBus;
      case 'minibus':
        return l10n.vehicleMinibus;
      case 'microbus':
        return l10n.vehicleMicrobus;
      case 'metro':
        return l10n.vehicleMetro;
      case 'monorail':
        return l10n.vehicleMonorail;
      case 'lrt':
        return l10n.vehicleLrt;
      case 'tram':
        return l10n.vehicleTram;
      case 'apm':
        return l10n.vehicleAirportShuttle;
      case 'brt':
        return l10n.vehicleBrt;
      case 'walk':
        return l10n.vehicleWalk;
      default:
        return l10n.vehicleBus;
    }
  }

  /// True for modes that run on their own right of way and are boarded at
  /// a named station -- used where the UI needs to say "station" rather
  /// than "stop", and to pick a station icon over a kerbside one.
  static bool isRail(String? vehicleType) =>
      vehicleType == 'metro' ||
      vehicleType == 'monorail' ||
      vehicleType == 'lrt' ||
      vehicleType == 'tram' ||
      vehicleType == 'apm' ||
      // Not rail, but boarded the same way: a named station on its own
      // right of way, reached by footbridge, not a kerbside stop.
      vehicleType == 'brt';
}
