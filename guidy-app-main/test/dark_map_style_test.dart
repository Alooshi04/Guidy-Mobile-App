import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/theme/app_theme.dart';

// Dark mode used to hide every map icon, so shops, cafes and supermarkets
// disappeared from the map at night while light mode showed them.
void main() {
  final rules = (jsonDecode(darkMapStyleJson) as List).cast<Map<String, dynamic>>();

  String? visibility(String? feature, String element) {
    String? v;
    for (final r in rules) {
      final f = r['featureType'] as String?;
      // No featureType, or "all", covers every feature.
      final applies = f == null || f == 'all' ||
          (feature != null && (feature == f || feature.startsWith('$f.')));
      // A rule reaches an element through itself or a parent: "labels" and
      // "all" (or no elementType) cover "labels.icon" too.
      final e = r['elementType'] as String?;
      final reaches = e == null || e == 'all' || element == e || element.startsWith('$e.');
      if (!applies || !reaches) continue;
      for (final s in (r['stylers'] as List).cast<Map<String, dynamic>>()) {
        if (s.containsKey('visibility')) v = s['visibility'] as String;
      }
    }
    return v;
  }

  test('the dark style is valid JSON', () => expect(rules, isNotEmpty));

  test('places and stations keep their icons in dark mode', () {
    for (final f in ['poi', 'poi.business', 'poi.medical', 'transit.station', 'transit.station.bus']) {
      expect(visibility(f, 'labels.icon'), isNot('off'), reason: f);
    }
  });

  test('other icons stay hidden', () {
    for (final f in ['road.highway', 'road.arterial', 'road.local', 'administrative']) {
      expect(visibility(f, 'labels.icon'), 'off', reason: f);
    }
  });
}
