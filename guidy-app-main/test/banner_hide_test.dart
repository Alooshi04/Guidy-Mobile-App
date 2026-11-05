import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/banner_hide_service.dart';
import 'package:guidy_app/widgets/app_banner_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime now;
  setUp(() {
    now = DateTime(2026, 10, 30, 12);
    SharedPreferences.setMockInitialValues({});
  });

  test('a reward hides the banner for 24 hours and it returns after', () async {
    final s = BannerHideService(clock: () => now);
    expect(s.hidden.value, isFalse);
    await s.hideForDay();
    expect(s.hidden.value, isTrue);
    expect(s.hiddenUntil, DateTime(2026, 10, 31, 12));

    now = DateTime(2026, 10, 31, 11, 59);
    s.refresh();
    expect(s.hidden.value, isTrue);
    now = DateTime(2026, 10, 31, 12, 1);
    s.refresh();
    expect(s.hidden.value, isFalse);
    s.dispose();
  });

  test('survives a restart', () async {
    final a = BannerHideService(clock: () => now);
    await a.hideForDay();
    a.dispose();
    now = DateTime(2026, 10, 30, 20);
    final b = BannerHideService(clock: () => now);
    await b.load();
    expect(b.hidden.value, isTrue);
    b.dispose();
  });

  test('an expired stored time is ignored', () async {
    SharedPreferences.setMockInitialValues({'banner_hidden_until_ms': DateTime(2026, 10, 29).millisecondsSinceEpoch});
    final s = BannerHideService(clock: () => now);
    await s.load();
    expect(s.hidden.value, isFalse);
  });

  test('a stored time more than 24 h away (clock moved) is ignored', () async {
    SharedPreferences.setMockInitialValues({'banner_hidden_until_ms': DateTime(2026, 12, 1).millisecondsSinceEpoch});
    final s = BannerHideService(clock: () => now);
    await s.load();
    expect(s.hidden.value, isFalse);
  });

  testWidgets('the shell builds no banner while hidden', (tester) async {
    appBannerEnabled.value = true;
    addTearDown(() {
      appBannerEnabled.value = false;
      BannerHideService.instance.hidden.value = false;
    });
    BannerHideService.instance.hidden.value = true;
    await tester.pumpWidget(MaterialApp(
      home: AppBannerShell(
        bannerBuilder: (_) => const SizedBox(key: Key('banner'), height: 50),
        child: const SizedBox.expand(),
      ),
    ));
    expect(find.byKey(const Key('banner')), findsNothing);
    BannerHideService.instance.hidden.value = false;
    await tester.pump();
    expect(find.byKey(const Key('banner')), findsOneWidget);
  });
}
