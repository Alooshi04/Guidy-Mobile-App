import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/ride_report_service.dart';
import 'package:guidy_app/widgets/ride_report_sheet.dart';

void main() {
  final t0 = DateTime(2026, 10, 4, 9);

  RideReport report() => RideReport(
        vehicleType: 'microbus',
        fareEgp: 10,
        plannedStep: {'from': 'A', 'to': 'B', 'distance_m': 2600},
        now: t0,
      );

  test('adds up the distance and ignores jitter', () {
    final r = report();
    r.addFix(30.0, 31.0, t0);
    r.addFix(30.00003, 31.0, t0.add(const Duration(seconds: 2))); // ~3 m: jitter
    r.addFix(30.009, 31.0, t0.add(const Duration(minutes: 3))); // ~1 km
    expect(r.distanceM, closeTo(1002, 10));
    expect(r.toPayload()['points'], hasLength(2));
  });

  test('payload the backend expects', () {
    final r = report()
      ..addFix(30.0, 31.0, t0)
      ..addFix(30.009, 31.0, t0.add(const Duration(minutes: 6)));
    r.end(t0.add(const Duration(minutes: 6)));
    final p = r.toPayload();
    expect(p['vehicle_type'], 'microbus');
    expect(p['fare_egp'], 10);
    expect(p['ended_at'] - p['started_at'], 360);
    expect(p['planned_step'], {'from': 'A', 'to': 'B', 'distance_m': 2600});
    expect(p['client_report_id'], isNotEmpty);
  });

  test('sends to /ride_reports', () async {
    late http.Request sent;
    final client = MockClient((req) async {
      sent = req;
      return http.Response('{"success": true}', 200);
    });
    final ok = await RideReportService.send(report()..end(t0), client: client);
    expect(ok, isTrue);
    expect(sent.url.path, endsWith('/ride_reports'));
    expect(jsonDecode(sent.body)['vehicle_type'], 'microbus');
  });

  testWidgets('the sheet returns the vehicle and fare', (tester) async {
    ({String vehicle, num fare})? result;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => TextButton(
          onPressed: () async => result = await showRideReportSheet(ctx),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tuk-tuk'));
    await tester.enterText(find.byType(TextField), '15');
    await tester.pump();
    await tester.tap(find.text('Start recording'));
    await tester.pumpAndSettle();
    expect(result, (vehicle: 'tuktuk', fare: 15));
  });
}
