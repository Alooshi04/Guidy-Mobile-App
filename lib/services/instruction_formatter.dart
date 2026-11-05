import '../l10n/app_localizations.dart';
import '../utils/ride_words.dart';
import 'transit_modes.dart';

/// Turns the backend's structured instruction/option data into localized
/// display text. This replaced an earlier approach that tried to
/// pattern-match pre-formatted English sentences from the backend via
/// regex -- fragile, and the reason turn-by-turn text used to silently
/// stay in English. Now the backend sends separate fields (action,
/// vehicle_type, route_number, route_description, station) and this
/// class is the only place that turns them into a sentence, in
/// whichever language the app is currently in.
/// Operator brands that change how a bus leg is named and fared.
enum TransitBrand { none, greenBus, mwasalatMisr }

class InstructionFormatter {
  /// [key] in the app's current language: the backend sends every name it
  /// translates as key_en / key_ar next to key (which is in the language
  /// the route was searched in), so a language switch needs no new search.
  static String? localized(Map<dynamic, dynamic> m, String key, {required bool isAr}) {
    final own = m[isAr ? '${key}_ar' : '${key}_en']?.toString().trim();
    if (own != null && own.isNotEmpty) return own;
    final any = m[key]?.toString().trim();
    return (any == null || any.isEmpty) ? null : any;
  }

  static bool _isAr(AppLocalizations l10n) => l10n.localeName.startsWith('ar');

  /// What changes on a ride step when the rider takes [line] from its
  /// boarding options: a line boarding a short walk away moves the leg to
  /// its stop (name in both languages and position) and carries the walk
  /// to it and from where it lets the rider off. The leg's own line has no
  /// walk, so taking it back restores the leg. Empty for options from a
  /// backend that doesn't say where they board.
  static Map<String, dynamic> legMovedTo(Map<dynamic, dynamic> line) {
    if (line['board_lat'] == null || line['board_lon'] == null) return const {};
    return {
      'station': line['board_stop_name'],
      'station_en': line['board_stop_name_en'],
      'station_ar': line['board_stop_name_ar'],
      'lat': line['board_lat'],
      'lon': line['board_lon'],
      'walk_to_board_m': line['walk_to_board_m'] ?? 0,
      'walk_from_alight_m': line['walk_from_alight_m'] ?? 0,
      'alight_stop_name': line['alight_stop_name'],
      'alight_stop_name_en': line['alight_stop_name_en'],
      'alight_stop_name_ar': line['alight_stop_name_ar'],
    };
  }

  /// Makes the walk that leads to a ride follow the ride to its new stop
  /// ([moved] is [legMovedTo]'s result): it names that stop, ends at its
  /// position, and is [moved]'s walk longer. The walk's first distance and
  /// place are kept so taking the planned line back restores them.
  static void walkFollowsLeg(Map<String, dynamic> walk, Map<String, dynamic> moved) {
    if (moved.isEmpty) return;
    walk.putIfAbsent('walk_base_m', () => walk['distance_m'] ?? 0);
    walk.putIfAbsent('walk_base_place', () => {for (final k in _placeKeys) k: walk[k]});
    final extra = asNum(moved['walk_to_board_m']) ?? 0;
    walk['distance_m'] = (asNum(walk['walk_base_m']) ?? 0) + extra;
    if (extra == 0) {
      walk.addAll(Map<String, dynamic>.from(walk['walk_base_place'] as Map));
    } else {
      for (final k in _placeKeys) {
        walk[k] = moved[k];
      }
    }
  }

  static const _placeKeys = ['station', 'station_en', 'station_ar', 'lat', 'lon'];

  /// The walks a ride step carries after the rider took a line a short
  /// walk away (see [legMovedTo]): to its stop first, and from where it
  /// lets them off.
  static List<String> legWalkNotes(AppLocalizations l10n, Map<dynamic, dynamic> step) {
    final isAr = _isAr(l10n);
    final toBoard = asNum(step['walk_to_board_m'])?.round() ?? 0;
    final fromAlight = asNum(step['walk_from_alight_m'])?.round() ?? 0;
    final boardAt = localized(step, 'station', isAr: isAr);
    final alightAt = localized(step, 'alight_stop_name', isAr: isAr);
    return [
      if (toBoard > 0 && boardAt != null) l10n.navWalkToStopFirst('$toBoard', boardAt),
      if (fromAlight > 0 && alightAt != null) l10n.navGetOffThenWalk(alightAt, '$fromAlight'),
    ];
  }

