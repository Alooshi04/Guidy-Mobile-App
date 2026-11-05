import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/SettingsScreen.dart';
import 'package:guidy_app/screens/trip/walk_step_ends.dart';
import 'package:guidy_app/services/simple_mode.dart';
import 'package:guidy_app/services/trip_sharing.dart';
import 'package:guidy_app/services/walk_feedback_service.dart';
import 'package:guidy_app/widgets/simple/simple_step_panel.dart';
import 'package:guidy_app/widgets/trip/trip_now_card.dart';
import 'package:guidy_app/widgets/trip/trip_step_tile.dart';
import 'package:guidy_app/widgets/walk_report_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Collects what would be sent, without a network.
class _FakeOutbox extends WalkOutbox {
  _FakeOutbox() : super('walk_traces', 'fake_queue');
  final List<Map<String, dynamic>> sent = [];

  @override
  Future<void> submit(Map<String, dynamic> payload, {http.Client? client}) async => sent.add(payload);
}

const double _mLat = 1 / 110540.0; // degrees of latitude in one metre

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TripSharing.enabled.value = true; // the default
  });

  final t0 = DateTime(2026, 10, 22, 9);

  /// A straight walk north of [meters], a fix every [every] metres, 2 s apart per 3 m.
  void walk(WalkTraceRecorder r, {required int step, required double meters, double every = 10, WalkStepInfo? info, double accuracy = 8, int from = 0}) {
    final i = info ?? WalkStepInfo(tripId: 'trip1', stepIndex: step, start: const LatLng(30, 31), end: const LatLng(30.01, 31), plannedDistanceM: 900);
    for (var k = 0; k * every <= meters; k++) {
      r.onFix(
        lat: 30 + (from + k * every) * _mLat,
        lon: 31,
        accuracy: accuracy,
        time: t0.add(Duration(seconds: (from + k * every) ~/ 1.5)),
        step: step,
        walk: i,
      );
    }
  }

  group('WalkTraceRecorder', () {
    test('records by default, under "Share my trips"', () {
      final out = _FakeOutbox();
      final r = WalkTraceRecorder(tripId: 'trip1', outbox: out);
      walk(r, step: 0, meters: 600);
      r.close();
      expect(out.sent, hasLength(1));
    });

    test('records nothing once "Share my trips" is off', () {
      TripSharing.enabled.value = false;
      final out = _FakeOutbox();
      final r = WalkTraceRecorder(tripId: 'trip1', outbox: out);
      walk(r, step: 0, meters: 600);
      r.close();
      expect(r.debugPointCount, 0);
      expect(out.sent, isEmpty);
    });

    test('sends the walk without its first and last 50 m, with the trip and step ids', () {
      final out = _FakeOutbox();
      final r = WalkTraceRecorder(tripId: 'trip1', outbox: out, consent: () => true);
      walk(r, step: 2, meters: 600);
      r.close();
      expect(out.sent, hasLength(1));
      final p = out.sent.single;
      expect(p['trip_id'], 'trip1');
      expect(p['step_index'], 2);
      expect(p['planned_distance_m'], 900);
      expect(p['client_trace_id'], 'trip1-2');
      final pts = (p['points'] as List).cast<List>();
      // Walked 0..600 m north of 30.0: the kept points lie in 50..550 m.
      final first = ((pts.first[0] as double) - 30) / _mLat;
      final last = ((pts.last[0] as double) - 30) / _mLat;
      expect(first, inInclusiveRange(49.5, 62));
      expect(last, inInclusiveRange(538, 550.5));
      // A straight line is thinned to its ends.
      expect(pts.length, lessThan(5));
    });

    test('a short walk sends nothing at all', () {
      final out = _FakeOutbox();
      final r = WalkTraceRecorder(tripId: 'trip1', outbox: out, consent: () => true);
      walk(r, step: 0, meters: 110);
      r.close();
      expect(out.sent, isEmpty);
    });

    test('a walk step is sent when the step ends, a ride step is never recorded', () {
      final out = _FakeOutbox();
      final r = WalkTraceRecorder(tripId: 'trip1', outbox: out, consent: () => true);
      walk(r, step: 0, meters: 500);
      expect(out.sent, isEmpty); // still walking
      // Step 1 is a ride: walk == null.
      for (var k = 0; k < 20; k++) {
        r.onFix(lat: 30.01 + k * 0.001, lon: 31, accuracy: 5, time: t0.add(Duration(minutes: 10, seconds: k * 10)), step: 1, walk: null);
      }
      expect(out.sent, hasLength(1));
      expect(r.debugPointCount, 0);
      r.close();
      expect(out.sent, hasLength(1));
    });

    test('nothing is recorded after the trip ended', () {
      final out = _FakeOutbox();
      final r = WalkTraceRecorder(tripId: 'trip1', outbox: out, consent: () => true);
      walk(r, step: 0, meters: 500);
      r.close();
      walk(r, step: 3, meters: 500);
      r.close();
      expect(out.sent, hasLength(1));
      expect(r.debugPointCount, 0);
    });

    test('pausing (floating window, background) sends the walk so far and stops that step', () {
      final out = _FakeOutbox();
      final r = WalkTraceRecorder(tripId: 'trip1', outbox: out, consent: () => true);
      walk(r, step: 0, meters: 300);
      r.pause();
      expect(out.sent, hasLength(1));
      r.resume();
      walk(r, step: 0, meters: 300, from: 300);
      r.close();
      expect(out.sent, hasLength(1)); // the rest of this step is not recorded
      walk(r, step: 4, meters: 300); // closed: even a new step records nothing
      expect(out.sent, hasLength(1));
    });

    test('turning it off mid-walk stops recording', () {
      final out = _FakeOutbox();
      var on = true;
      final r = WalkTraceRecorder(tripId: 'trip1', outbox: out, consent: () => on);
      walk(r, step: 0, meters: 200);
      on = false;
      walk(r, step: 0, meters: 200, from: 200);
      r.close();
      // What was kept before it was turned off was 0..200 m: trimmed to 50..150.
      final pts = (out.sent.single['points'] as List).cast<List>();
      expect(((pts.last[0] as double) - 30) / _mLat, lessThan(155));
    });

    test('poor fixes and standing still are dropped', () {
      final out = _FakeOutbox();
      final r = WalkTraceRecorder(tripId: 'trip1', outbox: out, consent: () => true);
      walk(r, step: 0, meters: 300, accuracy: 90);
      expect(r.debugPointCount, 0);
      for (var k = 0; k < 10; k++) {
        r.onFix(
            lat: 30, lon: 31, accuracy: 5, time: t0.add(Duration(seconds: k * 20)), step: 0,
            walk: WalkStepInfo(tripId: 'trip1', stepIndex: 0, start: const LatLng(30, 31), end: const LatLng(30.01, 31)));
      }
      expect(r.debugPointCount, 1);
    });

    test('a long winding walk is capped at 300 points', () {
      final out = _FakeOutbox();
      final r = WalkTraceRecorder(tripId: 'trip1', outbox: out, consent: () => true);
      final info = WalkStepInfo(tripId: 'trip1', stepIndex: 0, start: const LatLng(30, 31), end: const LatLng(30.1, 31));
      for (var k = 0; k < 3000; k++) {
        r.onFix(
            lat: 30 + k * 12 * _mLat, lon: 31 + (k.isEven ? 0.0004 : -0.0004), accuracy: 5,
            time: t0.add(Duration(seconds: k * 9)), step: 0, walk: info);
      }
      r.close();
      expect((out.sent.single['points'] as List).length, lessThanOrEqualTo(WalkTraceRecorder.maxPoints));
    });

    test('trimEnds / simplify', () {
      final line = [for (var k = 0; k <= 20; k++) [30 + k * 10 * _mLat, 31.0, 0.0]];
      final t = WalkTraceRecorder.trimEnds(line, 50);
      expect(t.first[0], closeTo(30 + 50 * _mLat, 1e-7));
      expect(t.last[0], closeTo(30 + 150 * _mLat, 1e-7));
      expect(WalkTraceRecorder.trimEnds(line.take(8).toList(), 50), isEmpty);
      expect(WalkTraceRecorder.simplify(t, 3), hasLength(2));
    });
  });

  group('WalkOutbox', () {
    Map<String, dynamic> payload(String id) => {'client_report_id': id, 'reason': 'too_long'};

    test('sends to the endpoint', () async {
      late http.Request req;
      final out = WalkOutbox('walk_reports', 'q1');
      await out.submit(payload('a'), client: MockClient((r) async {
        req = r;
        return http.Response('{}', 200);
      }));
      expect(req.url.path, endsWith('/walk_reports'));
      expect(jsonDecode(req.body)['client_report_id'], 'a');
      expect((await SharedPreferences.getInstance()).getStringList('q1') ?? [], isEmpty);
    });

    test('with no signal it is kept, then sent later', () async {
      final out = WalkOutbox('walk_reports', 'q2');
      await out.submit(payload('a'), client: MockClient((r) async => throw http.ClientException('offline')));
      await out.submit(payload('b'), client: MockClient((r) async => http.Response('', 503)));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('q2'), hasLength(2));
      await pumpEventQueue(); // the background flush each submit starts has finished
      final ids = <String>[];
      await out.flush(client: MockClient((r) async {
        ids.add(jsonDecode(r.body)['client_report_id'] as String);
        expect(jsonDecode(r.body).containsKey('_uid'), isFalse);
        return http.Response('{}', 200);
      }));
      expect(ids, ['a', 'b']);
      expect(prefs.getStringList('q2'), isEmpty);
    });

    test('a rejected report is dropped, not retried forever', () async {
      final out = WalkOutbox('walk_reports', 'q3');
      await out.submit(payload('a'), client: MockClient((r) async => http.Response('{}', 422)));
      expect((await SharedPreferences.getInstance()).getStringList('q3') ?? [], isEmpty);
    });

    test('rate limiting keeps it for later', () async {
      final out = WalkOutbox('walk_reports', 'q4');
      await out.submit(payload('a'), client: MockClient((r) async => http.Response('{}', 429)));
      expect((await SharedPreferences.getInstance()).getStringList('q4'), hasLength(1));
    });

    test('the queue is capped', () async {
      final out = WalkOutbox('walk_reports', 'q5', maxQueued: 3);
      for (var i = 0; i < 6; i++) {
        await out.submit(payload('$i'), client: MockClient((r) async => throw http.ClientException('offline')));
      }
      final q = (await SharedPreferences.getInstance()).getStringList('q5')!;
      expect(q.map((e) => jsonDecode(e)['client_report_id']), ['3', '4', '5']);
    });
  });

  test('the report payload has the step ends, reason and a short note', () {
    final info = WalkStepInfo(
        tripId: 'trip1', stepIndex: 3, start: const LatLng(30.0123456789, 31.2), end: const LatLng(30.02, 31.21), plannedDistanceM: 1234.6);
    final p = WalkFeedbackService.reportPayload(info, WalkReportReason.noPath, '  ${'x' * 400}  ', id: 'id1');
    expect(p['reason'], 'no_path');
    expect(p['step_index'], 3);
    expect(p['trip_id'], 'trip1');
    expect(p['start'], [30.012346, 31.2]);
    expect(p['end'], [30.02, 31.21]);
    expect(p['distance_m'], 1235);
    expect((p['note'] as String).length, 280);
    expect(p['client_report_id'], 'id1');
  });

  group('WalkStepEnds', () {
    final steps = <Map<String, dynamic>>[
      {'action': 'walk_to_station', 'distance_m': 300},
      {'action': 'board', 'vehicle_type': 'bus'},
      {'action': 'arrive'},
      {'action': 'walk_to_destination', 'distance_m': 450},
    ];
    const a = LatLng(30.0, 31.0), b = LatLng(30.002, 31.0), c = LatLng(30.05, 31.05), d = LatLng(30.052, 31.05), e = LatLng(30.056, 31.05);

    test('uses the drawn walk segments when they match the walking steps', () {
      final w1 = WalkStepEnds.of(
          tripId: 't', instructions: steps, stepPoints: [null, null, null, null], walkSegments: [[a, const LatLng(30.001, 31.0), b], [d, e]], index: 3);
      expect(w1!.start, d);
      expect(w1.end, e);
      expect(w1.plannedDistanceM, 450);
      expect(WalkStepEnds.of(tripId: 't', instructions: steps, stepPoints: [], walkSegments: [[a, b], [d, e]], index: 1), isNull);
    });

    test('falls back on the steps\' own points', () {
      final w = WalkStepEnds.of(
          tripId: 't', instructions: steps, stepPoints: [a, b, c, d], walkSegments: const [], index: 0, tripStart: a, destination: e);
      expect(w!.start, a);
      expect(w.end, b);
      final last = WalkStepEnds.of(
          tripId: 't', instructions: steps, stepPoints: [a, b, c, d], walkSegments: const [], index: 3, tripStart: a, destination: e);
      expect(last!.end, e);
    });
  });

  group('the report sheet', () {
    Future<void> open(WidgetTester tester, {bool simple = false, Locale locale = const Locale('en'), void Function(({WalkReportReason reason, String note})?)? onResult}) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () async {
              final r = await showWalkReportSheet(ctx, simple: simple);
              onResult?.call(r);
            },
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('needs a reason, then returns it with the note', (tester) async {
      ({WalkReportReason reason, String note})? result;
      await open(tester, onResult: (r) => result = r);
      expect(tester.widget<ElevatedButton>(find.byKey(const ValueKey('walk_report_send'))).onPressed, isNull);
      expect(find.text('It goes through buildings'), findsOneWidget);
      expect(find.text('It is too long'), findsOneWidget);
      expect(find.text('The path does not exist'), findsOneWidget);
      expect(find.text('Something else'), findsOneWidget);
      await tester.tap(find.text('The path does not exist'));
      await tester.enterText(find.byKey(const ValueKey('walk_report_note')), 'locked gate');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('walk_report_send')));
      await tester.pumpAndSettle();
      expect(result, (reason: WalkReportReason.noPath, note: 'locked gate'));
    });

    testWidgets('dismissing sends nothing', (tester) async {
      var called = false;
      ({WalkReportReason reason, String note})? result;
      await open(tester, onResult: (r) {
        called = true;
        result = r;
      });
      await tester.tapAt(const Offset(10, 10)); // the scrim
      await tester.pumpAndSettle();
      expect(called, isTrue);
      expect(result, isNull);
    });

    testWidgets('in simple mode every choice and the button are at least 56 dp tall', (tester) async {
      await open(tester, simple: true);
      for (final r in WalkReportReason.values) {
        expect(tester.getSize(find.byKey(ValueKey('walk_reason_${r.wire}'))).height, greaterThanOrEqualTo(56));
      }
      expect(tester.getSize(find.byKey(const ValueKey('walk_report_send'))).height, greaterThanOrEqualTo(56));
    });

    testWidgets('in Arabic it reads right to left, with Arabic words', (tester) async {
      await open(tester, locale: const Locale('ar'));
      expect(Directionality.of(tester.element(find.byKey(const ValueKey('walk_report_title')))), TextDirection.rtl);
      expect(find.text('بيعدّي من جوه مباني'), findsOneWidget);
      expect(find.text('الطريق ده مش موجود'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('where the buttons are', () {
    Widget app(Widget child, {Locale locale = const Locale('en'), bool dark = false}) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: locale,
          theme: dark ? ThemeData.dark() : ThemeData.light(),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        );

    final walkStep = [
      {'action': 'walk_to_station', 'station': 'Ramses', 'distance_m': 300, 'vehicle_type': 'walk'},
      {'action': 'board', 'vehicle_type': 'bus', 'route_number': '5', 'station': 'Ramses'},
    ];

    testWidgets('simple mode: on a walking step, at least 56 dp; on a ride, none', (tester) async {
      var taps = 0;
      await tester.pumpWidget(app(SimpleStepPanel(
        instructions: walkStep,
        index: 0,
        onNext: () {},
        onEnd: () {},
        onReportWalk: () => taps++,
      )));
      final btn = find.byKey(const ValueKey('simple_report_walk'));
      expect(find.text('This walk is wrong'), findsOneWidget);
      expect(tester.getSize(btn).height, greaterThanOrEqualTo(SimpleModeController.minTarget));
      await tester.tap(btn);
      expect(taps, 1);

      await tester.pumpWidget(app(SimpleStepPanel(instructions: walkStep, index: 1, onNext: () {}, onEnd: () {})));
      expect(find.byKey(const ValueKey('simple_report_walk')), findsNothing);
    });

    testWidgets('simple mode: once reported it says so and cannot be sent twice', (tester) async {
      await tester.pumpWidget(app(
          SimpleStepPanel(instructions: walkStep, index: 0, onNext: () {}, onEnd: () {}, onReportWalk: () {}, walkReported: true),
          locale: const Locale('ar')));
      expect(find.text('اتبلّغ عن المشي ده'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the Now card offers it only on a walk, in light and dark', (tester) async {
      Widget card({VoidCallback? onReport, bool reported = false}) => TripNowCard(
            instructions: walkStep,
            step: 0,
            distanceToNextStop: ValueNotifier('300 m'),
            locationProblem: ValueNotifier<String?>(null),
            rideReport: null,
            offersRideReport: false,
            onStartRideReport: () {},
            onStopRideReport: () {},
            onReportWalk: onReport,
            walkReported: reported,
          );
      for (final dark in [false, true]) {
        var taps = 0;
        await tester.pumpWidget(app(card(onReport: () => taps++), dark: dark));
        await tester.tap(find.byKey(const ValueKey('walk_report_button')));
        expect(taps, 1);
        await tester.pumpWidget(app(card(onReport: () => taps++, reported: true), dark: dark));
        expect(find.text('Walk reported'), findsOneWidget);
        await tester.pumpWidget(app(card(), dark: dark));
        expect(find.byKey(const ValueKey('walk_report_button')), findsNothing);
      }
    });

    testWidgets('a walking step further on can be reported from the list', (tester) async {
      var taps = 0;
      await tester.pumpWidget(app(TripStepTile(
        instructions: walkStep,
        index: 0,
        isNow: false,
        isOpen: false,
        tappable: false,
        onToggle: () {},
        onReportWalk: () => taps++,
      )));
      await tester.tap(find.byKey(const ValueKey('walk_report_step_0')));
      expect(taps, 1);
    });
  });

  group('Settings', () {
    setUp(() => PackageInfo.setMockInitialValues(
        appName: 'Guidy', packageName: 'app.guidy', version: '1.0.12', buildNumber: '1', buildSignature: ''));

    Future<void> openSettings(WidgetTester tester, {Locale locale = const Locale('en')}) async {
      tester.view.physicalSize = const Size(400 * 2.0, 2400 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: const SettingsScreen(),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('one switch, on by default; the info button says what it shares', (tester) async {
      await openSettings(tester);
      final sw = find.byKey(const ValueKey('trip-sharing-switch'));
      expect(tester.widget<Switch>(sw).value, isTrue);
      expect(find.byKey(const ValueKey('walk-traces-switch')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('trip-sharing-info')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('trip-sharing-info-dialog')), findsOneWidget);
      expect(find.textContaining('first and last 50 metres'), findsOneWidget);
      expect(find.textContaining('The route you rode'), findsOneWidget);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(TripSharing.enabled.value, isTrue);
    });

    testWidgets('turning it off drops walk paths and trips not yet sent', (tester) async {
      SharedPreferences.setMockInitialValues({
        'trip_sharing': true,
        'pending_walk_traces': ['{"x":1}'],
        'pending_trip_logs': ['{"client_trip_id":"1"}'],
      });
      await TripSharing.load();
      expect(TripSharing.enabled.value, isTrue);
      await openSettings(tester);
      await tester.tap(find.byKey(const ValueKey('trip-sharing-switch')));
      await tester.pumpAndSettle();
      expect(TripSharing.enabled.value, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('trip_sharing'), isFalse);
      expect(prefs.getStringList('pending_walk_traces'), isNull);
      expect(prefs.getStringList('pending_trip_logs'), isNull);

      // Back on: no question, it just records again.
      await tester.tap(find.byKey(const ValueKey('trip-sharing-switch')));
      await tester.pumpAndSettle();
      expect(TripSharing.enabled.value, isTrue);
    });

    testWidgets('Arabic', (tester) async {
      await openSettings(tester, locale: const Locale('ar'));
      expect(find.text('شارك مشاويري'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('trip-sharing-info')));
      await tester.pumpAndSettle();
      expect(find.text('«شارك مشاويري» بيعمل إيه'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
