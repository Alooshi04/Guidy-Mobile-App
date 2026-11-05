# Google Places Autocomplete: cost model and setup

Replaces the previous Nominatim (OpenStreetMap) location search with
Google Places Autocomplete (New) — see `lib/services/places_service.dart`
for the implementation and `lib/screens/LocationSearchScreen.dart` for
how it's wired into the UI.

## Why this doesn't (necessarily) cost much

Google bills Places by the **session**, not the keystroke — but only if
the client actually implements sessions correctly. Get it wrong (skip the
session token, reuse one across two different searches, or accidentally
request a Pro/Enterprise field in the Place Details call) and Google
silently reverts to billing every single Autocomplete request
individually, which can be 5-10x more expensive for the same usage.
This is the single most common way this API ends up costing far more
than expected — not the API being inherently pricey, but the session
mechanism being implemented wrong.

`PlacesService` in this codebase is built specifically to make that
mistake hard: session tokens are generated once per search (not per
keystroke) via `startSession()`, passed through every `autocomplete()`
call for that search, and consumed exactly once by `getPlaceDetails()`
when the person taps a result — which is the only call that can actually
cost money, and only requests the cheapest field tier (Essentials: just
`id`, `location`, `formattedAddress`, `displayName`).

**Current pricing** (Google Maps Platform, verified against the official
pricing docs as of August 2026 — confirm current rates in Cloud Console
before relying on this, Google revises these periodically):
- Essentials-tier SKUs (which is what a correctly-session-scoped
  Autocomplete + Place Details Essentials flow uses) get **10,000 free
  requests per month, per SKU**.
- Beyond that: Place Details Essentials is **$5.00 per 1,000** completed
  searches. That's the only line item that costs anything in the normal
  case — the Autocomplete keystroke requests within a properly-formed
  session fold into a separate free/near-free SKU.
- There is no longer a blanket $200/month credit (Google retired that in
  March 2025) — the per-SKU free tier above is what actually applies now.

Realistic math for a small-to-mid app: if every single trip search is a
*completed* search (person actually picks a result — abandoned searches
are cheaper, not more expensive, since they never reach the billable
Place Details call), the first 10,000 searches/month cost nothing, and
each one after that costs half a cent.

## What you need to do (none of this could be done from the sandbox this was built in)

1. **Enable "Places API (New)"** on the same Google Cloud project as the
   existing Maps SDK key — Cloud Console → APIs & Services → Library →
   search "Places API (New)" → Enable. This is a checkbox, not a new key;
   `PlacesService` reuses `MAPS_API_KEY_ANDROID`/`MAPS_API_KEY_IOS` from
   `secrets.properties`, already flowing into Dart via
   `--dart-define-from-file` (confirmed already wired for AdMob keys the
   same way — see `ad_service.dart`).
2. **Restrict that key properly** if it isn't already — Android app
   restriction (package name + SHA-1) / iOS app restriction (bundle ID),
   and API restriction limited to exactly the APIs it's used for (Maps
   SDK + Places API New). An unrestricted key is a real liability
   regardless of the billing model.
3. **Set a budget alert** — Cloud Console → Billing → Budgets & alerts.
   Even with sessions implemented correctly, set one anyway; it costs
   nothing and is the actual safety net if something changes later (a
   field mask gets accidentally widened, a future contributor adds a
   Pro-tier field, etc.).
4. **Watch the Cloud Console billing breakdown** by SKU after launch,
   specifically for a nonzero "Autocomplete Requests" line (as opposed to
   "Autocomplete Session Usage"). That specific SKU appearing at any real
   volume means sessions aren't being formed correctly somewhere and are
   reverting to per-keystroke billing — worth investigating immediately,
   not something to let ride.

## What NOT to change without re-reading this doc

- Don't add fields to `_essentialsFieldMask` in `places_service.dart`
  without checking which pricing tier they belong to first — one Pro or
  Enterprise field (ratings, hours, photos, phone, website, etc.) upgrades
  the *entire* Place Details request to that tier's price, not just the
  one field.
- Don't generate a new session token per keystroke, and don't reuse one
  across two different searches — both defeat the session discount
  entirely.
- Don't call `getPlaceDetails()` speculatively (e.g. preloading details
  for every visible suggestion) — only call it once, for the specific
  result the person actually taps.