  /// Delegates to [TransitModes] so the label, the icon and the colour for
  /// a vehicle_type all come from one table. Kept as a method here because
  /// several screens already call it by this name.
  static String vehicleTypeLabel(AppLocalizations l10n, String? vehicleType) =>
      TransitModes.label(l10n, vehicleType);

  /// Bare vehicle words the feed uses as `route_short_name` when a line
  /// has no public number (every microbus, the cooperative minibuses, the
  /// 8-seater "Tomnaya", the rail lines). They are a category, not a
  /// number: rendering one as a number is how a microbus line ended up
  /// badged "Tomnaya" and a timeline chip ended up showing a station name.
  static final Set<String> _bareVehicleWords = {
    'bus', 'microbus', 'minibus', 'tomnaya', 'box', 'lrt', 'monorail', 'apm',
    'metro', 'green', 'mm', 'cta', 'apta',
    'أتوبيس', 'اتوبيس', 'باص', 'ميكروباص', 'مينى باص', 'ميني باص', 'مينيباص',
    'ثمناية', 'تومناية', 'بوكس', 'مونوريل', 'المونوريل', 'جرين', 'مواصلات مصر',
    'القطار الكهربائي الخفيف', 'brt', 'الأتوبيس الترددي',
  };

  static final RegExp _numberPrefix = RegExp(
    r'^(?:MM|GRN|Green\s+Bus|Green|CTA|APTA|Minibus|Microbus|Bus|Line|Mwasalat\s+Misr|'
    r'أتوبيس|اتوبيس|مينى\s*باص|ميني\s*باص|ميكروباص|جرين\s*باص|جرين|مواصلات\s+مصر|باص)\s+',
    caseSensitive: false,
  );

  /// The rider-facing route number, or null when the line has none.
  ///
  /// Strips vehicle/operator words the feed puts in front of the code
  /// ("CTA 910", "APTA 44", "Minibus 305", "مينى باص 305", "Green G1", "MM M11") and
  /// returns null for a bare vehicle word ("Microbus", "Tomnaya"). Branch
  /// letters and brand codes survive: "24t", "G1", "M11", "MD-1", "Ms4".
  static String? cleanRouteNumber(String? routeNumber) {
    if (routeNumber == null) return null;
    var clean = routeNumber.trim();
    if (clean.isEmpty) return null;
    if (_bareVehicleWords.contains(clean.toLowerCase())) return null;
    // Two passes cover stacked prefixes: "Green Bus G1", "MM M11".
    for (var i = 0; i < 2; i++) {
      final stripped = clean.replaceFirst(_numberPrefix, '').trim();
      if (stripped == clean) break;
      clean = stripped;
    }
    if (clean.isEmpty || _bareVehicleWords.contains(clean.toLowerCase())) return null;
    return clean;
  }

  /// Which operator brand a bus leg belongs to, decided from what the
  /// backend says about the route (agency / route_id / is_green_bus).
  ///
  /// This used to be guessed from the route NUMBER -- anything starting
  /// with "M" became Mwasalat Misr and anything starting with "G" a Green
  /// Bus, whatever the vehicle. That mislabelled the Madinaty buses
  /// ("MD-1"), the LTRA minibus "Ms4" and so on. The number is now only
  /// consulted for a payload with no agency and no route_id at all (an old
  /// saved trip), and then only for the exact code shapes those operators
  /// use.
  static TransitBrand brandOf(Map<dynamic, dynamic> m) {
    final agency = (m['agency'] ?? m['agency_id'] ?? '').toString().trim().toUpperCase();
    final routeId = (m['route_id'] ?? '').toString().trim().toUpperCase();
    final vType = (m['vehicle_type'] ?? '').toString().toLowerCase();
    if (vType.isNotEmpty && vType != 'bus') return TransitBrand.none;
    if (m['is_green_bus'] == true ||
        agency == 'GRN' ||
        agency == 'GREEN BUS' ||
        routeId.startsWith('GRN_')) {
      return TransitBrand.greenBus;
    }
    if (agency == 'MM' || agency == 'MWASALAT MISR' || routeId.startsWith('MM_')) {
      return TransitBrand.mwasalatMisr;
    }
    if (agency.isEmpty && routeId.isEmpty) {
      final n = (cleanRouteNumber(m['route_number']?.toString()) ?? '').toUpperCase();
      if (RegExp(r'^G\d+$').hasMatch(n)) return TransitBrand.greenBus;
      if (RegExp(r'^(?:M|NS|NA)\d+$').hasMatch(n)) return TransitBrand.mwasalatMisr;
    }
    return TransitBrand.none;
  }

