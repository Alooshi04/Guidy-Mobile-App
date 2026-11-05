import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:app_links/app_links.dart';
import '../l10n/app_localizations.dart';
import '../screens/LiveTripViewerScreen.dart';
import '../screens/LocationSearchScreen.dart';
import '../screens/RouteOptionsScreen.dart';
import 'maps_link_parser.dart';
import 'places_service.dart';
import 'share_links.dart';

/// Everything that opens Guidy from outside:
///
///  * Guidy's own share links (https://guidyapp.com/r and /l/..., and the older guidy-19e46.web.app ones,
///    or guidy://...): a shared route opens the routes screen, a live trip
///    opens the live viewer. See ShareLinks.
///  * Map links and coordinates: tapped (Android "Open with" for
///    maps.google.com / maps.app.goo.gl / geo:, see AndroidManifest.xml),
///    or sent to Guidy with the Share button in WhatsApp, Google Maps or
///    any other app (Android ACTION_SEND, delivered by MainActivity over
///    the "guidy/shared_text" channel). Either way the place becomes the
///    destination of a new search.
///
/// A link that arrives before the person has signed in is kept and opened
/// right after sign-in (it used to be dropped).
///
/// Why "Share to Guidy" matters more than tapping: Android sends taps on
/// Google Maps links straight to the Google Maps app, which owns those
/// links; the Share sheet always lists Guidy. See README_DEEP_LINKS.md.
class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();
  static const MethodChannel _sharedText = MethodChannel('guidy/shared_text');
  static StreamSubscription<Uri>? _subscription;
  static StreamSubscription<User?>? _authWait;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static void initialize(GlobalKey<NavigatorState> navigatorKey) {
    _navigatorKey = navigatorKey;
    // Already-running app: link tapped while Guidy is in the background/foreground.
    _subscription = _appLinks.uriLinkStream.listen((uri) {
      handleText(uri.toString());
    }, onError: (err) {
      debugPrint('[DeepLink] stream error: $err');
    });

    // Cold start: app launched fresh BY tapping the link.
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) handleText(uri.toString());
    });

    // Text shared to Guidy from another app (Android).
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _sharedText.setMethodCallHandler((call) async {
        if (call.method == 'onSharedText' && call.arguments is String) {
          handleText(call.arguments as String);
        }
      });
      _sharedText.invokeMethod<String>('getInitialSharedText').then((text) {
        if (text != null && text.isNotEmpty) handleText(text);
      }).catchError((_) {});
    }
  }

  /// Opens whatever [text] points to: a Guidy link, a map link or
  /// coordinates (on their own or inside a message). Does nothing
  /// otherwise.
  static Future<void> handleText(String text) async {
    if (FirebaseAuth.instance.currentUser == null) {
      // Opened before signing in: open it right after.
      await _authWait?.cancel();
      _authWait = FirebaseAuth.instance.authStateChanges().where((u) => u != null).take(1).listen((_) {
        _authWait = null;
        Future.delayed(const Duration(milliseconds: 1200), () => handleText(text));
      });
      return;
    }

    final navState = _navigatorKey?.currentState;
    if (navState == null) return;

    final guidy = _guidyLinkIn(text);
    if (guidy != null) {
      _openGuidyLink(navState, guidy);
      return;
    }

    final parsed = await MapsLinkParser.parseOrLookup(text, _findPlaceByName);
    if (parsed == null) {
      debugPrint('[DeepLink] no place found in: $text');
      return;
    }

    final navContext = navState.context;
    // `mounted` matters here, not just null: parsing the link was an await,
    // and the navigator can be gone by the time it returns.
    if (!navContext.mounted) return;

    // This runs outside any widget's build, so the navigator's own context
    // is the only place to read localizations from. Without it the fallback
    // place name for an unresolvable pin came back in English.
    final l10n = AppLocalizations.of(navContext);
    final String lang = Localizations.localeOf(navContext).languageCode;

    final name = parsed.name ??
        await MapsLinkParser.reverseGeocodeName(parsed.lat, parsed.lon,
            fallbackLabel: l10n.pinnedLocation, lang: lang);

    navState.push(MaterialPageRoute(
      builder: (_) => LocationSearchScreen(
        initialEndLocation: {'name': name, 'full_name': name, 'lat': parsed.lat, 'lon': parsed.lon},
      ),
    ));
  }

  static GuidyLink? _guidyLinkIn(String text) {
    for (final m in RegExp(r'(https?://|guidy://)\S+').allMatches(text)) {
      final uri = Uri.tryParse(m.group(0)!);
      final link = uri == null ? null : ShareLinks.parse(uri);
      if (link != null) return link;
    }
    return null;
  }

  static void _openGuidyLink(NavigatorState nav, GuidyLink link) {
    switch (link) {
      case LiveShareLink(:final token):
        nav.push(MaterialPageRoute(builder: (_) => LiveTripViewerScreen(token: token)));
      case RouteShareLink():
        nav.push(MaterialPageRoute(
          builder: (ctx) {
            final l10n = AppLocalizations.of(ctx);
            return RouteOptionsScreen(
              startLat: link.startLat,
              startLon: link.startLon,
              startName: link.startName.isNotEmpty ? link.startName : l10n.pinnedLocation,
              endLat: link.endLat,
              endLon: link.endLon,
              endName: link.endName.isNotEmpty ? link.endName : l10n.pinnedLocation,
              preferRouteIds: link.routeIds,
            );
          },
        ));
    }
  }

  /// A link that names a place but has no coordinates: look it up (one
  /// Places autocomplete + details call, the same as typing it).
  static Future<ParsedMapsLocation?> _findPlaceByName(String query) async {
    try {
      final token = DateTime.now().microsecondsSinceEpoch.toString();
      final results = await PlacesService.autocomplete(query, token);
      if (results.isEmpty) return null;
      final first = results.first;
      final coords = await PlacesService.getPlaceDetails(first['placeId'].toString(), token);
      if (coords == null) return null;
      return ParsedMapsLocation(lat: coords['lat']!, lon: coords['lon']!, name: first['name']?.toString());
    } catch (_) {
      return null;
    }
  }

  static void dispose() {
    _subscription?.cancel();
    _authWait?.cancel();
  }
}
