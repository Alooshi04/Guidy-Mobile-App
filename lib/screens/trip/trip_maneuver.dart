import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart' show Geolocator;
import 'package:google_maps_flutter/google_maps_flutter.dart' show LatLng;

import '../../l10n/app_localizations.dart';
import '../../services/instruction_formatter.dart';
import '../../services/step_copy.dart';
import '../../utils/ride_words.dart';
import '../../services/transit_modes.dart';

/// Representation of an active turn-by-turn guidance maneuver.
class WalkManeuverInfo {
  final IconData icon;
  final String? iconKey;
  final String headline;
  final String subline;

  /// The fare of the ride [subline] says comes next ("then take minibus
  /// 66"), shown right after it; null when there is none.
  final String? fare;
  final bool isProximityAlert;

  const WalkManeuverInfo({
    required this.icon,
    this.iconKey,
    required this.headline,
    required this.subline,
    this.fare,
    this.isProximityAlert = false,
  });
}

/// The one instruction the trip screen's top card shows: arrived, get
/// ready to get off/on, ride to, or the next turn of a walk. Pure.
abstract final class TripManeuver {
  static WalkManeuverInfo? current(
    AppLocalizations l10n, {
    required List<dynamic> instructions,
    required int step,
    required List<LatLng?> stepPoints,
    required List<List<LatLng>> walkSegments,
    required List<LatLng> allPoints,
    required LatLng? here,
    required String destinationTitle,
  }) {
    if (instructions.isEmpty) return null;

    if (step >= instructions.length - 1) {
      return WalkManeuverInfo(
        icon: Icons.place_rounded,
        iconKey: 'arrive',
        headline: l10n.navYouArrived,
        subline: destinationTitle.isNotEmpty ? destinationTitle : '',
      );
    }

    final currentStep = instructions[step];
    if (currentStep is! Map) return null;
    final String action = (currentStep['action'] ?? '').toString();
    final int next = step + 1;
    final nextStep = next < instructions.length && instructions[next] is Map
        ? instructions[next] as Map<String, dynamic>
        : null;
    final curStation = _station(currentStep as Map<String, dynamic>, l10n);
    final nextStation = nextStep != null ? _station(nextStep, l10n) : '';
    final targetStation = nextStation.isNotEmpty ? nextStation : curStation;
    final LatLng? targetCoord = next < stepPoints.length ? stepPoints[next] : null;
    final isAr = l10n.localeName.startsWith('ar');
    final bool riding = action == 'board' || action == 'transfer';
    final String nextAction = (nextStep?['action'] ?? '').toString();
    // The line the rider takes after this walk, if any ("then take Metro 1").
    final String upcomingLine = (!riding && nextStep != null && (nextAction == 'board' || nextAction == 'transfer'))
        ? RideWords.action(l10n, nextStep, lowerFirst: true)
        : '';
    // Its fare, next to its number (beta feedback, 2026-11).
    final String? upcomingFare = upcomingLine.isEmpty ? null : StepCopy.fareOf(l10n, nextStep!);
    String fmtDist(double m) => m < 1000
        ? l10n.plannerMeters('${(m / 10).round() * 10}')
        : '${(m / 1000).toStringAsFixed(1)} ${isAr ? 'كم' : 'km'}';

    // Proximity alert (within 200m of the next boarding, transfer or exit stop)
    if (here != null && targetCoord != null) {
      final distToStop = Geolocator.distanceBetween(
        here.latitude,
        here.longitude,
        targetCoord.latitude,
        targetCoord.longitude,
      );
      if (distToStop <= 200 && targetStation.isNotEmpty) {
        final distStr = distToStop < 20 ? (isAr ? 'دلوقتي' : 'Now') : fmtDist(distToStop);
        return WalkManeuverInfo(
          icon: riding ? Icons.exit_to_app_rounded : Icons.notifications_active_rounded,
          iconKey: riding ? 'transfer' : 'arrive',
          headline: riding ? l10n.navGetReadyOff(targetStation) : l10n.navNearBoarding(targetStation),
          subline: riding || upcomingLine.isEmpty
              ? distStr
              : StepCopy.join(l10n, [distStr, _midSentence(l10n.navWalkThenBoard(upcomingLine), isAr)]),
          fare: riding ? null : upcomingFare,
          isProximityAlert: true,
        );
      }
    }

    // Transit leg guidance
    if (riding) {
      // Rider-facing line name ("Minibus 66", "Microbus") -- never the
      // internal route_id, which unnumbered microbus legs used to show.
      final lineName = InstructionFormatter.lineLabelFull(l10n, currentStep);
      final iconKey = (currentStep['icon'] ?? currentStep['vehicle_type'] ?? 'bus').toString();
      return WalkManeuverInfo(
        icon: TransitModes.icon(iconKey),
        iconKey: iconKey,
        headline: lineName.isNotEmpty ? l10n.navRiding(RideWords.thing(l10n, currentStep)) : l10n.navRideTo(targetStation),
        subline: lineName.isNotEmpty && targetStation.isNotEmpty ? l10n.navRideTo(targetStation) : '',
      );
    }
    if (action == 'arrive') {
      return WalkManeuverInfo(
        icon: Icons.flag_rounded,
        iconKey: 'arrive',
        headline: l10n.navGetOffHere,
        subline: curStation.isNotEmpty ? l10n.navWalkToDestinationFrom(curStation) : '',
      );
    }

    // Walking leg turn-by-turn guidance along road waypoints
    List<LatLng>? walkPts;
    if (walkSegments.isNotEmpty) {
      final ref = here ?? (step < stepPoints.length ? stepPoints[step] : null);
      if (ref != null) {
        double minD = double.infinity;
        for (final seg in walkSegments) {
          if (seg.isEmpty) continue;
          final d = Geolocator.distanceBetween(ref.latitude, ref.longitude, seg.first.latitude, seg.first.longitude);
          if (d < minD) {
            minD = d;
            walkPts = seg;
          }
        }
      }
      walkPts ??= walkSegments.first;
    } else if (allPoints.isNotEmpty) {
      walkPts = allPoints;
    }

    if (walkPts != null && walkPts.length > 2) {
      final ref = here ?? walkPts.first;
      int closestIdx = 0;
      double minD = double.infinity;
      for (int i = 0; i < walkPts.length; i++) {
        final d = Geolocator.distanceBetween(ref.latitude, ref.longitude, walkPts[i].latitude, walkPts[i].longitude);
        if (d < minD) {
          minD = d;
          closestIdx = i;
        }
      }

      // Look ahead for the next sharp turn maneuver
      for (int k = closestIdx + 1; k < walkPts.length - 1; k++) {
        final segDist = Geolocator.distanceBetween(
          walkPts[k].latitude,
          walkPts[k].longitude,
          walkPts[k + 1].latitude,
          walkPts[k + 1].longitude,
        );
        if (segDist < 5) continue;

        final b1 = _bearingBetween(walkPts[k - 1], walkPts[k]);
        final b2 = _bearingBetween(walkPts[k], walkPts[k + 1]);
        final diff = _turnAngle(b1, b2);

        if (diff.abs() >= 35) {
          double turnDist = Geolocator.distanceBetween(
            ref.latitude,
            ref.longitude,
            walkPts[closestIdx].latitude,
            walkPts[closestIdx].longitude,
          );
          for (int j = closestIdx; j < k; j++) {
            turnDist += Geolocator.distanceBetween(
              walkPts[j].latitude,
              walkPts[j].longitude,
              walkPts[j + 1].latitude,
              walkPts[j + 1].longitude,
            );
          }

          IconData turnIcon;
          String turnAction;
          if (diff > 125 || diff < -125) {
            turnIcon = Icons.u_turn_left_rounded;
            turnAction = l10n.walkManeuverUTurn;
          } else if (diff > 0) {
            turnIcon = Icons.turn_right_rounded;
            turnAction = l10n.walkManeuverRight;
          } else {
            turnIcon = Icons.turn_left_rounded;
            turnAction = l10n.walkManeuverLeft;
          }

          final distStr = fmtDist(turnDist);

          final headline = turnDist < 20 ? turnAction : l10n.walkInDistance(distStr, turnAction);
          final subline = upcomingLine.isNotEmpty
              ? l10n.navWalkThenBoard(upcomingLine)
              : (targetStation.isNotEmpty ? l10n.plannerTowards(targetStation) : '');

          return WalkManeuverInfo(
            icon: turnIcon,
            iconKey: 'walk',
            headline: headline,
            subline: subline,
            fare: upcomingFare,
          );
        }
      }
    }

    // Default straight walk maneuver
    final ref = here ?? (walkPts != null && walkPts.isNotEmpty ? walkPts.first : null);
    double straightDist = 0;
    if (ref != null && targetCoord != null) {
      straightDist = Geolocator.distanceBetween(
        ref.latitude,
        ref.longitude,
        targetCoord.latitude,
        targetCoord.longitude,
      );
    } else if (currentStep['distance_m'] != null) {
      straightDist = (InstructionFormatter.asNum(currentStep['distance_m']) ?? 0).toDouble();
    }

    final distStr = fmtDist(straightDist);
    final bool toDestination = nextStep == null || (nextAction == 'arrive' && next >= instructions.length - 1);
    return WalkManeuverInfo(
      icon: Icons.directions_walk_rounded,
      iconKey: 'walk',
      headline: targetStation.isNotEmpty && !toDestination
          ? l10n.plannerWalkTo(distStr, targetStation)
          : l10n.plannerWalkToDestination(distStr),
      subline: upcomingLine.isNotEmpty ? l10n.navWalkThenBoard(upcomingLine) : '',
      fare: upcomingFare,
    );
  }


  /// "Then take ..." after a comma: "50 m, then take ...".
  static String _midSentence(String s, bool isAr) =>
      isAr || s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  static String _station(Map<String, dynamic> step, AppLocalizations l10n) =>
      InstructionFormatter.localized(step, 'station', isAr: l10n.localeName.startsWith('ar')) ?? '';

  static double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lon1 = from.longitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final lon2 = to.longitude * math.pi / 180;
    final dLon = lon2 - lon1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final rad = math.atan2(y, x);
    return (rad * 180 / math.pi + 360) % 360;
  }

  static double _turnAngle(double b1, double b2) {
    double diff = (b2 - b1 + 180) % 360 - 180;
    if (diff < -180) diff += 360;
    return diff;
  }
}
