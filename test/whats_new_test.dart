import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/MainNavigator.dart';
import 'package:guidy_app/widgets/guidy_tour.dart';
import 'package:guidy_app/services/whats_new.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final newest = WhatsNew.entries.first;

  void mockBuild(int build) => PackageInfo.setMockInitialValues(
        appName: 'Guidy', packageName: 'com.guidy.guidy_app', version: '1.2.0',
        buildNumber: '$build', buildSignature: '',
      );

  group('pick', () {
    test('a fresh install sees nothing', () {
      expect(WhatsNew.pick(seenBuild: null, currentBuild: newest.build, freshInstall: true), isNull);
    });

    test('an update from before this feature sees the newest notes', () {
      expect(WhatsNew.pick(seenBuild: null, currentBuild: newest.build, freshInstall: false), newest);
    });

    test('an update past an entry shows it; already on it shows nothing', () {
      expect(WhatsNew.pick(seenBuild: newest.build - 1, currentBuild: newest.build, freshInstall: false), newest);
      expect(WhatsNew.pick(seenBuild: newest.build, currentBuild: newest.build + 1, freshInstall: false), isNull);
    });

    test('notes for a build not shipped yet are not shown', () {
      expect(WhatsNew.pick(seenBuild: 26, currentBuild: 27, freshInstall: false), isNull);
    });

    test('every entry has notes in both languages', () {
      for (final e in WhatsNew.entries) {
        expect(e.en, isNotEmpty);
        expect(e.ar.length, e.en.length);
      }
    });
  });

  group('takeForLaunch', () {
    test('shows once after an update, then not again', () async {
      SharedPreferences.setMockInitialValues({'whats_new_seen_build': newest.build - 1});
      mockBuild(newest.build);
      expect(await WhatsNew.takeForLaunch(freshInstall: false), newest);
      expect(await WhatsNew.takeForLaunch(freshInstall: false), isNull);
    });

    test('a fresh install records its build and stays quiet', () async {
      SharedPreferences.setMockInitialValues({});
      mockBuild(newest.build);
      expect(await WhatsNew.takeForLaunch(freshInstall: true), isNull);
      expect((await SharedPreferences.getInstance()).getInt('whats_new_seen_build'), newest.build);
    });
  });

  group('on launch', () {
    setUp(() => GuidyTour.autoStart = true);
    tearDown(() => GuidyTour.autoStart = false);

    testWidgets('a rider who updated sees the notes once, instead of the tour', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.resetPhysicalSize);
      SharedPreferences.setMockInitialValues({
        'tour_seen_home': true,
        'whats_new_seen_build': newest.build - 1,
      });
      mockBuild(newest.build);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: const MainNavigator(),
      ));
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('whats_new')), findsOneWidget);
      expect(find.text(newest.en.first), findsOneWidget);
      expect(find.byKey(const ValueKey('guidy_tour_card')), findsNothing);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('whats_new')), findsNothing);
    });
  });
}
