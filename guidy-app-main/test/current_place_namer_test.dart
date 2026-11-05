import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/current_place_namer.dart';
import 'package:guidy_app/services/maps_link_parser.dart';

void main() {
  tearDown(() => CurrentPlaceNamer.resolve = MapsLinkParser.reverseGeocodeName);

  test('a current-location place is flagged and named after the street, in the asked language', () async {
    String? askedLang;
    CurrentPlaceNamer.resolve = (lat, lon, {required fallbackLabel, lang = 'en'}) async {
      askedLang = lang;
      return 'شارع مصطفى النحاس';
    };
    final p = CurrentPlaceNamer.place(lat: 30.06, lon: 31.379, fallbackLabel: 'موقعي الحالي');
    expect(CurrentPlaceNamer.isCurrent(p), isTrue);
    final named = await CurrentPlaceNamer.named(p, lang: 'ar');
    expect(named['name'], 'شارع مصطفى النحاس');
    expect(named['lat'], 30.06);
    expect(CurrentPlaceNamer.isCurrent(named), isTrue);
    expect(askedLang, 'ar');
  });

  test('a failed lookup keeps the generic label', () async {
    CurrentPlaceNamer.resolve = (lat, lon, {required fallbackLabel, lang = 'en'}) async => throw Exception('offline');
    final p = CurrentPlaceNamer.place(lat: 30.0, lon: 31.0, fallbackLabel: 'My Current Location');
    expect((await CurrentPlaceNamer.named(p, lang: 'en'))['name'], 'My Current Location');
  });

  test('a chosen place is not a current location', () {
    expect(CurrentPlaceNamer.isCurrent({'name': 'Tahrir', 'lat': 30.0, 'lon': 31.0}), isFalse);
  });
}
