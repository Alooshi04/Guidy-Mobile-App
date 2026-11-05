# Play Console "Data safety" checklist, Guidy 1.2.0

What the app collects/shares as of 1.2.0, to tick in Play Console → App content → Data safety.
Encrypted in transit: **Yes** (HTTPS everywhere). Users can request deletion: **Yes** (account deletion / info@ email; confirm the URL you list).

| Data type (Play category) | Collected | Shared | Purpose | Optional? | Notes |
|---|---|---|---|---|---|
| **Precise location** | Yes | No (processed by our backend only) | App functionality (routing, live trip) | Yes: only with the location permission | Used on the phone for navigation. A **GPS trace of a trip is uploaded only if the rider answered "Share"** on the one-time ask or turned on Settings → "Share my trips" (default OFF since 1.2.0). Walk-path traces follow the same switch. |
| **Approximate location** | Yes | No | App functionality | Yes | Same permission group. |
| **Email address** | Yes | No | Account management | No (sign-in) | Firebase Authentication (email, Google sign-in). Name/photo come from Google sign-in if used. |
| **Name** (Google sign-in) | Yes | No | Account management | Yes | Only if the user signs in with Google. |
| **User IDs** | Yes | Shared with Google (Firebase/AdMob) | Analytics, app functionality, fraud prevention | No | Firebase Auth UID; random per-install ID (`X-Guidy-Install`, 32 hex chars, not tied to the account) used for rate limiting. |
| **App interactions** | Yes | Shared with Google (Firebase Analytics) | Analytics | Consent-gated | Screen views, route-calculated events. Off until consent is resolved (see below). |
| **Crash logs / diagnostics** | Yes | Shared with Google (Crashlytics) | Analytics / app stability | Consent-gated | Release builds only. Off until consent is resolved. |
| **Device or other IDs** | Yes | Shared with Google (AdMob) | Advertising | Consent-gated | Advertising ID, only when UMP consent allows ads. |
| **Saved places, trip history** | Yes | No | App functionality | Yes | Stored in Firestore under the account (Home, Work, saved places, history). |
| **Photos, contacts, financial info, health, messages, audio** | No | – | – | – | – |

## Consent behaviour (1.2.0)
- Firebase Analytics and Crashlytics are **disabled by default** in `AndroidManifest.xml` / `Info.plist` and switched on only after Google's UMP answer allows it (`canRequestAds`: consent given, or not required in the user's region). Withdrawing consent in Settings → Ad privacy switches them off again.
- Builds made with `-NoAds` have no consent form, so analytics and Crashlytics stay **off** unless built with `--dart-define=GUIDY_TELEMETRY=true` (internal testing only).
- Advertising: the app shows ads (AdMob). Declare "Contains ads: Yes". Ad ID use is declared under "Advertising or marketing".

## To confirm in the form
- [ ] "Data is collected, shared or both" → yes.
- [ ] Location: collected, optional, not shared; mark the trip upload as "optional, user-controlled".
- [ ] Analytics/crash/ad IDs: shared with Google as service providers.
- [ ] Privacy Policy URL: the website's current policy; make sure its text matches this table (trip sharing is now opt-in).
- [ ] Advertising ID declaration: yes, for advertising.
