# Trip Guidance, Short-Ride Policy, Ride Logging and Polish — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make live trips advance and read clearly, stop recommending short paid rides, let riders log unlisted rides, and fix five pieces of app polish.

**Architecture:** The app is Flutter (`guidy-app-main`) and the backend is FastAPI plus a RAPTOR engine (`guidy-backend-main`).
- New pure units carry the logic, so it can be tested without a phone:
  - `RouteProgress`: which step the rider is on.
  - `StepCopy`: the card wording.
  - `RideReport`: the ride recording.
  - `CurrentPlaceNamer`: the street name for the rider's position.
  - `ride_reports.py`: the backend review queue.
- `MapScreen` and `raptor_engine.py` only wire these in.

**Tech Stack:** Flutter/Dart (flutter_test, `package:http/testing.dart`), Python 3 (unittest/pytest), FastAPI, pydantic.

**Spec:** `docs/superpowers/specs/2026-10-04-trip-guidance-and-polish-design.md`

## Global Constraints

- Every user-visible string gets keys in both `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb`. Then run `flutter gen-l10n`. Arabic wording is Egyptian colloquial, matching the existing strings.
- Short-walk threshold: `SHORT_HOP_WALK_M = 1500`, with walking distance = straight line × `SHORT_HOP_WALK_DETOUR = 1.25`.
- Walking pace: the engine's `WALK_SPEED_MPS = 1.25`, which is 75 m/min.
- Ride-report vehicle types: `microbus, tuktuk, bus, taxi, other`. Fare must be 0–500 EGP. At most 2000 points.
- Reverse geocoding uses only the free `MapsLinkParser.reverseGeocodeName` (Nominatim). No Places API calls.
- Commit after each task in the repo it touches.
  - End every commit message with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
  - Do not push.
- App tests: `flutter test <file>` from `guidy-app-main`. Backend tests: `python -m pytest <file> -q` from `guidy-backend-main`.

---

## Batch A — app polish

### Task 1: Tool rail column on the screen edge

**Files:**
- Modify: `lib/widgets/guidy_tool_rail.dart`
- Test: `test/redesign_review_fixes_test.dart` (group `tool rail`)

**Interfaces:**
- No public API change. `GuidyToolRail(lead:, items:, showTooltip:, hideTooltip:)` stays the same.

- [ ] **Step 1: Write the failing tests.** Add them inside `group('tool rail', ...)` after `lays out in Arabic too`:

```dart
    testWidgets('the tools stack under the menu tab, on the screen edge', (tester) async {
      await tester.pumpWidget(rail([]));
      final menuX = tester.getCenter(find.byTooltip('Hide tools')).dx;
      final calcX = tester.getCenter(find.byTooltip('Calculator')).dx;
      final leadX = tester.getCenter(find.byTooltip('Overview')).dx;
      expect(calcX, moreOrLessEquals(menuX, epsilon: 0.5));
      expect(calcX, greaterThan(leadX), reason: 'LTR: the edge is on the right');
    });

    testWidgets('mirrors in Arabic: tools under the menu on the left edge', (tester) async {
      await tester.pumpWidget(rail([], locale: const Locale('ar')));
      final menuX = tester.getCenter(find.byTooltip('Hide tools')).dx;
      final calcX = tester.getCenter(find.byTooltip('Calculator')).dx;
      final leadX = tester.getCenter(find.byTooltip('Overview')).dx;
      expect(calcX, moreOrLessEquals(menuX, epsilon: 0.5));
      expect(calcX, lessThan(leadX));
    });
```

- [ ] **Step 2: Run and see them fail.** Run `flutter test test/redesign_review_fixes_test.dart --plain-name "tool rail"`. Expected: the two new tests FAIL, because `calcX` equals `leadX`, not `menuX`.

- [ ] **Step 3: Implement.** In `_GuidyToolRailState`:
  - Replace the constants with:

```dart
  // The menu tab and the column under it keep every button a 44dp tap
  // target; the lead button beside the tab is a little narrower.
  static const double _colW = 44;
  static const double _leadW = 40;
  static const double _rowH = 42;
  static const double _tabH = 46;
  static const double _bottomPad = 6;
```

  - In `build`:
    - The menu `_RailButton` uses `width: _colW`.
    - The folded `SizedBox` and painter size become `Size(_colW, _tabH)`.
    - The open state has width `_leadW + _colW`.
    - The `Stack` children become:

```dart
              PositionedDirectional(start: 0, top: 0, child: _RailButton(item: widget.lead, width: _leadW, height: _tabH)),
              PositionedDirectional(start: _leadW, top: 0, child: menu),
              for (var i = 0; i < widget.items.length; i++)
                PositionedDirectional(
                  start: _leadW,
                  top: _tabH + i * _rowH,
                  child: _RailButton(item: widget.items[i], width: _colW, height: _rowH),
                ),
```

  - Update the class doc to say the column runs down under the menu tab, on the screen-edge side.
  - In `_RailPainter._shape`, replace the open-state path with this one. It draws the lead on the left, and the menu plus column on the right:

```dart
    const leadW = _GuidyToolRailState._leadW;
    const tabH = _GuidyToolRailState._tabH;
    final w = size.width;
    final h = size.height;
    // Drawn left-to-right: lead button on the left, the menu tab and the
    // column under it on the right (the screen edge).
    return Path()
      ..moveTo(_r, 0)
      ..lineTo(w - _r, 0)
      ..arcToPoint(Offset(w, _r), radius: const Radius.circular(_r))
      ..lineTo(w, h - _r)
      ..arcToPoint(Offset(w - _r, h), radius: const Radius.circular(_r))
      ..lineTo(leadW + _r, h)
      ..arcToPoint(Offset(leadW, h - _r), radius: const Radius.circular(_r))
      ..lineTo(leadW, tabH + _fillet)
      ..arcToPoint(Offset(leadW - _fillet, tabH), radius: const Radius.circular(_fillet), clockwise: false)
      ..lineTo(_r, tabH)
      ..arcToPoint(Offset(0, tabH - _r), radius: const Radius.circular(_r))
      ..lineTo(0, _r)
      ..arcToPoint(const Offset(_r, 0), radius: const Radius.circular(_r))
      ..close();
```

- [ ] **Step 4: Run.** Run `flutter test test/redesign_review_fixes_test.dart`. Expected: all PASS, including `runs its tools and folds into the menu tab`.

- [ ] **Step 5: Commit.** Run `git add lib/widgets/guidy_tool_rail.dart test/redesign_review_fixes_test.dart && git commit -m "Tool rail: tools stack under the menu tab on the screen edge"` (with the trailer).

### Task 2: No intro cards on first launch

**Files:**
- Modify: `lib/main.dart:133-218`
- Delete: `lib/screens/OnboardingScreen.dart`
- Test: `test/widget_test.dart`

- [ ] **Step 1: Write the failing test.** In `test/widget_test.dart`:
  - Change the test name to `'GuidyApp shows the splash, then goes straight to the app'`.
  - Replace the `OnboardingScreen` import with `import 'package:guidy_app/screens/AuthGate.dart';`.
  - Change the final expectation to:

```dart
    // No intro carousel: straight from the splash into the app.
    expect(find.byType(AuthGate), findsOneWidget);
```

- [ ] **Step 2: Run and see it fail.** Run `flutter test test/widget_test.dart`. Expected: FAIL. AuthGate is not found, because OnboardingScreen is shown.

- [ ] **Step 3: Implement.** In `lib/main.dart`:
  - Remove the `OnboardingScreen` import.
  - Replace `_startDeferredServices`' notification block. Tracking is asked first, then notifications, because iOS can't show two system prompts at once:

```dart
  await TrackingService.requestAuthorization();
  if (isFirebaseReady) {
    try {
      await NotificationService.initialize();
    } catch (e) {
      debugPrint('Notification setup error: $e');
    }
  }
  try {
    await MobileAds.instance.initialize();
```

  - Keep the rest of the function as it is: the `MobileAds` catch and the AppOpenAdService init.
  - Update the doc comment: *"Order matters on iOS: it cannot show two system permission dialogs at once, and App Tracking Transparency has to be answered before the ads SDK starts -- so tracking, then notifications, then ads."*
  - Replace `StartupGate`:

```dart
/// Holds the launch animation for its full length, then opens the app.
/// (There used to be a three-card intro carousel here on first launch.)
class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  // Created once, in initState: GuidyApp rebuilds on every locale or theme
  // change, and a future built in build() would replay the splash each time.
  late final Future<void> _splash = Future<void>.delayed(AnimatedSplash.duration);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _splash,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const AnimatedSplash();
        if (!appBannerEnabled.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) => appBannerEnabled.value = true);
        }
        return const AuthGate();
      },
    );
  }
}
```

  - Fix the comment at `main.dart:252` to say `StartupGate holds the splash, then AuthGate ...`.
  - If `SharedPreferences` is now unused in `main.dart`, remove its import.
  - Delete `lib/screens/OnboardingScreen.dart`.
  - Fix the comment in `lib/widgets/animated_splash.dart:5` to read "shown while StartupGate holds the launch".
  - Run `grep -rn "OnboardingScreen" lib test`. Expected: no hits.

- [ ] **Step 4: Run.** Run `flutter test test/widget_test.dart` and expect PASS. Then run `flutter analyze lib/main.dart` and expect no issues.

- [ ] **Step 5: Commit.** Commit with the message "Launch: splash straight into the app, no intro cards".

### Task 3: Settings always opens at the top

**Files:**
- Modify: `lib/screens/MainNavigator.dart`, `lib/screens/SettingsScreen.dart:17-20,236`
- Test: `test/main_navigator_test.dart`

**Interfaces:**
- Produces: `SettingsScreen({Key? key, VoidCallback? onGoHome, ScrollController? scrollController})`.

- [ ] **Step 1: Write the failing test.** Add it inside the existing group in `test/main_navigator_test.dart`:

```dart
    testWidgets('Settings opens scrolled to the top every time', (tester) async {
      tester.view.physicalSize = const Size(400 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildNavigator());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
      await tester.pumpAndSettle();

      final settingsList = find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first;
      await tester.drag(settingsList, const Offset(0, -600));
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(settingsList).position.pixels, greaterThan(0));

      await tester.tap(find.widgetWithText(NavigationDestination, 'Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(NavigationDestination, 'Settings'));
      await tester.pumpAndSettle();
      expect(tester.state<ScrollableState>(settingsList).position.pixels, 0);
    });
```

- [ ] **Step 2: Run and see it fail.** Run `flutter test test/main_navigator_test.dart`. Expected: the new test FAILS on the last expect, because pixels stay at about 600.

- [ ] **Step 3: Implement.**
  - In `SettingsScreen`, add the field `final ScrollController? scrollController;`. Change the constructor to `const SettingsScreen({super.key, this.onGoHome, this.scrollController});`. Change `body: ListView(` to `body: ListView(controller: widget.scrollController,`.
  - In `_MainNavigatorState`:
    - Add `final ScrollController _settingsScroll = ScrollController();`.
    - In `dispose`, add `_settingsScroll.dispose();`.
    - Pass `SettingsScreen(onGoHome: _goToHome, scrollController: _settingsScroll)`.
    - Change `_onTabNotification`:

