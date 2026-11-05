# Guidy explainer video and bugs found: handoff (2026-10-08, updated 2026-10-09)

> **Status on 2026-10-09:** the four app bugs in section 2 are all FIXED, pushed to
> `origin/main` of `guidy-app` (commits `0fa0312..4975927`) and in build 1.0.11 (14).
> The full account is the top entry of `guidy-app-main/HANDOFF.md`. Sections 1, 3 and 4
> below are still useful; section 5 was wrong and has been corrected.
> **Video re-rendered on 2026-10-09 from build 1.0.11 (14).** Six screenshots were retaken
> because they showed the old UI (`05_navigate`, `07_trip_steps`, `09_report`,
> `17_metro_planner`, `18_network_map`, `19_fares`); the old ones are kept in
> `shots_v2_before_1.0.11-14/` and the previous video is `Guidy_Explainer_before_1.0.11-14_ui.mp4`.
> Still not retaken: `08_share_live` (it shows the OLD tool rail, dimmed, behind the share
> sheet; retaking it would create another live-share link on production), `06_trip_map` and
> `20_station` (not used by the video). The new shots were taken with GPS about 400 m from
> Sadat, so the current step reads "Walk to Sadat" and live tracking sends nothing to the
> server. They also show the new empty 50 dp ad strip under the bottom bar.

## 1. What was delivered

| File | What it is |
|---|---|
| `Claude outputs/Guidy_Explainer.mp4` | **Current video.** 1:14, 1920x1080, 30 fps, H.264, no audio, light-mode app screens only. |
| `Claude outputs/Guidy_Explainer_old_build.mp4` | First version (49 s), made from the old Play Store screenshots. Superseded. |
| `guidy_video/make_video_v2.py` | Renders the current video. Run `python make_video_v2.py` (about 4 min), or `--stills <dir>` for one frame per scene. |
| `guidy_video/make_video.py` | Script for the old version. Kept for reference only. |
| `guidy_video/shots_v2/` | 39 screenshots of build 1.0.11, 1440x3120, light mode, clean 9:30 status bar, no ad banner. |
| `guidy_video/emulator_helper.sh` | adb helper: `look`, `save NAME`, `tap x y`, `swipe`, `text`, `key`, `ui` (lists labelled elements with their centres). |
| `guidy_video/gps_path_tahrir_to_cfc.txt` | 162 GPS fixes (lon lat) along the real Tahrir to Cairo Festival City route, used to simulate a full trip. |

Video scenes, in order (all 14 on one sheet: `explainer_video_scenes_overview.webp`, next to this file; it shows the app as it was BEFORE the 2026-10-09 fixes):
1. Intro
2. The problem
3. Meet Guidy (seven modes; Greater Cairo and Alexandria)
4. Step 1, search
5. Step 2, mixed-mode routes
6. Step 3, compare
7. Step 4, step-by-step riding
8. Ride tools: live share, report, floating window, stop alert
9. Trip savings
10. Lines (359 bus, 697 microbus)
11. Two cities, with Alexandria
12. Metro and rail
13. Made for you: Arabic, Simple mode, saved places, guest or sign in
14. Outro

The live-share link in `08_share_live.png` is blurred in the video, in `load_shot()`.

**Still open with the user:**
- **Outro wording:** it says "Available on Google Play". Keep it only if the app is public on Play; otherwise change it in `scene_outro()`.
- **Not done yet (offered):** background music or voiceover, and a 9:16 vertical version.

## 2. Bugs found in the app (guidy-app-main): ALL FIXED on 2026-10-09

How each was fixed (file and line numbers below are from before the fix):
- **Bug 1:** the cause is now confirmed in geolocator_android's `FusedLocationClient.startPositionUpdates`: every request shows Google's resolution dialog, and a decline comes back as `LocationServiceDisabledException`. Fixed with `lib/services/location_fallback.dart`: after the first decline all requests use Android's LocationManager. The trip's separate one-off fix request (a second prompt) was removed. Checked on the emulator: one prompt, declined, never returned, trip ran normally.
- **Bug 2:** ICU plurals in `app_en.arb` / `app_ar.arb`.
- **Bug 3:** the pill now sits under the title (`MetroScreen.dart`, `below:` of `GuidyHeader`).
- **Bug 4:** the banner slot keeps its height when the first ad load fails (`banner_ad_placeholder.dart`), so nothing shifts. The cost is an empty 50 dp strip where ads never load.

### Bug 1: the Location Accuracy prompt loops during a trip (most important)

**Repro**
1. Use an Android device with Google Location Accuracy turned off.
2. Start any trip.
3. Google's prompt "For a better experience, your device will need to use Location Accuracy" appears.
4. Tap **No thanks**. The prompt comes straight back, every time.

The trip screen is unusable until the rider gives in. During the emulator session this also starved the app until it hit "Guidy isn't responding" (under software rendering).

**Code involved**
- `lib/utils/nav_math.dart:153`, `navLocationSettings()`: an `AndroidSettings(bestForNavigation, intervalDuration: 1s)` stream for trips.
- `lib/screens/MapScreen.dart:1103` and `:1216`: `getCurrentPosition(high, timeLimit 4s/5s)`.
- Also `HomeScreen.dart:105`, `:163` and `LocationSearchScreen.dart:361`.

**Likely cause (unconfirmed):** geolocator's fused-provider path runs a location-settings check and shows the resolution dialog on each new request or stream subscription. The app keeps re-requesting after a decline.

**Fix direction**
- Remember a decline for the session and stop triggering the dialog. One option is `forceLocationManager: true` or a lower accuracy after a decline.
- Optionally show a small in-app hint instead.
- Add a test.

### Bug 2: "1 changes" in the Metro Planner

