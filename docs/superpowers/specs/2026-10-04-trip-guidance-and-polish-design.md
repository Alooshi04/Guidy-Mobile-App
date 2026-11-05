# Trip guidance, short-ride policy, ride logging and app polish

Date: 2026-10-04. Approved in chat. Spans `guidy-app-main` and `guidy-backend-main`.

Built in three batches, A → B → C. Each batch is tested and committed on its own.

## Batch A: app polish

### A1. Tool rail layout (`lib/widgets/guidy_tool_rail.dart`)
- Today the top row is `[lead][menu]`, with the menu at the screen edge, and the items column sits under `lead` on the inner side.
- New layout: the top row is still `[lead][menu]`, but the items column sits under `menu`, against the screen edge.
- The rail is laid out with start/end positions, so RTL mirrors it automatically.
- Folded state is unchanged: only the menu tab shows.
- The painter's L-shape is mirrored to match.

### A2. Remove the first-run intro cards
- `StartupGate` (`lib/main.dart`) always routes to `AuthGate` after the splash. `OnboardingScreen` is no longer shown.
- `main.dart` currently waits until onboarding has been seen before asking for analytics consent. That check is rewired so consent is still asked once.
- The animated splash with the logo stays.

### A3. Settings opens at the top
- `SettingsScreen` lives in `MainNavigator`'s `IndexedStack`, so it keeps its scroll position between visits.
- Fix: give it a `ScrollController`. When the Settings tab is selected, `MainNavigator` tells Settings to jump to offset 0.

### A4. Test ads in release builds
- `build_release.ps1` gets a `-TestAds` switch, on by default.
- When on, the build ignores the AdMob IDs in secrets.properties, so `AdService` falls back to Google's test units.
- Turn it off to serve real ads and earn revenue.

### A5. Real name instead of "Current location"
- Reuse the free Nominatim reverse geocode in `maps_link_parser.dart`, with `accept-language` set to the app locale.
- Label format: "street, area" (or the place name).
- Show "Current location" while the lookup runs and keep it if the lookup fails.
- Cache results by coordinates rounded to ~50 m.
- Applies on: HomeScreen's start location, CommuteBudgetScreen, and the trip start name passed to MapScreen.
- `RouteOptionsScreen` must still treat this start as "the rider's position". It must not depend on the label text; it uses a flag in the location map instead.

## Batch B: live trip

### B1. Step advancement that doesn't need the exact point
- New pure function `NavMath.progressStep(here, stepPolylines, current)`:
  - Projects the GPS fix onto each step's polyline from `current` onward.
  - Returns the furthest step whose polyline is within 60 m of the fix.
  - Never returns a step earlier than `current`.
- In MapScreen:
  - The existing check (within 100 m of the next step's point) still advances immediately.
  - Otherwise, advance to the step `progressStep` returns once the same answer comes back on 2 GPS fixes in a row.
  - Several steps may be skipped at once. Each skipped step is recorded with `_recorder.onStep`.
- Tests:
  - Passing 150 m to the side of a transfer point.
  - Riding straight past a stop without coming near its point.
  - GPS jitter must not advance the step.
  - The step never moves backwards.

### B2. Clear cards
- Backend: every `board`/`transfer` instruction gets these new fields:
  - `alight_station`, `alight_station_en`, `alight_station_ar`: where to get off.
  - `ride_m`, `ride_min` (traffic included), `stops_count`.
  - `alight_lat`, `alight_lon`.
- Backend: every walk instruction gets `walk_min`, at the engine's walking pace.
- App cards:
  - Ride: "Ride Minibus 66 toward X → get off at Y · ~12 min · 5 stops".
  - Walk: "Walk 700 m · ~9 min".
- Live readouts while on a step:
  - Ride: "Get off at Y in ~4 min". This is the distance left on the ride divided by the ride's planned speed (`ride_m / ride_min`).
  - Walk: "~3 min left" at walking pace.
- Merging: a "walk to transfer" step straight after a ride is shown as "Get off at Y, walk N m to Z". The steps themselves stay separate in the data; only the wording changes.
- Alternative-vehicle choices for a ride are drawn inside that ride's card, never as a separate instruction.

## Batch C: routing and data

### C1. Short-ride policy (`raptor_engine.py`)
- Rule: for any ride in a trip (first, middle or last), work out the walking distance that would replace it:
  - straight-line distance from where you'd board to where you'd get off, × 1.25.
  - For a first or last ride, measure from the trip's start or to its end instead.
- If that walk is ≤ 1.5 km:
  - The trip that walks it instead must exist among the options and be the recommended one.
  - The trip with the ride is kept, labelled "faster", with the extra fare shown.
- This replaces the `SHORT_HOP_WORTH_MIN` time test.
- Constant: `SHORT_HOP_WALK_M = 1500`.
- Tests: synthetic short first, middle and last hops, plus the Koshary Tawagen Salsa → FMI Helwan trip from the report.

### C2. "I took a vehicle" during long walks
- App:
  - On any walk step of 1.5 km or more, the card shows "I took a vehicle".
  - The sheet asks for the vehicle type (microbus, tuk-tuk, bus, taxi, other) and the fare in EGP.
  - Recording keeps the GPS points, the distance and the elapsed time.
  - It stops when the rider taps "I got off" or when they rejoin the planned route.
  - The report is posted with the Firebase ID token, if there is one.
- Backend:
  - `POST /api/ride_reports` is rate-limited and validates the body: points capped at 2000, fare 0–500, and the vehicle type from a fixed list.
  - The rider is identified by a hashed uid, the same way `crowd_routes` does it.
  - Each report is appended to `gtfs_data/crowd/ride_reports.jsonl` with a timestamp.
  - `python ride_reports.py list` prints the queue.
  - Nothing changes routing automatically.

### Learning from riders: current state (no change)
- `crowd_routes.py` rebuilds every 6 h from trips by signed-in riders. It learns:
  - Where a line's vehicle actually drives between two stops (at least 20 riders, at least 60% share, riders' paths must agree).
  - How long each stretch between two stops takes (median of riders' times).
- It does not learn which line riders choose, new lines, or fares.
