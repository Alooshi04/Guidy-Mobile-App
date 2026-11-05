import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'better_route.dart';

/// What a rider says is wrong. Symbolic, never a translated string -- the
/// wording belongs in the UI, and a report read six months from now in a
/// console should not depend on which language the reporter had selected.
enum RouteReportReason {
  routeDoesNotExist,
  wrongStop,
  badTiming,
  wrongFare,
  betterRouteKnown,
  other,
}

extension RouteReportReasonId on RouteReportReason {
  /// Stored verbatim in Firestore. Kept explicit rather than using `.name`,
  /// so renaming the enum in Dart can never silently repartition months of
  /// collected reports.
  String get id => switch (this) {
        RouteReportReason.routeDoesNotExist => 'route_does_not_exist',
        RouteReportReason.wrongStop => 'wrong_stop',
        RouteReportReason.badTiming => 'bad_timing',
        RouteReportReason.wrongFare => 'wrong_fare',
        RouteReportReason.betterRouteKnown => 'better_route_known',
        RouteReportReason.other => 'other',
      };
}

enum RouteReportOutcome { sent, queuedOffline, notSignedIn, failed }

enum LineReportReason {
  routeDoesNotExist,
  wrongPath,
  wrongStop,
  wrongFare,
  badTiming,
  other,
}

extension LineReportReasonId on LineReportReason {
  String get id => switch (this) {
        LineReportReason.routeDoesNotExist => 'route_does_not_exist',
        LineReportReason.wrongPath => 'wrong_path',
        LineReportReason.wrongStop => 'wrong_stop',
        LineReportReason.wrongFare => 'wrong_fare',
        LineReportReason.badTiming => 'bad_timing',
        LineReportReason.other => 'other',
      };

  String get englishLabel => switch (this) {
        LineReportReason.routeDoesNotExist => 'Line does not exist or was discontinued',
        LineReportReason.wrongPath => 'Route takes a different path or diverted streets',
        LineReportReason.wrongStop => 'Missing stop or incorrect stop sequence',
        LineReportReason.wrongFare => 'Fare has changed or is incorrect',
        LineReportReason.badTiming => 'Schedule, frequency, or operating hours inaccurate',
        LineReportReason.other => 'Other line issue',
      };
}

enum MetroReportReason {
  stationClosed,
  wrongTransfer,
  wrongFare,
  delayOrDisruption,
  other,
}

extension MetroReportReasonId on MetroReportReason {
  String get id => switch (this) {
        MetroReportReason.stationClosed => 'station_closed',
        MetroReportReason.wrongTransfer => 'wrong_transfer',
        MetroReportReason.wrongFare => 'wrong_fare',
        MetroReportReason.delayOrDisruption => 'delay_or_disruption',
        MetroReportReason.other => 'other',
      };

  String get englishLabel => switch (this) {
        MetroReportReason.stationClosed => 'Station closed or out of service',
        MetroReportReason.wrongTransfer => 'Incorrect line interchange instructions',
        MetroReportReason.wrongFare => 'Incorrect ticket tier or pricing',
        MetroReportReason.delayOrDisruption => 'Line disruption or significant delay',
        MetroReportReason.other => 'Other rail network issue',
      };
}

/// Rider corrections to a planned route, written straight to Firestore.
///
/// WHY FIRESTORE AND NOT THE BACKEND
/// The backend is stateless and reads its GTFS feed from a read-only
/// volume; it has nowhere to put a report and no admin surface to read one
/// back. Firestore gives durable storage, a console to triage in, and --
/// the part that actually matters on a bus -- an offline queue. A rider
/// noticing a wrong route is very often underground or on bad signal,
/// which is exactly when they are least able to send anything.
///
/// WHAT GETS STORED, AND WHY IT IS SHAPED THIS WAY
/// Each reported step carries `route_id` and `direction_id`. Those are the
/// GTFS keys: a report saying "this bus doesn't go there" is only
/// actionable if it names the row in routes.txt. A route number alone is
/// not enough -- several hundred microbus routes in this feed carry no
/// number at all, only a corridor name.
class RouteReportService {
  RouteReportService._();

  /// Also the collection the deployed firestore.rules gates. Changing this
  /// string without changing that file means every write is denied.
  static const String collectionPath = 'route_reports';

  /// The form's limit, counted in characters. firestore.rules allows 4000
  /// rather than this, on purpose -- see the note there. The rule is only
  /// a backstop against abuse; this is the number a rider actually meets.
  static const int maxCommentLength = 500;

  static CollectionReference<Map<String, dynamic>> get _reports =>
      FirebaseFirestore.instance.collection(collectionPath);

  static String? _cachedVersion;

  static Future<String> _appVersion() async {
    if (_cachedVersion != null) return _cachedVersion!;
    try {
      final info = await PackageInfo.fromPlatform();
      return _cachedVersion = '${info.version}+${info.buildNumber}';
    } catch (_) {
      return _cachedVersion = 'unknown';
    }
  }

