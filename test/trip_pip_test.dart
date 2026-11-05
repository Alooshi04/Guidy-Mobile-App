import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/trip_pip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('guidy/pip');

  late List<MethodCall> calls;
  setUp(() {
    calls = [];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TripPip.active.value = false;
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  Future<void> fromAndroid(String method, Object? args) async {
    final data = const StandardMethodCodec().encodeMethodCall(MethodCall(method, args));
    await messenger.handlePlatformMessage('guidy/pip', data, (_) {});
  }

  test('a trip offers the floating window; leaving the trip withdraws it', () async {
    await TripPip.setAvailable(true);
    await TripPip.setAvailable(false);
    expect(calls.map((c) => '${c.method}:${c.arguments}'), ['setAvailable:true', 'setAvailable:false']);
  });

  test('Android saying the window opened or closed is what the trip screen reads', () async {
    await TripPip.setAvailable(true);
    await fromAndroid('pipChanged', true);
    expect(TripPip.active.value, isTrue);
    await fromAndroid('pipChanged', false);
    expect(TripPip.active.value, isFalse);
    await TripPip.setAvailable(false);
  });

  test('withdrawing it also clears a stale "in the window" state', () async {
    await TripPip.setAvailable(true);
    await fromAndroid('pipChanged', true);
    await TripPip.setAvailable(false);
    expect(TripPip.active.value, isFalse);
  });

  test('other platforms never touch the channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await TripPip.setAvailable(true);
    expect(calls, isEmpty);
    await TripPip.setAvailable(false);
  });

  test('a trip screen replaced by another (switching routes) leaves the window on', () async {
    await TripPip.setAvailable(true); // the old trip screen
    await TripPip.setAvailable(true); // the new one, before the old one is disposed
    await TripPip.setAvailable(false); // the old one's dispose
    expect(calls.last.arguments, isTrue);
    await TripPip.setAvailable(false); // the new one closes
    expect(calls.last.arguments, isFalse);
  });
}