  /// True for the air-conditioned operators with the higher flat fare.
  static bool isAcBus(Map<dynamic, dynamic> m) => brandOf(m) != TransitBrand.none;

  /// "Green Bus" / "Mwasalat Misr" / the plain vehicle label.
  static String vehicleLabelFor(AppLocalizations l10n, Map<dynamic, dynamic> m) {
    final isAr = l10n.localeName.startsWith('ar');
    switch (brandOf(m)) {
      case TransitBrand.greenBus:
        return isAr ? 'جرين باص' : 'Green Bus';
      case TransitBrand.mwasalatMisr:
        return isAr ? 'مواصلات مصر' : 'Mwasalat Misr';
      case TransitBrand.none:
        return vehicleTypeLabel(l10n, m['vehicle_type']?.toString());
    }
  }

  /// Short line name without the corridor: "Minibus 305", "Green Bus G1",
  /// "Mwasalat Misr M11", or just "Microbus" for an unnumbered line. Never
  /// falls back to a route_id -- those are internal ids such as
  /// "-pzqD_9pESIJi9DBe5yJq", which navigation used to show as
  /// "Riding -pzqD_9pESIJi9DBe5yJq" on every microbus leg.
  /// What tells this line apart from others with the same number: its
  /// two ends, or "via [stop]" (backend route_variants). Null when the
  /// number is unique.
  static String? variantOf(Map<dynamic, dynamic> m, {bool? isAr}) {
    final v = (isAr == null ? null : localized(m, 'route_variant', isAr: isAr)) ??
        (m['route_variant'] ?? m['variant'])?.toString().trim();
    return (v == null || v.isEmpty) ? null : v;
  }

  /// lineLabel plus the variant, for places with room for it: the step
  /// list, the vehicle drop-down and the navigation card.
  static String lineLabelFull(AppLocalizations l10n, Map<dynamic, dynamic> m) {
    final base = lineLabel(l10n, m);
    final v = variantOf(m, isAr: _isAr(l10n));
    return v == null ? base : '$base ($v)';
  }

  /// Cairo riders say "الخط التاني", never "المترو رقم 2".
  static const _metroLineOrdinalsAr = {
    '1': 'الأول', '2': 'التاني', '3': 'التالت', '4': 'الرابع', '5': 'الخامس', '6': 'السادس',
  };

  static String lineLabel(AppLocalizations l10n, Map<dynamic, dynamic> m) {
    final label = vehicleLabelFor(l10n, m);
    final number = cleanRouteNumber(m['route_number']?.toString());
    if ((m['vehicle_type'] ?? '').toString().toLowerCase() == 'metro') {
      final line = RegExp(r'_L(\d+)$').firstMatch((m['route_id'] ?? '').toString())?.group(1) ??
          RegExp(r'^\d+$').firstMatch(number ?? '')?.group(0);
      if (line != null) {
        if (!_isAr(l10n)) return 'Metro Line $line';
        final ordinal = _metroLineOrdinalsAr[line];
        return ordinal == null ? 'الخط $line' : 'الخط $ordinal';
      }
    }
    if (number == null) return label;
    return l10n.instrBoardWithNumber(label, number);
  }

  /// The route-identifying part of a "board"/"transfer" instruction:
  /// prefers a real route number ("Bus 27", "Green Bus G1") over a generic vehicle-type
  /// + corridor description ("Microbus towards Nahda City") when no
  /// number is available in the source data.
  static String _routeLabel(AppLocalizations l10n, Map<String, dynamic> instr) {
    final routeNumber = cleanRouteNumber(instr['route_number']?.toString());
    final isAr = l10n.localeName.startsWith('ar');
    final routeDescription = isAr
        ? (instr['route_description_ar']?.toString().isNotEmpty == true
            ? instr['route_description_ar']?.toString()
            : instr['route_description']?.toString())
        : (instr['route_description_en']?.toString().isNotEmpty == true
            ? instr['route_description_en']?.toString()
            : instr['route_description']?.toString());

    if (routeNumber != null) return lineLabel(l10n, instr);
    final vehicleLabel = vehicleLabelFor(l10n, instr);
    if (routeDescription != null && routeDescription.isNotEmpty) {
      return l10n.instrBoardGeneral(vehicleLabel, routeDescription);
    }
    return vehicleLabel;
  }