```dart
  void _onTabNotification() {
    final index = MainNavigator.activeTabNotifier.value;
    // Settings sits in the IndexedStack and keeps its scroll; it should
    // open at the top each time it's chosen.
    if (index == 4 && _settingsScroll.hasClients) _settingsScroll.jumpTo(0);
    if (mounted && _selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
  }
```

- [ ] **Step 4: Run.** Run `flutter test test/main_navigator_test.dart test/settings_screen_test.dart`. Expected: all PASS.

- [ ] **Step 5: Commit.** Commit with the message "Settings opens at the top every time".

### Task 4: Release builds serve test ads unless told otherwise

**Files:**
- Modify: `build_release.ps1:1-20,67-78`, `build_release.bat:2-3`, `HANDOFF.md` (the ads line)

- [ ] **Step 1: Implement.**
  - In `build_release.ps1`, change the header usage block to:

```powershell
#   .\build_release.ps1                      Play Store build with Google's TEST
#                                            ad units (the default for now: safe
#                                            to tap, earns nothing)
#   .\build_release.ps1 -RealAds             Play Store build with the real
#                                            AdMob units from secrets.properties
#   .\build_release.ps1 -Install             also install it on a USB phone
```

  - Change the param block to:

```powershell
param(
    [switch]$RealAds,
    # Kept so older callers (install_release_on_phone.bat) still work;
    # test ads are the default now.
    [switch]$TestAds,
    [switch]$Install
)
$TestAds = -not $RealAds
```

  - Leave the existing `if ($TestAds) { ... } else { ... }` block unchanged.
  - In `build_release.bat`, change the comment to: `REM Double-click: Play Store build with TEST ads. Real ads: "build_release.bat -RealAds".`
  - In `HANDOFF.md`, add one line under known issues: `Release builds use Google's test ad units by default (build_release.ps1); build with -RealAds to earn revenue.`

- [ ] **Step 2: Verify the script parses.** Run `powershell -NoProfile -Command "$null = [System.Management.Automation.Language.Parser]::ParseFile('build_release.ps1', [ref]$null, [ref]$e); $e.Count"`. Expected: `0`.

- [ ] **Step 3: Commit.** Commit with the message "Release builds serve test ads by default (-RealAds for real ones)".

### Task 5: Street or place name instead of "Current location"

**Files:**
- Create: `lib/services/current_place_namer.dart`
- Modify: `lib/screens/LocationSearchScreen.dart:70,259-275`, `lib/screens/HomeScreen.dart:100-104,157`, `lib/screens/CommuteBudgetScreen.dart:46-65`
- Test: `test/current_place_namer_test.dart`, `test/location_search_screen_test.dart`

**Interfaces:**
- Produces:
  - `CurrentPlaceNamer.place({required double lat, required double lon, required String fallbackLabel}) → Map<String,dynamic>`, with `'is_current': true`.
  - `CurrentPlaceNamer.isCurrent(Map?) → bool`.
  - `CurrentPlaceNamer.named(Map<String,dynamic> place, {required String lang}) → Future<Map<String,dynamic>>`.
  - `static PlaceNameResolver resolve`, which tests can override.

- [ ] **Step 1: Write the failing unit test** `test/current_place_namer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/services/current_place_namer.dart';
import 'package:guidy_app/services/maps_link_parser.dart';

void main() {
  tearDown(() => CurrentPlaceNamer.resolve = MapsLinkParser.reverseGeocodeName);

  test('a current-location place is flagged and named after the street, in the asked language', () async {
    String? askedLang;
    CurrentPlaceNamer.resolve = (lat, lon, {required fallbackLabel, lang = 'en'}) async {
      askedLang = lang;
      return 'شارع مصطفى النحاس';
    };
    final p = CurrentPlaceNamer.place(lat: 30.06, lon: 31.379, fallbackLabel: 'موقعي الحالي');
    expect(CurrentPlaceNamer.isCurrent(p), isTrue);
    final named = await CurrentPlaceNamer.named(p, lang: 'ar');
    expect(named['name'], 'شارع مصطفى النحاس');
    expect(named['lat'], 30.06);
    expect(CurrentPlaceNamer.isCurrent(named), isTrue);
    expect(askedLang, 'ar');
  });

  test('a failed lookup keeps the generic label', () async {
    CurrentPlaceNamer.resolve = (lat, lon, {required fallbackLabel, lang = 'en'}) async => throw Exception('offline');
    final p = CurrentPlaceNamer.place(lat: 30.0, lon: 31.0, fallbackLabel: 'My Current Location');
    expect((await CurrentPlaceNamer.named(p, lang: 'en'))['name'], 'My Current Location');
  });

  test('a chosen place is not a current location', () {
    expect(CurrentPlaceNamer.isCurrent({'name': 'Tahrir', 'lat': 30.0, 'lon': 31.0}), isFalse);
  });
}
```

- [ ] **Step 2: Run and see it fail.** Run `flutter test test/current_place_namer_test.dart`. Expected: FAIL, because the URI doesn't exist.

- [ ] **Step 3: Implement** `lib/services/current_place_namer.dart`:

```dart
import 'maps_link_parser.dart';

typedef PlaceNameResolver = Future<String> Function(
  double lat,
  double lon, {
  required String fallbackLabel,
  String lang,
});

/// "My current location" as the street or place the rider is at, in the
/// app's language ("Mostafa El Nahas St." / "شارع مصطفى النحاس"). Uses the
/// free reverse geocode MapsLinkParser already has (cached, Nominatim).
///
/// The place map carries `is_current: true` so screens know it's the
/// rider's own position without comparing label text.
class CurrentPlaceNamer {
  CurrentPlaceNamer._();

  static const String flag = 'is_current';

  /// Swappable for tests.
  static PlaceNameResolver resolve = MapsLinkParser.reverseGeocodeName;

  static Map<String, dynamic> place({required double lat, required double lon, required String fallbackLabel}) =>
      {'name': fallbackLabel, 'lat': lat, 'lon': lon, flag: true};

  static bool isCurrent(Map<dynamic, dynamic>? place) => place != null && place[flag] == true;

  /// [place] renamed after what is there; unchanged if the lookup fails.
  static Future<Map<String, dynamic>> named(Map<String, dynamic> place, {required String lang}) async {
    final lat = place['lat'], lon = place['lon'];
    if (lat is! num || lon is! num) return place;
    final fallback = (place['name'] ?? '').toString();
    try {
      final name = (await resolve(lat.toDouble(), lon.toDouble(), fallbackLabel: fallback, lang: lang)).trim();
      if (name.isEmpty || name == fallback) return place;
      return {...place, 'name': name};
    } catch (_) {
      return place;
    }
  }
}
```

- [ ] **Step 4: Run.** Run `flutter test test/current_place_namer_test.dart`. Expected: PASS.

- [ ] **Step 5: Write the failing screen test.** Add this to `test/location_search_screen_test.dart`, with the import `package:guidy_app/services/current_place_namer.dart` and the import of `maps_link_parser.dart`:

```dart
    testWidgets('a current-location start shows the street name', (tester) async {
      CurrentPlaceNamer.resolve = (lat, lon, {required fallbackLabel, lang = 'en'}) async => 'Mostafa El Nahas St.';
      addTearDown(() => CurrentPlaceNamer.resolve = MapsLinkParser.reverseGeocodeName);
      await tester.pumpWidget(buildSearchScreen(
        initialStart: CurrentPlaceNamer.place(lat: 30.06, lon: 31.379, fallbackLabel: 'My Current Location'),
      ));
      await tester.pump();
      await tester.pump();
      expect(find.text('Mostafa El Nahas St.'), findsOneWidget);
      expect(find.text('My Current Location'), findsNothing);
    });
```

- [ ] **Step 6: Run and see it fail.** Run `flutter test test/location_search_screen_test.dart`. Expected: the new test FAILS.

