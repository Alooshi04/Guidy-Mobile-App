import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../../l10n/app_localizations.dart';
import '../../utils/minutes_text.dart';
import '../api_service.dart';
import '../instruction_formatter.dart';
import '../locale_controller.dart';
import 'commute_planner.dart';
import 'commute_store.dart';

/// The words of one notification.
abstract final class CommuteCopy {
  /// 1380 -> "11:00 PM" / "11:00 م". Minutes may pass midnight.
  static String clock(int minuteOfDay, {required bool arabic}) {
    final m = minuteOfDay % (24 * 60);
    final h = m ~/ 60, min = m % 60;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final am = h < 12;
    return '$h12:${min.toString().padLeft(2, '0')} ${arabic ? (am ? 'ص' : 'م') : (am ? 'AM' : 'PM')}';
  }

  static ({String title, String body}) of(AppLocalizations l10n, CommuteNotice n) {
    final arabic = l10n.localeName.startsWith('ar');
    String at(int m) => clock(m, arabic: arabic);
    switch (n.kind) {
      case CommuteNoticeKind.lastService:
        return (title: l10n.commuteLastServiceTitle(n.line ?? '', at(n.untilMin)), body: l10n.commuteLastServiceBody);
      case CommuteNoticeKind.easierNow:
        return (
          title: n.morning ? l10n.commuteEasierTitleMorning : l10n.commuteEasierTitleEvening,
          body: l10n.commuteEasierBody(n.line ?? '', l10n.minutes(n.every), at(n.untilMin), l10n.minutes(n.slowEvery)),
        );
      case CommuteNoticeKind.beatRush:
        return n.morning
            ? (title: l10n.commuteRushTitleMorning, body: l10n.commuteRushBodyMorning(at(n.untilMin)))
            : (title: l10n.commuteRushTitleEvening, body: l10n.commuteRushBodyEvening(at(n.untilMin)));
    }
  }
}

/// Saved Home and Work, as LocationPickerScreen stores them: "name|lat|lon"
/// under "Home" / "Work".
typedef HomeWork = ({double homeLat, double homeLon, double workLat, double workLon});

/// Commute notifications (owner, 2026-10-14): the lines of the rider's
/// saved Home <-> Work route, found when they plan that trip (or, failing
/// that, by one search every two weeks), and a week of notifications
/// scheduled on the phone from those lines' hours and frequencies. Nothing
/// is sent from the server, so this adds no load there.
abstract final class CommuteNotifications {
  /// A trip counts as the commute when both ends are this close to Home
  /// and Work (either way round).
  static const double matchRadiusM = 400;

  /// Notification ids 7000-7099 are this feature's: id = base + weekday*10 + k.
  static const int _baseId = 7000;

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// The same plugin and set-up serve the trip notifications (see
  /// TripNotification): one initialisation, one tap handler.
  static FlutterLocalNotificationsPlugin get plugin => _plugin;
  static Future<void> init() => _init();
  static bool get supported => _supported;

  /// A notification was tapped; its payload says which (the trip's is 'trip').
  static void Function(String? payload)? onTap;

  /// Lets a test stand in for a phone (it then registers the plugin's
  /// platform side itself).
  @visibleForTesting
  static bool? debugSupported;

  static bool get _supported => debugSupported ?? (!kIsWeb && (Platform.isAndroid || Platform.isIOS));

  // ------------------------------------------------------------- Home/Work

  static HomeWork? homeWorkFrom(SharedPreferences prefs) {
    ({double lat, double lon})? slot(String key) {
      final parts = prefs.getString(key)?.split('|');
      if (parts == null || parts.length < 3) return null;
      final lat = double.tryParse(parts[parts.length - 2]), lon = double.tryParse(parts.last);
      return lat == null || lon == null ? null : (lat: lat, lon: lon);
    }

    final home = slot('Home'), work = slot('Work');
    if (home == null || work == null) return null;
    return (homeLat: home.lat, homeLon: home.lon, workLat: work.lat, workLon: work.lon);
  }

  /// Names a Home/Work pair, to tell when either one moved.
  static String keyOf(HomeWork hw) => [hw.homeLat, hw.homeLon, hw.workLat, hw.workLon]
      .map((v) => v.toStringAsFixed(3))
      .join(',');

