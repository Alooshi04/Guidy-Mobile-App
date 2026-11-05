import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/widgets/route_card_skeleton.dart';

// "Find routes" showed only the card silhouettes while it loaded, and the
// map popped in above them afterwards. The map's place is held now.
void main() {
  Widget app(Widget child) => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );

  testWidgets('the loading skeleton holds the map at its size above the cards', (tester) async {
    await tester.pumpWidget(app(const RouteCardSkeletonList(mapHeight: 240)));
    final map = find.byKey(const ValueKey('route-map-skeleton'));
    expect(map, findsOneWidget);
    expect(tester.getSize(map).height, 240);
    expect(tester.getSize(map).width, tester.view.physicalSize.width / tester.view.devicePixelRatio);
    final label = AppLocalizations.of(tester.element(find.byType(Scaffold))).availableRoutes;
    expect(find.text(label), findsOneWidget, reason: 'card silhouettes follow the map');
    expect(tester.getTopLeft(find.text(label)).dy, greaterThan(tester.getBottomLeft(map).dy));
  });

  testWidgets('without a map (showMap off) it is the card silhouettes alone', (tester) async {
    await tester.pumpWidget(app(const RouteCardSkeletonList()));
    expect(find.byKey(const ValueKey('route-map-skeleton')), findsNothing);
  });
}
