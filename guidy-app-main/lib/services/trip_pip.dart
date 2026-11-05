import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android picture-in-picture for a trip in progress: leave Guidy mid-trip
/// (home button, another app) and the trip map carries on in a small
/// floating window, as Google Maps does. Drag the window to the bottom of
/// the screen to close it. MainActivity does the Android side.
///
/// iOS has no picture-in-picture for anything but video, so this is
/// Android only.
class TripPip {
  TripPip._();

  static const MethodChannel _channel = MethodChannel('guidy/pip');

  /// True while the trip is showing in the floating window.
  static final ValueNotifier<bool> active = ValueNotifier(false);

  static bool _listening = false;

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Trip screens that want the window. A count, not a flag: switching
  /// routes replaces one trip screen with another, and the old one's
  /// dispose (saying "off") runs after the new one's initState.
  static int _owners = 0;

  /// A trip screen calls this with true when it opens and false when it
  /// closes: while any is open, leaving the app opens the window.
  static Future<void> setAvailable(bool available) async {
    _owners = available ? _owners + 1 : (_owners > 0 ? _owners - 1 : 0);
    available = _owners > 0;
    if (!available) active.value = false;
    if (!_supported) return;
    if (!_listening) {
      _listening = true;
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'pipChanged') active.value = call.arguments == true;
      });
    }
    try {
      await _channel.invokeMethod<void>('setAvailable', available);
    } on PlatformException catch (e) {
      debugPrint('Picture-in-picture: $e');
    } on MissingPluginException {
      // A build without the native side (tests, other embedders).
    }
  }
}
