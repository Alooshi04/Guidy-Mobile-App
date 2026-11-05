import '../l10n/app_localizations.dart';
import 'instruction_formatter.dart';
import 'route_summary.dart';

/// One part of a route a rider says beats the ones we offered, as they
/// build it on BetterRouteBuilderScreen: a walk, or a ride on a line from
/// the network (or one they typed because we don't have it).
///
/// Mutable on purpose: the builder edits a leg in place as the rider types
/// into its fields, and [id] keeps its card in place while the list is
/// reordered.
class BetterRouteLeg {
  BetterRouteLeg.walk({this.meters})
      : id = _nextId++,
        isWalk = true,
        vehicleType = 'walk',
        routeId = null,
        routeNumber = null,
        routeDescription = null,
        agency = null,
        typedName = null;

  /// A line from the network, as `/routes` (ApiService.searchRoutes) sends
  /// it: `route_id`, `number`, `description`, `vehicle_type`, `agency`.
  BetterRouteLeg.line(Map<String, dynamic> route)
      : id = _nextId++,
        isWalk = false,
        vehicleType = (route['vehicle_type'] ?? 'bus').toString(),
        routeId = route['route_id']?.toString(),
        routeNumber = route['number']?.toString() ?? route['route_number']?.toString(),
        routeDescription = route['description']?.toString(),
        agency = route['agency']?.toString(),
        typedName = null;

  /// A line the app doesn't have: the mode and whatever the rider calls it
  /// ("66", "Gesr El Suez microbus").
  BetterRouteLeg.typed({required this.vehicleType, required String name})
      : id = _nextId++,
        isWalk = false,
        routeId = null,
        routeNumber = null,
        routeDescription = null,
        agency = null,
        typedName = name.trim();

  static int _nextId = 0;

  final int id;
  final bool isWalk;
  final String vehicleType;
  final String? routeId;
  final String? routeNumber;
  final String? routeDescription;
  final String? agency;

  /// What the rider typed for a line that isn't in the app.
  final String? typedName;

  /// How far a walk is, if the rider said.
  int? meters;

  /// Where the rider gets on and off, and what it cost (decimal), if said.
  String? boardAt;
  String? alightAt;
  num? fare;

  bool get fromNetwork => routeId != null;

  /// The keys GuidyModeStyle.forRide and RouteSummary.rideLine read, so a
  /// picked line has the colour, icon and name it has on a route card.
  Map<String, dynamic> get asRide => {
        'vehicle_type': vehicleType,
        'route_id': routeId,
        'route_number': routeNumber,
        'agency': agency,
      };

  /// "Minibus 66", "M3", "Microbus"; a typed line as the rider wrote it.
  String label(AppLocalizations l10n) => typedName ?? RouteSummary.rideLine(l10n, asRide);

  /// Stored with the report. Symbolic, like every report field: the
  /// GTFS keys for a network line, never a translated label.
  Map<String, dynamic> toReport() {
    String? clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    if (isWalk) return {'kind': 'walk', 'distance_m': ?meters};
    return {
      'kind': 'ride',
      'source': fromNetwork ? 'network' : 'typed',
      'vehicle_type': vehicleType,
      'route_id': ?routeId,
      'route_number': ?routeNumber,
      'route_description': ?clean(routeDescription),
      'typed_name': ?clean(typedName),
      'board_at': ?clean(boardAt),
      'alight_at': ?clean(alightAt),
      'fare_egp': ?fare,
    };
  }

  /// A number the rider typed, Arabic-Indic digits and an Arabic decimal
  /// mark included ("٧٫٥" is 7.5). Null when empty or not a number.
  static num? parseNumber(String text) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final b = StringBuffer();
    for (final ch in text.trim().split('')) {
      final a = arabic.indexOf(ch);
      final p = persian.indexOf(ch);
      b.write(a >= 0 ? '$a' : p >= 0 ? '$p' : (ch == '٫' || ch == ',') ? '.' : ch);
    }
    return num.tryParse(b.toString());
  }
}

/// A better route a rider reported from Route Options: written in their
/// own words, or built leg by leg ([legs]). Either way it carries both
/// ends and what we offered, so whoever triages it can see what it beats.
class BetterRouteReport {
  const BetterRouteReport({
    required this.startLat,
    required this.startLon,
    required this.endLat,
    required this.endLon,
    required this.startName,
    required this.endName,
    required this.locale,
    this.comment = '',
    this.legs = const [],
    this.shownOptions = const [],
  });

  final double startLat;
  final double startLon;
  final double endLat;
  final double endLon;
  final String startName;
  final String endName;
  final String locale;

  /// The rider's description, or the builder's optional note.
  final String comment;

  /// [BetterRouteLeg.toReport] of each leg, in order; empty for a written one.
  final List<Map<String, dynamic>> legs;

  /// [summarize] of the routes the rider was shown.
  final List<Map<String, dynamic>> shownOptions;

  /// Most legs a built route may have; firestore.rules allows a few more.
  static const int maxLegs = 12;

  /// Most of the shown routes the report carries.
  static const int maxShownOptions = 8;

  /// The report's own fields (RouteReportService adds who, when and the
  /// app). `legs` only for a built route.
  Map<String, dynamic> toFields() => {
        'comment': comment.trim(),
        'trip': {
          'start_name': startName,
          'end_name': endName,
          'start_lat': startLat,
          'start_lon': startLon,
          'end_lat': endLat,
          'end_lon': endLon,
        },
        if (legs.isNotEmpty) 'legs': legs,
        'shown_options': shownOptions.take(maxShownOptions).toList(),
      };

  /// What a route option was, in a few keys: its kind, time, fare and each
  /// leg (walk metres, or the line's GTFS id and number).
  static List<Map<String, dynamic>> summarize(List<Map<String, dynamic>> options) => [
        for (final o in options.take(maxShownOptions))
          {
            'type': o['type'],
            'time_min': InstructionFormatter.asNum(o['time']),
            'fare_egp': InstructionFormatter.asNum(o['fare_total_egp'] ?? o['fare_egp']),
            'legs': [
              for (final i in (o['instructions'] as List? ?? const []))
                if (i is Map && (i['action'] == 'board' || i['action'] == 'transfer'))
                  {'mode': i['vehicle_type'], 'route_id': i['route_id'], 'route_number': i['route_number']}
                else if (i is Map && '${i['action']}'.contains('walk'))
                  {'mode': 'walk', 'distance_m': InstructionFormatter.asNum(i['distance_m'])},
            ],
          },
      ];
}
