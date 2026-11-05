# Google Maps links: what actually works here, and why

Two separate features, easy to conflate but genuinely different:

1. **Paste a Google Maps link or coordinates into the search bar** —
   fully implemented, works identically on Android and iOS. See
   `lib/services/maps_link_parser.dart`.
2. **Tap a Google Maps link elsewhere and have it open in Guidy** —
   partially implemented, Android only, and even there it's "Guidy shows
   up as an option" rather than "Guidy opens automatically." This doc is
   mostly about explaining that gap and why it exists.

## Why #2 can't fully work, on either platform

Both Android App Links and iOS Universal Links — the mechanisms that let
an app become the *automatic* handler for a web URL — require proving
you own the domain in the link, by hosting a verification file
(`assetlinks.json` on Android, `apple-app-site-association` on iOS) at
that exact domain. `maps.google.com`, `www.google.com`, and
`maps.app.goo.gl` are Google's domains. Nobody else can complete that
verification for them, on either platform, ever — this isn't a
configuration gap, it's the mechanism working as designed to stop random
apps from hijacking traffic to domains they don't control.

## What's actually implemented (Android)

`AndroidManifest.xml` registers Guidy for `android.intent.action.VIEW`
on:
- `geo:` URIs — Android's own standard scheme for map coordinates, and
  the one most likely to actually surface Guidy in an "Open with"
  chooser, since it's a scheme Android treats as OS-standard rather than
  a browsable https URL Chrome/the Google Maps app may claim by default.
- `https://maps.google.com`, `https://www.google.com/maps/...`,
  `https://maps.app.goo.gl/...` — registered without `autoVerify`, since
  auto-verification would just fail (see above). Practically, this means
  Android *may* offer Guidy in a disambiguation dialog for these links
  when there's no single app Android considers the definite default —
  it will not make Guidy the automatic handler, and if the real Google
  Maps app is installed and set as default, Android will likely route
  there without ever asking.

When Guidy does receive one of these (via `app_links`, see
`lib/services/deep_link_service.dart`), it parses out coordinates
(preferring an embedded pin location over the map's viewport center — a
Maps link can have both, and they're not always the same point) and
opens the search screen with that as the destination.

## What's NOT implemented: the Share Sheet path

The more reliable version of "open a Maps link in Guidy" is via the OS
Share Sheet — someone taps **Share** on a location in Google Maps (or a
browser, or a chat app) and picks Guidy from the list. Unlike the
intent-filters above, `ACTION_SEND` always shows a full app chooser with
no "default app" for Guidy to lose out to.

This was deliberately left out here, not forgotten: doing it properly
needs a real native iOS Share Extension (a second Xcode target, an App
Group for passing data between the extension and the main app,
entitlements) that has to be built and tested directly in Xcode — nothing
that can be verified without that toolchain. Adding the Android manifest
entry for `ACTION_SEND` without also building the iOS half would leave a
platform inconsistency, and adding it on Android alone without a way to
actually receive the shared text in Flutter would put Guidy in the share
sheet and then do nothing when tapped — worse than not being there.

If this turns out to matter in practice, worth revisiting with a
maintained package (check current maintenance status before picking one
— this ecosystem has had some churn) and a real device to test the iOS
Share Extension against.

## Known simplification: pre-sign-in links

If someone taps a Guidy-routed Maps link before ever signing in, the
link is currently just dropped (see the comment in
`deep_link_service.dart`) rather than queued and replayed after sign-in
completes. This should be a rare timing case — it only matters for
someone who's never opened the app before and encounters a shared link
before onboarding — but it's a real gap, not an oversight to be
surprised by later.


## Update 2026-09-24: Share to Guidy, and Guidy's own links

- **Share to Guidy (Android) is now implemented.** An `ACTION_SEND`
  `text/plain` intent-filter plus `MainActivity.kt` pass shared text to
  Dart over the `guidy/shared_text` channel. `DeepLinkService` finds the map
  link or coordinates inside it (`MapsLinkParser.findInText`). Links that
  carry only a place name (`?q=Name&ftid=...`, common for shared places) are
  looked up with one Places autocomplete + details call. So: in WhatsApp,
  long-press the message, then Share, then Guidy; in Google Maps, Share, then Guidy.
- **iOS** still has no Share Extension. iPhone users paste the link into
  search, which already works.
- **Links that arrive before sign-in** are kept and opened after sign-in.
- **Guidy's own links**: `https://guidy-19e46.web.app/r?...` (a route) and
  `/l/TOKEN` (a live trip), see `lib/services/share_links.dart`. We own this
  domain, so Android verifies them (`autoVerify`,
  `website/public/.well-known/assetlinks.json` with the release key's SHA-256) and
  they open straight in the app. When they don't (app missing, iPhone),
  `open.html` tries `guidy://...` and falls back to the Play Store. When the
  app is published with Play App Signing, add Play's app-signing SHA-256
  (Play Console, App integrity) to `website/public/.well-known/assetlinks.json`.
- `flutter_deeplinking_enabled` / `FlutterDeepLinkingEnabled` are off: links
  go through app_links, not Flutter's router (which would push "/r" as a
  named route).