  static String title(AppLocalizations l10n, Map<String, dynamic> instr) {
    final action = instr['action'];
    switch (action) {
      case 'walk_to_station':
        return l10n.instrWalkToStationTitle;
      case 'walk_to_transfer':
        return l10n.instrWalkToTransferTitle;
      case 'continue_walk':
        return l10n.instrContinueWalkTitle;
      case 'board':
        return l10n.instrBoardTitleWithVehicle(RideWords.thing(l10n, instr));
      case 'transfer':
        return l10n.instrTransferTitle;
      case 'arrive':
        return l10n.instrArriveTitle;
      case 'walk_to_destination':
        return l10n.instrWalkToDestinationTitle;
      default:
        return '';
    }
  }

  static String subtitle(AppLocalizations l10n, Map<String, dynamic> instr) {
    final action = instr['action'];
    final isAr = l10n.localeName.startsWith('ar');
    final String station = (isAr
        ? (instr['station_ar']?.toString().isNotEmpty == true
            ? instr['station_ar']?.toString()
            : instr['station']?.toString())
        : (instr['station_en']?.toString().isNotEmpty == true
            ? instr['station_en']?.toString()
            : instr['station']?.toString())) ?? '';
    switch (action) {
      case 'walk_to_station':
        return l10n.instrWalkToStationSubtitle((instr['distance_m'] ?? 0).toString(), station);
      case 'walk_to_transfer':
        return l10n.instrWalkToTransferSubtitle(station);
      case 'continue_walk':
        return l10n.instrContinueWalkSubtitle;
      case 'board':
      case 'transfer':
        return _routeLabel(l10n, instr);
      case 'arrive':
        return l10n.instrArriveSubtitle(station);
      case 'walk_to_destination':
        return l10n.instrWalkToDestinationSubtitle((instr['distance_m'] ?? 0).toString());
      default:
        return '';
    }
  }

  /// Icon-selection key ("walk" / "transfer" / "arrive" / vehicle type)
  /// so screens don't each re-derive this from raw strings.
  static String iconKey(Map<String, dynamic> instr) {
    final action = instr['action'];
    if (action == 'walk_to_station' || action == 'walk_to_transfer' || action == 'continue_walk' || action == 'walk_to_destination') {
      return 'walk';
    }
    if (action == 'transfer') return 'transfer';
    if (action == 'arrive') return 'arrive';
    return instr['vehicle_type']?.toString() ?? 'bus';
  }

  static String routeTierLabel(AppLocalizations l10n, String tier) {
    switch (tier) {
      case 'Recommended':
        return l10n.routeTierRecommended;
      case 'Fastest':
        return l10n.routeTierFastest;
      case 'Regular':
        return l10n.routeTierRegular;
      case 'Cheapest':
        return l10n.routeTierCheapest;
      case 'Alternative':
        return l10n.routeTierAlternative;
      case 'Walk':
        return l10n.routeTierWalk;
      // Late at night: a trip on lines that are running right now, shown
      // beside the usual route whose lines have stopped.
      case 'Available now':
        return l10n.routeTierAvailableNow;
      // Not a tier like the others: this is what the engine returns when
      // it could not reach the destination at all and fell back to the
      // closest stop it can reach. Labelled so the card cannot be
      // mistaken for a complete route -- the accompanying banner in
      // RouteOptionsScreen says exactly what is missing.
      case 'Partial':
        return l10n.routeTierPartial;
      default:
        return tier;
    }
  }

  /// Short summary used on the route-option card, e.g. "Minibus 302" or
  /// "Microbus towards Nahda City" or just "Walk" for a walking-only option.
  /// The kind of bus a line runs, from the bracket ending its
  /// description: "El-Mandara - K21 (AC)" -> "AC", "(كهربائي, مكيف)" ->
  /// "كهربائي, مكيف". Null for an ordinary line ("(regular)"), for none,
  /// and for a bracket that names a place ("(Nasr City)").
  static String? vehicleKind(Map option, {required bool isAr}) {
    final desc = (isAr
            ? option['route_description_ar'] ?? option['route_description']
            : option['route_description_en'] ?? option['route_description'])
        ?.toString()
        .trim();
    if (desc == null) return null;
    final kinds = RegExp(r'\(([^()]+)\)$')
        .firstMatch(desc)
        ?.group(1)
        ?.split(RegExp(r'[,،]'))
        .map((k) => k.trim())
        .toList();
    if (kinds == null || !kinds.every(_busKinds.contains)) return null;
    final shown = kinds.where((k) => !_ordinaryBus.contains(k)).toList();
    return shown.isEmpty ? null : shown.join(isAr ? '، ' : ', ');
  }

