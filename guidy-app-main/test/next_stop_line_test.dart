import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/trip/next_stop_line.dart';

final en = lookupAppLocalizations(const Locale('en'));

// ~111 m per 0.001 deg of latitude.
LatLng at(double metresNorth) => LatLng(30 + metresNorth / 111195, 31);

const _steps = [
  {'action': 'walk_to_station', 'station': 'Ramses', 'distance_m': 640},
  {'action': 'board', 'station': 'Ramses'},
  {'action': 'arrive', 'station': 'Tahrir'},
];

String? line({int step = 0, LatLng? here, LatLng? destination}) => nextStopLine(
      en,
      instructions: _steps,
      step: step,
      stepPoints: [at(0), at(2000), at(5000)],
      here: here,
      destination: destination ?? at(5000),
      progress: null,
      isArabic: false,
    );

void main() {
  // The card's title already says "Walk to Ramses": the live line says
  // only what is left, in words (beta feedback, 2026-11).
  test('metres left to the next stop by GPS, without repeating its name', () {
    expect(line(here: at(1500)), '500 m left, about 7 min');
  });

  test('a long walk counts in metres too', () {
    expect(line(here: at(0)), '2000 m left, about 27 min');
  });

  test('a ride with no pace to count by names where to get off', () {
    expect(line(step: 1, here: at(3000)), '2.0 km to Tahrir');
  });

  test('within 100 m: arriving', () {
    expect(line(here: at(1950)), 'Arriving at Ramses...');
  });

  test('no position yet: empty, so the step\'s planned line stands', () {
    expect(line(), '');
  });

  test('no separators, and never "0 m" or a bare "~minute"', () {
    for (final here in [at(1500), at(0), at(1950), at(1999)]) {
      final text = line(here: here)!;
      expect(text, isNot(contains('\u00b7')));
      expect(text, isNot(contains('~')));
      expect(text, isNot(startsWith('0 m')));
    }
  });

  test('last step at the destination: arrived', () {
    expect(line(step: 2, here: at(5000)), en.youHaveArrived);
  });

  test('no steps: nothing to say', () {
    expect(
      nextStopLine(en,
          instructions: const [], step: 0, stepPoints: const [], here: null,
          destination: null, progress: null, isArabic: false),
      isNull,
    );
  });
}