  /// One step, reduced to the fields that make it actionable.
  static Map<String, dynamic> _step(int index, Map<String, dynamic> i) => {
        'index': index,
        'action': i['action'],
        'vehicle_type': i['vehicle_type'],
        // The GTFS identity of the leg. Without these a report is a
        // complaint; with them it is a lookup.
        'route_id': i['route_id'],
        'direction_id': i['direction_id'],
        'route_number': i['route_number'],
        'route_description': i['route_description'],
        'station': i['station'],
        'lat': i['lat'],
        'lon': i['lon'],
        'distance_m': i['distance_m'],
        'fare_egp': i['fare_egp'],
      };

  /// Submits a report. [stepIndexes] is the rider's actual selection;
  /// selecting every step is recorded as a whole-route report rather than
  /// as N separate step complaints, because those mean different things to
  /// whoever triages them.
  static Future<RouteReportOutcome> submit({
    required Map<String, dynamic> option,
    required Set<int> stepIndexes,
    required RouteReportReason reason,
    required String comment,
    required String startName,
    required String endName,
    required String locale,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return RouteReportOutcome.notSignedIn;

    final instructions = (option['instructions'] as List?) ?? const [];

    Map<String, dynamic> at(int n) =>
        _step(n, Map<String, dynamic>.from(instructions[n] as Map));

    final chosen = stepIndexes.where((n) => n >= 0 && n < instructions.length).toList()..sort();
    final wholeRoute = instructions.isNotEmpty && chosen.length == instructions.length;

    final doc = <String, dynamic>{
      // Bumped whenever this shape changes, so a later reader can tell an
      // old document from a malformed one.
      'schema': 1,
      'status': 'new',
      'created_at': FieldValue.serverTimestamp(),
      // Also recorded client-side: created_at is null in the local cache
      // until the write reaches Firestore, so an offline report has no
      // usable time at all without this.
      'created_at_client': DateTime.now().toUtc().toIso8601String(),
      'uid': user.uid,
      'reason': reason.id,
      'comment': comment.trim(),
      'scope': wholeRoute ? 'route' : 'step',
      'app_version': await _appVersion(),
      'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
      'locale': locale,
      'trip': {
        'start_name': startName,
        'end_name': endName,
        'profile': option['type'],
        'total_time_min': option['time'],
        'total_fare_egp': option['fare_total_egp'],
        'distance_m': option['distance_m'],
        'step_count': instructions.length,
      },
      'steps': [for (final n in chosen) at(n)],
      // The full itinerary, always -- even for a single-step report.
      // Whether a leg is wrong often depends on what came before it, and a
      // report that cannot be reproduced is a report that cannot be fixed.
      'all_steps': [for (var n = 0; n < instructions.length; n++) at(n)],
    };

    return _send(doc);
  }

  /// Report for a trip the engine could not plan at all.
  ///
  /// The ordinary [submit] path can only describe an itinerary that
  /// exists, which means it can only ever tell us about routes we already
  /// have. A coverage HOLE produces no itinerary to attach a complaint
  /// to, so without this the riders best placed to tell us what is
  /// missing -- the ones who just watched the app fail -- have no way to.
  ///
  /// Stored with the same schema and in the same collection so triage is
  /// one queue, not two; `scope` is what separates them.
  static Future<RouteReportOutcome> submitMissingRoute({
    required double startLat,
    required double startLon,
    required double endLat,
    required double endLon,
    required String startName,
    required String endName,
    required String comment,
    required String locale,
    String? failureCode,
    int? uncoveredM,
    String? lastCoveredStop,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return RouteReportOutcome.notSignedIn;

    final doc = <String, dynamic>{
      'schema': 1,
      'status': 'new',
      'created_at': FieldValue.serverTimestamp(),
      'created_at_client': DateTime.now().toUtc().toIso8601String(),
      'uid': user.uid,
      'reason': RouteReportReason.routeDoesNotExist.id,
      'comment': comment.trim(),
      'scope': 'missing_route',
      'app_version': await _appVersion(),
      'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
      'locale': locale,
      'trip': {
        'start_name': startName,
        'end_name': endName,
        // Coordinates, not just names: a place name a rider typed cannot
        // be matched back against the feed, but a coordinate pair can be
        // dropped straight onto a map next to the existing stops.
        'start_lat': startLat,
        'start_lon': startLon,
        'end_lat': endLat,
        'end_lon': endLon,
      },
      // What the engine actually did, so a report can be told apart from
      // one filed after a partial answer -- those two mean different
      // things: no answer at all vs. an answer that stopped short.
      'failure': {
        'code': failureCode,
        'uncovered_m': uncoveredM,
        'last_covered_stop': lastCoveredStop,
      },
    };

    return _send(doc);
  }

  /// A route the rider knows that beats the ones offered ("Know a better
  /// route?" on Route Options), written in their words or built leg by leg
  /// from the network.
  ///
  /// Like [submitMissingRoute] it names both ends by coordinates, and it
  /// adds what the engine offered (`shown_options`): "better" only means
  /// something next to what it is better than. A built route's `legs`
  /// name each network line by its GTFS route_id, so it can be checked
  /// against the feed and planned again; a typed line is marked as such,
  /// a line we don't have at all.
  static Future<RouteReportOutcome> submitBetterRoute(BetterRouteReport report) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return RouteReportOutcome.notSignedIn;

    final doc = <String, dynamic>{
      'schema': 1,
      'status': 'new',
      'created_at': FieldValue.serverTimestamp(),
      'created_at_client': DateTime.now().toUtc().toIso8601String(),
      'uid': user.uid,
      'reason': RouteReportReason.betterRouteKnown.id,
      'scope': 'better_route',
      'app_version': await _appVersion(),
      'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
      'locale': report.locale,
      ...report.toFields(),
    };

    return _send(doc);
  }

  /// Report filed directly from a line browser or line detail screen.
  static Future<RouteReportOutcome> submitLineReport({
    required String routeId,
    required String? routeNumber,
    required String? routeDescription,
    required String? vehicleType,
    required int directionIndex,
    required String? directionTerminus,
    required List<Map<String, dynamic>> stops,
    required Map<String, dynamic>? selectedStop,
    required LineReportReason reason,
    required String comment,
    required String locale,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return RouteReportOutcome.notSignedIn;

    final stopsPreview = stops.take(15).map((s) {
      final name = s['name'] ?? s['station'] ?? s['stop_id'] ?? '';
      return name.toString();
    }).where((n) => n.isNotEmpty).toList();

    final doc = <String, dynamic>{
      'schema': 1,
      'status': 'new',
      'created_at': FieldValue.serverTimestamp(),
      'created_at_client': DateTime.now().toUtc().toIso8601String(),
      'uid': user.uid,
      'user_email': user.email,
      'scope': 'line',
      'category': 'line_report',
      'reason': reason.id,
      'reason_label': reason.englishLabel,
      'comment': comment.trim(),
      'app_version': await _appVersion(),
      'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
      'locale': locale,
      'line': {
        'route_id': routeId,
        'route_number': routeNumber,
        'route_description': routeDescription,
        'vehicle_type': vehicleType ?? 'bus',
        'direction_index': directionIndex,
        'direction_terminus': directionTerminus,
        'stops_count': stops.length,
      },
      if (selectedStop != null)
        'selected_stop': {
          'stop_id': selectedStop['stop_id'],
          'stop_name': selectedStop['name'] ?? selectedStop['station'],
          'lat': selectedStop['lat'],
          'lon': selectedStop['lon'],
        },
      'stops_preview': stopsPreview,
    };

    return _send(doc);
  }

  /// Report filed directly from the metro trip planner or rail network directory.
  static Future<RouteReportOutcome> submitMetroReport({
    Map<String, dynamic>? metroPlan,
    Map<String, dynamic>? station,
    required MetroReportReason reason,
    required String comment,
    required String locale,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return RouteReportOutcome.notSignedIn;

    final doc = <String, dynamic>{
      'schema': 1,
      'status': 'new',
      'created_at': FieldValue.serverTimestamp(),
      'created_at_client': DateTime.now().toUtc().toIso8601String(),
      'uid': user.uid,
      'user_email': user.email,
      'scope': 'metro',
      'category': 'metro_report',
      'reason': reason.id,
      'reason_label': reason.englishLabel,
      'comment': comment.trim(),
      'app_version': await _appVersion(),
      'platform': Platform.isAndroid ? 'android' : (Platform.isIOS ? 'ios' : 'other'),
      'locale': locale,
      if (metroPlan != null)
        'metro_trip': {
          'from_station': metroPlan['from_station'] ?? metroPlan['from'],
          'to_station': metroPlan['to_station'] ?? metroPlan['to'],
          'fare_egp': metroPlan['fare_egp'],
          'duration_min': metroPlan['time_min'] ?? metroPlan['time'],
          'hops': metroPlan['hops'] ?? metroPlan['station_count'],
          'transfers': metroPlan['transfers'],
        },
      if (station != null)
        'station': {
          'name': station['name'] ?? station['station_name'],
          'lines': station['lines'],
          'is_interchange': station['is_interchange'],
        },
    };

    return _send(doc);
  }

  /// Shared write path, so both report kinds treat offline the same way.
  static Future<RouteReportOutcome> _send(Map<String, dynamic> doc) async {
    try {
      // The timeout is the point, not a safety net. Firestore writes to its
      // local cache synchronously and returns a Future that completes only
      // once the SERVER acknowledges -- which never happens while offline,
      // so awaiting it plainly would hang the button forever. A short
      // timeout separates "sent" from "safely queued", and both are
      // successes the rider deserves to be told apart.
      await _reports.add(doc).timeout(const Duration(seconds: 6));
      return RouteReportOutcome.sent;
    } on FirebaseException catch (e) {
      // 'unavailable' is just no signal; anything else (permission-denied
      // above all) is a real fault worth surfacing rather than dressing up
      // as a successful queue.
      if (e.code == 'unavailable') return RouteReportOutcome.queuedOffline;
      return RouteReportOutcome.failed;
    } catch (_) {
      // Timed out waiting for the server. The document is already in the
      // local cache and Firestore delivers it when signal returns.
      return RouteReportOutcome.queuedOffline;
    }
  }
}
