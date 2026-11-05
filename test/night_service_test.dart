import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/RouteOptionsScreen.dart';

Map<String, dynamic> _opt(String type, List<String> routes, {String time = '60', String fare = '20'}) => {
      'type': type,
      'time': time,
      'fare_egp': fare,
      'fare_total_egp': fare,
      'price': '$fare EGP',
      'instructions': [
        {'action': 'walk_to_station', 'distance_m': 200},
        for (var i = 0; i < routes.length; i++)
          {
            'action': i == 0 ? 'board' : 'transfer',
            'route_id': routes[i],
            'route_number': routes[i],
            'vehicle_type': 'microbus',
          },
        {'action': 'arrive'},
      ],
    };

Widget _screen(Map<String, dynamic> data) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: RouteOptionsScreen(
        startLat: 30.0665,
        startLon: 31.3807,
        startName: '8th District',
        endLat: 30.0444,
        endLon: 31.2357,
        endName: 'Tahrir',
        initialData: data,
        showMap: false,
      ),
    );

void main() {
  test('the usual route is marked only when it rides a stopped line', () {
    final ns = {'closed_route_ids': ['L1']};
    expect(RouteOptionsScreen.isUsualOnly(_opt('Recommended', ['A', 'L1']), ns), isTrue);
    expect(RouteOptionsScreen.isUsualOnly(_opt('Cheapest', ['A']), ns), isFalse);
    expect(RouteOptionsScreen.isUsualOnly(_opt('Available now', ['L1']), ns), isFalse);
    expect(RouteOptionsScreen.isUsualOnly(_opt('Recommended', ['L1']), null), isFalse);
  });

  testWidgets('after midnight: what runs now comes first, the usual route stays', (tester) async {
    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_screen({
      'success': true,
      'options': [_opt('Recommended', ['L1'], time: '60', fare: '30')],
      'night_service': {
        'usual_route_closed': true,
        'usual_opens_at': '6:00 AM',
        'usual_opens_at_ar': '6:00 الصبح',
        'usual_opens_in_min': 330,
        'closed_route_ids': ['L1'],
        'available_now': _opt('Available now', ['M1', 'M2'], time: '66', fare: '22'),
        'nothing_running': false,
        'can_walk': false,
      },
    }));
    await tester.pumpAndSettle();
    expect(find.text('Late night: your usual lines have stopped'), findsOneWidget);
    expect(find.textContaining('6:00 AM (in 5 h 30 min)'), findsOneWidget);
    expect(find.text('Running now'), findsOneWidget);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Usual route, runs again at 6:00 AM'), findsOneWidget);
    // The running-now card is first and selected.
    final running = tester.getTopLeft(find.text('Running now'));
    final usual = tester.getTopLeft(find.text('Recommended'));
    expect(running.dy, lessThan(usual.dy));
    // 66 min, over an hour: the hours over the minutes.
    expect(find.text('1 h'), findsWidgets);
    expect(find.text('6 min'), findsWidgets);
  });

  testWidgets('deep night: says plainly the trip is impossible until the lines reopen', (tester) async {
    await tester.pumpWidget(_screen({
      'success': true,
      'options': [_opt('Recommended', ['L1'])],
      'night_service': {
        'usual_route_closed': true,
        'usual_opens_at': '5:15 AM',
        'usual_opens_in_min': 45,
        'closed_route_ids': ['L1'],
        'available_now': null,
        'nothing_running': true,
        'can_walk': true,
      },
    }));
    await tester.pumpAndSettle();
    expect(find.text("Nothing's running for this trip right now"), findsOneWidget);
    expect(find.textContaining('5:15 AM (in 45 min)'), findsOneWidget);
    expect(find.textContaining('close enough to walk'), findsOneWidget);
    expect(find.text('Running now'), findsNothing);
  });

  testWidgets('daytime: no night notice', (tester) async {
    await tester.pumpWidget(_screen({
      'success': true,
      'options': [_opt('Recommended', ['L1'])],
    }));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('night-notice')), findsNothing);
  });
}