- [ ] **Step 7: Implement in the screens.**
  - `LocationSearchScreen`:
    - Import `../services/current_place_namer.dart` and `../services/locale_controller.dart` (if it isn't imported already).
    - After `_selectedStart = widget.initialStartLocation;`, add `_nameCurrentStart();`.
    - Add the method:

```dart
  /// A "current location" start, renamed to the street the rider is on.
  Future<void> _nameCurrentStart() async {
    final start = _selectedStart;
    if (!CurrentPlaceNamer.isCurrent(start)) return;
    final named = await CurrentPlaceNamer.named(start!, lang: localeController.isArabic ? 'ar' : 'en');
    if (!mounted || !identical(_selectedStart, start)) return;
    setState(() => _selectedStart = named);
  }
```

    - In `_fetchCurrentLocationForStart`, set `_selectedStart = CurrentPlaceNamer.place(lat: position.latitude, lon: position.longitude, fallbackLabel: l10n.myCurrentLocation);`. After `_maybePrefetchRoute();`, add `_nameCurrentStart();`.
  - `HomeScreen`: both places that build the current-location map (`:100` and `:157`) use `CurrentPlaceNamer.place(lat: position.latitude, lon: position.longitude, fallbackLabel: l10n.myCurrentLocation)`. At `:100`, use `_l10n?.myCurrentLocation ?? 'Current Location'`.
  - `CommuteBudgetScreen._routeToOffice`: after the position is known (after the try/catch that sets `startLat`/`startLon`), add:

```dart
    startName = (await CurrentPlaceNamer.named(
      CurrentPlaceNamer.place(lat: startLat, lon: startLon, fallbackLabel: startName),
      lang: isArabic ? 'ar' : 'en',
    ))['name'] as String;
    if (!mounted) return;
```

    Only add the `mounted` check if the method doesn't already check it at that point.

- [ ] **Step 8: Run.** Run `flutter test test/current_place_namer_test.dart test/location_search_screen_test.dart test/commute_budget_screen_test.dart test/main_navigator_test.dart`. Expected: all PASS.

- [ ] **Step 9: Commit.** Commit with the message "Start shows the street you're on instead of 'Current location'".

---

## Batch B — live trip

### Task 6: `RouteProgress` — which step the rider is on

**Files:**
- Create: `lib/utils/route_progress.dart`
- Test: `test/route_progress_test.dart`

**Interfaces:**
- Produces:
  - `RouteProgress(List<LatLng> route, List<LatLng?> stepPoints)`
  - `int stepAt(LatLng here, int current)`
  - `double? metersToStep(LatLng here, int current, int target)`
  - `double get totalM`
  - `static const double maxOffRouteM = 60`
  - `static const double passedSlackM = 25`

- [ ] **Step 1: Write the failing test** `test/route_progress_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:guidy_app/utils/route_progress.dart';

// A straight 3 km road north from (30.0, 31.0); 0.001 deg lat ~ 111 m.
List<LatLng> road() => [for (var i = 0; i <= 27; i++) LatLng(30.0 + i * 0.001, 31.0)];
LatLng at(double km, {double eastM = 0}) => LatLng(30.0 + km * 1000 / 111320, 31.0 + eastM / (111320 * 0.866));

void main() {
  // walk_to_station (start), board (0.3 km), walk_to_transfer (1.5 km), transfer (1.7 km), arrive (2.8 km)
  final steps = <LatLng?>[at(0), at(0.3), at(1.5), at(1.7), at(2.8)];

  test('moves on when a stop was passed far to the side of its point', () {
    final p = RouteProgress(road(), steps);
    // On the road 150 m past the transfer point, never within 100 m of it.
    expect(p.stepAt(at(1.65), 1), 2);
  });

  test('skips several steps at once after riding straight past them', () {
    final p = RouteProgress(road(), steps);
    expect(p.stepAt(at(2.0), 1), 3);
  });

  test('stays put when off the route (GPS jump)', () {
    final p = RouteProgress(road(), steps);
    expect(p.stepAt(at(2.0, eastM: 400), 1), 1);
  });

  test('never goes backwards', () {
    final p = RouteProgress(road(), steps);
    expect(p.stepAt(at(0.2), 3), 3);
  });

  test('does not move on before reaching the step', () {
    final p = RouteProgress(road(), steps);
    expect(p.stepAt(at(1.4), 1), 1);
  });

  test('a route that doubles back matches the first pass, not the return', () {
    final out = [for (var i = 0; i <= 10; i++) LatLng(30.0 + i * 0.001, 31.0)];
    final back = [for (var i = 10; i >= 0; i--) LatLng(30.0 + i * 0.001, 31.0003)]; // ~30 m east
    final p = RouteProgress([...out, ...back], [out.first, out[5], back[5]]);
    // At out[3]: the return leg passes 30 m away, but the rider is on step 0.
    expect(p.stepAt(out[3], 0), 0);
  });

  test('metres left to a step', () {
    final p = RouteProgress(road(), steps);
    expect(p.metersToStep(at(1.0), 1, 2), closeTo(500, 15));
    expect(p.metersToStep(at(1.0, eastM: 400), 1, 2), isNull);
  });
}
```

- [ ] **Step 2: Run and see it fail.** Run `flutter test test/route_progress_test.dart`. Expected: FAIL, because the URI doesn't exist.

- [ ] **Step 3: Implement** `lib/utils/route_progress.dart`:

```dart
import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'nav_math.dart';

/// Where the rider is along the drawn route, and so which step they're on.
///
/// Navigation used to move on only within 100 m of the next step's exact
/// point, and only one step at a time: a stop passed 150 m to the side, or
/// two steps passed between fixes, left the trip stuck. Here every step is
/// a distance along the route, and the rider is too.
class RouteProgress {
  RouteProgress(this.route, List<LatLng?> stepPoints) : _cum = _cumulative(route) {
    var floor = 0.0;
    for (final p in stepPoints) {
      final hit = p == null ? null : _project(p, floor);
      _stepAlong.add(hit?.along);
      if (hit != null) floor = hit.along;
    }
  }

  final List<LatLng> route;
  final List<double> _cum;
  final List<double?> _stepAlong = [];

  /// Further than this from the line, a fix says nothing about progress.
  static const double maxOffRouteM = 60;

  /// A step counts as reached this close before its point.
  static const double passedSlackM = 25;

  /// How far behind the current step a fix may still match.
  static const double _backtrackM = 50;

  double get totalM => _cum.isEmpty ? 0 : _cum.last;

  static List<double> _cumulative(List<LatLng> r) {
    final out = <double>[];
    for (var i = 0; i < r.length; i++) {
      out.add(i == 0 ? 0 : out[i - 1] + NavMath.distanceM(r[i - 1], r[i]));
    }
    return out;
  }

  /// The first stretch of route at or after [minAlong] that passes within
  /// [maxOffRouteM] of [p]: the closest point on it. Taking the FIRST such
  /// stretch, not the closest on the whole route, keeps a route that comes
  /// back along the same road from matching its return leg.
  ({double along, double off})? _project(LatLng p, double minAlong) {
    if (route.length < 2) return null;
    const mPerDeg = 111320.0;
    final cosLat = math.cos(p.latitude * math.pi / 180);
    ({double along, double off})? best;
    for (var i = 0; i < route.length - 1; i++) {
      if (_cum[i + 1] < minAlong) continue;
      final a = route[i], b = route[i + 1];
      final ax = (a.longitude - p.longitude) * mPerDeg * cosLat, ay = (a.latitude - p.latitude) * mPerDeg;
      final dx = (b.longitude - a.longitude) * mPerDeg * cosLat, dy = (b.latitude - a.latitude) * mPerDeg;
      final len2 = dx * dx + dy * dy;
      final segLen = _cum[i + 1] - _cum[i];
      var t = len2 == 0 ? 0.0 : (-(ax * dx + ay * dy) / len2).clamp(0.0, 1.0);
      if (segLen > 0 && _cum[i] + t * segLen < minAlong) t = ((minAlong - _cum[i]) / segLen).clamp(0.0, 1.0);
      final x = ax + t * dx, y = ay + t * dy;
      final off = math.sqrt(x * x + y * y);
      if (off <= maxOffRouteM) {
        if (best == null || off < best.off) best = (along: _cum[i] + t * segLen, off: off);
      } else if (best != null) {
        break; // left the first matching stretch
      }
    }
    return best;
  }

  ({double along, double off})? _rider(LatLng here, int current) {
    final from = (current < _stepAlong.length ? _stepAlong[current] : null) ?? 0;
    return _project(here, math.max(0, from - _backtrackM));
  }

  /// The furthest step the rider has reached; [current] if the fix is off
  /// the route. Never earlier than [current].
  int stepAt(LatLng here, int current) {
    final hit = _rider(here, current);
    if (hit == null) return current;
    var step = current;
    for (var k = current + 1; k < _stepAlong.length; k++) {
      final s = _stepAlong[k];
      if (s != null && s <= hit.along + passedSlackM) step = k;
    }
    return step;
  }

  /// Metres along the route from [here] to step [target] (the route's end
  /// for a target past the last step); null off the route.
  double? metersToStep(LatLng here, int current, int target) {
    final hit = _rider(here, current);
    if (hit == null) return null;
    final s = target < _stepAlong.length ? _stepAlong[target] : totalM;
    if (s == null) return null;
    return math.max(0, s - hit.along);
  }
}
```

- [ ] **Step 4: Run.** Run `flutter test test/route_progress_test.dart`. Expected: PASS. If `doubles back` fails, check that the `break` only fires after a hit.

- [ ] **Step 5: Commit.** Commit with the message "RouteProgress: the step the rider is on, from distance along the route".

### Task 7: MapScreen advances with `RouteProgress`

**Files:**
- Modify: `lib/screens/MapScreen.dart` (fields near `:110`, `_parsePathData` `:385-411`, `_checkIfApproachingNextStep` `:1494-1534`, `_switchToAlternativeVehicle` `:2962-2968`)
- Test: `test/maneuver_navigation_test.dart`, `test/trip_back_navigation_test.dart` (regression only)

**Interfaces:**
- Consumes: `RouteProgress` from Task 6.
- Produces:
  - `RouteProgress? _progress` (private; Task 9 reads it).
  - `void _advanceTo(int target)`.

- [ ] **Step 1: Implement.** Add the import `../utils/route_progress.dart`. Add these fields next to `_stepPoints`:

```dart
  /// Distance-along-route view of the trip (see RouteProgress). Rebuilt
  /// when a step's point moves (a vehicle switch).
  RouteProgress? _progress;

  /// A step RouteProgress says the rider has reached, and how many fixes
  /// in a row have said so: two, so one GPS jump can't skip a step.
  int? _progressCandidate;
  int _progressVotes = 0;
```

  - At the end of `_parsePathData` (after `_addAlternativePolylines();`), add `_progress = RouteProgress(List.of(_allPoints), List.of(_stepPoints));`.
  - In `_switchToAlternativeVehicle`, after `_stepPoints[stepIndex] = ...;`, add `_progress = RouteProgress(List.of(_allPoints), List.of(_stepPoints));`.
  - Replace the block in `_checkIfApproachingNextStep` from `if (distance < 100) {` to the end of the method with:

```dart
    if (distance < 100) {
      _distanceToNextStop.value = station.isNotEmpty ? l10n.arrivingAt(station) : l10n.youHaveArrived;
      _advanceTo(next);
      return;
    }

    // Not near the next step's point -- but the rider may have passed it to
    // the side, or passed several steps between fixes.
    final reached = _progress?.stepAt(here, _currentStepIndex) ?? _currentStepIndex;
    if (reached > _currentStepIndex) {
      _progressVotes = reached == _progressCandidate ? _progressVotes + 1 : 1;
      _progressCandidate = reached;
      if (_progressVotes >= 2) {
        _advanceTo(reached);
        return;
      }
    } else {
      _progressCandidate = null;
      _progressVotes = 0;
    }
    _updateDistanceDisplay();
  }

  /// Moves navigation on to [target], recording every step passed on the way.
  void _advanceTo(int target) {
    if (target <= _currentStepIndex || target >= _instructions.length) return;
    _stopAlarmTriggeredForCurrent = false;
    _progressCandidate = null;
    _progressVotes = 0;
    if (mounted) {
      final from = _currentStepIndex;
      setState(() {
        _currentStepIndex = target;
        _upcomingAlarmStation = null;
      });
      for (var s = from + 1; s <= target; s++) {
        _recorder.onStep(s, _instructions[s]);
      }
      AnalyticsService.setCrashlyticsKey('active_step', target);
      AnalyticsService.logBreadcrumb('MapScreen: Advanced to step $target');
    }
    _syncLiveTrackingForCurrentStep();
    final p = target < _stepPoints.length ? _stepPoints[target] : null;
    if (p != null && !_followMode) _moveCamera(CameraUpdate.newLatLngZoom(p, 16.0));
    _updateDistanceDisplay();
  }
```

  - Keep `final int next = _currentStepIndex + 1; ... if (target == null) return;` above the block. Remove that early `return`, so a step without coordinates still lets RouteProgress move on. Do that by guarding instead:

```dart
    final int next = _currentStepIndex + 1;
    final LatLng? target = next < _stepPoints.length ? _stepPoints[next] : null;
    final String station = _stationOf(_instructions[next], _isArabicNow);
    final double distance = target == null
        ? double.infinity
        : Geolocator.distanceBetween(here.latitude, here.longitude, target.latitude, target.longitude);
```

  - Leave the stop-alarm block as it is. Its `distance <= 150` test is false for `infinity`.

- [ ] **Step 2: Analyze and run the navigation tests.** Run `flutter analyze lib/screens/MapScreen.dart`, then `flutter test test/maneuver_navigation_test.dart test/trip_back_navigation_test.dart test/navigation_step_advancement_test.dart test/route_chooser_and_nav_cleanup_test.dart`. Expected: no issues, all PASS.

- [ ] **Step 3: Commit.** Commit with the message "Trips move on when a stop is passed to the side or skipped".

### Task 8: Backend — get-off station, ride time, stop count, walk minutes

**Files:**
- Modify: `guidy-backend-main/raptor_engine.py` (`_build_option_data` `:4031-4525`)
- Test: `guidy-backend-main/test_step_annotations.py`

**Interfaces:**
- Produces, on every `board`/`transfer` instruction with a `route_id`:
  - `alight_station`, `alight_station_en`, `alight_station_ar`
  - `alight_lat`, `alight_lon`
  - `ride_m` (int), `ride_min` (int ≥ 1, traffic included), `stops_count` (int ≥ 1)
- Produces, on every walk instruction with a distance: `walk_min` (int ≥ 1).

- [ ] **Step 1: Write the failing test** `test_step_annotations.py`:

```python
"""Ride steps say where to get off, how long the ride is and how many
stops; walk steps say how long the walk is (the app's trip cards)."""
from test_routing_engine import GuidyEngineTestCase

TRIPS = [
    (30.0745, 31.3035, 30.0600, 31.3790),   # Fair Zone -> Salsa Koshary
    (30.0600, 31.3790, 29.8686, 31.3155),   # Salsa Koshary -> Helwan University
]
WALKS = ('walk_to_station', 'walk_to_destination', 'walk_to_transfer', 'continue_walk')


class TestStepAnnotations(GuidyEngineTestCase):
    def test_rides_and_walks_are_annotated(self):
        seen_ride = False
        for trip in TRIPS:
            for o in self.route(*trip).get('options', []):
                steps = o['instructions']
                for k, s in enumerate(steps):
                    if s['action'] in ('board', 'transfer') and s.get('route_id'):
                        seen_ride = True
                        nxt = steps[k + 1]
                        self.assertEqual(s['alight_station'], nxt.get('station'))
                        self.assertEqual(s['alight_station_en'], nxt.get('station_en'))
                        self.assertEqual((s['alight_lat'], s['alight_lon']), (nxt['lat'], nxt['lon']))
                        self.assertGreaterEqual(s['ride_min'], 1)
                        self.assertGreaterEqual(s['stops_count'], 1)
                        self.assertGreater(s['ride_m'], 0)
                    if s['action'] in WALKS and (s.get('distance_m') or 0) > 0:
                        self.assertGreaterEqual(s['walk_min'], 1)
        self.assertTrue(seen_ride)

    def test_walk_minutes_use_walking_pace(self):
        for o in self.route(*TRIPS[0]).get('options', []):
            for s in o['instructions']:
                if s.get('walk_min') and s.get('distance_m', 0) >= 300:
                    self.assertAlmostEqual(s['walk_min'], s['distance_m'] / 75, delta=1.01)
```

- [ ] **Step 2: Run and see it fail.** Run `python -m pytest test_step_annotations.py -q`. Expected: FAIL with `KeyError: 'alight_station'`.

- [ ] **Step 3: Implement.**
  - In `_build_option_data`, after `current_leg_wait_sec = 0.0`, add:

```python
        current_leg_ride_sec = 0.0
        current_leg_hops = 0
```

  - Add the helper method next to `_tidy_instructions`:

```python
    @staticmethod
    def _close_leg(instr, distance_m, ride_sec, hops):
        """What the trip card says about a ride: its length, its time
        (traffic included, as the trip total) and how many stops it rides."""
        instr["ride_m"] = round(distance_m)
        instr["ride_min"] = max(1, round(ride_sec / 60))
        instr["stops_count"] = max(1, hops)

    def _annotate_steps(self, instructions):
        """A ride step names where to get off -- the station of the step
        after it (the change, the walk that starts there, or the arrival).
        Riders were told to board minibus 66, then "walk to transfer", with
        nothing in between saying where to get off. Walk steps get minutes
        at walking pace."""
        for k, inst in enumerate(instructions):
            a = inst.get("action")
            if a in ("board", "transfer") and inst.get("route_id") and k + 1 < len(instructions):
                nxt = instructions[k + 1]
                for sfx in ("", "_en", "_ar"):
                    inst["alight_station" + sfx] = nxt.get("station" + sfx)
                inst["alight_lat"], inst["alight_lon"] = nxt.get("lat"), nxt.get("lon")
            if a in self._WALK_ACTIONS and (inst.get("distance_m") or 0) > 0:
                inst["walk_min"] = max(1, math.ceil(inst["distance_m"] / self.WALK_SPEED_MPS / 60))
        return instructions
```

  - In the two places that close a leg (`if current_leg_instruction is not None and current_route not in (None, "WALK"):` inside the loop, and the one after it), add as the first line inside the `if`:

```python
                    self._close_leg(current_leg_instruction, current_leg_distance_m,
                                    current_leg_ride_sec, current_leg_hops)
```

    Use matching indentation for the one after the loop.
  - Where `current_leg_distance_m = 0` is reset, add `current_leg_ride_sec = 0.0` and `current_leg_hops = 0`.
  - In the per-hop block `if route not in (None, "WALK"):` that adds `current_leg_distance_m += hop_dist`, add `current_leg_ride_sec += edge_time` and `current_leg_hops += 1`.
  - In the return dict, change `"instructions": self._with_line_names_in_both(self._tidy_instructions(instructions)),` to `"instructions": self._with_line_names_in_both(self._annotate_steps(self._tidy_instructions(instructions))),`.

- [ ] **Step 4: Run.** Run `python -m pytest test_step_annotations.py test_short_hops.py test_recommended_consistency.py -q`. Expected: all PASS.

- [ ] **Step 5: Commit (backend repo).** Commit with the message "Ride steps carry get-off station, ride time and stops; walks carry minutes".

### Task 9: App — clear step cards and live ETAs

**Files:**
- Create: `lib/services/step_copy.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` (then run `flutter gen-l10n`), `lib/screens/MapScreen.dart` (`_sheetHeader` `:2665-2678`, `_stepTile` `:2850-2888`, remove `_buildIntermission`/`_getIntermissionInfo`/`_IntermissionInfo`, `_updateDistanceDisplay` `:1218-1278`)
- Test: `test/step_copy_test.dart`

**Interfaces:**
- Consumes: the instruction fields from Task 8, and `RouteProgress.metersToStep`.
- Produces:
  - `StepCopy({required String title, List<String> lines})`
  - `StepCopy.of(AppLocalizations, List steps, int index)`
  - `StepCopy.live(AppLocalizations, List steps, int index, double metersLeft) → String?`
  - `StepCopy.walkMinutes(num meters) → int`

- [ ] **Step 1: Add the strings.** Add to `app_en.arb` before the closing `}` (add a comma after the previous last entry):

```json
  "stepWalkTo": "Walk to {place}",
  "@stepWalkTo": {"placeholders": {"place": {"type": "String"}}},
  "stepWalkToDestination": "Walk to your destination",
  "@stepWalkToDestination": {},
  "stepWalkMeta": "{meters} m · ~{minutes}",
  "@stepWalkMeta": {"placeholders": {"meters": {"type": "String"}, "minutes": {"type": "String"}}},
  "stepRide": "Ride {line}",
  "@stepRide": {"placeholders": {"line": {"type": "String"}}},
  "stepBoardAt": "Board at {station}",
  "@stepBoardAt": {"placeholders": {"station": {"type": "String"}}},
  "stepToward": "toward {place}",
  "@stepToward": {"placeholders": {"place": {"type": "String"}}},
  "stepRideTo": "Ride to {station}",
  "@stepRideTo": {"placeholders": {"station": {"type": "String"}}},
  "stepStops": "{count, plural, =1{1 stop} other{{count} stops}}",
  "@stepStops": {"placeholders": {"count": {"type": "int"}}},
  "stepGetOffAt": "Get off at {station}",
  "@stepGetOffAt": {"placeholders": {"station": {"type": "String"}}},
  "stepThenWalkTo": "then walk {meters} m to {place} · ~{minutes}",
  "@stepThenWalkTo": {"placeholders": {"meters": {"type": "String"}, "place": {"type": "String"}, "minutes": {"type": "String"}}},
  "stepThenWalkToDestination": "then walk {meters} m to your destination · ~{minutes}",
  "@stepThenWalkToDestination": {"placeholders": {"meters": {"type": "String"}, "minutes": {"type": "String"}}},
  "liveGetOffIn": "Get off at {station} in ~{minutes}",
  "@liveGetOffIn": {"placeholders": {"station": {"type": "String"}, "minutes": {"type": "String"}}},
  "liveWalkLeft": "{meters} m to {place} · ~{minutes}",
  "@liveWalkLeft": {"placeholders": {"meters": {"type": "String"}, "place": {"type": "String"}, "minutes": {"type": "String"}}}
```

  Add to `app_ar.arb` before the closing `}`:

```json
  "stepWalkTo": "امشي لحد {place}",
  "stepWalkToDestination": "امشي لحد المكان اللي رايحه",
  "stepWalkMeta": "{meters} متر · ~{minutes}",
  "stepRide": "اركب {line}",
  "stepBoardAt": "اركب من {station}",
  "stepToward": "اتجاه {place}",
  "stepRideTo": "خليك راكب لحد {station}",
  "stepStops": "{count, plural, =1{محطة واحدة} =2{محطتين} few{{count} محطات} other{{count} محطة}}",
  "stepGetOffAt": "انزل في {station}",
  "stepThenWalkTo": "وبعدين امشي {meters} متر لحد {place} · ~{minutes}",
  "stepThenWalkToDestination": "وبعدين امشي {meters} متر لحد المكان اللي رايحه · ~{minutes}",
  "liveGetOffIn": "هتنزل في {station} بعد ~{minutes}",
  "liveWalkLeft": "فاضل {meters} متر لحد {place} · ~{minutes}"
```

  Run `flutter gen-l10n`. Expected: no errors.

- [ ] **Step 2: Write the failing test** `test/step_copy_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/step_copy.dart';

Future<AppLocalizations> l10nFor(String code) => AppLocalizations.delegate.load(Locale(code));

final trip = <Map<String, dynamic>>[
  {'action': 'walk_to_station', 'distance_m': 704, 'station': '8th District', 'station_en': '8th District'},
  {
    'action': 'board', 'vehicle_type': 'minibus', 'route_number': '66', 'route_id': 'R66',
    'station': '8th District', 'station_en': '8th District', 'towards': 'Ramses', 'towards_en': 'Ramses',
    'alight_station': 'Kids Land', 'alight_station_en': 'Kids Land', 'ride_m': 4200, 'ride_min': 12, 'stops_count': 5,
  },
  {'action': 'walk_to_transfer', 'distance_m': 200, 'station': 'Kids Land', 'station_en': 'Kids Land'},
  {'action': 'transfer', 'vehicle_type': 'microbus', 'route_id': 'R9', 'station': 'Abbas', 'station_en': 'Abbas',
   'alight_station': 'Helwan', 'alight_station_en': 'Helwan', 'ride_m': 9000, 'ride_min': 25, 'stops_count': 1},
  {'action': 'arrive', 'station': 'Helwan', 'station_en': 'Helwan'},
  {'action': 'walk_to_destination', 'distance_m': 300, 'station': null},
];

void main() {
  test('walk to the station: where, how far, how long', () async {
    final c = StepCopy.of(await l10nFor('en'), trip, 0);
    expect(c.title, 'Walk to 8th District');
    expect(c.lines, ['704 m · ~10 min']);
  });

  test('a ride says where to board, where to get off, time and stops', () async {
    final c = StepCopy.of(await l10nFor('en'), trip, 1);
    expect(c.title, 'Ride Minibus 66');
    expect(c.lines, ['Board at 8th District · toward Ramses', 'Ride to Kids Land · ~12 min · 5 stops']);
  });

  test('getting off and walking to the next ride is one instruction', () async {
    final c = StepCopy.of(await l10nFor('en'), trip, 2);
    expect(c.title, 'Get off at Kids Land');
    expect(c.lines, ['then walk 200 m to Abbas · ~3 min']);
  });

  test('the last get-off names the walk to the destination', () async {
    final c = StepCopy.of(await l10nFor('en'), trip, 4);
    expect(c.title, 'Get off at Helwan');
    expect(c.lines, ['then walk 300 m to your destination · ~4 min']);
  });

  test('Arabic stop counts', () async {
    final c = StepCopy.of(await l10nFor('ar'), trip, 3);
    expect(c.lines.last, contains('محطة واحدة'));
  });

  test('live: a ride counts down to the get-off at the ride pace', () async {
    // 4200 m in 12 min = 350 m/min; 1400 m left = 4 min.
    expect(StepCopy.live(await l10nFor('en'), trip, 1, 1400), 'Get off at Kids Land in ~4 min');
  });

  test('live: a walk counts down at walking pace', () async {
    expect(StepCopy.live(await l10nFor('en'), trip, 0, 450), '450 m to 8th District · ~6 min');
  });
}
```

- [ ] **Step 3: Run and see it fail.** Run `flutter test test/step_copy_test.dart`. Expected: FAIL, because the URI doesn't exist.

- [ ] **Step 4: Implement** `lib/services/step_copy.dart`:

```dart
import 'dart:math' as math;

import '../l10n/app_localizations.dart';
import '../utils/minutes_text.dart';
import 'instruction_formatter.dart';

/// What a trip step says, as one instruction per card: where to walk to, or
/// which vehicle to ride, where to board and where to get off -- with how
/// long each takes. Replaces the card-plus-"intermission" pairs that
/// repeated each instruction and never said where to get off.
class StepCopy {
  const StepCopy({required this.title, this.lines = const []});

  final String title;
  final List<String> lines;

  /// The engine's walking pace: 1.25 m/s.
  static const double walkMetersPerMin = 75;

  static int walkMinutes(num meters) => math.max(1, (meters / walkMetersPerMin).ceil());

  static bool _isAr(AppLocalizations l10n) => l10n.localeName.startsWith('ar');

  static Map<String, dynamic>? _at(List steps, int i) =>
      i >= 0 && i < steps.length && steps[i] is Map ? Map<String, dynamic>.from(steps[i] as Map) : null;

  static String _name(AppLocalizations l10n, Map<String, dynamic>? m, [String key = 'station']) =>
      m == null ? '' : (InstructionFormatter.localized(m, key, isAr: _isAr(l10n)) ?? '');

  static int _meters(Map<String, dynamic> m) => InstructionFormatter.asNum(m['distance_m'])?.round() ?? 0;

  static StepCopy of(AppLocalizations l10n, List steps, int index) {
    final s = _at(steps, index)!;
    final next = _at(steps, index + 1);
    final d = _meters(s);
    String walkMeta(int m) => l10n.stepWalkMeta('$m', l10n.minutes(walkMinutes(m)));

    switch (s['action']) {
      case 'walk_to_station':
      case 'continue_walk':
        final to = _name(l10n, s['action'] == 'continue_walk' ? next : s);
        return StepCopy(
          title: to.isNotEmpty ? l10n.stepWalkTo(to) : InstructionFormatter.title(l10n, s),
          lines: [if (d > 0) walkMeta(d)],
        );
      case 'board':
      case 'transfer':
        final board = _name(l10n, s);
        final towards = _name(l10n, s, 'towards');
        final alight = _name(l10n, s, 'alight_station');
        final rideMin = InstructionFormatter.asNum(s['ride_min']);
        final stops = InstructionFormatter.asNum(s['stops_count'])?.round();
        final rideLine = [
          if (alight.isNotEmpty) l10n.stepRideTo(alight),
          if (rideMin != null) '~${l10n.minutes(rideMin)}',
          if (stops != null && stops > 0) l10n.stepStops(stops),
        ].join(' · ');
        return StepCopy(
          title: l10n.stepRide(InstructionFormatter.lineLabelFull(l10n, s)),
          lines: [
            if (board.isNotEmpty) [l10n.stepBoardAt(board), if (towards.isNotEmpty) l10n.stepToward(towards)].join(' · '),
            if (rideLine.isNotEmpty) rideLine,
            ...InstructionFormatter.legWalkNotes(l10n, s),
          ],
        );
      case 'walk_to_transfer':
        final to = _name(l10n, next);
        return StepCopy(
          title: l10n.stepGetOffAt(_name(l10n, s)),
          lines: [if (d > 0 && to.isNotEmpty) l10n.stepThenWalkTo('$d', to, l10n.minutes(walkMinutes(d)))],
        );
      case 'arrive':
        final walk = next != null && next['action'] == 'walk_to_destination' ? _meters(next) : 0;
        return StepCopy(
          title: l10n.stepGetOffAt(_name(l10n, s)),
          lines: [if (walk > 0) l10n.stepThenWalkToDestination('$walk', l10n.minutes(walkMinutes(walk)))],
        );
      case 'walk_to_destination':
        return StepCopy(title: l10n.stepWalkToDestination, lines: [if (d > 0) walkMeta(d)]);
      default:
        return StepCopy(title: InstructionFormatter.title(l10n, s), lines: [InstructionFormatter.subtitle(l10n, s)]);
    }
  }

  /// The live line for the step the rider is on, given the metres left to
  /// the end of it; null when the step has nothing to count down.
  static String? live(AppLocalizations l10n, List steps, int index, double metersLeft) {
    final s = _at(steps, index);
    if (s == null) return null;
    final left = metersLeft.round();
    switch (s['action']) {
      case 'board':
      case 'transfer':
        final rideM = InstructionFormatter.asNum(s['ride_m']);
        final rideMin = InstructionFormatter.asNum(s['ride_min']);
        final alight = _name(l10n, s, 'alight_station');
        if (rideM == null || rideMin == null || rideM <= 0 || rideMin <= 0 || alight.isEmpty) return null;
        final mins = math.max(1, (left / (rideM / rideMin)).ceil());
        return l10n.liveGetOffIn(alight, l10n.minutes(mins));
      case 'walk_to_station':
      case 'continue_walk':
      case 'walk_to_transfer':
      case 'walk_to_destination':
      case 'arrive':
        final next = _at(steps, index + 1);
        var to = _name(l10n, s['action'] == 'walk_to_station' ? s : next);
        if (to.isEmpty) to = l10n.stepWalkToDestination;
        final shown = (left / 10).round() * 10;
        return l10n.liveWalkLeft('$shown', to, l10n.minutes(walkMinutes(left)));
      default:
        return null;
    }
  }
}
```

  - If `liveWalkLeft` with the "Walk to your destination" fallback reads oddly, use the destination title instead. Leave the test as written.

- [ ] **Step 5: Run.** Run `flutter test test/step_copy_test.dart test/l10n_coverage_test.dart`. Expected: PASS. Fix any number mismatch by checking `walkMinutes` (704/75 → 10).

- [ ] **Step 6: Wire into MapScreen.**
  - Import `../services/step_copy.dart`.
  - In `_sheetHeader`, replace the two `Text`s for title and subtitle with:

```dart
                        Builder(builder: (context) {
                          final copy = StepCopy.of(l10n, _instructions, _currentStepIndex);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(copy.title,
                                  style: const TextStyle(color: AppColors.brandBlue, fontSize: 17, fontWeight: FontWeight.w800, height: 1.2)),
                              for (final line in copy.lines) ...[
                                const SizedBox(height: 2),
                                Text(line, style: TextStyle(color: context.textSecondary, fontSize: 13.5, height: 1.3)),
                              ],
                            ],
                          );
                        }),
```

  - In `_stepTile`:
    - Build `final copy = StepCopy.of(l10n, _instructions, index);`.
    - The title `Text` uses `copy.title`.
    - Replace the subtitle `Text`, the `if (stName.isNotEmpty) Text(stName ...)` and the `legWalkNotes` loop with:

```dart
                          for (final line in copy.lines)
                            Text(line, style: TextStyle(color: context.textSecondary, fontSize: 12.5)),
```

    - Remove the now-unused `stName` local.
  - Delete the line `if (!isLast) _buildIntermission(context, l10n, index),`, the methods `_buildIntermission` and `_getIntermissionInfo`, and the `_IntermissionInfo` class.
  - Alternatives stay inside the tile, as they are now (`if (isOpen) _alternatives(...)`).
  - In `_updateDistanceDisplay`, after the arrived early return and before `final int next = ...`, add:

```dart
    // A live countdown in words: "Get off at Kids Land in ~4 min",
    // "450 m to 8th District · ~6 min".
    final hereNow = _currentLocation.value;
    if (hereNow != null && _progress != null) {
      final left = _progress!.metersToStep(hereNow, _currentStepIndex, _currentStepIndex + 1);
      final live = left == null ? null : StepCopy.live(l10n, _instructions, _currentStepIndex, left);
      if (live != null) {
        _distanceToNextStop.value = live;
        return;
      }
    }
```

- [ ] **Step 7: Analyze and run.** Run `flutter analyze lib/screens/MapScreen.dart lib/services/step_copy.dart`, then `flutter test`. Expected: no analyzer issues. Any test asserting the old intermission or subtitle text is updated to the `StepCopy` wording. Show each changed assertion in the commit and don't delete tests.

- [ ] **Step 8: Commit.** Commit with the message "Trip cards: one clear instruction per step, where to get off, ride and walk ETAs".

---

## Batch C — routing and data

### Task 10: Backend — never recommend a ride walking would replace (≤ 1.5 km)

**Files:**
- Modify: `guidy-backend-main/raptor_engine.py`:
  - constants `:486-498`
  - `_short_hop_trims` `:3981-4029`
  - edge-time lookup `:4099-4100`
  - `_drop_short_hops` `:5814-5835`
  - its call `:5648`
  - `_put_short_walk_first` `:5518-5543`
- Test: `guidy-backend-main/test_short_hops.py` (rewrite)

**Interfaces:**
- Produces `GTFSRaptorEngine._demote_short_hops(options) → options`. A hop card that has a cheaper walking twin gets:
  - `_beaten = True`
  - `type` changed from `Recommended` to `Alternative`
  - `short_ride = {"saves_min": int, "extra_egp": int}`
- Produces `_short_hop_trims`, which now also returns middle rides with end `"middle"`.

- [ ] **Step 1: Rewrite the tests.** In `test_short_hops.py`:
  - Replace the import with `from raptor_engine import GTFSRaptorEngine, SHORT_HOP_WALK_M`.
  - Replace `TestReportedTrip.test_no_second_fare_for_a_short_last_ride` with:

```python
    def test_recommended_never_rides_where_walking_would_do(self):
        for trip in (REPORTED, (30.0600, 31.3790, 29.8686, 31.3155)):
            rec = [o for o in self.route(*trip).get('options', []) if o['type'] == 'Recommended']
            for o in rec:
                rides = _rides(o)
                if len(rides) >= 2:
                    self.assertGreater(_dist(*rides[-1]) * 1.25, SHORT_HOP_WALK_M,
                                       f"Recommended rides a short last hop: {_lines(o)}")
```

  - Replace `TestDropShortHops` with:

```python
class TestDemoteShortHops(unittest.TestCase):
    demote = staticmethod(GTFSRaptorEngine._demote_short_hops)

    def test_the_hop_stays_as_a_choice_but_is_never_recommended(self):
        hop = _card(['66', '101'], 30, 40, hop=True)
        hop['type'] = 'Recommended'
        walk = _card(['66'], 45, 20)
        out = self.demote([hop, walk])
        self.assertEqual(out, [hop, walk])
        self.assertEqual(hop['type'], 'Alternative')
        self.assertTrue(hop['_beaten'])
        self.assertEqual(hop['short_ride'], {'saves_min': 15, 'extra_egp': 20})

    def test_a_middle_hop_counts_too(self):
        hop = _card(['66', '9', '101'], 30, 50, hop=True)
        walk = _card(['66', '101'], 38, 40)
        self.demote([hop, walk])
        self.assertTrue(hop.get('_beaten'))

    def test_untouched_without_a_walking_twin(self):
        hop = _card(['66', '57'], 46, 40, hop=True)
        hop['type'] = 'Recommended'
        self.demote([hop, _card(['12'], 50, 20)])
        self.assertEqual(hop['type'], 'Recommended')
        self.assertNotIn('short_ride', hop)


class TestShortWalkFirst(unittest.TestCase):
    def test_a_walk_up_to_1500_m_goes_first_and_is_recommended(self):
        walk = {'type': 'Walk', 'raw_time': 19, 'distance_m': 1400}
        bus = {'type': 'Recommended', 'raw_time': 8, 'raw_price': 15}
        opts = [bus, walk]
        GTFSRaptorEngine._put_short_walk_first(opts)
        self.assertIs(opts[0], walk)
        self.assertEqual(bus['type'], 'Alternative')
        self.assertIn('Recommended', walk['also_qualifies_as'])

    def test_a_longer_walk_does_not(self):
        walk = {'type': 'Walk', 'raw_time': 25, 'distance_m': 1900}
        bus = {'type': 'Recommended', 'raw_time': 8, 'raw_price': 15}
        opts = [bus, walk]
        GTFSRaptorEngine._put_short_walk_first(opts)
        self.assertIs(opts[0], bus)


class TestMiddleTrim(unittest.TestCase):
    def test_short_middle_ride_is_offered_walked(self):
        eng = GTFSRaptorEngine.__new__(GTFSRaptorEngine)
        # A, B 3 km apart; B->C 600 m; C->D 3 km. Rides: R1 A-B, R2 B-C, R3 C-D.
        eng.stops = {s: {'lat': lat, 'lon': 31.0} for s, lat in
                     (('A', 30.0), ('B', 30.027), ('C', 30.0324), ('D', 30.0594))}
        path = [('A', 'R1', '0'), ('B', 'R2', '0'), ('C', 'R3', '0'), ('D', None, None)]
        trims = eng._short_hop_trims(path, 30.0, 31.0, 30.0594, 31.0)
        self.assertIn(([('A', 'R1', '0'), ('B', 'WALK', None), ('C', 'R3', '0'), ('D', None, None)], 'middle'), trims)
```

- [ ] **Step 2: Run and see them fail.** Run `python -m pytest test_short_hops.py -q`. Expected: FAIL with an ImportError for `_demote_short_hops`, or attribute errors.

- [ ] **Step 3: Implement.**
  - Constants: replace the block from `# A ride this short ...` to `SHORT_HOP_WORTH_MIN = 10` with:

```python
# A ride that walking would replace with at most SHORT_HOP_WALK_M of walking
# (straight line x SHORT_HOP_WALK_DETOUR) -- first, middle or last ride of a
# trip -- is never Recommended over the trip that walks it (owner's rule,
# 2026-10-04: no 10-20 EGP microbus or bus for a walk of a kilometre or so).
# _short_hop_trims builds the walking twin; _demote_short_hops keeps the ride
# as a faster choice, never the recommendation.
SHORT_HOP_WALK_M = 1500
SHORT_HOP_WALK_DETOUR = 1.25
```

  - `_short_hop_trims`: update the docstring to describe first, middle and last. Replace everything from `trims = []` to `return trims` with:

```python
        def walk_m(a, b):
            return hav(*a, *b) * SHORT_HOP_WALK_DETOUR

        trims = []
        # Last ride: get off the previous vehicle, walk to the destination.
        alight = legs[-2][1] + 1
        if walk_m(ll(path[alight][0]), (end_lat, end_lon)) <= SHORT_HOP_WALK_M:
            trims.append((path[:alight] + [(path[alight][0], None, None)], "last"))
        # First ride: walk from the start to the second vehicle.
        board = legs[1][0]
        if walk_m((start_lat, start_lon), ll(path[board][0])) <= SHORT_HOP_WALK_M:
            trims.append((path[board:], "first"))
        # A ride between two others: walk from where it boards to where it
        # lets off, and carry on.
        for leg in legs[1:-1]:
            b_stop, a_idx = path[leg[0]][0], leg[1] + 1
            if walk_m(ll(b_stop), ll(path[a_idx][0])) <= SHORT_HOP_WALK_M:
                trims.append((path[:leg[0]] + [(b_stop, "WALK", None)] + path[a_idx:], "middle"))
        return trims
```

    Delete the now-unused `ride_m` helper.
  - Edge time: replace

```python
            base_edge_time = next((t for n, r, d, t in self.graph[curr_stop]
                                   if n == next_stop and r == route and d == direction), 10)
```

    with

```python
            base_edge_time = next((t for n, r, d, t in self.graph.get(curr_stop, ())
                                   if n == next_stop and r == route and d == direction), None)
            if base_edge_time is None:
                # A walk _short_hop_trims put in place of a ride has no graph
                # edge: time it at walking pace over the detoured distance.
                base_edge_time = (max(hop_dist * SHORT_HOP_WALK_DETOUR / self.WALK_SPEED_MPS, 10)
                                  if route == "WALK" else 10)
```

  - Replace `_drop_short_hops` with:

```python
    @classmethod
    def _demote_short_hops(cls, options):
        """A card riding a vehicle where walking it would do (marked
        `_short_hop` from _short_hop_trims) is never Recommended when the
        card that walks it instead -- the same vehicles less that one, and
        cheaper -- is there. It stays as the faster choice, marked with what
        it saves and costs (`short_ride`), and is kept out of Recommended
        (`_beaten`, see _pick_recommended)."""
        sig = cls._ride_signature
        for o in options:
            if not o.get('_short_hop') or o.get('raw_time') is None:
                continue
            rides = sig(o)
            shorter = {rides[:j] + rides[j + 1:] for j in range(len(rides))}
            fare = o.get('fare_total_egp', 9999)
            twins = [t for t in options if t is not o and t.get('raw_time') is not None
                     and sig(t) in shorter and t.get('fare_total_egp', 9999) < fare]
            if not twins:
                continue
            twin = min(twins, key=lambda t: t['raw_time'])
            o['_beaten'] = True
            o['short_ride'] = {'saves_min': max(0, twin['raw_time'] - o['raw_time']),
                               'extra_egp': fare - twin.get('fare_total_egp', 0)}
            if o.get('type') == 'Recommended':
                o['type'] = 'Alternative'
        return options
```

  - Change the call to `final_options = cls._demote_short_hops(final_options)`.
  - `_put_short_walk_first`:
    - Set `first = w.get('distance_m', 1e9) <= SHORT_HOP_WALK_M` when there are usual cards (no time test).
    - Update the docstring: "A walk of at most SHORT_HOP_WALK_M goes first and is the recommendation, whatever a vehicle saves (owner's rule, 2026-10-04)."
    - Inside `if first:`, before moving the card, add:

```python
            if usual_times:
                for o in options:
                    if o.get('type') == 'Recommended':
                        o['type'] = 'Alternative'
                quals = w.setdefault('also_qualifies_as', [])
                if 'Recommended' not in quals:
                    quals.append('Recommended')
```

  - Run `grep -n "_drop_short_hops\|SHORT_HOP_WORTH_MIN\|SHORT_HOP_RIDE_M" *.py qa/*.py`. Expected: no hits.
  - Check that `_pick_recommended` runs after `_demote_short_hops` (it does, in `_finish_cards`), and that nothing after `_put_short_walk_first` re-assigns `Recommended`. To check, run `grep -n "'Recommended'" raptor_engine.py` and read every assignment after line 5412.

- [ ] **Step 4: Run.** Run `python -m pytest test_short_hops.py test_recommended_consistency.py test_dominated_options.py test_extra_cheapest.py test_three_profiles_and_invariants.py test_routing_engine.py -q`. Expected: all PASS.
  - A pre-existing test that asserted a 1.2–1.5 km walk is *not* first now conflicts with the owner's rule. Update its expectation and say so in the commit message.

- [ ] **Step 5: Commit (backend repo).** Commit with the message "Never recommend a ride that a walk of up to 1.5 km replaces; keep it as a choice".

### Task 11: App — label the faster paid-ride option

**Files:**
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` (then run `flutter gen-l10n`), `lib/screens/RouteOptionsScreen.dart:980-986`
- Test: `test/route_options_parsing_test.dart`

- [ ] **Step 1: Add the strings.**
  - en: `"routeShortRide": "{minutes} faster · +{fare} EGP"`, with placeholders `minutes` and `fare` as String.
  - ar: `"routeShortRide": "أسرع بـ{minutes} · +{fare} ج.م"`.
  - Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test.** Look at how `test/route_options_parsing_test.dart` pumps `RouteOptionsScreen` with canned options, and reuse its helper. Add a test with one option carrying `'short_ride': {'saves_min': 15, 'extra_egp': 20}` that expects `find.text('15 min faster · +20 EGP')`.

- [ ] **Step 3: Run and see it fail.** Run `flutter test test/route_options_parsing_test.dart`. Expected: the new test FAILS.

- [ ] **Step 4: Implement.** In `_buildRouteRow`, inside the badge `Wrap` children after the tiers loop, add:

```dart
                            if (option['short_ride'] is Map)
                              _tierBadge(
                                'ShortRide',
                                l10n.routeShortRide(
                                  l10n.minutes(_num((option['short_ride'] as Map)['saves_min'])),
                                  '${_num((option['short_ride'] as Map)['extra_egp'])?.round() ?? 0}',
                                ),
                              ),
```

- [ ] **Step 5: Run.** Run `flutter test test/route_options_parsing_test.dart test/l10n_coverage_test.dart`. Expected: PASS.

- [ ] **Step 6: Commit.** Commit with the message "Route options: label a paid ride that a short walk replaces".

### Task 12: Backend — ride report review queue

**Files:**
- Create: `guidy-backend-main/ride_reports.py`
- Modify: `guidy-backend-main/main.py` (a model next to `TripLog`, an endpoint after `forget_my_trips`)
- Test: `guidy-backend-main/test_ride_reports.py`

**Interfaces:**
- Produces:
  - `ride_reports.VEHICLES`
  - `ride_reports.store(folder, rider, verified, report: dict) -> dict`, which returns the stored record
  - `ride_reports.read(folder) -> list[dict]`
  - `POST /api/ride_reports`

- [ ] **Step 1: Write the failing test** `test_ride_reports.py`:

```python
import json
import os
import tempfile
import unittest

import ride_reports


def _report(**kw):
    r = {"client_report_id": "r1", "vehicle_type": "microbus", "fare_egp": 10,
         "started_at": 1000.0, "ended_at": 1600.0, "distance_m": 2400,
         "points": [[30.0, 31.0, 1000.0], [30.01, 31.0, 1300.0], [30.02, 31.0, 1600.0]],
         "planned_step": {"from": "A", "to": "B", "distance_m": 2600}, "app_version": "1.0.8"}
    r.update(kw)
    return r


class RideReportTests(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def test_stores_and_reads_back(self):
        rec = ride_reports.store(self.dir, "abc", True, _report())
        self.assertEqual(rec["rider"], "abc")
        self.assertTrue(rec["verified"])
        self.assertEqual(rec["minutes"], 10)
        self.assertIn("received_at", rec)
        self.assertEqual(ride_reports.read(self.dir), [rec])

    def test_drops_points_outside_egypt(self):
        rec = ride_reports.store(self.dir, "abc", False, _report(points=[[0, 0, 1.0], [30.0, 31.0, 2.0]]))
        self.assertEqual(rec["points"], [[30.0, 31.0, 2.0]])

    def test_same_report_twice_is_stored_once(self):
        ride_reports.store(self.dir, "abc", True, _report())
        self.assertIsNone(ride_reports.store(self.dir, "abc", True, _report()))
        self.assertEqual(len(ride_reports.read(self.dir)), 1)

    def test_listing_line(self):
        rec = ride_reports.store(self.dir, "abc", True, _report())
        line = ride_reports.describe(rec)
        self.assertIn("microbus", line)
        self.assertIn("10 EGP", line)
        self.assertIn("2.4 km", line)
```

- [ ] **Step 2: Run and see it fail.** Run `python -m pytest test_ride_reports.py -q`. Expected: FAIL with ModuleNotFoundError.

- [ ] **Step 3: Implement** `ride_reports.py`:

```python
"""Rides riders took that Guidy doesn't know: during a long walk the app
lets a rider say "I took a vehicle", with its type and fare, and records
the path, distance and time. Reports are queued here for review
(gtfs_data/crowd/ride_reports.jsonl) -- nothing changes routing by itself.

    python ride_reports.py list [folder]    # newest first
"""
import datetime
import json
import os
import sys
import threading
import time

VEHICLES = ("microbus", "tuktuk", "bus", "taxi", "other")
FILENAME = "ride_reports.jsonl"
EGYPT_LAT = (21.5, 32.0)
EGYPT_LON = (24.5, 37.5)
_lock = threading.Lock()


def _path(folder):
    return os.path.join(folder, FILENAME)


def read(folder):
    try:
        with open(_path(folder), encoding="utf-8") as f:
            return [json.loads(line) for line in f if line.strip()]
    except FileNotFoundError:
        return []


def store(folder, rider, verified, report):
    """Appends one report; returns the stored record, or None if this rider
    already sent this report (the app retries)."""
    points = [[round(p[0], 6), round(p[1], 6), round(p[2], 1)] for p in report.get("points", ())
              if len(p) >= 3 and EGYPT_LAT[0] <= p[0] <= EGYPT_LAT[1] and EGYPT_LON[0] <= p[1] <= EGYPT_LON[1]]
    rec = {
        "rider": rider,
        "verified": bool(verified),
        "received_at": round(time.time(), 1),
        "client_report_id": report["client_report_id"],
        "vehicle_type": report["vehicle_type"],
        "fare_egp": report["fare_egp"],
        "started_at": report["started_at"],
        "ended_at": report["ended_at"],
        "minutes": max(0, round((report["ended_at"] - report["started_at"]) / 60)),
        "distance_m": round(report.get("distance_m") or 0),
        "planned_step": report.get("planned_step") or {},
        "app_version": report.get("app_version", ""),
        "points": points,
    }
    os.makedirs(folder, exist_ok=True)
    with _lock:
        if any(r["rider"] == rider and r["client_report_id"] == rec["client_report_id"] for r in read(folder)):
            return None
        with open(_path(folder), "a", encoding="utf-8") as f:
            f.write(json.dumps(rec, ensure_ascii=False) + "\n")
    return rec


def describe(rec):
    when = datetime.datetime.fromtimestamp(rec["started_at"]).strftime("%Y-%m-%d %H:%M")
    step = rec.get("planned_step") or {}
    return (f"{when}  {rec['vehicle_type']:<8} {rec['fare_egp']:g} EGP  "
            f"{rec['distance_m'] / 1000:.1f} km  {rec['minutes']} min  "
            f"{step.get('from', '?')} -> {step.get('to', '?')}  "
            f"{'verified' if rec['verified'] else 'anonymous'}  {len(rec['points'])} pts")


if __name__ == "__main__":
    if len(sys.argv) < 2 or sys.argv[1] != "list":
        print(__doc__)
        sys.exit(1)
    folder = sys.argv[2] if len(sys.argv) > 2 else os.path.join("gtfs_data", "crowd")
    for r in sorted(read(folder), key=lambda r: r["started_at"], reverse=True):
        print(describe(r))
```

- [ ] **Step 4: Run.** Run `python -m pytest test_ride_reports.py -q`. Expected: PASS.

- [ ] **Step 5: Add the endpoint** to `main.py`. Add `from typing import Literal` if it isn't already imported. After `TripLog`:

```python
class RideReport(BaseModel):
    """A ride the rider took during a long walk (see ride_reports.py)."""
    client_report_id: str = Field(..., min_length=1, max_length=64)
    vehicle_type: Literal["microbus", "tuktuk", "bus", "taxi", "other"]
    fare_egp: float = Field(..., ge=0, le=500)
    started_at: float = Field(..., ge=0)
    ended_at: float = Field(..., ge=0)
    distance_m: float = Field(0, ge=0, le=200000)
    # [lat, lon, unix_time]
    points: list[list[float]] = Field(default_factory=list, max_length=2000)
    planned_step: dict = Field(default_factory=dict)
    app_version: str = Field("", max_length=32)
```

  After `forget_my_trips`:

```python
@app.post("/api/ride_reports")
@_limit(f"{RATE_LIMIT_PER_MINUTE}/minute")
def report_ride(request: Request, report: RideReport):
    """A ride a rider took that Guidy didn't suggest: vehicle, fare, path,
    distance and time. Queued for review; routing never changes from it on
    its own. Same rider identity as trip logs (salted uid hash)."""
    crowd = getattr(transit_engine, "crowd", None)
    if crowd is None:
        raise HTTPException(status_code=503, detail="Ride reports are unavailable right now.")
    import crowd_routes
    import ride_reports

    auth = request.headers.get("authorization", "")
    token = auth[7:].strip() if auth.lower().startswith("bearer ") else ""
    uid = crowd_routes.verify_firebase_token(token) if token else None
    rider = crowd.store.rider_key(uid) if uid else "anonymous"
    try:
        rec = ride_reports.store(crowd.store.dir, rider, uid is not None, report.model_dump())
    except Exception:
        logger.exception("Could not store ride report")
        raise HTTPException(status_code=500, detail="Could not store the ride right now.")
    return {"success": True, "stored": rec is not None, "duplicate": rec is None}
```

  Run `python -c "import ast; ast.parse(open('main.py', encoding='utf-8').read())"`. Expected: no error.

- [ ] **Step 6: Commit (backend repo).** Commit with the message "Ride reports: rides riders took during long walks, queued for review".

### Task 13: App — "I took a vehicle" during long walks

**Files:**
- Create: `lib/services/ride_report_service.dart`, `lib/widgets/ride_report_sheet.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ar.arb` (then run `flutter gen-l10n`), `lib/screens/MapScreen.dart` (`_sheetHeader`, the GPS fix handler near `:859`, `_advanceTo` from Task 7, `dispose`)
- Test: `test/ride_report_test.dart`

**Interfaces:**
- Produces:
  - `RideReport({required String vehicleType, required num fareEgp, required Map<String,dynamic> plannedStep, DateTime? now})`
  - `void addFix(double lat, double lon, DateTime t)`
  - `double distanceM`
  - `Duration elapsed([DateTime? now])`
  - `void end([DateTime? now])`
  - `Map<String,dynamic> toPayload()`
  - `RideReportService.send(RideReport r, {http.Client? client}) → Future<bool>`
  - `RideReportService.vehicles`
  - `RideReportService.minWalkM = 1500`
  - `showRideReportSheet(BuildContext) → Future<({String vehicle, num fare})?>`

- [ ] **Step 1: Add the strings.**

  en:

```json
  "rideReportButton": "I took a vehicle",
  "@rideReportButton": {},
  "rideReportTitle": "What did you take?",
  "@rideReportTitle": {},
  "rideReportFare": "Fare (EGP)",
  "@rideReportFare": {},
  "rideReportStart": "Start recording",
  "@rideReportStart": {},
  "rideReportRecording": "Recording your ride · {distance} · {minutes}",
  "@rideReportRecording": {"placeholders": {"distance": {"type": "String"}, "minutes": {"type": "String"}}},
  "rideReportStop": "I got off",
  "@rideReportStop": {},
  "rideReportThanks": "Thanks! We'll review this ride.",
  "@rideReportThanks": {},
  "rideVehicleTuktuk": "Tuk-tuk",
  "@rideVehicleTuktuk": {},
  "rideVehicleTaxi": "Taxi",
  "@rideVehicleTaxi": {},
  "rideVehicleOther": "Other",
  "@rideVehicleOther": {}
```

  ar:

```json
  "rideReportButton": "ركبت مواصلة",
  "rideReportTitle": "ركبت إيه؟",
  "rideReportFare": "الأجرة (ج.م)",
  "rideReportStart": "ابدأ التسجيل",
  "rideReportRecording": "بنسجّل المشوار · {distance} · {minutes}",
  "rideReportStop": "نزلت",
  "rideReportThanks": "شكرًا! هنراجع المشوار ده.",
  "rideVehicleTuktuk": "توكتوك",
  "rideVehicleTaxi": "تاكسي",
  "rideVehicleOther": "حاجة تانية"
```

  Run `flutter gen-l10n`.

- [ ] **Step 2: Write the failing test** `test/ride_report_test.dart`:

```dart
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
    final r = report()..addFix(30.0, 31.0, t0)..addFix(30.009, 31.0, t0.add(const Duration(minutes: 6)));
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
    await tester.tap(find.text('Start recording'));
    await tester.pumpAndSettle();
    expect(result, (vehicle: 'tuktuk', fare: 15));
  });
}
```

- [ ] **Step 3: Run and see it fail.** Run `flutter test test/ride_report_test.dart`. Expected: FAIL, because the URIs don't exist.

- [ ] **Step 4: Implement** `lib/services/ride_report_service.dart`:

```dart
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../utils/nav_math.dart';
import 'api_service.dart';

