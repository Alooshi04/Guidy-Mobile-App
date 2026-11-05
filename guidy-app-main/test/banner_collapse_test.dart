import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/widgets/app_banner_shell.dart';
import 'package:guidy_app/widgets/banner_ad_placeholder.dart';

// No ad could load (here: not a phone, so the SDK is never asked): the slot
// takes no room and the screen keeps the status bar's own padding.
void main() {
  setUp(() => appBannerCollapsed.value = false);
  tearDown(() {
    appBannerEnabled.value = false;
    appBannerCollapsed.value = false;
  });

  testWidgets('an ad that cannot load leaves no blank box and gives the status bar back', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 30);
    tester.view.viewPadding = const FakeViewPadding(top: 30);
    addTearDown(tester.view.reset);
    appBannerEnabled.value = true;
    EdgeInsets? seen;
    await tester.pumpWidget(MaterialApp(
      builder: (context, page) => AppBannerShell(child: page!),
      home: Builder(builder: (context) {
        seen = MediaQuery.of(context).padding;
        return const Scaffold(body: SizedBox.expand());
      }),
    ));
    await tester.pump();
    await tester.pump();

    expect(appBannerCollapsed.value, isTrue);
    expect(tester.getSize(find.byType(BannerAdPlaceholder)).height, 0);
    expect(seen!.top, 30);
  });
}
