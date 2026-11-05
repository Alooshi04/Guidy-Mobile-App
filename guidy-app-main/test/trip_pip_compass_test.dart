import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/MapScreen.dart';
import 'package:guidy_app/services/trip_pip.dart';
import 'package:guidy_app/widgets/app_banner_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _trip() => {
      'instructions': [
        {'action': 'walk_to_station', 'station': 'Ramses', 'lat': 30.05, 'lon': 31.24, 'distance_m': 200},
        {'action': 'board', 'station': 'Ramses', 'route_id': 'R1', 'route_number': '66', 'vehicle_type': 'minibus', 'lat': 30.05, 'lon': 31.24},
        {'action': 'arrive', 'station': 'Tahrir', 'lat': 30.06, 'lon': 31.25},
      ],
      'option': {'type': 'Recommended', 'time': '30', 'fare_egp': 10},
      'segments': [],
    };

/// Counts who is listening to the compass plugin's event channel.
class _CompassStream extends MockStreamHandler {
  int listening = 0;

  @override
  void onListen(Object? arguments, MockStreamHandlerEventSink events) => listening++;

  @override
  void onCancel(Object? arguments) => listening--;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const compass = EventChannel('hemanthraj/flutter_compass');
  late _CompassStream stream;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    stream = _CompassStream();
    messenger.setMockStreamHandler(compass, stream);
    messenger.setMockMethodCallHandler(const MethodChannel('guidy/pip'), (_) async => null);
  });
  tearDown(() {
    messenger.setMockStreamHandler(compass, null);
    messenger.setMockMethodCallHandler(const MethodChannel('guidy/pip'), null);
    TripPip.active.value = false;
  });

  // The tester's report: minimise the trip and the arrow stops turning with
  // the phone until the trip is restarted.
  testWidgets('the compass keeps running through the floating window and back', (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // A banner with an ad: the shell takes the slot and the app's top padding.
      builder: (context, page) => AppBannerShell(
        bannerBuilder: (_) => const SizedBox(height: 50),
        child: page!,
      ),
      home: MapScreen(pathData: _trip()),
    ));
    await tester.pump(const Duration(milliseconds: 500));
    expect(stream.listening, 1);

    TripPip.active.value = true;
    await tester.pump();
    expect(stream.listening, 1, reason: 'compass stopped in the floating window');

    TripPip.active.value = false;
    await tester.pump();
    expect(stream.listening, 1, reason: 'compass not back after the floating window');

    await tester.pumpWidget(const SizedBox());
    expect(stream.listening, 0, reason: 'the trip closing stops the compass');
  });
}