  static double _metres(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final p1 = lat1 * math.pi / 180, p2 = lat2 * math.pi / 180;
    final dp = p2 - p1, dl = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dp / 2) * math.sin(dp / 2) + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  /// Whether a trip from start to end is the Home <-> Work commute.
  static bool isCommute(HomeWork hw, double startLat, double startLon, double endLat, double endLon) {
    bool near(double a, double b, double c, double d) => _metres(a, b, c, d) <= matchRadiusM;
    return (near(startLat, startLon, hw.homeLat, hw.homeLon) && near(endLat, endLon, hw.workLat, hw.workLon)) ||
        (near(startLat, startLon, hw.workLat, hw.workLon) && near(endLat, endLon, hw.homeLat, hw.homeLon));
  }

  // --------------------------------------------------------------- capture

  /// The vehicle legs of a route option: each line once, with the direction
  /// it was ridden in, named as the app names it.
  static List<({String routeId, String? directionId, String label})> legsOf(
      AppLocalizations l10n, Map<String, dynamic> option) {
    final seen = <String>{};
    final legs = <({String routeId, String? directionId, String label})>[];
    for (final s in (option['instructions'] as List? ?? const [])) {
      if (s is! Map || (s['action'] != 'board' && s['action'] != 'transfer')) continue;
      final id = s['route_id']?.toString();
      if (id == null || !seen.add(id)) continue;
      legs.add((routeId: id, directionId: s['direction_id']?.toString(), label: InstructionFormatter.lineLabel(l10n, s)));
    }
    return legs;
  }

  /// A line's hours and frequencies from its detail (backend route_detail).
  static CommuteLine lineFrom(({String routeId, String? directionId, String label}) leg, Map<String, dynamic> detail) {
    final directions = [for (final d in (detail['directions'] as List? ?? const [])) if (d is Map) d];
    final ridden = directions.where((d) => d['direction_id']?.toString() == leg.directionId).firstOrNull ??
        directions.where((d) => d['headway_bands'] is List).firstOrNull;
    return CommuteLine(
      routeId: leg.routeId,
      label: leg.label,
      bands: [for (final b in (ridden?['headway_bands'] as List? ?? const [])) ?HeadwayBand.fromJson(b)],
      windows: [for (final w in (detail['service_windows'] as List? ?? const [])) ?ServiceWindow.fromJson(w)],
    );
  }

  /// Keeps the lines of [option] as the commute's, if the trip it is for
  /// is the Home <-> Work one, and schedules the week. Called when the
  /// rider plans or starts a trip; costs one line-detail request a line.
  static Future<void> captureIfCommute({
    required AppLocalizations l10n,
    required Map<String, dynamic> option,
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    ApiService? api,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hw = homeWorkFrom(prefs);
      if (hw == null || !isCommute(hw, startLat, startLon, endLat, endLon)) return;
      await _capture(l10n, option, hw, api ?? ApiService());
      await reschedule();
    } catch (e) {
      debugPrint('[Commute] capture failed: $e');
    }
  }

  static Future<void> _capture(AppLocalizations l10n, Map<String, dynamic> option, HomeWork hw, ApiService api) async {
    final lines = <CommuteLine>[];
    for (final leg in legsOf(l10n, option)) {
      try {
        lines.add(lineFrom(leg, await api.fetchRouteDetail(leg.routeId, lang: localeController.isArabic ? 'ar' : 'en')));
      } catch (_) {
        lines.add(CommuteLine(routeId: leg.routeId, label: leg.label));
      }
    }
    if (lines.isNotEmpty) await CommuteStore.saveLines(lines, homeWorkKey: keyOf(hw));
  }

