# Handoff — Play Store submission (2026-10-04)

Where the Play Store launch stands, for whoever picks this up next. Everything
below was checked at the time of writing.

## 00000. Update 2026-10-22: "This walk is wrong" and opt-in walk traces (PR, not merged)

- **Report:** every walking step has "This walk is wrong" (Now card, the step list for other walking steps,
  and a 56 dp row in Simple Mode). Sheet: through buildings / too long / path doesn't exist / other + optional
  note. Sent to `POST /walk_reports` through `WalkOutbox` (queued in SharedPreferences when offline, 4xx dropped,
  never blocks the trip). `lib/services/walk_feedback_service.dart`, `lib/widgets/walk_report_sheet.dart`.
- **Traces:** Settings -> "Share my walking paths", off by default, explained in a dialog before it turns on
  (not shown in Simple Mode's trimmed Settings). `WalkTraceRecorder` reads the fixes the trip already gets
  (no extra GPS request), only on walking steps, stops on floating window / background, cuts the first and last
  50 m, simplifies, and uploads each step to `POST /walk_traces` with the trip log's id + step index when the step ends.
  Turning it off clears the unsent queue. The trip log (always on, Terms of Service) is unchanged.
- **Privacy text** is drafted in `website/legal/PRIVACY_POLICY(.ar).md` (see the comment at the top); the effective
  date and `LegalConsentService.currentVersion` are NOT bumped and nothing was built or published.
- Backend side: `guidy-backend` `walk_feedback.py`, `docs/walk-feedback.md`; review candidates come from
  `python -m scripts.audits.walk_gap_candidates`.

## 0000. Update 2026-10-21: Simple Mode rebuilt, banner ad moved to the top (PR, not merged)

- **Banner ad is at the TOP now**, under the status bar, on every screen (Moovit style): the
  shell stacks banner then screen, the screen loses its top safe-area padding, and keeps its
  bottom padding (the nav bar is no longer covered). `lib/widgets/app_banner_shell.dart`,
  `banner_ad_placeholder.dart` (`topMargin` became `bottomMargin`, `maintainBottomSafeAreaOnFailure`
  became `maintainSlotOnFailure`). Still hidden in the floating trip window and while the
  keyboard is open. The empty-strip trade-off above now applies to the top.
- **Simple Mode is a real flow**, not just big text: Home is one "Where do you want to go?"
  button plus Go home / Go to work / My saved places / Go again; search asks only for the
  destination; route options are at most 3 big plain-word cards, fewest changes first
  (`SimpleModeController.easiest`); the trip shows one step at a time with the exact words to
  tell the driver; ending a trip, clearing searches/history and logging out ask first; no
  tour, no tooltips, no swipe-only or long-press-only actions; every control is a labelled
  button of at least 56 dp. New widgets are in `lib/widgets/simple/`. New riders are offered
  Simple Mode once (MainNavigator, before the tour); Settings has a big "Turn off Simple
  Mode" button while it is on.
- Tests: `test/simple_mode_flow_test.dart`, `test/top_banner_test.dart`. `guidy_tour_test`
  now starts with the simple-mode offer already answered.

## 000. Update 2026-10-09: build 1.0.11 (14), twelve app fixes and changes (pushed, built, NOT uploaded to Play)

Read this first. It is written for whoever continues next, possibly a different
assistant on a different machine, with no memory of the sessions before it.

### State at the end of 2026-10-09

- **Both repos are pushed to `origin` `main`** (`youssefezat/guidy-app`,
  `youssefezat/guidy-backend`). Nothing is left unpushed.
- **Backend: no changes this session, and nothing waiting to deploy.** Its HEAD
  is `9343fdf` (`fare_from_egp`). Production already runs it: checked live, the
  Lines API returns `fare_from_egp` for 101 of 104 Alexandria microbuses (the
  other 3 are the intercity ones, a fixed fare) and `/api/health` says 5,177
  stops. If a backend change is ever needed, the deploy commands are in the
  2026-10-07 entry below and in `guidy-backend-main/DEPLOYMENT.md`.
- **App: 1.0.11 (14)**, both flavours built from the final code on 2026-10-09:
  `build/release/guidy-testads.aab/.apk` (Google TEST ads, for closed testing)
  and `build/release/guidy-release.aab/.apk` (real ads, production). Play
  accepts each build number once: upload only ONE of the two per number. Not
  uploaded yet. "What's new" (en/ar) is `release_notes_1.0.11.txt`, updated for
  this build.
- **Tests:** 518 pass (`flutter test`). `flutter analyze` is clean apart from two
  old infos in `tool/preview/`.
- The website was deployed on 2026-10-08 and is unchanged since.

### What changed in the app (commits `0fa0312..4975927`)

| Item | What it does now | Where |
|---|---|---|
| Tool rail | One horizontal bar: menu button at the screen edge, map / share / report extending toward the start side. Compass, recenter and stop alarm sit directly under it and the step card is wider. | `lib/widgets/guidy_tool_rail.dart`, top overlay in `lib/screens/MapScreen.dart` |
| Step card vs ad | The map bottom sheet's lowest stop is at least as tall as its measured header, so the "Now" card is never clipped. | `MapScreen.dart` (`_peekFor`, `_measureSheetHeader`) |
| Ad slot jump | If the first ad load fails, the banner slot keeps its 50 dp height (empty) and a later successful refresh fills it. | `lib/widgets/banner_ad_placeholder.dart` |
| Alexandria toggle | A chip under the Lines search bar. On, it lists Alexandria's own lines plus the Cairo-Alexandria microbuses, across all modes (179 lines now). It filters on the client with `lineCityOf()`. | `lib/screens/LinesScreen.dart` |
| Version in Settings | Reads `PackageInfo`, shows `v1.0.11 (14)`. | `SettingsScreen.dart` |
| Tab reset | Each tab goes back to the top when another tab is chosen. An open Lines mode stays open (only its scroll resets). | `lib/screens/MainNavigator.dart` (per-tab `PrimaryScrollController`) |
| Find Routes loading | A map-sized shimmer block above the card silhouettes. | `lib/widgets/route_card_skeleton.dart`, `RouteOptionsScreen.dart` |
| Recent trips lag | `TripHistoryService.getHistory()` kept re-parsing the whole stored history (every trip's full route data) on the main thread, for Home and Trips at once. It is now cached until the stored text changes, and Home skips a rebuild when nothing changed. | `lib/services/trip_history_service.dart`, `HomeScreen.dart` |
| Bug 1: Location Accuracy prompt loop | After the first "No thanks", every location request uses Android's LocationManager (no Google prompt). The trip's extra one-off fix request, which caused a second prompt, is gone; the stream resubscribes once after a decline. | new `lib/services/location_fallback.dart`, used by `MapScreen`, `HomeScreen`, `LocationSearchScreen`, `lib/utils/nav_math.dart` |
| Bug 2: "1 changes" | ICU plurals in English and Arabic. | `app_en.arb`, `app_ar.arb` (l10n regenerated) |
| Bug 3: Metro title overlap | The "Network Map" pill now sits under the title. | `MetroScreen.dart` |
| Rail map header | Removed the fare icon that duplicated the "Fares & Pass Guide" chip. | `RailNetworkMapScreen.dart` |

New tests: `metro_changes_plural_test`, `map_sheet_peek_test`, `location_fallback_test`,
`trip_history_cache_test`, `route_skeleton_map_test`, `lines_alexandria_toggle_test`, and a
Home scroll-reset test in `main_navigator_test`. Updated: the rail tests in
`redesign_review_fixes_test`, the receipt-button test in `rail_network_map_test`, and the
version assertion in `settings_screen_test`.

The four bugs came from the explainer-video session's handoff,
`docs/handoffs/guidy_video_HANDOFF_2026-10-08.md` (also in `Claude outputs/guidy_video/`). They are all fixed now. Its "minor observations" are not: recent-trip cards in
Arabic keep English place names, and the route options count can differ between searches.

### Decisions worth knowing

- **Distances were deliberately NOT changed.** The user first asked for everything in km,
  then changed their mind. Metres under 1 km and km above stay as they were. Do not "fix"
  this.
- **The empty ad strip is a trade-off.** On a phone where ads never load, the bottom shows
  an empty 50 dp strip instead of the layout shifting. To revert, make
  `BannerAdPlaceholder` collapse again on failure (the `_failed` branch in `build`).
- **The Alexandria toggle filters on the client** and assumes `/api/routes?limit=2000`
  returns every line. Today there are 1,278. If the catalogue ever passes 2,000, the
  filter would miss lines: move it to the server.
- **The sheet's lowest stop is capped** at the half-height stop minus 4%, so a huge
  header (very large text size) still leaves a draggable sheet.

### Checked on the emulator (test-ads build) and what was not

Checked on screen: version string, Alexandria toggle (179 lines), Metro header, the new
rail, the collapsed sheet, the reserved ad slot, and the Location Accuracy prompt. With
Location Accuracy turned off, Google's prompt appeared once at launch, "No thanks" was
tapped, and it never came back, including after starting a trip (the trip ran with GPS
updates). The old build was NOT rerun, so there is no before/after for that.

NOT checked on screen: the tab scroll reset, the loading map placeholder, Arabic layouts,
distances, and the recent-trips lag (the fix is covered by tests, the lag was never
measured, and it did not show on the emulator). Nothing was tried on a real phone.

### Notes for the next person (laptop, different assistant)

- **Repos and remotes.** `guidy-app-main` and `guidy-backend-main` each have `origin`
  (the real private repo, push here) and `public-ci` (a PUBLIC mirror of a sanitized
  snapshot). Never push `main` to `public-ci`. Refresh the mirrors only with
  `tool/make_ci_snapshot.sh` then `push_ci_mirror.bat` (in the workspace folder above the
  repos), which refuses snapshots containing secrets. They were NOT refreshed in this
  session. Pull only from `origin`.
- **Signing and secrets are not all in git.** `android/key.properties` and
  `android/app/guidy-release-key.jks` are ignored: run `restore_signing_files.bat` or ask
  the user for them. `secrets.properties` is force-added to the private repo, so a clone
  has it. Never print or paste its values, and do not copy it into the public mirrors.
- **Building.** Use `build_release.ps1` (test ads) or `build_release.ps1 -RealAds`. In
  `cmd`, call `.\build_both.bat` (with the `.\`); it asks whether to raise the build
  number. Build ONE flavour at a time with nothing else heavy open: it needs about 8 GB
  of free RAM. After a build, the Gradle daemon stays resident (about 3.5 GB): run
  `android\gradlew.bat --stop`, and kill the remaining `java` process if memory is
  still low. A build once failed at `uploadCrashlyticsMappingFileRelease` with an SSL
  handshake error (a network blip); Gradle retried and it passed. When memory is starved a
  build can take well over an hour.
- **Line endings.** Many files are CRLF and git warns about it. Keep each file's endings.
  Do NOT run `dart format` on `MapScreen.dart`: it rewrites about 1,300 lines. Edit the
  lines you need.
- **Package name** is `guidy_app` (tests import `package:guidy_app/...`). The Android id
  is `com.guidy.guidy_app`.
- **Test quirks.** Some state is static and leaks between tests:
  `MainNavigator.activeTabNotifier` (reset it in `setUp`) and the duplicate check in
  `TripHistoryService.recordTrip` (use different destinations per test).
- **The emulator.** AVD `Guidy_Screens` (Pixel 7 Pro). Start it hidden:
  `emulator -avd Guidy_Screens -qt-hide-window -no-audio -no-boot-anim -gpu host -no-snapshot-save`.
  Wait about 90 seconds after boot before touching the app: while Google Play services is
  still busy, the emulator drops frames and Guidy shows "isn't responding" (this is the
  emulator, not the app; it happened twice here, once while the PC was out of memory). Do
  not run a Gradle build and the emulator together. Location Accuracy is currently OFF on
  that emulator; switch it with
  `adb shell am start -a com.google.android.gms.location.settings.GOOGLE_LOCATION_SETTINGS`.
  The adb helper script and screenshots live in `Claude outputs/guidy_video/`, which is
  outside the repos.
- **Untracked scratch files** in `guidy-app-main`, not read and not committed:
  `crash.txt`, `testResults.xml`, `website/website.7z`. Delete or ignore them as the user
  prefers.
- **Memory tools.** The claude-mem observer ran out of allowance (first Claude, then
  Gemini), so nothing from this session was saved there. This file is the record.
- **The user's standing preferences** (they live in the previous assistant's memory, which
  a new one will not have): do not drive the user's PC with mouse/keyboard automation;
  Guidy's dark mode must keep the app's existing dark theme colours, not navy/blue shades;
  pull only from the production origin repos. Ask before anything outward-facing: pushes
  to `origin` were authorised by the user in this session; Play uploads, website deploys
  and server deploys were not.

### Still open

- Upload 1.0.11 (14) to Play (one flavour), with `release_notes_1.0.11.txt`.
- Update the Play store listing (it still says Cairo only, with 3 October screenshots): the
  draft text, a Play-ready screenshot set and step-by-step instructions are in
  `store_assets/1.0.11/` (read its `README.md`, which also lists screenshots that show
  outdated UI). Not uploaded. An Arabic listing does not exist yet.
- The explainer video was re-rendered on 2026-10-09 from build 14 (see
  `docs/handoffs/`; the file is `Claude outputs/Guidy_Explainer.mp4`, outside the repo). Its
  outro says "Available on Google Play": confirm the app is public before sharing it. A music/voiceover version and a 9:16 vertical cut were offered, not
  made.
- Cleanup of the production side effects from the screenshot session (one simulated trip,
  one live-share link, one guest consent), listed in section 3 of
  `docs/handoffs/guidy_video_HANDOFF_2026-10-08.md` (a copy of the file in
  `Claude outputs/guidy_video/`). Today's emulator checks added only a few short-lived live
  position reports for Metro 1, already expired. The user has not decided on the cleanup.
- Parked by the user: ENR trains and Port Said.
- If wanted: measure the recent-trips lag before/after on a real phone, and check the
  Location Accuracy fix on one.

## 000. Update 2026-10-08 (evening): Terms, privacy and website for two cities

- Terms and privacy policy (en/ar), effective 8 October 2026: Greater Cairo
  and Alexandria plus the intercity microbuses; APTA added to "not
  affiliated with"; fares can be our estimates and microbus fares depend
  on distance; open-data credits (TfC CC BY 4.0, APTA, OpenStreetMap).
  `LegalConsentService.currentVersion` = 2026-10-08: everyone is asked to
  agree again on 1.0.11 (13).
- Website copy: two cities, counts 697 / 359 / 214 lines, 5,177 stops.
  Committed and pushed, NOT deployed: run `deploy_website.bat`.
- Test build is now **1.0.11 (13)** (`guidy-testads.aab`), replacing (12).

## 000. Update 2026-10-08 (later): app 1.0.11 (12), test ads -- superseded by (13) above

- `build/release/guidy-testads.aab` / `.apk`: 1.0.11 (12), Google TEST ads.
  "What's new": `release_notes_1.0.11.txt`. 1.0.10 (11) is live on Play.
- Lines card and detail: an Alexandria microbus shows "5 to 22 EGP" (it
  charges by distance), from the backend's new `fare_from_egp` (backend
  `lookups.py`; deploy it, or the app just shows the cap as before).
- The 14 new Alexandria lines come from the backend: they already appear in
  the Lines tab with the amber Alexandria pill (agency `ALX_*`).

## 000. Update 2026-10-08: more Alexandria lines and real Alexandria fares (deployed, pushed)

Backend `b4eb908`, live (`/api/health` 5,177 stops). No app change needed.
- **14 new Alexandria microbus/tomnaya lines** (`ALX_TT_`, third build
  `build_alexandria_terminal_routes.py`): TfC timed them at terminals but
  never traced them (catalogue datasets 91 + 12). Borg El-Arab is now
  reachable. Skipped: 6 unnumbered TfC buses, 2 duplicates, 1 bad detour.
- **Fares** (`alexandria_source/alex_fares.json`): buses and minibuses sell
  one ticket per line, microbuses charge by distance.
  - APTA buses: APTA's signed Oct 2024 tariff, still in force (no change
    in March 2026). Tier per line by length is ours: regular 4.5-5.5 (9
    past 40 km), AC/electric 9-20, double-decker 25.
  - Private minibuses (Minibus 1/4/5/20/25): 10 EGP, an ESTIMATE.
  - Microbuses: the governorate's distance bands, capped at the line fare.
    Intercity stays 140/143.
- 4 TfC terminal points added to `landmark_fixes.csv`; the Borg lines
  still need the in-between landmarks (New Borg El-Arab, Borg airport).
- **Parked by the user:** ENR trains, Port Said (community GTFS, CC BY-NC:
  needs the author's permission).

## 000. Update 2026-10-07 evening: deployed, pushed, 1.0.10 (11) built

- **Backend deployed** (`2ff8ae5`): two-city walking graph, Alexandria data
  (`/api/health` 4,795 stops), and a search fix: Cairo <-> Alexandria took
  ~18 s on the server (app timeout 15 s), now 5-9 s. The old walking-graph
  backup on the server is deleted.
- **Both repos pushed.**
- **App 1.0.10 (11) built** with real ads: `build/release/guidy-release.aab`
  (and `.apk`). Not uploaded to Play yet. "What's new" text in en/ar:
  `release_notes_1.0.10.txt`.
- TfC's catalogue (data.transportforcairo.com) was unreachable on 2026-10-07;
  its Cairo GTFS (document 88) is the feed we already use (checked against the
  Mobility Database copy). The other ~30 entries are still unchecked.

## 000. Update 2026-10-07: Alexandria + Cairo/Giza <-> Alexandria (now pushed and deployed, see above)

Nothing is pushed or deployed. Commits are local on `main` in both repos:
- backend `f84864a..d3d5591`
- app `68ccf26..42d5e75`

Design: `guidy-backend-main/docs/superpowers/specs/2026-10-07-alexandria-transit-design.md`.
Sources and how to rebuild: `guidy-backend-main/alexandria_source/README.md`.

**What riders get**

Alexandria data:
- **101 TfC-surveyed lines** (2022 survey, CC-BY): 74 microbus, 13 tomnaya, 9 APTA buses, 5 minibus.
- **61 official APTA lines rebuilt from APTA's own landmark lists.** These include bus 13, which now follows the Corniche.
- **32 APTA lines are still skipped.** `alexandria_source/apta_missing_landmarks.csv` lists the landmark blocking each one, with a Google Maps link.
  - The fix needs someone local. Copy the coordinates from Google Maps into `landmark_fixes.csv` (columns `landmark_ar,lat_lon,name_en,note`), then re-run both builds. The steps are in the README.
- **No trams.**

Intercity microbuses, Cairo/Giza <-> Alexandria (Mawqaf El-Gedid, Moharam Bek):
- **From:** Aboud and Ramses (Cairo), Munib (Giza).
- **Fares:** 140 EGP (Cairo) and 143 EGP (Giza). These are fact-checked: the Oct 2025 tariff (122/125) plus the 14–17% rise of March 2026. The 200–400 EGP heard anecdotally is above the official tariff.
- **Ride time:** 3h15–3h20. Tahrir -> Raml comes out at about 4h15 and about 147 EGP.

Alexandria fares:
- Microbus fares come from the March 2026 tariff.
- **APTA buses still use the Cairo estimate (20/45 EGP).** No current official figure was found.

App (needs a new release; older versions still work with the new backend):
- **Place search** is biased around the rider's location, or toward both cities when their location is unknown.
- **The map picker** opens where the rider is.
- **Lines screen:**
  - Alexandria lines carry an amber "الإسكندرية" pill, and intercity lines a blue "القاهرة ⇄ الإسكندرية" pill. Cairo and Giza cards are unchanged.
  - Microbus lines with a fare of their own show it instead of "10–15 EGP".
- **Release notes:**
  - Older app versions list Alexandria lines without the pill.
  - Older versions also show "10–15 EGP" for intercity and Alexandria microbuses.

**Cairo is unchanged, by construction.**
- **What the review found:** an independent code review found that a Cairo trip ending near Aboud changed its Recommended option, because the intercity stops entered the candidate search.
- **The fix:** a trip with neither end in Alexandria now never sees Alexandria's routes or stops.
- **Tests:**
  - `TestCairoIsolation` compares answers with and without Alexandria, including around Aboud, Ramses and Munib, in Arabic and English, by day and at night.
  - `TestTranslationsConsistent` guards the Arabic labels (Cairo's "Minibus 1" had been relabelled).
  - Backend: 514 tests pass. The only failure is the Windows-only `os.fork` test, as before. App: 499 pass.

**Review files** are in `guidy-backend-main/alexandria_source/` and now open correctly in Excel:
- `alexandria_validation.csv`
- `alexandria_names_review.csv`: 268 stop names are my translations, `verified=0`.
- `apta_skipped_lines.csv`
- `apta_missing_landmarks.csv`

**Deploy, in this order** (your SSH key has a passphrase, so these run from your terminal):

1. Walking graph. The script does the following:
   - refuses to start without about 2 GB of free RAM or 3 GB of disk;
   - builds the new graph beside the live one;
   - checks a walk in each city;
   - swaps it in, keeping the old graph as a backup;
   - checks the live service, rolling back by itself if that fails.

   The crop is already prepared from OSM data of 2026-10-06. It also refreshes Cairo's walking network, so Cairo walk times can shift slightly.

   `scp osrm_two_city/cairo.osm.pbf osrm_server_update.sh root@202.61.197.114:~/guidy-backend-main/`, then
   `ssh root@202.61.197.114 "cd ~/guidy-backend-main && bash osrm_server_update.sh"`
2. Backend code and data:
   - `scp raptor_engine.py lookups.py .dockerignore root@202.61.197.114:~/guidy-backend-main/`
   - `scp gtfs_data/*.txt gtfs_data/alex_route_fares.json gtfs_data/osrm_edge_cache.json root@202.61.197.114:~/guidy-backend-main/gtfs_data/`
   - Then `ssh root@202.61.197.114 "cd ~/guidy-backend-main && chown -R 10001:10001 gtfs_data && docker compose up --build -d backend"`.
3. Check: `/api/health` should report 4,795 stops (it was 3,280). Then plan Tahrir -> Raml Station in the app.
4. Push both repos to origin once you're happy.

## 0000. Update 2026-10-06: review of everything since 1.0.8, fixes pushed

Everything since 1.0.8 was reviewed (app `877e4ec..`, backend `adf1082^..`,
website demo `a5350d8`) and the real bugs fixed, each with a test that failed
first. Both repos are pushed. App: 486 tests pass, `flutter analyze` clean.
Backend: 470 pass (the one failure is the Windows-only `os.fork` test).
Website: 27 pass, oxlint clean, checked in a browser before and after.

- **CI was not flaky, it was failing twice since Oct 4:** `legal_consent_test`
  loaded Roboto from the Flutter SDK cache, which CI's Flutter lacks (now the
  app theme + bundled fonts, `d74fc5b`); `history_screen_layout_test` was a
  real bug, trips recorded in one millisecond shared an id, so two cards had
  one key and deleting one deleted both (`9200033`). Section 6's "flaky
  history test" note was this.
- **App:** RouteOptionsScreen had the same map-after-dispose crash as
  LineDetail (`77a03a7`); no banner ad in the floating window (`3c3629c`);
  sharing a trip, opening a browser or settings no longer drops Guidy into
  the floating window on Android 8-11 (`71889cc`, FLAG_ACTIVITY_NO_USER_ACTION
  while a trip is on screen). **Compiled but not tried on an Android 8-11
  phone: check "Share live trip" mid-trip there.**
- **Backend (deployed 2026-10-06 by the user, `656e157`):** ride reports are
  bounded (planned_step ≤ 4 KB, queue ≤ 50 MB then 503, damaged lines
  skipped, flock across the gunicorn workers) and unlinked on account
  deletion (`1518291`); a share stored with Infinity no longer 500s
  (`9b1082d`); a short-ride card whose walking twin is dropped is no longer
  left with no Recommended card (`656e157`). Deployed with the Oct 4 work
  (`adf1082`..`43151fb`): scp of crowd_routes, lookups, main, raptor_engine,
  ride_reports, share_live, user_gtfs_overlay, then `docker compose up
  --build -d backend` (build context 461 kB; `/api/health` ok, 3280 stops).
  Note: `docker compose up --build` without the scp first just rebuilds the
  old files. Still worth doing: time route search p95 (`qa/prod_api.py`),
  since walking alternatives are now built for more paths.
- **Website (deployed 2026-10-06, bundle `index-C1o3HJMF.js`):** the demo's
  tour stops when a visitor reaches in and has Pause/Play, focus stays in the
  demo, "How it works" cards are valid, plus smaller a11y fixes (`b9a4bc7`).
  Checked live: the new bundle, no console errors, assetlinks.json (JSON, 3
  fingerprints), `/l/...`, legal pages, `/ar`, `/features` all 200.
  `npm audit`: 0 in shipped deps; 1 high in `source-map-js` (build tool only).
  Not done: `firebase.json` sends no-cache for the hashed `/assets/**` too;
  a long immutable rule would help, but check how Hosting merges header
  rules first so `index.html` stays no-cache.
- **1.0.9 (10) rebuilt with all of the above** (2026-10-06 19:09-19:14,
  `build/release`): `guidy-testads.apk/.aab` (Google test units only) and
  `guidy-release.apk/.aab` (the real banner + app-open units, checked in the
  snapshot). The test-ads APK is installed on the user's Xiaomi (Android 13)
  over wireless debugging; it replaced the Play-installed 1.0.8, so that
  phone gets no Play updates until Guidy is uninstalled again. It launched
  clean (no crash, no Flutter errors; first-run tour, test banner).
  Xiaomi needs the on-phone "Install via USB" prompt tapped within a few
  seconds, or adb reports INSTALL_FAILED_USER_RESTRICTED.
- **Left (minor):** ~650 KB of bundled font faces are never loaded (the
  theme fakes bold); the Arabic ETA chip can clip at large text; the ETA
  double-counts when a step has no coordinates; TextPainters in guidy_ui.dart
  aren't disposed; the tour promises the floating window on phones without
  it; a card can read "Alternative · Fastest"; 1.0.8's local saved trips stay
  until sign-out; `crowdLow/Medium/High` strings are unused;
  `website/website.7z` is untracked and not ignored.

## 000. Update 2026-10-06: console audit and Crashlytics fixes, pushed

`main` is pushed (`00bb902`): `4b1e327` map crash fix, `00bb902` bundled fonts.
481 tests pass locally and `flutter analyze lib test` is clean. **Not in
`build/release` yet**: that 1.0.9 (10) build predates both; rebuild before
uploading.

- **CI is out:** the free monthly Actions minutes are used up, and the artifact
  storage quota is full (each push uploads a debug APK). Verify locally until
  they reset. CI also fails one test that passes locally, from before these
  commits: `legal_consent_test` "sign-up fits on one phone screen without
  scrolling".
- **Crashlytics** (30 days: 6 open crash issues, all from 1.0.0-1.0.5, none
  since 1.0.6):
  - fixed now: "GoogleMapController ... used after the GoogleMap widget had
    already been disposed" in LineDetailScreen and RailNetworkMapScreen; the
    fonts.gstatic.com download failing offline (fonts are now in
    `assets/google_fonts/`, OFL licences beside them and on the licence page);
  - already fixed: WorkDatabase launch crash (`3698690`);
  - left alone: `Element.widget` null check (InkWell -> MediaQuery) and
    `DraggableScrollableController._onExtentReplaced`. Their stacks are
    Flutter-only and they appeared in 1.0.0 only.
  - Close all six once 1.0.9 ships; Crashlytics reopens any that come back.
- **Console audit (read-only), fine:** deployed Firestore rules = `firestore.rules`
  (Sep 27); budget "Guidy spend tripwire" $10/month with alerts; Play developer
  account has no policy issues; `/api/health` ok. Every Maps key is restricted.
  The 30-day metrics show a few rejected calls to Geocoding, Elevation, Static,
  Street View, Time Zone and Routes (someone trying the key from the APK);
  the restrictions held. "Routes API test" is the key
  `route_comparison_audit.py` uses; keep it.
- **"API key 2"** is restricted to the app but carries neither Play app-signing
  SHA-1 (§4); its SHA-1s are `10:35:3F...`, `18:17:EF...`, `DF:7D:F0...`. So only
  sideloaded debug/upload-signed builds (1.0.0-1.0.5 testers) could use it.
  Check Metrics -> Group by: Credential -> 30 days before deleting it.
- **Left for the user** (the permission classifier blocked console changes):
  disable the unused Maps APIs (Solar, Weather, Map Management, Isochrones,
  Maps 3D Android/iOS, Grounding Lite, Navigation Connect, Places Aggregate,
  Places UI Kit, Street View Publish, Street View Static, Time Zone; keep Maps
  SDK Android/iOS, Places API (New), Routes); decide on "API key 2"; check
  the app's Play policy status (only the account-level page was checked).
- **Also fixed (`4e1fcbb`, another session):** the rail station sheet
  overflowed on short screens (32 px at 800x600).
- **For map-screen tests:** `test/support/fake_google_maps_platform.dart`.
  A `GoogleMap` reports in through `onMapCreated` after `viewCreationDelay`,
  as on a phone, and the fake records every camera move by map ID.

## 00. Update 2026-10-06 (later): test sweep and cleanup, both repos pushed

Both `main` branches are pushed to `origin`. **The backend is not deployed**:
pushing runs CI only, so the fixes below reach riders after a deploy on the
server (DEPLOYMENT.md). `build/release` was rebuilt after the cleanup (test-ads
and real-ads, still 1.0.9 (10)).

- **Backend fixes:** request bodies refuse NaN / Infinity (one `eta: Infinity`
  used to 500 a live share's public view for good); SQLite connections in
  `share_live.py` / `crowd_routes.py` are closed (they were left to the GC);
  route search maps ٠-٩ to 0-9 (`٦٥` found nothing) and a query of only
  emoji/punctuation finds nothing instead of the first routes; `fcntl` is
  optional, so trip logs and their tests run on Windows. Local suite: 460
  passed, 1 Windows-only failure (mocks `os.fork`).
- **Backend cleanup:** 8 one-off scripts removed (incl. `stress_test_harness.py`,
  which targeted production). The feed-building pipeline and QA sweeps stay.
  QA scripts write UTF-8 and use repo-relative paths.
- **App cleanup:** RouteReportScreen, AnimatedNavStepIcon, `lib/models.dart`,
  110 unused strings, `cupertino_icons` and 11 uncalled helpers removed.
- **Saved trips:** their screens were already gone; the app no longer saves,
  caches or syncs them (every sign-in used to read and write
  `users/{uid}/saved_trips`). Sign-out still clears older versions' local
  copy and account deletion still deletes the cloud copy. Riders' existing
  cloud docs stay until they delete their account. 475 tests pass,
  `flutter analyze` clean (bar the untracked `tool/preview`).
- **Not run:** `qa/prod_api.py` against the live API (the permission
  classifier blocked production reads). Run it after the deploy.
- **Untracked clutter still on disk** (the classifier blocked recycling it):
  8 `gtfs_data.backup-*` folders (216 MB), two `crash.txt`, two Sep-21
  `guidy.apk`, two Guidy zips in the workspace root.

## 0. Update 2026-10-06: version 1.0.9 (10) on `main`, not pushed

Built (signed, TEST ads): `build/release/guidy-testads.apk` / `.aab`. Not yet
tried on a phone: check GPS smoothness on a walk, the rider arrow near
buildings, and leaving the app mid-trip (floating window).

- **Ads:** real units need `--dart-define=GUIDY_REAL_ADS=true` as well as the
  unit IDs. Only `build_release.ps1 -RealAds`, `run_app.ps1 -RealAds` and the
  CI release workflow pass it. Everything else serves Google's test ads.
- **Live trip:** Android GPS is 1 fix/s (the plugin default was 5 s). The dot
  snaps to the nearby stretch of route within 12-20 m. The card shows live
  minutes / distance left / arrival (`lib/utils/trip_eta.dart`). 3D buildings
  are off on the trip map (they hid the flat rider arrow).
- **Picture-in-picture (Android):** `MainActivity.kt` + `lib/services/trip_pip.dart`.
  It's a count of trip screens, so switching routes keeps it on. Not possible on iOS.
- **Tutorial:** `lib/widgets/guidy_tour.dart`. It runs once on first launch and once
  on the first trip, and Settings → Replay tutorial runs it again. Tests turn
  auto-start off in `test/flutter_test_config.dart`.
- **Search:** Home/Work/saved-place chips for either field, a pin button on both.
  The "Drop pin for destination" row is gone.
- **Pin names:** never a house number (`MapsLinkParser.placeNameFromReverse`).
- **Removed:** the commute budget / pass calculator.
- **Known, not done:**
  - the ETA leaves out the wait while still at the stop;
  - the floating window shows whatever screen is on top;
  - a tall tutorial card can run off-screen;
  - the trip screen rebuilds every second while a ride report records.

## 1. Where things stand

- **Version 1.0.7 (8)** is uploaded to **Closed testing → Alpha** and sent for
  review, together with the store listing, App content and store settings.
  Wait for Google's review email.
- **The review was not approved yet** when this was written. If it comes back
  rejected, the email names the policy and the fix.
- Versions 1.0.5 (6) and 1.0.6 (7) were built but never uploaded. Version
  codes only need to go up, so the gap is fine.
- `main` is pushed and clean (`origin/main` = the commit that adds this file).
  The backend repo had no changes this session.

## 2. Next steps

1. **Testers.** Closed testing → Alpha → Testers: add an email list or Google
   Group and share the opt-in link. A personal developer account needs **at
   least 12 testers opted in for 14 days in a row** before it can apply for
   production access, and the 14 days only start once they opt in.
2. **After approval, on a Play-installed copy:** Google sign-in, the map (not
   blank), a shared `guidyapp.com/r/...` or `/l/...` link opening the app, log
   out right after a guest sign-in, and the one-time "agree to the updated
   policies" prompt (consent version is now `2026-10-03`).
3. **AdMob:** link the Android app to its Play listing once it's published
   (MANUAL_QA_CHECKLIST.md §8).
4. **Optional:** add an Arabic store listing (the English text is in
   `Guidy Assets/Play Store/store_listing_en.txt`, outside this repo).

## 3. What changed this session (all on `main`)

| Commit | What |
|---|---|
| `fc69a8c` | Data-deletion page: how to delete some data without deleting the account (en + ar) |
| `b42549d` | Privacy policy: the "follow my trip" live sharing feature (en + ar), effective 3 Oct 2026 |
| `95ece13`, `5aa62ee` | `assetlinks.json`: both Play app signing keys |
| `c4c531e` | **Bug fix:** Log Out did nothing after signing in during the same session. The sign-in screens replaced `AuthGate` (the only sign-in listener) via `pushReplacementNamed('/home')`. `/home` and `/signin` are now `AuthGate` itself. Also bumps `LegalConsentService.currentVersion` to `2026-10-03`, which `legal_consent_test` requires whenever a policy's effective date changes. |
| `c16e2e5` | Guests see "Delete Guest Data" (they are real anonymous Firebase accounts holding consent records) |
| `ae1d309` | Sign-in has no terms checkbox; a new Google/guest account meets `LegalConsentGate` right after. Sign-in fits one screen. |
| `f5a02da` | Sign-up fits one screen: the password checklist shows only while focused or while the password breaks a rule |
| `0b98acf`, `7da4dab` | Versions 1.0.6+7 and 1.0.7+8 |

The website (guidyapp.com, Firebase Hosting `guidy-19e46`) is deployed with all
of the above. Don't use `deploy_website.bat` from a feature branch: it ends with
`git push origin HEAD:main`.

## 4. Play app signing — two keys

Play Console shows an app signing key **in use** plus a **previous** one (a
"quantum-ready" key). The first Play-installed build was signed with the
previous one. Both are registered everywhere:

| Key | SHA-1 | SHA-256 |
|---|---|---|
| A (signed the first Play build) | `E0:69:90:1F:7F:A8:39:29:C8:AD:88:BE:1E:A1:2A:64:30:47:ED:E8` | `52:D9:B6:EB:EA:99:9D:1A:47:D5:6C:DE:25:3D:4A:32:11:0B:80:8F:79:A4:8F:50:7F:B0:43:BE:01:23:BD:C4` |
| B (in use now) | `9C:CC:C1:D8:0D:A0:51:00:A6:9E:C4:C6:FE:5D:44:88:A8:0B:E5:CF` | `22:8F:E2:33:B0:B9:D5:00:2E:82:21:6C:6E:9E:38:F3:36:5D:F3:FC:F3:17:2A:6B:15:04:9C:C1:1F:37:63:D1` |

Registered in: Firebase Android app `com.guidy.guidy_app` (SHA-1 + SHA-256 of
both); Cloud project `guidy-19e46` → "Android key (auto created by Firebase)"
(SHA-1 of both — Firebase Auth/Firestore use it); Cloud project `guidy-maps` →
"Guidy Android (Maps + Places)" (SHA-1 of both); `assetlinks.json` (SHA-256 of
both). The upload/release key (`02:32:B6:...`) and the debug keys are still there.

`guidy-maps` also has an older Android key, "API key 2", that was left alone.
If the Play-installed map is ever blank, check which key `MAPS_API_KEY_ANDROID`
in `secrets.properties` actually is.

## 5. Play Console answers given (in case they need editing)

- **Content rating:** all No, except Miscellaneous → "shares precise location
  with other users" = **Yes** (live trip sharing).
- **Target audience:** 18 and over.
- **Data safety:** collected — name, email, user IDs (account); precise
  location (routing, live position, trip logs); approximate location, device
  IDs (shared with AdMob for advertising); app interactions, other actions,
  crash logs, diagnostics. Encrypted in transit. Account deletion and
  partial-deletion URL: `https://guidyapp.com/data-deletion`.
- **Advertising ID:** Yes — Advertising or marketing, Analytics.
- **Category:** Maps & Navigation. Contact `info@guidyapp.com`, website
  `https://guidyapp.com`.
- **Play Integrity API:** not set up; the app doesn't use it.

## 6. Landmines

- `history_screen_layout_test` failed once in a full run and passed every
  rerun, with and without changes — flaky, not a regression.
- The Android emulator (`Medium_Phone_API_36.1`) is starved at its default
  2 GB and throws "not responding" dialogs; start it with `-memory 4096`.
- The user's Xiaomi phone blocks `adb shell input` unless "USB debugging
  (Security settings)" is on; screenshots and logcat work without it.
- Release builds use Google's TEST ad units by default (`build_release.ps1`);
  build with `-RealAds` to serve real ads and earn revenue.
- Store screenshots (8, 1080x1920) and the icon/feature graphic are in
  `C:\gemini workspace\Guidy Assets\Play Store\`, not in this repo.