  static const _ordinaryBus = {'regular', 'عادي', 'عادى'};
  static const _busKinds = {
    ..._ordinaryBus,
    'AC', 'double-decker', 'natural gas', 'electric',
    'مكيف', 'دبل ديكر', 'غاز', 'كهربائي',
  };

  static String optionSummary(AppLocalizations l10n, Map<String, dynamic> option) {
    final vehicleType = option['vehicle_type'];
    if (vehicleType == 'walk' || vehicleType == null) {
      return vehicleTypeLabel(l10n, 'walk');
    }
    if (cleanRouteNumber(option['route_number']?.toString()) != null) {
      return lineLabel(l10n, option);
    }
    final isAr = l10n.localeName.startsWith('ar');
    final vehicleLabel = vehicleLabelFor(l10n, option);
    final routeDesc = isAr
        ? (option['route_description_ar'] ?? option['route_description'] ?? option['routeDescription'] ?? option['summary'])
        : (option['route_description_en'] ?? option['route_description'] ?? option['routeDescription'] ?? option['summary']);
    if (routeDesc != null && routeDesc.toString().trim().isNotEmpty) {
      final desc = routeDesc.toString().trim();
      if (desc.toLowerCase().startsWith(vehicleLabel.toLowerCase())) {
        return desc;
      }
      // "Microbus Moassasa - Nahda City": no "•" between them, which read
      // as a separator like the middle dot the beta reviewer asked to drop.
      return '$vehicleLabel $desc';
    }
    return vehicleLabel;
  }

  /// The fare on a route option, localized.
  ///
  /// The backend also sends a pre-formatted `price` string ("20 EGP",
  /// "Free"), which is English whatever language the app is in -- it was
  /// the reason a fare stayed in English on an otherwise Arabic screen.
  /// Safely converts dynamic values (num, string representations of numbers) to num.
  static num? asNum(dynamic val) {
    if (val == null) return null;
    if (val is num) return val;
    if (val is String) return num.tryParse(val.trim());
    return null;
  }

  /// Prefer the numbers and format them here; fall back to that string
  /// only if an older backend is on the other end and sends neither.
  static String fareText(AppLocalizations l10n, Map<String, dynamic> option) {
    final total = option['fare_total_egp'] ?? option['fare_egp'];
    if (total != null) {
      final n = asNum(total);
      if (n != null) {
        return n == 0 ? l10n.fareFree : l10n.fareEgp(_trimZero(n));
      }
    }
    if (option['vehicle_type'] == 'walk') return l10n.fareFree;
    return option['price']?.toString() ?? '-';
  }

  /// Turns the backend's stable error `code` into a localized sentence.
  ///
  /// The server also sends an English `message`. That is a fallback for a
  /// code this build doesn't know yet, not the normal path -- showing it is
  /// how English sentences appeared on Arabic screens.
  static String errorMessage(AppLocalizations l10n, Map<String, dynamic> data) {
    switch (data['error_code']) {
      case 'network':
        return l10n.serverUnreachable;
      case 'outside_coverage':
        return l10n.errorOutsideCoverage;
      case 'outside_service_hours':
        return l10n.errorNoServiceThisHour;
      case 'no_coverage':
      case 'no_route_found':
        return l10n.errorNoRouteFound;
    }
    final message = data['error'];
    if (message is String && message.isNotEmpty) return message;
    return l10n.routeCalculationFailed;
  }

  /// The heading over [errorMessage], or null for "Something went wrong".
  static String? errorTitle(AppLocalizations l10n, Map<String, dynamic> data) {
    switch (data['error_code']) {
      case 'outside_coverage':
      case 'no_coverage':
      case 'no_route_found':
        return l10n.errorTitleNotCovered;
      case 'outside_service_hours':
        return l10n.errorTitleNoService;
    }
    return null;
  }

  /// True for a failure that is about the connection, not the trip.
  static bool isNetworkError(Map<String, dynamic> data) => data['error_code'] == 'network';

  static String _trimZero(num n) =>
      n == n.roundToDouble() ? n.round().toString() : n.toString();
}
