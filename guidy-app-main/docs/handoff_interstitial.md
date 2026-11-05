# Handoff: trip-end interstitial (H) and rewarded banner hide (I)

Branch `feat/interstitial-rewarded` (merged with origin/main incl. PR #57). Nothing has been run on a device or emulator; no build was completed.

## Done (code written)
- `lib/services/ad_service.dart`: `interstitialAdUnitId`, `rewardedAdUnitId` via `optionalUnit` (Google test units; real unit only in `-RealAds` builds, null if missing).
- `lib/services/interstitial_policy.dart`: pure cap logic (`canShow`): not first trip, >=2 h gap, <=2 per local day, not within 5 min of app-open ad, future timestamps count as recent.
- `lib/services/interstitial_ad_service.dart`: preload (`MapScreen.initState`), `recordArrival()` (at arrival, counts trips, sets eligibility), `showAfterTrip()` (called when the rider taps Done/History on the arrival sheet; skipped if not loaded, PiP, no consent, `-NoAds`). Persists times in SharedPreferences (`interstitial_shown_ms`, `interstitial_completed_trips`). Uses `AppOpenAdService.instance.lastShownAt` (PR #57).
- `lib/services/banner_hide_service.dart`: 24 h hide, persisted (`banner_hidden_until_ms`), injectable clock, ignores expired or >24 h-away stored values; `BannerHideService.instance.load()` is called in `main()` before `runApp`.
- `lib/widgets/app_banner_shell.dart`: banner not built while hidden.
- `lib/services/rewarded_ad_service.dart` + `lib/widgets/hide_banner_tile.dart`: Settings row (above "Ad privacy settings"); loads the rewarded ad on tap; snackbars for done / not watched / unavailable. Hidden when no rewarded unit.
- l10n: `removeBanner*` keys in both ARBs, generated files updated.
- `run_app.ps1`, `build_release.ps1` (optional units, warns if missing), `.github/workflows/release.yml`: both new keys wired like native.
- Tests: `test/interstitial_policy_test.dart`, `test/banner_hide_test.dart` (passed before the merge).

## Decisions
- Ad shows at Done/History on the arrival sheet (after the rider read "you have arrived"), not over the sheet itself and not in `TripRecapScreen` (untouched).
- Swiping the sheet away shows no ad (conservative).
- Rewarded ad is loaded on demand only; reward hides the banner immediately; native cards/other formats unaffected.
- `secrets.properties` is tracked in git and modified locally: never commit it.

## Cloud session (finished the code)
- Merged origin/main (PR #58) into the branch.
- `showAfterTrip()` waits for a pending `recordArrival()` (fast tap on Done) and for `NavigationSession` to end (MapScreen is disposed only after the pop transition, up to 2 s), so the ad never covers navigation; re-checks PiP after that.
- `InterstitialAdService` takes an injectable app-open time; new `test/interstitial_ad_service_test.dart` (first trip, persisted trip count, app-open window, stored gap/daily cap, one chance per trip).
- `HideBannerTile` shows a spinner while the rewarded ad loads and ignores taps meanwhile.
- `main()` refreshes the banner hide on resume (`AppLifecycleListener`).
- `flutter gen-l10n` produced no content change. `flutter analyze` clean on changed files; tests listed below all pass.

## Left (device check on the PC)
1. Emulator with TEST ads (AVD `Guidy_Screens`, not emulator-5554): first trip after a fresh install shows no interstitial; second trip shows one after Done/History, once the map has closed; a third within 2 h shows none. Settings row -> rewarded test ad -> banner disappears, tile shows "hidden until"; closing the ad early shows "the banner stays"; airplane mode shows "no ad available"; restart keeps the banner hidden. Screenshots light+dark, EN+AR to `C:\gemini workspace\Claude outputs\ad_spots\implemented\`. Never tap a non-rewarded ad.
2. GitHub secrets needed for CI: `ADMOB_INTERSTITIAL_AD_UNIT_ID_ANDROID`, `ADMOB_REWARDED_AD_UNIT_ID_ANDROID` (until then both features are off in release builds).
3. Review and merge the PR after the device check; delete the worktree `C:\gemini workspace\worktrees\interstitial`.
