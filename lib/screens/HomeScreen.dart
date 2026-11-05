import '../widgets/trip/current_trip_card.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'LocationSearchScreen.dart';
import '../services/location_fallback.dart';
import 'LocationPickerScreen.dart';
import 'SavedPlacesScreen.dart';
import 'TripRecapScreen.dart';
import 'MainNavigator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/places_service.dart';
import '../services/account_service.dart';
import '../services/current_place_namer.dart';
import '../services/trip_history_service.dart';
import '../services/location_localizer.dart';
import '../services/transit_modes.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';
import '../utils/minutes_text.dart';
import '../services/simple_mode.dart';
import '../widgets/native_ad_card.dart';
import '../widgets/simple/simple_ui.dart';

/// What the app tour points at on Home (see MainNavigator).
class HomeTourKeys {
  final GlobalKey search = GlobalKey(debugLabel: 'tour_search');
  final GlobalKey quick = GlobalKey(debugLabel: 'tour_quick');
  final GlobalKey recent = GlobalKey(debugLabel: 'tour_recent');
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.tourKeys});

  final HomeTourKeys? tourKeys;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _currentLocationData;
  List<TripHistoryEntry> _recentTrips = [];
  AppLocalizations? _l10n;
  String? _userName;
  StreamSubscription<User?>? _userSub;

  /// Which of Home and Work the rider has saved (simple mode's two big
  /// buttons say "tap to choose" for one that isn't).
  final Map<String, bool> _slotSet = {'Home': false, 'Work': false};

  Future<void> _loadSlots() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final k in _slotSet.keys.toList()) {
        _slotSet[k] = prefs.getString(k) != null;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _loadSlots();
    _fetchCurrentLocationQuietly();
    _loadRecentTrips();
    _loadUserName();
    TripHistoryService.changeNotifier.addListener(_loadRecentTrips);
    try {
      _userSub = FirebaseAuth.instance.userChanges().listen((_) {
        _loadUserName();
      });
    } catch (_) {
      // Resilient fallback for testing or offline environments
    }
  }

  @override
  void dispose() {
    TripHistoryService.changeNotifier.removeListener(_loadRecentTrips);
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final name = await AccountService.getUserFirstName();
    if (mounted && name != _userName) {
      setState(() => _userName = name);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _l10n = AppLocalizations.of(context);
    _loadRecentTrips();
  }

  Future<void> _loadRecentTrips() async {
    final trips = await TripHistoryService.getHistory();
    // Same trips as already shown (the history is cached while unchanged):
    bool unchanged = trips.length == _recentTrips.length;
    if (unchanged) {
      for (int i = 0; i < trips.length; i++) {
        if (!identical(trips[i], _recentTrips[i])) {
          unchanged = false;
          break;
        }
      }
    }
    if (mounted && !unchanged) {
      setState(() => _recentTrips = trips);
    }
  }

  // Just resolves the person's current position to prefill the search
  // screen's start field. Uses Geolocator only (device GPS/OS location
  // services) -- no Google Maps API call is involved here, so this is free
  // regardless of Maps Platform billing.
  Future<void> _fetchCurrentLocationQuietly() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationFallback.fix(accuracy: LocationAccuracy.high),
      );
      // Searches from here on favour the rider's city (Cairo or Alexandria).
      PlacesService.rememberRiderLocation(position.latitude, position.longitude);
      if (mounted) {
        setState(() {
          _currentLocationData = CurrentPlaceNamer.place(
            lat: position.latitude,
            lon: position.longitude,
            fallbackLabel: _l10n?.myCurrentLocation ?? 'Current Location',
          );
        });
      }
    } catch (e) {
      // Silent -- the search screen falls back to asking for location itself.
      // A turned-down Location Accuracy prompt is remembered, so nothing
      // asks again.
      LocationFallback.noteError(e);
    }
  }

  Future<void> _openSearchScreen() async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, animation, secondaryAnimation) => LocationSearchScreen(
          initialStartLocation: _currentLocationData,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
    _loadRecentTrips();
  }

  // STANDARD TAP: Routes to the location
  Future<void> _handleQuickRoute(String key, String label) async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    String? savedData = prefs.getString(key);
    final l10n = AppLocalizations.of(context);

    if (savedData == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (context) => LocationPickerScreen(saveKey: key)));
    } else {
      final parts = savedData.split('|');
      final String name = parts[0];
      final double? lat = parts.length >= 3 ? double.tryParse(parts[1]) : null;
      final double? lon = parts.length >= 3 ? double.tryParse(parts[2]) : null;
      if (lat == null || lon == null) {
        // A corrupted saved place: let the rider pick it again.
        await prefs.remove(key);
        if (!mounted) return;
        await Navigator.push(context, MaterialPageRoute(builder: (context) => LocationPickerScreen(saveKey: key)));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.routingTo(name))));

      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          // Only the phone's settings can fix this one.
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(l10n.gpsRequiredToRoute),
            action: SnackBarAction(
              label: l10n.commuteNotifsOpenSettings,
              onPressed: Geolocator.openAppSettings,
            ),
          ));
          return;
        }
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: LocationFallback.fix(accuracy: LocationAccuracy.high),
        );
        if (mounted) {
          await Navigator.push(context, MaterialPageRoute(
            builder: (context) => LocationSearchScreen(
              initialStartLocation: CurrentPlaceNamer.place(
                lat: position.latitude,
                lon: position.longitude,
                fallbackLabel: l10n.myCurrentLocation,
              ),
              initialEndLocation: {'name': name, 'lat': lat, 'lon': lon},
            ),
          ));
          _loadRecentTrips();
        }
      } catch (e) {
        LocationFallback.noteError(e);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.gpsRequiredToRoute)));
        }
      }
    }
  }

  // LONG PRESS: Overwrites the saved location
  Future<void> _resetQuickRoute(String key, String displayLabel) async {
    final l10n = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.resettingLocation(displayLabel))));
    await Navigator.push(context, MaterialPageRoute(builder: (context) => LocationPickerScreen(saveKey: key)));
  }

  // Picks the right greeting for the current hour, personalized with the
  // user's name if signed in (e.g. via registration or Google Sign-In).
  String _greeting(AppLocalizations l10n) {
    return AccountService.formatGreeting(l10n, name: _userName);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: simpleMode,
      builder: (context, simple, _) => simple ? _buildSimpleHome(context) : _buildHome(context),
    );
  }

  /// Simple mode's Home: one question, one big button, then the few places
  /// a rider goes most. Everything is a labelled button of at least 56 dp;
  /// nothing needs a long press (Change is its own button).
  Widget _buildSimpleHome(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    Widget place(String key, IconData icon, String go, String label) {
      final saved = _slotSet[key] == true;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SimpleButton(
            key: ValueKey('simple_go_$key'),
            icon: icon,
            label: go,
            subtitle: saved ? null : l10n.simpleTapToChoose,
            onPressed: () async {
              await _handleQuickRoute(key, label);
              _loadSlots();
            },
          ),
          if (saved)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: ValueKey('simple_change_$key'),
                style: TextButton.styleFrom(minimumSize: const Size(64, SimpleModeController.minTarget)),
                onPressed: () async {
                  await _resetQuickRoute(key, label);
                  _loadSlots();
                },
                icon: const Icon(Icons.edit_rounded, size: 24),
                label: Text('${l10n.simpleChangePlace}: $label', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      );
    }

    final recent = _recentTrips.take(2).toList();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          key: const ValueKey('simple_home'),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            // The brand, calmly: the logo, the greeting in the app's display
            // face, and a short blue-to-amber rule. The one main button below
            // is well clear of the banner above all of this.
            Image.asset(
              context.isDark ? 'assets/images/logo_dark.png' : 'assets/images/logo_light.png',
              key: const ValueKey('simple_logo'),
              height: 30,
              fit: BoxFit.contain,
              alignment: AlignmentDirectional.centerStart,
            ),
            const SizedBox(height: 14),
            Text(_greeting(l10n),
                style: GuidyUi.display(context, size: 30, color: context.textPrimary)),
            const SizedBox(height: 10),
            Container(
              key: const ValueKey('simple_brand_rule'),
              height: 4,
              width: 88,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.brandBlue, AppColors.brandAmber]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const CurrentTripCard(),
            const SizedBox(height: 20),
            SimpleButton(
              key: const ValueKey('simple_where_to'),
              icon: Icons.search_rounded,
              label: l10n.simpleWhereToGo,
              primary: true,
              onPressed: _openSearchScreen,
            ),
            const SizedBox(height: 14),
            place('Home', Icons.home_rounded, l10n.simpleGoHome, l10n.quickAccessHome),
            const SizedBox(height: 10),
            place('Work', Icons.work_rounded, l10n.simpleGoWork, l10n.quickAccessWork),
            const SizedBox(height: 14),
            SimpleButton(
              key: const ValueKey('simple_saved_places'),
              icon: Icons.bookmark_rounded,
              label: l10n.simpleSavedPlaces,
              onPressed: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPlacesScreen()));
                _loadRecentTrips();
              },
            ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(l10n.simpleGoAgain,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary)),
              const SizedBox(height: 10),
              for (final trip in recent) ...[
                SimpleButton(
                  key: ValueKey('simple_again_${trip.id}'),
                  icon: Icons.history_rounded,
                  label: _localizeLocation(trip.endName, isArabic,
                      nameAr: trip.endNameAr, nameEn: trip.endNameEn, lat: trip.endLat, lon: trip.endLon),
                  subtitle: l10n.simpleFrom(_localizeLocation(trip.startName, isArabic,
                      nameAr: trip.startNameAr, nameEn: trip.startNameEn, lat: trip.startLat, lon: trip.startLon)),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LocationSearchScreen(
                          initialStartLocation: _currentLocationData,
                          initialEndLocation: trip.endLat == null || trip.endLon == null
                              ? null
                              : {
                                  'name': _localizeLocation(trip.endName, isArabic,
                                      nameAr: trip.endNameAr, nameEn: trip.endNameEn, lat: trip.endLat, lon: trip.endLon),
                                  'lat': trip.endLat,
                                  'lon': trip.endLon,
                                },
                        ),
                      ),
                    );
                    _loadRecentTrips();
                  },
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHome(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: false,
            floating: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            toolbarHeight: 0,
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // HERO CARD -- brand gradient, logo, greeting, tagline
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroCardGradient,
                    borderRadius: BorderRadius.circular(GuidyUi.radius),
                    boxShadow: GuidyUi.cardShadow(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Image.asset('assets/images/logo_dark.png', height: 24, fit: BoxFit.contain, alignment: AlignmentDirectional.centerStart),
                      const SizedBox(height: 16),
                      Text(
                        _greeting(l10n),
                        style: GuidyUi.display(
                          context,
                          size: 30,
                          color: Colors.white,
                          shadows: const [Shadow(color: Color(0x40000000), blurRadius: 1.9, offset: Offset(0, 3))],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(l10n.appTagline, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ],
                  ),
                ),

                // A trip in progress, kept here until it ends (see CurrentTrip).
                const CurrentTripCard(),

                const SizedBox(height: 18),

                // SEARCH BAR: the main action, so it is taller than the cards
                // under it and wears a thin edge in the brand's blue and amber.
                DecoratedBox(
                  key: widget.tourKeys?.search,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.brandBlue, AppColors.brandAmber]),
                    borderRadius: BorderRadius.circular(GuidyUi.radius),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: GuidyCard(
                      key: const ValueKey('home_where_to'),
                      onTap: _openSearchScreen,
                      radius: GuidyUi.radius - 2,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 44),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(l10n.whereTo,
                                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600, color: GuidyUi.heading(context))),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.brandBlue.withValues(alpha: context.isDark ? 0.18 : 0.12),
                              ),
                              child: const Icon(Icons.search, color: AppColors.brandBlue, size: 32),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                GuidySectionLabel(l10n.quickDestinationsLabel),

                Row(
                  key: widget.tourKeys?.quick,
                  children: [
                    Expanded(child: _buildQuickAccessCard(context, 'dest_home', "Home", l10n.quickAccessHome)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildQuickAccessCard(context, 'dest_work', "Work", l10n.quickAccessWork)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _quickAccessCardBody(
                        context,
                        'dest_saved',
                        l10n.quickAccessSaved,
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPlacesScreen()));
                          _loadRecentTrips();
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // RECENT TRIPS SECTION (Replaces Saved Commutes)
                _buildRecentTripsSection(context, l10n),

                const NativeAdCard(),
              ]),
            ),
          ),
        ],
            ),
          ),
        ],
      ),
    );
  }

  // `storageKey` is the stable English key used for SharedPreferences /
  // routing lookups; `displayLabel` is the localized text shown on screen.
  Widget _buildQuickAccessCard(BuildContext context, String icon, String storageKey, String displayLabel) {
    return _quickAccessCardBody(
      context,
      icon,
      displayLabel,
      onTap: () => _handleQuickRoute(storageKey, displayLabel),
      onLongPress: () => _resetQuickRoute(storageKey, displayLabel),
    );
  }

  Widget _quickAccessCardBody(BuildContext context, String icon, String displayLabel, {VoidCallback? onTap, VoidCallback? onLongPress}) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: GuidyCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
        child: Column(
          children: [
            SizedBox(height: 24, child: Center(child: GuidySvgIcon(icon, size: 22, color: AppColors.brandAmber))),
            const SizedBox(height: 8),
            Text(
              displayLabel,
              style: TextStyle(fontSize: 13, color: GuidyUi.heading(context)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTripsSection(BuildContext context, AppLocalizations l10n) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Column(
      key: widget.tourKeys?.recent,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_recentTrips.isEmpty)
          GuidyCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                GuidySvgIcon('mode_microbus', size: 26, color: GuidyModeStyle.color('microbus', dark: context.isDark)),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    l10n.noRecentTripsYet,
                    style: TextStyle(fontSize: 12, color: context.textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          )
        else
          SizedBox(
            // Room for the card plus its shadow, which a horizontal list
            // would otherwise clip.
            height: 146,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: _recentTrips.length > 8 ? 8 : _recentTrips.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final trip = _recentTrips[index];
                return _buildRecentTripCard(context, l10n, trip, isArabic);
              },
            ),
          ),
        const SizedBox(height: 14),
        // "Recent Trips" bar: opens the Trips tab.
        Material(
          color: GuidyUi.chipFill(context),
          borderRadius: BorderRadius.circular(GuidyUi.radius),
          child: InkWell(
            borderRadius: BorderRadius.circular(GuidyUi.radius),
            onTap: () => MainNavigator.goToTab(3),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, size: 18, color: context.isDark ? context.textSecondary : GuidyUi.mist),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.recentTripsTitle,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: GuidyUi.heading(context)),
                        ),
                        Text(
                          l10n.recentTripsSubtitle,
                          style: TextStyle(fontSize: 11, color: context.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (_recentTrips.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: const BoxDecoration(color: AppColors.brandAmber, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(
                        '${_recentTrips.length}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _localizeLocation(
    String name,
    bool isArabic, {
    String? nameAr,
    String? nameEn,
    double? lat,
    double? lon,
  }) {
    return LocationLocalizer.localize(
      name,
      isArabic: isArabic,
      nameAr: nameAr,
      nameEn: nameEn,
      lat: lat,
      lon: lon,
    );
  }

  /// "+12 EGP saved" (money first), "+8 min saved", or empty.
  static String _savedText(AppLocalizations l10n, TripHistoryEntry trip, bool isArabic) {
    if (trip.moneySavedEgp > 0) {
      final egp = trip.moneySavedEgp.toStringAsFixed(0);
      return isArabic ? 'وفّرت $egp ج.م' : '+$egp EGP saved';
    }
    if (trip.timeSavedMin > 0) {
      return isArabic ? 'وفّرت ${l10n.minutes(trip.timeSavedMin)}' : '+${l10n.minutes(trip.timeSavedMin)} saved';
    }
    return '';
  }

  Widget _buildRecentTripCard(BuildContext cardContext, AppLocalizations l10n, TripHistoryEntry trip, bool isArabic) {
    final fareStr = '${trip.transitFareEgp} ${isArabic ? "ج.م" : "EGP"}';
    final durationStr = l10n.minutes(trip.transitDurationMin);
    final primaryMode = trip.primaryMode ?? (trip.transitModes.isNotEmpty ? trip.transitModes.first : 'bus');

    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => TripRecapScreen(
              option: trip.option ?? (trip.pathData['option'] is Map ? Map<String, dynamic>.from(trip.pathData['option']) : <String, dynamic>{}),
              pathData: trip.pathData,
              startName: _localizeLocation(
                trip.startName,
                isArabic,
                nameAr: trip.startNameAr,
                nameEn: trip.startNameEn,
                lat: trip.startLat,
                lon: trip.startLon,
              ),
              endName: _localizeLocation(
                trip.endName,
                isArabic,
                nameAr: trip.endNameAr,
                nameEn: trip.endNameEn,
                lat: trip.endLat,
                lon: trip.endLon,
              ),
            ),
          ),
        );
        _loadRecentTrips();
      },
      child: Container(
        width: 236,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: cardContext.surfaceCard,
          borderRadius: BorderRadius.circular(GuidyUi.radius),
          border: Border.all(color: AppColors.brandBlue.withValues(alpha: cardContext.isDark ? 0.35 : 0.30)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (GuidyModeStyle.icon(primaryMode) != null)
                  GuidySvgIcon(GuidyModeStyle.icon(primaryMode)!, size: 24, color: GuidyModeStyle.color(primaryMode, dark: cardContext.isDark))
                else
                  Icon(TransitModes.icon(primaryMode), size: 22, color: GuidyModeStyle.color(primaryMode, dark: cardContext.isDark)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.routeNumber != null && trip.routeNumber!.isNotEmpty
                        ? '${TransitModes.label(l10n, primaryMode)} • ${trip.routeNumber}'
                        : TransitModes.label(l10n, primaryMode),
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: GuidyUi.heading(cardContext)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: GuidyUi.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    fareStr,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: GuidyUi.greenText(cardContext)),
                  ),
                ),
              ],
            ),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: _localizeLocation(trip.startName, isArabic, nameAr: trip.startNameAr, nameEn: trip.startNameEn, lat: trip.startLat, lon: trip.startLon)),
                const WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(Icons.arrow_forward_rounded, size: 13, color: AppColors.brandBlue),
                  ),
                ),
                TextSpan(text: _localizeLocation(trip.endName, isArabic, nameAr: trip.endNameAr, nameEn: trip.endNameEn, lat: trip.endLat, lon: trip.endLon)),
              ]),
              style: TextStyle(fontSize: 12.5, height: 1.35, color: GuidyUi.heading(cardContext)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              children: [
                Icon(Icons.schedule_rounded, size: 14, color: cardContext.isDark ? cardContext.textSecondary : GuidyUi.mist),
                const SizedBox(width: 5),
                Text(
                  durationStr,
                  style: TextStyle(fontSize: 11.5, color: GuidyUi.mutedText(cardContext)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _savedText(l10n, trip, isArabic),
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: GuidyUi.greenText(cardContext)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, size: 20, color: AppColors.brandBlue),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