/// A ride a rider took during a long walk that Guidy didn't suggest
/// ("I took a vehicle"): its type and fare, and the path, distance and time
/// recorded while on it. Sent to the backend's review queue
/// (ride_reports.py); nothing changes routing by itself.
class RideReport {
  RideReport({required this.vehicleType, required this.fareEgp, required this.plannedStep, DateTime? now})
      : startedAt = now ?? DateTime.now(),
        id = '${(now ?? DateTime.now()).millisecondsSinceEpoch}';

  static const int maxPoints = 2000;

  /// Closer than this to the last kept fix is GPS wander, not travel.
  static const double minStepM = 10;

  final String id;
  final String vehicleType;
  final num fareEgp;
  final Map<String, dynamic> plannedStep;
  final DateTime startedAt;
  DateTime? endedAt;
  double distanceM = 0;
  final List<List<num>> _points = [];

  bool get isRecording => endedAt == null;

  void addFix(double lat, double lon, DateTime t) {
    if (!isRecording) return;
    if (_points.isNotEmpty) {
      final last = LatLng(_points.last[0].toDouble(), _points.last[1].toDouble());
      final d = NavMath.distanceM(last, LatLng(lat, lon));
      if (d < minStepM) return;
      distanceM += d;
    }
    if (_points.length < maxPoints) _points.add([lat, lon, t.millisecondsSinceEpoch / 1000]);
  }

