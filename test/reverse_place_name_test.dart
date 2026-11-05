import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/maps_link_parser.dart';

/// A dropped pin is named from Nominatim's reverse answer. Pins on a
/// building used to come back as its house number ("17", "17 Tahrir St").
void main() {
  String? pick(Map<String, dynamic> data) => MapsLinkParser.placeNameFromReverse(data);

  test('a place with a real name keeps it', () {
    expect(pick({'name': 'Cairo Tower', 'address': {'road': 'Hadayek El Zohreya'}}), 'Cairo Tower');
  });

  test('a house number name becomes the street, without the number', () {
    expect(pick({'name': '17', 'address': {'house_number': '17', 'road': 'Tahrir Street'}}), 'Tahrir Street');
  });

  test('Arabic-Indic digits are a number too', () {
    expect(pick({'name': '١٧', 'address': {'road': 'شارع التحرير'}}), 'شارع التحرير');
  });

  test('ranges, slashes and lettered numbers are numbers', () {
    for (final n in ['12/3', '12-14', '12A', '12 B', '11511']) {
      expect(pick({'name': n, 'address': {'road': 'Nile Corniche'}}), 'Nile Corniche', reason: n);
    }
  });

  test('a name that starts with a number is still a name', () {
    expect(pick({'name': '15 May', 'address': {'road': 'Ring Road'}}), '15 May');
  });

  test('a landmark beats the street', () {
    expect(
      pick({'name': '', 'address': {'amenity': 'Al Azhar Park', 'road': 'Salah Salem'}}),
      'Al Azhar Park',
    );
  });

  test('no street: the area', () {
    expect(pick({'address': {'house_number': '4', 'suburb': 'Zamalek', 'postcode': '11211'}}), 'Zamalek');
  });

  test('a numbered road (a postcode, a road code) is skipped for the area', () {
    expect(pick({'address': {'road': '11511', 'neighbourhood': 'Garden City'}}), 'Garden City');
  });

  test('only a display name: its first part that is not a number or postcode', () {
    expect(pick({'display_name': '5, 11511, Qasr El Nil, Cairo, Egypt'}), 'Qasr El Nil');
  });

  test('nothing usable: null, so the caller shows its own label', () {
    expect(pick({'name': '22', 'display_name': '22, 11511'}), isNull);
  });

  group('in the app language', () {
    final data = {
      'address': {'road': 'المنار', 'suburb': 'Smouha', 'city': 'Alexandria'},
    };

    test('English app: an Arabic-only street gives way to the English area', () {
      expect(MapsLinkParser.placeNameFromReverse(data, lang: 'en'), 'Smouha');
    });

    test('Arabic app: the Arabic street', () {
      expect(MapsLinkParser.placeNameFromReverse(data, lang: 'ar'), 'المنار');
    });

    test('nothing in the right script: the most specific name, never the city', () {
      expect(
        MapsLinkParser.placeNameFromReverse(
            {'address': {'road': 'المنار', 'city': 'Alexandria'}}, lang: 'en'),
        'المنار',
      );
    });
  });
}
