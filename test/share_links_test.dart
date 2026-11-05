import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/LiveTripViewerScreen.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';
import 'package:guidy_app/services/maps_link_parser.dart';
import 'package:guidy_app/services/share_links.dart';

void main() {
  group('Guidy share links', () {
    test('a route link round-trips, names and vehicles included', () {
      final uri = ShareLinks.routeLink(
        startLat: 30.0665, startLon: 31.3807, startName: 'الحي الثامن',
        endLat: 30.0444, endLon: 31.2357, endName: 'Tahrir & Co',
        routeIds: ['CTA_69', 'NAT_L1'],
      );
      expect(uri.host, 'guidyapp.com');
      final link = ShareLinks.parse(Uri.parse(uri.toString())) as RouteShareLink;
      expect(link.startName, 'الحي الثامن');
      expect(link.endName, 'Tahrir & Co');
      expect(link.endLat, closeTo(30.0444, 1e-6));
      expect(link.routeIds, ['CTA_69', 'NAT_L1']);
    });

    test('live links work as https and as guidy://', () {
      expect((ShareLinks.parse(Uri.parse('https://guidy-19e46.web.app/l/AbC_123-xyz')) as LiveShareLink).token,
          'AbC_123-xyz');
      expect((ShareLinks.parse(Uri.parse('guidy://l/AbC_123-xyz')) as LiveShareLink).token, 'AbC_123-xyz');
      expect(ShareLinks.parse(Uri.parse('guidy://r?f=30.1,31.2&t=30.0,31.1')), isA<RouteShareLink>());
      expect((ShareLinks.parse(Uri.parse('https://guidyapp.com/l/AbC_123-xyz')) as LiveShareLink).token,
          'AbC_123-xyz');
      expect(ShareLinks.parse(Uri.parse('https://www.guidyapp.com/r?f=30.1,31.2&t=30.0,31.1')),
          isA<RouteShareLink>());
    });

    test('other links and broken ones are not Guidy links', () {
      expect(ShareLinks.parse(Uri.parse('https://maps.app.goo.gl/abc')), isNull);
      expect(ShareLinks.parse(Uri.parse('https://guidy-19e46.web.app/privacy')), isNull);
      expect(ShareLinks.parse(Uri.parse('https://guidy-19e46.web.app/r?f=abc&t=30,31')), isNull);
      expect(ShareLinks.parse(Uri.parse('https://guidy-19e46.web.app/l/x')), isNull);
    });
  });

  group('Map links inside shared text', () {
    test('WhatsApp / Google Maps share text', () {
      expect(MapsLinkParser.findInText('Cairo Tower\nhttps://maps.app.goo.gl/AbCd1234'),
          'https://maps.app.goo.gl/AbCd1234');
      expect(MapsLinkParser.findInText('تعالى هنا (https://maps.google.com/?q=30.0459,31.2243).'),
          'https://maps.google.com/?q=30.0459,31.2243');
      expect(MapsLinkParser.findInText('Location: 30.04590, 31.22430 see you'), '30.04590,31.22430');
      expect(MapsLinkParser.findInText('hello, no place here'), isNull);
    });

    test('a link with only a place name is looked up by name', () async {
      expect(MapsLinkParser.placeQueryOf('https://maps.google.com/?q=Cairo+Tower,+Zamalek&ftid=0x1:0x2'),
          'Cairo Tower, Zamalek');
      expect(MapsLinkParser.placeQueryOf('https://maps.google.com/?q=30.1,31.2'), isNull);
      final found = await MapsLinkParser.parseOrLookup(
        'https://maps.google.com/?q=Cairo+Tower&ftid=0x1:0x2',
        (q) async => ParsedMapsLocation(lat: 30.0459, lon: 31.2243, name: q),
      );
      expect(found?.name, 'Cairo Tower');
    });

    test('a link with coordinates needs no lookup', () async {
      final found = await MapsLinkParser.parseOrLookup(
        'see https://www.google.com/maps/place/X/@30.1,31.2,17z',
        (q) async => throw StateError('should not look up'),
      );
      expect(found?.lat, 30.1);
    });
  });

  test('a shared route selects the option with the same vehicles', () {
    Map<String, dynamic> opt(List<String> ids) => {
          'instructions': [
            {'action': 'walk_to_station'},
            for (var i = 0; i < ids.length; i++) {'action': i == 0 ? 'board' : 'transfer', 'route_id': ids[i]},
            {'action': 'arrive'},
          ],
        };
    final options = [opt(['A']), opt(['B', 'C']), opt(['C'])];
    expect(RouteOptionsScreen.preferredOptionIndex(options, ['B', 'C']), 1);
    expect(RouteOptionsScreen.preferredOptionIndex(options, ['C', 'B']), isNull);
    expect(RouteOptionsScreen.preferredOptionIndex(options, const []), isNull);
  });

  group('Following a live trip', () {
    Widget app(Future<Map<String, dynamic>?> Function(String) fetch) => MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: LiveTripViewerScreen(token: 'tokentoken', showMap: false, fetcher: fetch),
        );

    testWidgets('shows who, which bus and when they arrive', (tester) async {
      final eta = DateTime.now().add(const Duration(minutes: 12)).millisecondsSinceEpoch / 1000;
      await tester.pumpWidget(app((_) async => {
            'status': 'active',
            'updated_at': DateTime.now().millisecondsSinceEpoch / 1000,
            'summary': {
              'dest_name': 'Tahrir',
              'sharer_name': 'Youssef',
              'steps': [
                {'action': 'walk_to_station'},
                {'action': 'board', 'vehicle_type': 'bus', 'route_number': '69'},
              ],
            },
            'state': {'lat': 30.05, 'lon': 31.3, 'step': 1, 'eta': eta},
          }));
      await tester.pump();
      await tester.pump();
      expect(find.text('Youssef is on the way to Tahrir'), findsOneWidget);
      expect(find.textContaining('69'), findsOneWidget);
      expect(find.textContaining('Arrives around'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('an ended share says so', (tester) async {
      await tester.pumpWidget(app((_) async => null));
      await tester.pump();
      await tester.pump();
      expect(find.text('This trip is no longer being shared.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
