# Guidy Manual QA Checklist

Pass for release 1.0.4 (5), Android only, 2026-09-30. iOS is out of scope
for this release; its items are marked N/A.

- [x] = verified: by hand, against the live server, or by an automated test
  (named where it matters).
- [ ] = still to do on a phone. Everything left needs a person: sign-in
  accounts, the Google picker, ads and notification prompts.

---

## 1. Does it even build?

- [x] `flutter pub get` completes with no errors
- [x] `flutter analyze` — zero issues in `lib/` and `test/`
- [x] Release build: `build_release.ps1` (real ads) → `build/release/guidy-release.aab` and `.apk`, versionCode 5, signed with the upload key in `assetlinks.json`, no Google test ad units in the binary
- [x] Release APK launches on a real Android phone without a crash (crash log empty)
- [x] `flutter test` — 381 passing
- N/A iOS build and launch

## 2. Auth flows (all on a phone)

Before testing guest login: Firebase Console → Authentication → Sign-in
method → Anonymous must be on.

- [ ] Email/password sign up → account created, lands in the app
- [ ] Sign up with an already-used email → clear error, not a crash
- [ ] Sign in with correct credentials
- [ ] Sign in with a wrong password → clear error
- [ ] Google Sign-In completes and lands in the app — **on the Play-installed build too** (Play re-signs the app; its SHA-1 must be in Firebase, see section 8)
- [ ] Google Sign-In cancelled midway → back to sign-in, no crash
- [ ] Continue as Guest → lands in the app
- [ ] Guest session survives an app restart
- [ ] Settings shows "Guest" when signed in anonymously
- [ ] Sign out → back to sign-in, nothing left from the previous session
- [ ] Delete Account (email user) → asks for the password, deletes, back to sign-in
- [ ] Delete Account (Google user) → Google picker again, deletes, back to sign-in
- [ ] Delete Account (guest) → deletes directly, back to sign-in
- [ ] Delete Account can be cancelled without deleting anything
- [ ] After deleting, signing in again with the same email/Google gives a new, empty account

## 3. Routing / core functionality

- [ ] Search a start location by name, results appear
- [ ] Gibberish search → "No places found", not stale history or a blank screen
- [x] Recent searches show when the field is empty, and "Clear history" clears them (`location_search_screen_test`)
- [x] Start + destination → at least one route option (live API, `qa/prod_api.py`: 8 trips × 2 languages)
- [ ] Metro, bus and microbus/minibus legs show the right icon and colour
- [x] Multi-leg routes list every leg in order and the lines join up (QA sweep, 1,760 trips: 0 `starts_badly` / `ends_badly` / `arrive_not_second_last` / `segment_gap`)
- [x] Fare total matches the legs (QA sweep: 0 `fare_sum_mismatch`)
- [ ] Tapping a route shows full turn-by-turn instructions
- [ ] The map shows the actual route path
- [x] Start = destination doesn't crash (live API: returns a walk card)
- [ ] Denying location permission still lets you pick a start point manually
- [ ] Trip recap shows fare, time and distance
- [ ] Live navigation: tool rail (overview, menu fold, share, report), compass / recenter / stop alarm under it; nothing hidden under the sheet

## 4. Localization (English / Arabic)

- [x] Switching language changes the whole app, no restart (`language_switch_test`, `redesign_review_fixes_test`)
- [x] Language button on every screen except Home and the search screen; line names, line detail and the metro picker reload in the new language (`redesign_review_fixes_test`)
- [x] Back and forward arrows point the right way in Arabic (`redesign_review_fixes_test`, preview renders)
- [x] Every English string has an Arabic one (`l10n_coverage_test`)
- [x] No overflow in Arabic on search, settings and the Lines screens (widget tests); previews of every tab reviewed in both languages
- [ ] Fonts: Almarai for Arabic, Nunito Sans for English. They download on first launch (not bundled), so check once online; offline first launch shows the system font until then.
- [x] Metro stations and line names in real Arabic (live API; QA sweep: 0 `latin_station_in_arabic`, 0 `ar_en_differ`)

## 5. Visual / branding

