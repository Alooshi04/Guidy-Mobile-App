import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter/widgets.dart' show Locale;
import 'package:geolocator/geolocator.dart' show AndroidResource, ForegroundNotificationConfig;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../l10n/app_localizations.dart';
import '../screens/trip/trip_plan.dart';
import 'commute/commute_notifications.dart';
import 'commute/commute_store.dart';
import 'current_trip.dart';
import 'locale_controller.dart';
import 'step_copy.dart';
import 'trip_pip.dart';

/// The phone's notifications for a trip in progress (owner, 2026-10-31):
///
///  * an ongoing, silent one with the current step, while the rider is not
///    looking at the live trip screen (another screen, another app, phone
///    locked), and
///  * one heads-up ("Get ready") when the stop where they get off or change
///    is near, unless the floating window is showing the trip.
///
/// BACKGROUND LOCATION. Android withholds location from an app in the
/// background (checked on an API 36 emulator: the stream goes "inactive"),
/// so while a trip runs the live screen's GPS stream is a foreground
/// service of type location (geolocator's foregroundNotificationConfig;
/// FOREGROUND_SERVICE_LOCATION in the manifest; started from the live
/// screen while the app is in front, so Android 14+ allows it without
/// ACCESS_BACKGROUND_LOCATION). Its mandatory notification IS the step
/// notification: while the service runs, step updates replace its content
/// (same id and channel); there is no second ongoing notification. The
/// service ends with the trip (arrival, End trip, timeout) or when the
/// live screen closes, and from then on the step notification is the
/// separate ongoing one again, frozen at its last step, since nothing
/// updates it any more. Play Console needs the "Foreground service"
/// declaration for location (navigation use case) before release.
///
/// Respects the phone's notification permission and the Settings
/// notifications switch (CommuteStore.settings.enabled).
abstract final class TripNotification {
  static const int ongoingId = 7100;
  static const int alertId = 7101;

  /// geolocator's foreground-service notification: its id and channel are
  /// fixed in the plugin (GeolocatorLocationService), and posting to the same
  /// id replaces its content.
  static const int serviceId = 75415;
  static const String serviceChannelId = 'geolocator_channel_01';
  static const String payload = 'trip';

  /// True while the live trip screen is on screen and the app in front.
  /// MapScreen owns it.
  static final ValueNotifier<bool> liveScreenVisible = ValueNotifier(false);

  /// True while the live screen's GPS runs as a foreground service.
  static final ValueNotifier<bool> foregroundService = ValueNotifier(false);

  static bool _wired = false;
  static String? _shownKey;
  static int? _shownId;

  /// Stands in for the permission/switch check in tests.
  @visibleForTesting
  static Future<bool> Function()? debugAllowed;

  /// Listens for what changes the notification. Safe to call again.
  static void start() {
    if (_wired) return;
    _wired = true;
    CurrentTrip.active.addListener(sync);
    liveScreenVisible.addListener(sync);
    TripPip.active.addListener(sync);
    foregroundService.addListener(sync);
  }

  /// A new launch with a saved trip: shows (or drops) its notification.
  static Future<void> restore() async {
    start();
    await CurrentTrip.ensureLoaded();
    await sync();
  }

  static Future<bool> _allowed() async {
    if (debugAllowed != null) return debugAllowed!();
    if (!CommuteNotifications.supported) return false;
    await CommuteStore.loadSettings();
    if (!CommuteStore.settings.value.enabled) return false;
    return await CommuteNotifications.notificationsAllowed() ?? false;
  }

  static AppLocalizations _l10n() => lookupAppLocalizations(Locale(localeController.isArabic ? 'ar' : 'en'));

  /// The words of the ongoing notification: the step now, then where the
  /// trip goes on a line of its own ("678 m, about 10 min" / "Going to X"),
  /// with no middle-dot run-on between them (beta feedback, 2026-11).
  static ({String title, String body}) copyFor(AppLocalizations l10n, CurrentTripData t) {
    final plan = TripPlan.fromPathData(t.pathData, defaultColor: const Color(0xFF0A84FF));
    final steps = plan.instructions;
    final step = steps.isEmpty ? -1 : t.step.clamp(0, steps.length - 1);
    final copy = step < 0 ? null : StepCopy.of(l10n, steps, step);
    final dest = (t.endName ?? t.pathData['end_name'])?.toString() ?? '';
    final trip = dest.isEmpty ? l10n.currentTripLabel : l10n.tripGoingTo(dest);
    final detail = copy == null || copy.lines.isEmpty ? '' : copy.lines.first;
    return (
      title: copy?.title ?? l10n.currentTripLabel,
      body: detail.isEmpty ? trip : '$detail\n$trip',
    );
  }

