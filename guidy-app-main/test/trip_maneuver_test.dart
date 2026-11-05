import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/trip/trip_maneuver.dart';

final en = lookupAppLocalizations(const Locale('en'));

// ~111 m per 0.001 deg of latitude.
LatLng at(double metresNorth) => LatLng(30 + metresNorth / 111195, 31);

const _trip = [
  {'action': 'walk_to_station', 'station': 'Ramses', 'lat': 30.0, 'lon': 31.0, 'distance_m': 600},
  {'action': 'board', 'station': 'Ramses', 'vehicle_type': 'metro', 'route_number': '1', 'lat': 30.009, 'lon': 31.0},
  {'action': 'arrive', 'station': 'Tahrir', 'lat': 30.02, 'lon': 31.0},
];

WalkManeuverInfo? maneuver({int step = 0, LatLng? here, List<List<LatLng>> walks = const []}) => TripManeuver.current(
      en,
      instructions: _trip,
      step: step,
      stepPoints: [for (final s in _trip) LatLng(s['lat'] as double, s['lon'] as double)],
      walkSegments: walks,
      allPoints: const [],
      here: here,
      destinationTitle: 'Tahrir',
    );

void main() {
  test('last step: arrived, with the destination', () {
    final m = maneuver(step: 2)!;
    expect(m.headline, en.navYouArrived);
    expect(m.subline, 'Tahrir');
  });

  test('riding: the line, and where to get off', () {
    final m = maneuver(step: 1, here: at(0))!;
    expect(m.iconKey, 'metro');
    expect(m.subline, en.navRideTo('Tahrir'));
    expect(m.isProximityAlert, isFalse);
  });

  test('riding within 200 m of the stop: get ready to get off', () {
    final m = maneuver(step: 1, here: at(2100))!; // ~124 m before Tahrir
    expect(m.isProximityAlert, isTrue);
    expect(m.headline, en.navGetReadyOff('Tahrir'));
  });

  test('walking, far from the station: walk there, then board', () {
    final m = maneuver(here: at(0))!;
    expect(m.iconKey, 'walk');
    expect(m.headline, contains('Ramses'));
    expect(m.subline, isNotEmpty); // "then take Metro 1"
  });

  test('walking to a ride: "then take minibus 66" gets its fare beside it', () {
    final trip = [
      {..._trip[0]},
      {..._trip[1], 'vehicle_type': 'minibus', 'route_number': '66', 'fare_egp': 10},
      {..._trip[2]},
    ];
    WalkManeuverInfo m(Locale l, LatLng here) => TripManeuver.current(
          lookupAppLocalizations(l),
          instructions: trip,
          step: 0,
          stepPoints: [for (final s in trip) LatLng(s['lat'] as double, s['lon'] as double)],
          walkSegments: const [],
          allPoints: const [],
          here: here,
          destinationTitle: 'Tahrir',
        )!;
    final far = m(const Locale('en'), at(0));
    expect(far.subline, 'Then take minibus 66');
    expect(far.fare, '10 EGP');
    final near = m(const Locale('en'), at(950)); // ~50 m before Ramses
    expect(near.isProximityAlert, isTrue);
    expect(near.subline, '50 m, then take minibus 66');
    expect(near.fare, '10 EGP');
    final ar = m(const Locale('ar'), at(0));
    expect(ar.subline, 'وبعدين اركب ميني باص رقم 66');
    expect(ar.fare, lookupAppLocalizations(const Locale('ar')).fareEgp('10'));
    expect(maneuver(here: at(0))!.fare, isNull, reason: 'the metro has no fare of its own');
  });

  test('no maneuver line has a middle dot or a tilde', () {
    for (final here in [at(0), at(950), at(2100)]) {
      for (final step in [0, 1, 2]) {
        final m = maneuver(step: step, here: here)!;
        for (final t in [m.headline, m.subline]) {
          expect(t, isNot(contains('\u00b7')));
          expect(t, isNot(contains('~')));
        }
      }
    }
  });

  test('walking with a sharp turn ahead: the turn', () {
    // North 100 m, then east: a right turn ~100 m ahead.
    final walk = [at(0), at(50), at(100), const LatLng(30 + 100 / 111195, 31.002)];
    final m = maneuver(here: at(0), walks: [walk])!;
    expect(m.headline, contains(en.walkManeuverRight));
  });

  test('no steps: nothing to show', () {
    expect(
      TripManeuver.current(en,
          instructions: const [], step: 0, stepPoints: const [], walkSegments: const [], allPoints: const [],
          here: null, destinationTitle: ''),
      isNull,
    );
  });
}