- [x] Launcher icon is the Guidy "G" mark (`mipmap-*/ic_launcher.png`)
- [ ] Icon looks right on the home screen: there is no adaptive icon, so some launchers shrink it into a white shape
- [x] Colours and dark mode reviewed on preview renders of every screen, both languages; dark mode keeps the app's own dark palette
- [ ] Map dark style looks right on the phone

## 6. Ads / tracking / notifications (Android)

- [ ] Banner ad shows in its slot. **Real ad units don't serve yet**: AdMob answers "Publisher data not found" (error 3) until the app is published on Play and linked in AdMob (section 8). Never tap ads on your own phone.
- [x] `https://guidyapp.com/app-ads.txt` published with the AdMob publisher ID
- [ ] Notification permission prompt appears; granting it works
- [ ] Denying notifications doesn't break anything
- N/A iOS App Tracking Transparency items

## 7. Backend / deployment

- [x] `https://api.guidyapp.com/api/health` → ok over HTTPS
- [x] The release build calls `https://api.guidyapp.com/api` (build log)
- [x] Rate limiting: 20 simultaneous route requests → 18 × 200, 2 × 429, none 5xx; normal again 3 s later
- [x] OSRM reachable in production: walking legs follow streets (9–13 points), not straight lines
- [x] Backend survived a redeploy (2026-09-30) with its GTFS data
- [x] Live-API checks `qa/prod_api.py` (backend repo, updated for the live domain): 49/49 pass

### Routing QA sweep (backend `qa/sweep.py` + `qa/checks.py`, 2026-09-30)

1,760 trips (landmarks, stop pairs, reverse, Arabic, night, Friday, each
filter): every trip answered, no partial cards, same answer twice. Compared
against the backend without the short-hop fix, same data: the fix cut
"many changes" from 17 cases to 3 and "Recommended pays much for little"
by 3, added none, and costs no time (15 slowest trips: 63.5 s vs 63.7 s).

What the checker still flags, and why it is not a bug:
- Recommended 20+ EGP dearer than Cheapest for little time (90): in 71 the
  cheap card walks 500 m+ more (median 1.5 km, often past the 2.5 km limit
  for Recommended); the other 19 are at the chosen rate of ~2 EGP per
  minute saved (`RECOMMENDED_SEC_PER_EGP`).
- Beaten card shown (560): cards on other lines are kept as Alternatives on
  purpose (backend commit ec904a1); the checker predates that.
- Long walks (673 / 582): mostly Cheapest cards, allowed to walk further
  when the walk pays for itself.
- Night trips recommending a closed line (117): the "usual route, opens at
  6 AM" card beside what runs now (`night_service`).
- Slower than walking (21): measured on the straight line; walking the
  streets is ~1.3x longer.

Real, known: 139 bus/minibus boardings show no line number, because the
feed has none for those corridors (data, not engine).

## 8. Play Console / accounts (before submitting)

- [x] **Play App Signing** (done 2026-10-04; both Play signing keys, see HANDOFF.md): Google re-signs the app. Copy the *app signing key* SHA-256 and SHA-1 from Play Console → Test and release → App integrity, then:
  - add the SHA-256 to `website/public/.well-known/assetlinks.json` (next to the upload key) and redeploy the site, or shared links won't open the app;
  - add the SHA-1 to the Android restrictions of the Maps API key in Google Cloud, or the map can be blank in the Play-installed app;
  - add the SHA-1 to the Android app in Firebase, or Google Sign-In fails.
- [ ] AdMob: link the Android app to its Play listing once published, and make sure the listing's website is `https://guidyapp.com`.
- [ ] Confirm `info@guidyapp.com` receives mail (the domain's mail goes to Zoho; the mailbox itself wasn't tested). It is the contact on the app and all legal pages.
- [ ] Privacy policy URL in the listing: `https://guidyapp.com/privacy`; data deletion: `https://guidyapp.com/data-deletion`.
- [ ] Data safety form matches the privacy policy (location, account, analytics, crash reports, ads ID).

---

## Bugs found while running this list

- 2026-09-30 (section 3, real trip): Fair Zone → Salsa Koshary offered minibus 66 then a second minibus for one stop at 20 EGP more. Fixed in the backend (`_short_hop_trims` / `_drop_short_hops`, `test_short_hops.py`), deployed.
- 2026-09-30 (section 4): a line's detail page and the metro station picker kept the old language after the in-page language switch. Fixed in the app.