  /// At app start: finds the commute's lines when there are none yet, or
  /// they are old or for another Home/Work (one route search), then
  /// schedules the week.
  static Future<void> refresh({ApiService? api}) async {
    if (!_supported) return;
    try {
      await CommuteStore.loadSettings();
      if (!CommuteStore.settings.value.enabled) {
        await reschedule();
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final hw = homeWorkFrom(prefs);
      final saved = await CommuteStore.loadLines();
      final stale = saved.lines.isEmpty ||
          saved.key != (hw == null ? null : keyOf(hw)) ||
          saved.capturedAt == null ||
          DateTime.now().difference(saved.capturedAt!) > CommuteStore.staleAfter;
      if (hw != null && stale) {
        final service = api ?? ApiService();
        final lang = localeController.isArabic ? 'ar' : 'en';
        final data = await service.fetchRoute(hw.homeLat, hw.homeLon, hw.workLat, hw.workLon, lang: lang);
        final options = [for (final o in (data['options'] as List? ?? const [])) if (o is Map) Map<String, dynamic>.from(o)];
        if (options.isNotEmpty) await _capture(lookupAppLocalizations(Locale(lang)), options.first, hw, service);
      }
      await reschedule();
    } catch (e) {
      debugPrint('[Commute] refresh failed: $e');
    }
  }

  // -------------------------------------------------------------- schedule

  static Future<void> _init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    await _plugin.initialize(
      onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_launcher_monochrome'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  /// Asks for the notification permission (Android 13+, iOS).
  static Future<void> requestPermission() async {
    if (!_supported) return;
    try {
      await _init();
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, sound: true);
    } catch (e) {
      debugPrint('[Commute] permission request failed: $e');
    }
  }

  /// Whether the phone lets Guidy show notifications; null where unknown.
  /// Settings says so when they're blocked, or the alerts never arrive
  /// without a word.
  static Future<bool?> notificationsAllowed() async {
    if (!_supported) return null;
    try {
      await _init();
      final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return await android.areNotificationsEnabled();
      final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return (await ios?.checkPermissions())?.isEnabled;
    } catch (_) {
      return null;
    }
  }

  /// Replaces this feature's scheduled notifications with a fresh week
  /// from the saved lines and settings. Each repeats weekly on its day.
  static Future<void> reschedule() async {
    if (!_supported) return;
    await _init();
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (p.id >= _baseId && p.id < _baseId + 100) await _plugin.cancel(id: p.id);
    }
    final s = CommuteStore.settings.value;
    if (!s.enabled) return;
    final lines = (await CommuteStore.loadLines()).lines;
    if (lines.isEmpty) return;
    // Asked once, when there is first something to notify about, from
    // every path that gets here. It used to be asked only when a planned
    // trip matched Home and Work within 400 m, or when the (on by default)
    // switch was turned on, so most riders were never asked, and Android
    // 13+ dropped every notification scheduled below.
    if (await CommuteStore.takePermissionAsk()) await requestPermission();
    final l10n = lookupAppLocalizations(Locale(localeController.isArabic ? 'ar' : 'en'));
    final details = _details(l10n);
    final now = tz.TZDateTime.now(tz.local);
    for (var weekday = DateTime.monday; weekday <= DateTime.sunday; weekday++) {
      final notices = CommutePlanner.forDay(weekday, lines, easier: s.easier, lastService: s.lastService);
      for (var k = 0; k < notices.length; k++) {
        final n = notices[k];
        final copy = CommuteCopy.of(l10n, n);
        await _plugin.zonedSchedule(
          id: _baseId + weekday * 10 + k,
          scheduledDate: nextAt(now, weekday, n.minuteOfDay),
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: copy.title,
          body: copy.body,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }
  }

  static NotificationDetails _details(AppLocalizations l10n) => NotificationDetails(
        android: AndroidNotificationDetails(
          'commute',
          l10n.commuteChannelName,
          channelDescription: l10n.commuteChannelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  /// The test button exists in debug builds, and in a release build made with
  /// `--dart-define=GUIDY_NOTIF_TEST=true` (to try R8-minified delivery on a
  /// phone). The store builds never set it.
  static const bool testHook = kDebugMode || bool.fromEnvironment('GUIDY_NOTIF_TEST');

  /// Debug builds only (Settings shows the button only there): schedules one
  /// notification [delay] from now through exactly the path the real ones
  /// take (same channel, same alarm mode, weekly repeat), so delivery with
  /// the app closed and after a reboot can be tried without waiting for a
  /// timetable. Returns when it is due, or null when not allowed.
  static Future<DateTime?> debugScheduleTest({Duration delay = const Duration(minutes: 1)}) async {
    if (!testHook || !_supported) return null;
    await _init();
    await requestPermission();
    final l10n = lookupAppLocalizations(Locale(localeController.isArabic ? 'ar' : 'en'));
    final at = tz.TZDateTime.now(tz.local).add(delay);
    await _plugin.zonedSchedule(
      id: _baseId + 99,
      scheduledDate: at,
      notificationDetails: _details(l10n),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: 'Guidy test alert',
      body: 'Debug: scheduled the way the commute alerts are.',
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
    return at;
  }

  /// The next [weekday] at [minuteOfDay] after [now]; minutes past
  /// midnight fall on the next day.
  static tz.TZDateTime nextAt(tz.TZDateTime now, int weekday, int minuteOfDay) {
    final day = weekday + minuteOfDay ~/ (24 * 60);
    final minute = minuteOfDay % (24 * 60);
    final want = (day - 1) % 7 + 1;
    // Built by calendar day, not by adding 24 h, so a DST change keeps
    // the wall-clock time.
    for (var d = 0;; d++) {
      final at = tz.TZDateTime(now.location, now.year, now.month, now.day + d, minute ~/ 60, minute % 60);
      if (at.weekday == want && at.isAfter(now)) return at;
    }
  }
}
