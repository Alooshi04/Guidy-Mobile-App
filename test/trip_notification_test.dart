import 'dart:ui' show Locale;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart' show AndroidSettings;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guidy_app/utils/nav_math.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/trip/trip_progress.dart';
import 'package:guidy_app/services/commute/commute_notifications.dart';
import 'package:guidy_app/services/current_trip.dart';
import 'package:guidy_app/services/trip_notification.dart';
import 'package:guidy_app/services/trip_pip.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _trip() => {
      'end_name': 'Tahrir',
      'instructions': [
        {'action': 'walk_to_station', 'station': 'Ramses', 'lat': 30.05, 'lon': 31.24, 'distance_m': 300},
        {'action': 'board', 'station': 'Ramses', 'route_id': 'R1', 'route_number': '44', 'vehicle_type': 'microbus', 'alight_station': 'Sidi Gaber', 'lat': 30.05, 'lon': 31.24},
        {'action': 'arrive', 'station': 'Tahrir', 'lat': 30.06, 'lon': 31.25},
      ],
      'option': {'type': 'Recommended', 'time': '30', 'fare_egp': 10},
      'segments': [],
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  late List<MethodCall> calls;

  List<MethodCall> shown() => [for (final c in calls) if (c.method == 'show') c];
  List<MethodCall> cancelled() => [for (final c in calls) if (c.method == 'cancel') c];

  setUp(() {
    calls = [];
    SharedPreferences.setMockInitialValues({});
    CommuteNotifications.debugSupported = true;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    FlutterLocalNotificationsPlatform.instance = AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return call.method == 'initialize' ? true : null;
    });
    CurrentTrip.debugReset();
    TripNotification.debugReset();
    TripNotification.debugAllowed = () async => true;
    TripPip.active.value = false;
    TripNotification.start();
  });

  tearDown(() {
    CommuteNotifications.debugSupported = null;
    debugDefaultTargetPlatformOverride = null;
    TripNotification.debugReset();
    CurrentTrip.debugReset();
    TripPip.active.value = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 50));

  test('words: the step now, then the trip', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final t = CurrentTripData(
      pathData: _trip(),
      alternatives: const [],
      endName: 'Tahrir',
      step: 0,
      startedAt: DateTime(2026, 10, 31),
      lastActiveAt: DateTime(2026, 10, 31),
    );
    final c = TripNotification.copyFor(l10n, t);
    expect(c.title, 'Walk to Ramses');
    // The step, then where the trip goes on its own line: no run-on
    // "300 m · ~4 min · Your trip to Tahrir" (beta feedback, 2026-11).
    expect(c.body, '300 m, about 4 min\nGoing to Tahrir');
    final ar = TripNotification.copyFor(lookupAppLocalizations(const Locale('ar')), t);
    expect(ar.title, contains('Ramses'));
    expect(ar.body, '300 متر، حوالي 4 دقائق\nرايح Tahrir');
    for (final body in [c.body, ar.body]) {
      expect(body, isNot(contains('\u00b7')));
      expect(body, isNot(contains('~')));
    }
  });

  test('shown while the trip runs and the live screen is not in front', () async {
    await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir');
    await settle();
    expect(shown(), hasLength(1));
    expect(shown().single.arguments['id'], TripNotification.ongoingId);
  });

  test('not shown while the live screen is in front, and removed when it comes to the front', () async {
    TripNotification.liveScreenVisible.value = true;
    await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir');
    await settle();
    expect(shown(), isEmpty);

    TripNotification.liveScreenVisible.value = false;
    await settle();
    expect(shown(), hasLength(1));

    TripNotification.liveScreenVisible.value = true;
    await settle();
    expect(cancelled(), isNotEmpty);
  });

  test('updated when the step changes, not for the same step', () async {
    await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir');
    await settle();
    await CurrentTrip.touch();
    await settle();
    expect(shown(), hasLength(1));
    await CurrentTrip.setStep(1);
    await settle();
    expect(shown(), hasLength(2));
    expect(shown().last.arguments['title'], contains('44'));
  });

  test('cleared on arrival, End trip and timeout (all CurrentTrip.clear)', () async {
    await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir');
    await settle();
    await CurrentTrip.clear();
    await settle();
    expect(cancelled().where((c) => c.arguments == TripNotification.ongoingId || c.arguments?['id'] == TripNotification.ongoingId), isNotEmpty);

    calls.clear();
    var clock = DateTime(2026, 10, 31, 9);
    CurrentTrip.now = () => clock;
    await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir');
    await settle();
    clock = clock.add(const Duration(hours: 3));
    await TripNotification.sync();
    await settle();
    expect(CurrentTrip.active.value, isNull);
    expect(cancelled(), isNotEmpty);
  });

  test('not shown when notifications are blocked or the Settings switch is off', () async {
    TripNotification.debugAllowed = () async => false;
    await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir');
    await settle();
    expect(shown(), isEmpty);
  });

  test('not shown in the floating window', () async {
    TripPip.active.value = true;
    await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir');
    await settle();
    expect(shown(), isEmpty);
  });

  group('near-stop alert', () {
    final stops = <LatLng?>[const LatLng(30.0, 31.0), const LatLng(30.0, 31.0 + 0.0), const LatLng(30.0, 31.0)];
    StepCheck check(StepTracker t, double metersFromTarget) {
      // Target at lon 31.0; walk in along the same latitude.
      final dLon = metersFromTarget / 96300; // ~metres per degree at 30 N
      return t.check(LatLng(30.0, 31.0 - dLon),
          step: 0, stepPoints: stops, progress: null, alarmAllowed: true);
    }

    test('fires once within 400 m, again only after the step changes', () {
      final t = StepTracker();
      expect(check(t, 900).near, isFalse);
      expect(check(t, 390).near, isTrue);
      expect(check(t, 300).near, isFalse);
      expect(check(t, 200).near, isFalse);
      t.onAdvanced();
      expect(check(t, 300).near, isTrue);
    });

    test('not when the rider has the alarm switched off', () {
      final t = StepTracker();
      final c = t.check(const LatLng(30.0, 30.9965), step: 0, stepPoints: stops, progress: null, alarmAllowed: false);
      expect(c.near, isFalse);
    });

    // Beta report: "I shouldn't get 'almost there' while walking, only
    // during a ride."
    test('never on foot, however close the stop', () {
      for (final end in [StepEnd.walk, StepEnd.street, StepEnd.station]) {
        final t = StepTracker();
        for (final m in [390.0, 140.0, 60.0]) {
          final dLon = m / 96300;
          final c = t.check(LatLng(30.0, 31.0 - dLon),
              step: 0, stepPoints: stops, progress: null, alarmAllowed: true, end: end);
          expect([c.near, c.alarm], [false, false], reason: '$end at $m m');
        }
      }
    });

    // On the ride step of _trip(): the only time the heads-up may go out.
    Future<void> onRide() async {
      await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir', step: 1);
      await settle();
      calls.clear();
    }

    List<MethodCall> alerts() => [for (final c in shown()) if (c.arguments['id'] == TripNotification.alertId) c];

    test('sends one heads-up, on the alert channel', () async {
      await onRide();
      await TripNotification.nearStop('Sidi Gaber');
      expect(alerts(), hasLength(1));
      expect(alerts().single.arguments['body'], contains('Sidi Gaber'));
    });

    test('never during a walk, whoever asks (the screen in the background, the service)', () async {
      await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir', step: 0);
      await settle();
      expect(TripNotification.ridingNow, isFalse);
      await TripNotification.nearStop('Ramses');
      expect(alerts(), isEmpty);

      await CurrentTrip.setStep(1);
      expect(TripNotification.ridingNow, isTrue);
      await CurrentTrip.setStep(2); // got off: walking again
      expect(TripNotification.ridingNow, isFalse);
      await TripNotification.nearStop('Tahrir');
      expect(alerts(), isEmpty);
    });

    test('never without a trip in progress', () async {
      await TripNotification.nearStop('Sidi Gaber');
      expect(alerts(), isEmpty);
    });

    test('suppressed in the floating window', () async {
      await onRide();
      TripPip.active.value = true;
      await TripNotification.nearStop('Sidi Gaber');
      expect(alerts(), isEmpty);
    });

    test('suppressed when blocked or switched off', () async {
      await onRide();
      TripNotification.debugAllowed = () async => false;
      await TripNotification.nearStop('Sidi Gaber');
      expect(alerts(), isEmpty);
    });
  });

  group('foreground location service', () {
    test('its notification is the step notification, shown even with the live screen in front', () async {
      TripNotification.liveScreenVisible.value = true;
      await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir');
      await settle();
      expect(shown(), isEmpty);

      TripNotification.foregroundService.value = true;
      await settle();
      expect(shown(), hasLength(1));
      final c = shown().single;
      expect(c.arguments['id'], TripNotification.serviceId);
      expect(c.arguments['platformSpecifics']['channelId'], TripNotification.serviceChannelId);
    });

    test('step changes replace the service notification; no second ongoing one', () async {
      TripNotification.foregroundService.value = true;
      await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir');
      await settle();
      await CurrentTrip.setStep(1);
      await settle();
      expect(shown().map((c) => c.arguments['id']).toSet(), {TripNotification.serviceId});
      expect(shown().last.arguments['title'], contains('44'));
    });

    test('moving to the separate notification when the service stops', () async {
      await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir');
      TripNotification.foregroundService.value = true;
      await settle();
      TripNotification.foregroundService.value = false;
      await settle();
      expect(shown().last.arguments['id'], TripNotification.ongoingId);
    });

    test('the service notification starts with the step now', () async {
      await CurrentTrip.begin(pathData: _trip(), endName: 'Tahrir', step: 1);
      final c = TripNotification.foregroundConfig()!;
      expect(c.notificationTitle, contains('44'));
      expect(c.setOngoing, isTrue);
      expect(c.enableWakeLock, isTrue);
    });

    test('the nav stream asks for the service only when given a config', () {
      final c = TripNotification.foregroundConfig()!;
      final on = NavMath.navLocationSettings(TargetPlatform.android, foreground: c) as AndroidSettings;
      expect(on.foregroundNotificationConfig, same(c));
      final off = NavMath.navLocationSettings(TargetPlatform.android) as AndroidSettings;
      expect(off.foregroundNotificationConfig, isNull);
    });
  });
}
