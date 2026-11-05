# Play Store listing assets for 1.0.11 (prepared 2026-10-09)

Nothing here has been uploaded. The listing on Play is still the one from early October
(Cairo only). These files are ready to upload by hand.

## What is here

| File | What it is |
|---|---|
| `store_listing_en_1.0.11_DRAFT.txt` | New short (78 of 80 characters) and full (2,243 of 4,000) description: Greater Cairo and Alexandria, intercity microbuses, the Alexandria filter, APTA prices, distance-based microbus fares. |
| `store_listing_en_CURRENT_on_play_before_1.0.11.txt` | The text that is on Play now, for comparison or to roll back. |
| `screenshots/01..08_*.png` | Eight phone screenshots, 1080x2160, 24-bit PNG without alpha, which meets Play's rules. Taken on the emulator from build 1.0.11 (13), light mode, clean status bar. |

## Where the other assets are (outside this repo, on the original PC)

- `C:\gemini workspace\Guidy Assets\Play Store\`: `app_icon_512.png` (512x512),
  `feature_graphic_1024x500.png`, the old 8 screenshots (1080x1920, 3 Oct), and this same
  text and screenshot set. The icon and feature graphic need no change: the graphic has
  only the logo and a street scene, no text about Cairo.
- `C:\gemini workspace\Claude outputs\guidy_video\shots_v2\`: all 39 raw screenshots
  (1440x3120, RGBA). Play REJECTS these as they are: the height is more than twice the
  width, and PNGs must have no alpha. The set in `screenshots/` was made from them by
  converting to RGB, cropping to exactly 2:1 (120 px off the top and bottom, or 240 px off the
  bottom for the two retaken shots), and scaling to 1080x2160.
- `C:\gemini workspace\Claude outputs\Guidy_Explainer.mp4`: the explainer video, re-rendered
  on 2026-10-09 from build 14 (the old UI is gone from it). Play takes a YouTube link, not a
  file. Its outro says "Available on Google Play": only share it once the app is public.

## Known problems with these screenshots

Updated 2026-10-09 after the fixes. `04_navigate.png` (new horizontal tool rail) and
`06_metro.png` (full "Metro Planner" title, "1 change") were retaken from build 1.0.11 (14).
`01` to `03`, `05`, `07` and `08` were taken from build 13 and show screens that did not
change. What to know:
- The new shots were taken with GPS about 400 m from Sadat (current step "Walk to Sadat")
  and show the new empty 50 dp ad strip under the bottom bar, cropped to the 2:1 Play limit.
- The Lines landing screen in `05_lines_alexandria.png` is the bus list, so it does not show
  the new Alexandria chip; the chip sits under the search bar on the landing page.
- Still old-UI in `shots_v2/` (not used here): `06_trip_map.png`, `08_share_live.png`,
  `10_pip.png` (old L-shaped rail) and `20_station.png` (removed fare icon behind the sheet).
To retake more: see "The emulator" in `HANDOFF.md`, then `emulator_helper.sh save NAME`
(outside the repo). The convert step: RGB, crop to exactly 2:1 (for shots with a bottom bar,
crop 0 px off the top and 240 px off the bottom of 1440x3120), scale to 1080x2160.

## How to update the listing in Play Console

Menu names change now and then, so look for the same words.

1. Open the app, then **Grow users > Store presence > Main store listing** (it may be
   called "Store presence > Main store listing").
2. **App name**: leave as `Guidy`.
3. **Short description**: paste the SHORT DESCRIPTION line from the draft.
4. **Full description**: paste everything under FULL DESCRIPTION.
5. **Phone screenshots**: delete the old ones and upload `screenshots/01..08` in order
   (2 to 8 are allowed). Play wants JPEG or 24-bit PNG, each side 320 to 3,840 px, and the
   long side at most twice the short side.
6. Icon and feature graphic: leave as they are.
7. Optional: **Promo video** takes a YouTube URL.
8. **Save**, then go to **Publishing overview** and **Send changes for review**. Listing
   changes are reviewed on their own, separately from an app release, and can go live before
   or after 1.0.11 (14).
9. Optional, and not done yet: an **Arabic** listing under **Manage translations**
   (Main store listing, language selector). Only the English text exists.

Do not mention anything in the listing that the app does not do yet. The draft was checked
against the app on 2026-10-09 (two cities, the Alexandria filter, APTA prices, distance-based
microbus fares, the Cairo to Alexandria microbuses).