  /// The service notification as the GPS stream starts: the step now.
  static ForegroundNotificationConfig? foregroundConfig() {
    final l10n = _l10n();
    final t = CurrentTrip.active.value;
    final c = t == null ? null : copyFor(l10n, t);
    return ForegroundNotificationConfig(
      notificationTitle: c?.title ?? l10n.currentTripLabel,
      notificationText: c?.body ?? '',
      notificationChannelName: l10n.tripChannelName,
      notificationIcon: const AndroidResource(name: 'ic_launcher_monochrome', defType: 'drawable'),
      enableWakeLock: true,
      setOngoing: true,
    );
  }

  /// Brings the notification in line with the trip and the screen: shown
  /// while a trip runs and the live screen isn't in front, gone otherwise.
  static Future<void> sync() async {
    final t = CurrentTrip.active.value;
    if (t != null && CurrentTrip.isStale(t)) {
      await CurrentTrip.clear(); // sets the notifier, which comes back here
      return;
    }
    // While the location service runs its notification is the step
    // notification, shown whatever the screen. Otherwise a separate one,
    // while the live screen isn't in front.
    final service = foregroundService.value;
    final show = t != null && (service || (!liveScreenVisible.value && !TripPip.active.value));
    if (!show) {
      if (_shownKey != null || t == null) await cancel();
      return;
    }
    final id = service ? serviceId : ongoingId;
    if (_shownId != null && _shownId != id && _shownId != serviceId) await cancel();
    final l10n = _l10n();
    final key = '$id-${t.startedAt.millisecondsSinceEpoch}-${t.step}-${l10n.localeName}';
    if (key == _shownKey) return;
    try {
      if (!service && !await _allowed()) return;
      await CommuteNotifications.init();
      final copy = copyFor(l10n, t);
      _shownKey = key;
      _shownId = id;
      await CommuteNotifications.plugin.show(
        id: id,
        title: copy.title,
        body: copy.body,
        payload: payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            service ? serviceChannelId : 'trip',
            l10n.tripChannelName,
            channelDescription: l10n.tripChannelDescription,
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showWhen: false,
            // The body is two lines (the step, then where to); expanded,
            // the notification shows both.
            styleInformation: BigTextStyleInformation(copy.body),
            playSound: false,
            enableVibration: false,
            icon: 'ic_launcher_monochrome',
          ),
        ),
      );
    } catch (e) {
      _shownKey = null;
      debugPrint('[TripNotification] show failed: $e');
    }
  }

  /// Arrived, ended, timed out, or the live screen is back in front.
  static Future<void> cancel() async {
    final was = _shownId;
    _shownKey = null;
    _shownId = null;
    try {
      if (!CommuteNotifications.supported) return;
      await CommuteNotifications.init();
      await CommuteNotifications.plugin.cancel(id: ongoingId);
      // The service's own notification goes when the service stops; it is
      // never cancelled from here while the service runs.
      if (was == serviceId && !foregroundService.value) await CommuteNotifications.plugin.cancel(id: serviceId);
    } catch (_) {}
  }

  /// Whether the trip in progress is on a ride (board or transfer), the
  /// only time "get ready to get off" means anything. Read from the trip
  /// itself, so no caller (the live screen in the background, the
  /// foreground service's fixes) can send it during a walk.
  static bool get ridingNow {
    final t = CurrentTrip.active.value;
    final steps = t?.pathData['instructions'];
    if (t == null || steps is! List || t.step < 0 || t.step >= steps.length) return false;
    return TripPlan.isRide(steps[t.step]);
  }

  /// "Get ready": [place] is the stop to get off or change at. The caller
  /// (MapScreen) fires this once per stop, and not while the rider is
  /// looking at the trip screen, which has its own banner. Only during a
  /// ride (see [ridingNow]).
  static Future<void> nearStop(String place) async {
    if (TripPip.active.value || !ridingNow) return;
    try {
      if (!await _allowed()) return;
      await CommuteNotifications.init();
      final l10n = _l10n();
      await CommuteNotifications.plugin.show(
        id: alertId,
        title: l10n.tripNearTitle,
        body: l10n.tripNearBody(place),
        payload: payload,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'trip_alert',
            l10n.tripAlertChannelName,
            channelDescription: l10n.tripAlertChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            category: AndroidNotificationCategory.alarm,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[TripNotification] alert failed: $e');
    }
  }

  @visibleForTesting
  static void debugReset() {
    _shownKey = null;
    _shownId = null;
    debugAllowed = null;
    liveScreenVisible.value = false;
    foregroundService.value = false;
  }
}
