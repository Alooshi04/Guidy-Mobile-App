import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/maps_link_parser.dart';

void main() {
  // ────────────────────────────────────────────────────────────────────
  // looksLikeMapsInput
  // ────────────────────────────────────────────────────────────────────
  group('looksLikeMapsInput', () {
    test('accepts long Google Maps URLs', () {
      expect(MapsLinkParser.looksLikeMapsInput(
        'https://www.google.com/maps/place/Cairo+Tower/@30.0459,31.2243,17z',
      ), isTrue);
    });

    test('accepts google.com.eg TLD', () {
      expect(MapsLinkParser.looksLikeMapsInput(
        'https://www.google.com.eg/maps/@30.0444,31.2357,15z',
      ), isTrue);
    });

    test('accepts maps.google.com variant', () {
      expect(MapsLinkParser.looksLikeMapsInput(
        'https://maps.google.com/@30.0444,31.2357',
      ), isTrue);
    });

    test('accepts short links (maps.app.goo.gl)', () {
      expect(MapsLinkParser.looksLikeMapsInput(
        'https://maps.app.goo.gl/abc123xyz',
      ), isTrue);
    });

    test('accepts short links (goo.gl/maps)', () {
      expect(MapsLinkParser.looksLikeMapsInput(
        'https://goo.gl/maps/abc123xyz',
      ), isTrue);
    });

    test('accepts bare coordinate pair', () {
      expect(MapsLinkParser.looksLikeMapsInput('30.0444, 31.2357'), isTrue);
    });

    test('accepts geo: URI', () {
      expect(MapsLinkParser.looksLikeMapsInput('geo:30.0444,31.2357'), isTrue);
    });

    test('rejects plain text', () {
      expect(MapsLinkParser.looksLikeMapsInput('hello world'), isFalse);
    });

    test('rejects empty string', () {
      expect(MapsLinkParser.looksLikeMapsInput(''), isFalse);
    });

    test('rejects phone numbers', () {
      expect(MapsLinkParser.looksLikeMapsInput('+20 2 1234 5678'), isFalse);
    });

    test('rejects integers without decimals', () {
      // Bare "12, 34" should not be recognized — needs decimal points
      expect(MapsLinkParser.looksLikeMapsInput('12, 34'), isFalse);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // parse — long Google Maps URLs
  // ────────────────────────────────────────────────────────────────────
  group('parse long URLs', () {
    test('extracts coordinates from !3d/!4d format', () async {
      final result = await MapsLinkParser.parse(
        'https://www.google.com/maps/place/Cairo+Tower/@30.0459,31.2243,17z/data=!3d30.0459!4d31.2243',
      );
      expect(result, isNotNull);
      expect(result!.lat, closeTo(30.0459, 0.001));
      expect(result.lon, closeTo(31.2243, 0.001));
    });

    test('extracts place name from /maps/place/ URL', () async {
      final result = await MapsLinkParser.parse(
        'https://www.google.com/maps/place/Cairo+Tower/@30.0459,31.2243,17z/data=!3d30.0459!4d31.2243',
      );
      expect(result, isNotNull);
      expect(result!.name, equals('Cairo Tower'));
    });

    test('extracts coordinates from @ viewport format', () async {
      final result = await MapsLinkParser.parse(
        'https://www.google.com/maps/@30.0444,31.2357,15z',
      );
      expect(result, isNotNull);
      expect(result!.lat, closeTo(30.0444, 0.001));
      expect(result.lon, closeTo(31.2357, 0.001));
    });

    test('prefers !3d/!4d over @ when both present', () async {
      final result = await MapsLinkParser.parse(
        'https://www.google.com/maps/place/X/@29.0,32.0,15z/data=!3d30.0459!4d31.2243',
      );
      expect(result, isNotNull);
      // Should get the !3d/!4d coordinates, not the @ ones
      expect(result!.lat, closeTo(30.0459, 0.001));
      expect(result.lon, closeTo(31.2243, 0.001));
    });

    test('extracts from ?q=lat,lng query parameter', () async {
      final result = await MapsLinkParser.parse(
        'https://www.google.com/maps?q=30.0444,31.2357',
      );
      expect(result, isNotNull);
      expect(result!.lat, closeTo(30.0444, 0.001));
    });

    test('extracts from ?ll=lat,lng query parameter', () async {
      final result = await MapsLinkParser.parse(
        'https://www.google.com/maps?ll=30.0444,31.2357',
      );
      expect(result, isNotNull);
      expect(result!.lat, closeTo(30.0444, 0.001));
    });

    test('returns null for maps URL with no coordinates', () async {
      final result = await MapsLinkParser.parse(
        'https://www.google.com/maps/search/restaurants/',
      );
      expect(result, isNull);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // parse — geo: URIs
  // ────────────────────────────────────────────────────────────────────
  group('parse geo: URIs', () {
    test('plain geo:lat,lon', () async {
      final result = await MapsLinkParser.parse('geo:30.0444,31.2357');
      expect(result, isNotNull);
      expect(result!.lat, closeTo(30.0444, 0.001));
      expect(result.lon, closeTo(31.2357, 0.001));
      expect(result.name, isNull);
    });

    test('geo:0,0?q=lat,lon(Label) extracts q and label', () async {
      final result = await MapsLinkParser.parse(
        'geo:0,0?q=30.0444,31.2357(Cairo%20Tower)',
      );
      expect(result, isNotNull);
      expect(result!.lat, closeTo(30.0444, 0.001));
      expect(result.name, equals('Cairo Tower'));
    });

    test('geo:0,0?q=lat,lon without label', () async {
      final result = await MapsLinkParser.parse('geo:0,0?q=30.0444,31.2357');
      expect(result, isNotNull);
      expect(result!.lat, closeTo(30.0444, 0.001));
      expect(result.name, isNull);
    });

    test('geo:0,0 alone returns null (placeholder, not real)', () async {
      final result = await MapsLinkParser.parse('geo:0,0');
      expect(result, isNull);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // parse — bare coordinate pairs
  // ────────────────────────────────────────────────────────────────────
  group('parse bare coordinates', () {
    test('valid coordinate pair', () async {
      final result = await MapsLinkParser.parse('30.0444, 31.2357');
      expect(result, isNotNull);
      expect(result!.lat, closeTo(30.0444, 0.001));
      expect(result.lon, closeTo(31.2357, 0.001));
      expect(result.name, isNull);
    });

    test('valid with extra whitespace', () async {
      final result = await MapsLinkParser.parse('  30.0444 , 31.2357  ');
      expect(result, isNotNull);
      expect(result!.lat, closeTo(30.0444, 0.001));
    });

    test('negative coordinates (Southern/Western hemisphere)', () async {
      final result = await MapsLinkParser.parse('-33.8688, 151.2093');
      expect(result, isNotNull);
      expect(result!.lat, closeTo(-33.8688, 0.001));
    });

    test('out of range lat returns null', () async {
      final result = await MapsLinkParser.parse('91.0000, 31.0000');
      expect(result, isNull);
    });

    test('integers without decimal points rejected', () async {
      final result = await MapsLinkParser.parse('12, 34');
      expect(result, isNull);
    });
  });

  // ────────────────────────────────────────────────────────────────────
  // parse — non-maps input
  // ────────────────────────────────────────────────────────────────────
  group('parse non-maps input', () {
    test('plain text returns null', () async {
      expect(await MapsLinkParser.parse('hello world'), isNull);
    });

    test('empty string returns null', () async {
      expect(await MapsLinkParser.parse(''), isNull);
    });

    test('random URL returns null', () async {
      expect(await MapsLinkParser.parse('https://example.com'), isNull);
    });
  });
}
