import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/widgets/trip/trip_sheets.dart';

Future<T?> openSheet<T>(WidgetTester tester, Future<T?> Function(BuildContext) show, String tap) async {
  late Future<T?> result;
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(onPressed: () => result = show(context), child: const Text('open')),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(tap));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  testWidgets('switch route: confirming says true, cancel says false', (tester) async {
    expect(await openSheet(tester, (c) => showSwitchRouteSheet(c, minutes: '25 min', fare: 15), en.navSwitchRouteConfirm), isTrue);
    expect(await openSheet(tester, (c) => showSwitchRouteSheet(c, minutes: '25 min', fare: null), en.cancelButton), isFalse);
  });

  testWidgets('live share: stop says true, share again says false', (tester) async {
    expect(await openSheet(tester, showLiveShareActiveSheet, en.shareLiveStop), isTrue);
    expect(await openSheet(tester, showLiveShareActiveSheet, en.shareLiveTooltip), isFalse);
  });
}