  Duration elapsed([DateTime? now]) => (endedAt ?? now ?? DateTime.now()).difference(startedAt);

  void end([DateTime? now]) => endedAt ??= now ?? DateTime.now();

  Map<String, dynamic> toPayload() => {
        'client_report_id': id,
        'vehicle_type': vehicleType,
        'fare_egp': fareEgp,
        'started_at': startedAt.millisecondsSinceEpoch / 1000,
        'ended_at': (endedAt ?? DateTime.now()).millisecondsSinceEpoch / 1000,
        'distance_m': distanceM.round(),
        'points': _points,
        'planned_step': plannedStep,
      };
}

class RideReportService {
  RideReportService._();

  static const List<String> vehicles = ['microbus', 'tuktuk', 'bus', 'taxi', 'other'];

  /// Walks at least this long offer "I took a vehicle".
  static const double minWalkM = 1500;

  static Future<bool> send(RideReport r, {http.Client? client}) async {
    final c = client ?? http.Client();
    try {
      String? token;
      if (Firebase.apps.isNotEmpty) {
        try {
          token = await FirebaseAuth.instance.currentUser?.getIdToken();
        } catch (_) {}
      }
      final res = await c
          .post(
            Uri.parse('${ApiService.baseUrl}/ride_reports'),
            headers: {'Content-Type': 'application/json', if (token != null) 'Authorization': 'Bearer $token'},
            body: jsonEncode(r.toPayload()),
          )
          .timeout(const Duration(seconds: 15));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    } finally {
      if (client == null) c.close();
    }
  }
}
```

  Then `lib/widgets/ride_report_sheet.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/ride_report_service.dart';
