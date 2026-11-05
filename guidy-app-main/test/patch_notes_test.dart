import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/screens/PatchNotesScreen.dart';
import 'package:guidy_app/screens/SettingsScreen.dart';
import 'package:guidy_app/services/whats_new.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Patch notes: the whole history from one list, the popup unchanged for
// riders who were already getting it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('entries', () {
    test('newest first, one per build, both languages the same length', () {
      final builds = [for (final e in WhatsNew.entries) e.build];
      expect(builds, [...builds]..sort((a, b) => b.compareTo(a)));
      expect(builds.toSet().length, builds.length);
      for (final e in WhatsNew.entries) {
        expect(e.en, isNotEmpty, reason: '${e.build}');
        expect(e.ar.length, e.en.length, reason: '${e.build}');
        expect(DateTime.tryParse(e.date), isNotNull, reason: '${e.build} date');
        expect(e.version, matches(RegExp(r'^\d+\.\d+\.\d+$')));
      }
    });

    test('the popup stays short; the page keeps every note', () {
      final newest = WhatsNew.entries.first;
      expect(newest.build, 30);
      expect(newest.popupNotesFor('en').length, lessThanOrEqualTo(WhatsNew.popupMaxNotes));
      expect(newest.popupNotesFor('en'), newest.en.take(WhatsNew.popupMaxNotes).toList());
      expect(newest.notesFor('en').length, greaterThan(WhatsNew.popupMaxNotes));
      expect(newest.popupNotesFor('ar').length, newest.popupNotesFor('en').length);
    });
  });

  group('the popup behaves as it did before the history was added', () {
    // The list as it was (builds 30, 29, 28 and 26 only), and the rule as it was.
    const legacyBuilds = [30, 29, 28, 26];
    int? legacyPick(int? seen, int current, bool fresh) {
      if (seen == null && fresh) return null;
      for (final b in legacyBuilds) {
        if (b <= current && (seen == null || b > seen)) return b;
      }
      return null;
    }

    test('every combination of seen / current build / fresh install gives the same answer', () {
      for (final fresh in [false, true]) {
        for (final int? seen in [null, for (var s = 1; s <= 32; s++) s]) {
          for (var current = 1; current <= 34; current++) {
            expect(WhatsNew.pick(seenBuild: seen, currentBuild: current, freshInstall: fresh)?.build,
                legacyPick(seen, current, fresh),
                reason: 'seen $seen, current $current, fresh $fresh');
          }
        }
      }
    });

    test('older entries are history only', () {
      for (final e in WhatsNew.entries) {
        expect(e.popup, [30, 29, 28, 26].contains(e.build), reason: '${e.build}');
      }
    });
  });

  group('the page', () {
    Future<void> open(WidgetTester tester, {Locale locale = const Locale('en'), double scale = 1.0}) async {
      tester.view.physicalSize = const Size(720, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: const PatchNotesScreen(currentBuild: 30),
      ));
      await tester.pumpAndSettle();
    }

    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets('lists newest first with version (build), marks the current one (${locale.languageCode})',
          (tester) async {
        await open(tester, locale: locale, scale: 1.3);
        expect(tester.takeException(), isNull);
        final l10n = AppLocalizations.of(tester.element(find.byType(PatchNotesScreen)));
        expect(find.text('1.2.1 (30)'), findsOneWidget);
        expect(find.byKey(const ValueKey('patch_notes_current')), findsOneWidget);
        expect(find.text(l10n.patchNotesCurrent), findsOneWidget);
        final newest = WhatsNew.entries.first.notesFor(locale.languageCode).first;
        expect(find.text(newest), findsOneWidget);
        // Newest above the older ones.
        final y30 = tester.getTopLeft(find.byKey(const ValueKey('patch_notes_30'))).dy;
        await tester.scrollUntilVisible(find.byKey(const ValueKey('patch_notes_29')), 400);
        expect(find.byKey(const ValueKey('patch_notes_29')), findsOneWidget);
        expect(y30, lessThan(tester.getTopLeft(find.byKey(const ValueKey('patch_notes_29'))).dy + 100000));
      });
    }

    testWidgets('a rider on an older build is not marked, and the oldest entry is reachable', (tester) async {
      tester.view.physicalSize = const Size(720, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PatchNotesScreen(currentBuild: 25),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('patch_notes_current')), findsNothing);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('patch_notes_11')), 600);
      expect(find.text('1.0.10 (11)'), findsOneWidget);
    });
  });

  testWidgets('Settings has a Patch notes row that opens the page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'Guidy', packageName: 'com.guidy.guidy_app', version: '1.2.1', buildNumber: '30', buildSignature: '');
    tester.view.physicalSize = const Size(720, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
    ));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('patch-notes-row')), 300);
    await tester.ensureVisible(find.byKey(const ValueKey('patch-notes-row')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('patch-notes-row')));
    await tester.pumpAndSettle();
    expect(find.byType(PatchNotesScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('patch_notes_current')), findsOneWidget);
  });
}