- **Where:** `lib/l10n/app_en.arb:689` has `"metroChangesCount": "{count} changes"`, used at `lib/screens/MetroScreen.dart:452`. Helwan to Cairo University shows "1 changes".
- **Fix:** make it an ICU plural, e.g. `{count, plural, =1{1 change} other{{count} changes}}`.
- **Arabic:** `app_ar.arb:218` (`"{count} تغيير"`) should get plural forms too. Then regenerate l10n.

### Bug 3: the "Network Map" pill overlaps the "Metro Planner" title

- **Where:** `lib/screens/MetroScreen.dart:252-256`, where the header title is followed by trailing `_networkMapButton()` (`:198`).
- **Where it was seen:** a 411 dp wide phone (Pixel 7 Pro). The title is cut off at "Metro Planne…" under the pill.
- **Fix:** let the title shrink, ellipsize or wrap, or move the pill out of the title row. Check both English and Arabic.

### Bug 4: the ad placeholder shifts the layout after a cold start

- **Where:** `lib/widgets/banner_ad_placeholder.dart:182-195` shows a 50 px "Advertisement" box while the ad loads. When loading fails it collapses to `SizedBox.shrink()` (`:169-177`).
- **Effect:** the bottom nav and content jump a few seconds after launch, so a tap aimed at one control lands on another. On Settings in Simple mode, a tap meant for a tab hit **Contact us** and opened Gmail.
- **Fix direction:** keep the space reserved, or animate the collapse, or don't show the placeholder until an ad is actually loaded. There's a trade-off with the "banner never flashes empty" goal in `app_banner_shell.dart`.

### Minor observations, not necessarily bugs

- In Arabic, recent-trip cards keep place names in English, because names were saved while the app was in English.
- In `/route` for Tahrir to Cairo Festival City, the app first showed only two options (Recommended=Cheapest, Fastest). Later the API returned three (Recommended, Fastest, Cheapest). This is probably live data or traffic changing.

## 3. Side effects on production from the screenshot session

Everything ran as a **guest on an emulator** against the live backend (`api.guidyapp.com`). Clean these up if you want clean data:
- **Simulated trip:** one completed trip, Tahrir Square to Cairo Festival City Mall, around 17:24 on 2026-10-08, made by feeding fake GPS along the route. `TripRecorder.finish` likely posted a trace (`/live/submit_trace`), and Firebase Analytics logged a trip completion.
- **Live-share session:** one created, link `guidyapp.com/l/wh33…`.
- **Guest consent:** a terms acceptance recorded for the emulator's guest.
- **Nothing sent:** no emails or messages. Gmail and Google hum-to-search were opened by misclicks and closed without doing anything.
- **2026-10-09 (the fix-checking session), also as a guest on the emulator:** two trips were started (Tahrir Square to Cairo Festival City, current step "Ride Metro 1") and not finished, so no trace was submitted and no trip was completed. While the Metro leg was current, the app's live tracking sends the GPS position to `/api/live/position` (Metro 1, at Tahrir Square) every 8 to 30 seconds; that is a few ephemeral crowd-sourced "vehicle" reports. The server drops them 90 seconds after the last one: `live_vehicles_tracked` read 0 afterwards. The emulator was shut down mid-trip, so no explicit `/live/end` was sent. Nothing else left the emulator.

## 4. Emulator setup, for retakes

- **AVD `Guidy_Screens`:** Pixel 7 Pro, 1440x3120 at 560 dpi, Android 36.1 Play Store image, 4 GB RAM.
- **Launch hidden with the GPU:** `emulator -avd Guidy_Screens -qt-hide-window -no-audio -no-boot-anim -gpu host -no-snapshot-save`. With `-no-window` it falls back to software rendering, which is far too slow for the map.
- **Settings inside the emulator only:**
  - Play Store disabled, so it stops auto-updating Google Play services, which kills the app.
  - Private DNS set to `dns.adguard-dns.com`, which blocks AdMob so the banner collapses.
  - Location Accuracy: OFF since 2026-10-09 (to reproduce Bug 1). Turn it back on for screenshots with `adb shell am start -a com.google.android.gms.location.settings.GOOGLE_LOCATION_SETTINGS`, then tap "Location Accuracy" and the switch.
  - Light mode.
- **After each boot, reapply demo mode:** `settings put global sysui_demo_allowed 1`, then the `com.android.systemui.demo` broadcasts: clock 0930, battery 100, `mobile hide`, wifi level 4, notifications hidden.
- **APK:** `guidy-app-main/build/release/guidy-testads.apk`. The `shots_v2` set was taken with the 8 Oct 13:21 build, 1.0.11 (13). The file there now is 1.0.11 (14), built 9 Oct 09:07, and is what is installed on the emulator.
- **Stability:** after boot, wait about 90 seconds before touching the app. While Google Play services is busy the whole emulator drops frames and Guidy shows "isn't responding" (it happened twice on 9 Oct, once with the PC out of memory). Never run a Gradle build and the emulator together: close the Gradle daemon first (`android\gradlew.bat --stop`, then end the leftover `java` process).
- **GPS:** `adb emu geo fix <lon> <lat>`. Feed it every 2 s, or trips show "Lost GPS signal". Arrival needs the last step plus being within 60 m of the destination.
- **Accuracy prompt:** on an emulator with Location Accuracy off, the trip screen hits Bug 1 above.

## 5. Not touched

(Corrected 2026-10-09.) When this was first written, `guidy-app-main` had uncommitted changes from another session (the `pubspec.yaml` bump to `1.0.11+14` and CRLF-only l10n changes) and this video work touched no repo. Today those were committed with the bug fixes and everything is pushed to `origin/main` in both repos. The scratch files `crash.txt`, `testResults.xml` and `website/website.7z` are committed too. The backend was never changed by this work.