import '../services/transit_modes.dart';
import '../theme/app_theme.dart';

String rideVehicleLabel(AppLocalizations l10n, String v) => switch (v) {
      'tuktuk' => l10n.rideVehicleTuktuk,
      'taxi' => l10n.rideVehicleTaxi,
      'other' => l10n.rideVehicleOther,
      _ => TransitModes.label(l10n, v),
    };

/// Asks which vehicle the rider took and its fare. Null if dismissed.
Future<({String vehicle, num fare})?> showRideReportSheet(BuildContext context) {
  return showModalBottomSheet<({String vehicle, num fare})>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => const _RideReportSheet(),
  );
}

class _RideReportSheet extends StatefulWidget {
  const _RideReportSheet();

  @override
  State<_RideReportSheet> createState() => _RideReportSheetState();
}

class _RideReportSheetState extends State<_RideReportSheet> {
  String? _vehicle;
  final _fare = TextEditingController();

  @override
  void dispose() {
    _fare.dispose();
    super.dispose();
  }

  num? get _fareValue {
    final n = num.tryParse(_fare.text.trim());
    return n != null && n >= 0 && n <= 500 ? n : null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ready = _vehicle != null && _fareValue != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.rideReportTitle, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: context.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in RideReportService.vehicles)
                ChoiceChip(
                  label: Text(rideVehicleLabel(l10n, v)),
                  selected: _vehicle == v,
                  onSelected: (_) => setState(() => _vehicle = v),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _fare,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            decoration: InputDecoration(labelText: l10n.rideReportFare),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: ready ? () => Navigator.pop(context, (vehicle: _vehicle!, fare: _fareValue!)) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(l10n.rideReportStart, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run.** Run `flutter test test/ride_report_test.dart`. Expected: PASS.

- [ ] **Step 6: Wire into MapScreen.**
  - Import both new files.
  - Add the field `RideReport? _rideReport;`.
  - In the GPS fix handler, where `_recorder.onFix(position, _currentStepIndex);` is (around `:859`), add:

```dart
    final ride = _rideReport;
    if (ride != null) {
      ride.addFix(position.latitude, position.longitude, position.timestamp);
      if (mounted) setState(() {}); // the recording line's distance and time
    }
```

  - Add the methods:

```dart
  bool _offersRideReport(Map<String, dynamic> step) =>
      InstructionFormatter.iconKey(step) == 'walk' &&
      (_asNum(step['distance_m']) ?? 0) >= RideReportService.minWalkM;

  Future<void> _startRideReport(AppLocalizations l10n) async {
    final picked = await showRideReportSheet(context);
    if (picked == null || !mounted) return;
    final step = _instructions[_currentStepIndex] as Map<String, dynamic>;
    final isAr = _isArabicNow;
    final next = _currentStepIndex + 1 < _instructions.length ? _instructions[_currentStepIndex + 1] : null;
    setState(() => _rideReport = RideReport(
          vehicleType: picked.vehicle,
          fareEgp: picked.fare,
          plannedStep: {
            'action': step['action'],
            'distance_m': step['distance_m'],
            'from': widget.startName ?? '',
            'to': _stationOf(step, isAr).isNotEmpty ? _stationOf(step, isAr) : _stationOf(next, isAr),
            'step_index': _currentStepIndex,
          },
        ));
    final here = _currentLocation.value;
    if (here != null) _rideReport!.addFix(here.latitude, here.longitude, DateTime.now());
    _recorder.onEvent('ride_report_start', {'step': _currentStepIndex, 'vehicle': picked.vehicle});
  }

  /// Ends the recording (the rider got off, or reached the next step) and sends it.
  void _finishRideReport({bool thank = true}) {
    final ride = _rideReport;
    if (ride == null) return;
    ride.end();
    _rideReport = null;
    if (mounted) setState(() {});
    _recorder.onEvent('ride_report_end', {'distance_m': ride.distanceM.round()});
    unawaited(RideReportService.send(ride));
    if (thank && mounted) {
      final l10n = _l10n ?? AppLocalizations.of(context);
      _showFloatingToast(l10n.rideReportThanks, icon: Icons.check_circle_outline, color: AppColors.primaryTeal);
    }
  }
```

  - In `_advanceTo` (Task 7), at the top: `if (_rideReport != null) _finishRideReport();`. Reaching the next step ends the ride.
  - In `dispose`, before the controllers are disposed: `_finishRideReport(thank: false);`.
  - In `_sheetHeader`, after the `Wrap` of chips and before the `_locationProblem` builder, add:

```dart
              if (_rideReport != null)
                Padding(
                  padding: const EdgeInsets.only(top: 11),
                  child: Row(
                    children: [
                      const Icon(Icons.fiber_manual_record, size: 12, color: Colors.redAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l10n.rideReportRecording(
                            _rideReport!.distanceM >= 1000
                                ? l10n.distanceKm((_rideReport!.distanceM / 1000).toStringAsFixed(1))
                                : '${_rideReport!.distanceM.round()} ${_isArabicNow ? 'متر' : 'm'}',
                            l10n.minutes(_rideReport!.elapsed().inMinutes),
                          ),
                          style: TextStyle(color: context.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton(onPressed: _finishRideReport, child: Text(l10n.rideReportStop)),
                    ],
                  ),
                )
              else if (_offersRideReport(step))
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => _startRideReport(l10n),
                    icon: const Icon(Icons.airport_shuttle_rounded, size: 18),
                    label: Text(l10n.rideReportButton),
                  ),
                ),
```

  - Note on the spec: the spec said recording stops when the rider "rejoins the planned route". Here it stops when navigation reaches the next step, i.e. the rider arrives where the walk was going. A vehicle driving along the walk path never leaves the route, so "rejoining" can't be detected.

- [ ] **Step 7: Analyze and run.** Run `flutter analyze lib`, then `flutter test`. Expected: no new issues, all PASS.

- [ ] **Step 8: Commit.** Commit with the message "\"I took a vehicle\": record and report rides during long walks".

---

## Final: verification and build

### Task 14: Full verification, version bump, release build

- [ ] **Step 1: App.** In `guidy-app-main`, run `flutter analyze` and `flutter test`. Expected: no issues and all tests green. If `history_screen_layout_test` fails, rerun it alone; it's a known flaky test.
- [ ] **Step 2: Backend.** In `guidy-backend-main`, run `python -m pytest test_short_hops.py test_step_annotations.py test_ride_reports.py test_recommended_consistency.py test_dominated_options.py test_extra_cheapest.py test_three_profiles_and_invariants.py test_routing_engine.py test_api_endpoints.py -q`. Expected: all PASS.
- [ ] **Step 3: Bump the version.** In `pubspec.yaml`, change `1.0.7+8` to `1.0.8+9`. Commit with the message "Version 1.0.8+9".
- [ ] **Step 4: Build.** Run `.\build_release.ps1` in `guidy-app-main`. Expected: "TEST ad units (safe to tap)." and the signed APK and AAB in `build\release\`.
- [ ] **Step 5: Report to the owner.** Give the test results, the build paths, and the work still to do:
  - Deploy the backend to the VPS, which the Task 8, 10 and 12 changes need.
  - Push both repos.
  - Upload 1.0.8 to Closed testing.

  Ask before pushing or deploying.
