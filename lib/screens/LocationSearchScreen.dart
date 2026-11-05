import 'package:flutter/material.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../services/location_fallback.dart';
import '../services/places_service.dart';
import '../services/maps_link_parser.dart';
import 'RouteOptionsScreen.dart';
import 'LocationPickerScreen.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';
import '../services/search_history_service.dart';
import '../services/current_place_namer.dart';
import '../services/locale_controller.dart';
import '../services/saved_places_service.dart';
import '../theme/guidy_ui.dart';
import '../services/simple_mode.dart';
import '../widgets/simple/simple_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationSearchScreen extends StatefulWidget {
  final Map<String, dynamic>? initialStartLocation;
  final Map<String, dynamic>? initialEndLocation; // Supports Home/Work Hotkeys

  const LocationSearchScreen({super.key, this.initialStartLocation, this.initialEndLocation});

  @override
  State<LocationSearchScreen> createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final FocusNode _startFocusNode = FocusNode();
  final FocusNode _endFocusNode = FocusNode();

  Map<String, dynamic>? _selectedStart;
  Map<String, dynamic>? _selectedEnd;
  List<Map<String, dynamic>> _searchResults = [];
  List<Map<String, dynamic>> _recentSearches = [];
  bool _isLoading = false;
  bool _isNavigating = false;
  Timer? _debounceTimer;
  bool _isEditingStart = false;

  /// Simple mode: the starting point is the rider's location and stays out of
  /// the way until "Change starting point" is pressed.
  bool _simpleEditStart = false;
  // Google Places session token -- covers one search's worth of
  // keystrokes plus the terminating Place Details call, which is what
  // makes Places billing cheap (see places_service.dart). null means
  // "no search in progress"; a fresh one is generated on the first
  // keystroke of each new search and cleared again once a selection
  // resolves or the field is cleared. Never reused across two searches.
  String? _sessionToken;
  // Incremented on every new search; a response only gets applied if it's
  // still the most recent one issued. Without this, a slower response to
  // an OLDER (shorter/partial) query can arrive after a faster response
  // to a NEWER query and silently overwrite the good results with
  // incomplete ones -- this was the actual cause of results appearing to
  // randomly "cut off" on some searches.
  int _searchRequestId = 0;
  /// The exact text the results on screen belong to. "No places found" is
  /// only honest when a search has actually come back for what is currently
  /// typed -- otherwise it flashes during the debounce, and (before the
  /// fields stopped holding their selection as text) it stayed on screen
  /// after both places were chosen, which read as "your choices are wrong".
  String _resultsForQuery = '';

  /// Home and Work (null until set) and the saved places: one tap fills
  /// whichever field is being edited -- the start as much as the destination.
  Map<String, dynamic>? _home;
  Map<String, dynamic>? _work;
  List<SavedPlace> _savedPlaces = [];

  @override
  void initState() {
    super.initState();
    SearchHistoryService.getRecent().then((recent) {
      if (mounted) setState(() => _recentSearches = recent);
    });
    _loadQuickPlaces();

    // Deliberately NOT written into the controllers. A chosen place is
    // shown as the field's hint instead, so the first keystroke replaces
    // it -- previously "My Current Location" sat there as real text and
    // had to be deleted character by character before you could type a
    // different starting point.
    _selectedStart = widget.initialStartLocation;
    _selectedEnd = widget.initialEndLocation;
    _nameCurrentStart();
    _refreshCurrentStart();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybePrefetchRoute();
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_selectedStart == null) {
        _startFocusNode.requestFocus();
      } else if (_selectedEnd == null) {
        _endFocusNode.requestFocus();
      }
    });
    
    _startFocusNode.addListener(() {
      if (_startFocusNode.hasFocus) setState(() => _isEditingStart = true);
    });
    
    _endFocusNode.addListener(() {
      if (_endFocusNode.hasFocus) {
        setState(() {
          _isEditingStart = false;
          _simpleEditStart = false;
        });
      }
    });
  }

  /// Home/Work are stored as "name|lat|lon" under "Home" / "Work" (see
  /// LocationPickerScreen's saveKey).
  static Map<String, dynamic>? _slot(SharedPreferences prefs, String key) {
    final parts = prefs.getString(key)?.split('|');
    if (parts == null || parts.length < 3) return null;
    // Coordinates are the last two parts: a name may itself contain '|'.
    final lat = double.tryParse(parts[parts.length - 2]), lon = double.tryParse(parts.last);
    if (lat == null || lon == null) return null;
    return {'name': parts.sublist(0, parts.length - 2).join('|'), 'lat': lat, 'lon': lon};
  }

  Future<void> _loadQuickPlaces() async {
    final prefs = await SharedPreferences.getInstance();
    List<SavedPlace> saved = const [];
    try {
      saved = await SavedPlacesService.getAll();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _home = _slot(prefs, 'Home');
      _work = _slot(prefs, 'Work');
      _savedPlaces = saved;
    });
  }

  /// Home or Work: used if set, otherwise set it first on the map.
  Future<void> _useSlot(String key) async {
    var place = key == 'Home' ? _home : _work;
    if (place == null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => LocationPickerScreen(saveKey: key)));
      if (!mounted) return;
      await _loadQuickPlaces();
      place = key == 'Home' ? _home : _work;
    }
    if (place != null && mounted) _selectLocation(place);
  }

  Widget _quickDestinations(AppLocalizations l10n) {
    if (simpleMode.value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SimpleButton(
              key: const ValueKey('quick_Home'),
              icon: Icons.home_rounded,
              label: l10n.quickAccessHome,
              onPressed: () => _useSlot('Home')),
          const SizedBox(height: 10),
          SimpleButton(
              key: const ValueKey('quick_Work'),
              icon: Icons.work_rounded,
              label: l10n.quickAccessWork,
              onPressed: () => _useSlot('Work')),
          for (final p in _savedPlaces) ...[
            const SizedBox(height: 10),
            SimpleButton(
              key: ValueKey('quick_saved_${p.id}'),
              icon: Icons.bookmark_rounded,
              label: p.label,
              onPressed: () => _selectLocation({'name': p.name, 'lat': p.lat, 'lon': p.lon}),
            ),
          ],
          const SizedBox(height: 16),
        ],
      );
    }
    Widget chip(Key key, Widget icon, String label, VoidCallback onTap) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: ActionChip(
            key: key,
            avatar: icon,
            label: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            onPressed: onTap,
            backgroundColor: context.fieldFill,
            side: BorderSide.none,
            shape: const StadiumBorder(),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.quickDestinationsLabel.toUpperCase(),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textSecondary, letterSpacing: 0.6),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              chip(const ValueKey('quick_Home'), const GuidySvgIcon('dest_home', size: 16, color: AppColors.brandAmber),
                  l10n.quickAccessHome, () => _useSlot('Home')),
              chip(const ValueKey('quick_Work'), const GuidySvgIcon('dest_work', size: 16, color: AppColors.brandAmber),
                  l10n.quickAccessWork, () => _useSlot('Work')),
              for (final p in _savedPlaces)
                chip(
                  ValueKey('quick_saved_${p.id}'),
                  const Icon(Icons.bookmark_rounded, size: 16, color: AppColors.brandAmber),
                  p.label,
                  () => _selectLocation({'name': p.name, 'lat': p.lat, 'lon': p.lon}),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  void _maybePrefetchRoute() {
    if (!mounted) return;
    if (_selectedStart != null &&
        _selectedEnd != null &&
        _selectedStart!['lat'] != null &&
        _selectedStart!['lon'] != null &&
        _selectedEnd!['lat'] != null &&
        _selectedEnd!['lon'] != null) {
      final isArabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
      ApiService().prefetchRoute(
        (_selectedStart!['lat'] as num).toDouble(),
        (_selectedStart!['lon'] as num).toDouble(),
        (_selectedEnd!['lat'] as num).toDouble(),
        (_selectedEnd!['lon'] as num).toDouble(),
        lang: isArabic ? 'ar' : 'en',
      );
    }
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _startFocusNode.dispose();
    _endFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    if (query.isEmpty) {
      // Abandoning whatever search was in progress -- discard the
      // session token rather than let it get reused for an unrelated
      // future search (a reused token bills as if there were no session
      // token at all, i.e. every keystroke individually).
      _sessionToken = null;
      setState(() {
        _searchResults = [];
        _resultsForQuery = '';
        _isLoading = false;
      });
      return;
    }

    // A pasted Google Maps link or raw "lat,lng" is already a precise,
    // resolved location -- skip Places entirely (no point spending a
    // session on it, and a URL isn't a meaningful Autocomplete query
    // anyway) and resolve it directly instead.
    if (MapsLinkParser.looksLikeMapsInput(query)) {
      _handlePastedMapsLink(query);
      return;
    }

    // One token per search, generated on its first keystroke -- not
    // regenerated on every keystroke, which is what actually makes this
    // a "session" for billing purposes.
    // Nothing below the minimum ever reaches the network, so don't show a
    // spinner for a request that will not be made. Clearing the results
    // also matches what the rider sees: backspacing past three characters
    // means the old suggestions no longer match what is in the field.
    if (PlacesService.isQueryTooShort(query)) {
      setState(() {
        _searchResults = [];
        _resultsForQuery = '';
        _isLoading = false;
      });
      return;
    }

    _sessionToken ??= PlacesService.startSession();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final int requestId = ++_searchRequestId;
      setState(() => _isLoading = true);
      try {
        final results = await PlacesService.autocomplete(query, _sessionToken!);
        if (mounted && requestId == _searchRequestId) {
          setState(() {
            _searchResults = results;
            _resultsForQuery = query;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted && requestId == _searchRequestId) setState(() => _isLoading = false);
      }
    });
  }

  Future<void> _handlePastedMapsLink(String text) async {
    // Captured before the awaits: reading localizations off `context`
    // after an async gap is the pattern that produces a use-after-dispose.
    final l10n = AppLocalizations.of(context);
    final String lang = Localizations.localeOf(context).languageCode;
    final int requestId = ++_searchRequestId;
    setState(() => _isLoading = true);
    final parsed = await MapsLinkParser.parse(text);
    if (!mounted || requestId != _searchRequestId) return;

    if (parsed == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noSearchResultsFound)),
        );
      }
      return;
    }

    final name = parsed.name ?? await MapsLinkParser.reverseGeocodeName(parsed.lat, parsed.lon,
            fallbackLabel: l10n.pinnedLocation, lang: lang);
    if (!mounted || requestId != _searchRequestId) return;
    setState(() => _isLoading = false);
    _selectLocation({'name': name, 'full_name': name, 'lat': parsed.lat, 'lon': parsed.lon});
  }

  /// A selected place's name in the app's language, or [fallback].
  String _label(Map<String, dynamic>? place, String fallback) => place == null
      ? fallback
      : SearchHistoryService.nameFor(place, Localizations.localeOf(context).languageCode);

  Future<void> _selectLocation(Map<String, dynamic> location) async {
    final l10n = AppLocalizations.of(context);

    // Recent-search entries (and "my current location") already carry
    // real coordinates from local storage/GPS -- resolving them again
    // through Place Details would be a wasted billable call for data we
    // already have. Only fresh Autocomplete predictions (identified by
    // having a placeId and no coordinates yet) need resolving.
    Map<String, dynamic> resolved;
    if (location['lat'] != null && location['lon'] != null) {
      resolved = location;
    } else {
      final sessionToken = _sessionToken;
      // Session ends here regardless of outcome -- the next search (even
      // a retry after a failed lookup below) starts a fresh one rather
      // than reusing this one, since reuse defeats the billing benefit.
      _sessionToken = null;

      setState(() => _isLoading = true);
      final place = sessionToken == null
          ? null
          : await PlacesService.getPlace(location['placeId'], sessionToken,
              lang: Localizations.localeOf(context).languageCode);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (place == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noSearchResultsFound)),
        );
        return;
      }
      final lang = Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
      // The prediction's own name is in the language typed; Place Details
      // came back in the app's. Keep both when they differ.
      resolved = SearchHistoryService.withNames(
        {
          ...location,
          if (place.name != null) 'name': place.name,
          'lat': place.lat,
          'lon': place.lon,
        },
        name: location['name']?.toString(),
      );
      if (place.name != null) {
        resolved[lang == 'ar' ? 'nameAr' : 'nameEn'] = place.name;
      }
    }

    SearchHistoryService.addSearch(
      resolved['name'],
      resolved['lat'],
      resolved['lon'],
      placeId: resolved['placeId']?.toString(),
      nameEn: resolved['nameEn'] as String?,
      nameAr: resolved['nameAr'] as String?,
    );
    setState(() {
      if (_isEditingStart) {
        _selectedStart = resolved;
        _startController.clear();
        _endFocusNode.requestFocus();
      } else {
        _selectedEnd = resolved;
        _endController.clear();
        _endFocusNode.unfocus();
      }
      _searchResults = [];
    });
    _maybePrefetchRoute();
  }

  Future<void> _fetchCurrentLocationForStart() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _isLoading = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationFallback.fix(accuracy: LocationAccuracy.high),
      );
      // The fix can take seconds (permission dialog, slow GPS); the rider may
      // have left this screen by then.
      if (!mounted) return;
      PlacesService.rememberRiderLocation(position.latitude, position.longitude);
      setState(() {
        _selectedStart = CurrentPlaceNamer.place(
          lat: position.latitude,
          lon: position.longitude,
          fallbackLabel: l10n.myCurrentLocation,
        );
        _startController.clear();
        _isLoading = false;
        _endFocusNode.requestFocus();
      });
      _maybePrefetchRoute();
      _nameCurrentStart();
    } catch (e) {
      LocationFallback.noteError(e);
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.gpsFetchFailed)));
    }
  }

  /// Home looks for the rider once, when it opens, and the app can stay open
  /// for hours while they travel. A start that is still "my current location"
  /// is looked up again here, so it is where they are now and not where they
  /// were. Silent: if the fix fails or they have picked another start in the
  /// meantime, nothing changes.
  Future<void> _refreshCurrentStart() async {
    final start = _selectedStart;
    if (!CurrentPlaceNamer.isCurrent(start)) return;
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationFallback.fix(accuracy: LocationAccuracy.high),
      );
      // The street-name lookup may already have swapped in a renamed copy;
      // only a start the rider has picked by hand is left alone.
      if (!mounted || !CurrentPlaceNamer.isCurrent(_selectedStart)) return;
      PlacesService.rememberRiderLocation(position.latitude, position.longitude);
      final moved = Geolocator.distanceBetween(
        (start!['lat'] as num).toDouble(),
        (start['lon'] as num).toDouble(),
        position.latitude,
        position.longitude,
      );
      if (moved < 30) return;
      setState(() {
        _selectedStart = CurrentPlaceNamer.place(
          lat: position.latitude,
          lon: position.longitude,
          fallbackLabel: AppLocalizations.of(context).myCurrentLocation,
        );
      });
      _maybePrefetchRoute();
      _nameCurrentStart();
    } catch (e) {
      LocationFallback.noteError(e);
    }
  }

  /// A "current location" start, renamed to the street the rider is on.
  Future<void> _nameCurrentStart() async {
    final start = _selectedStart;
    if (!CurrentPlaceNamer.isCurrent(start)) return;
    final named = await CurrentPlaceNamer.named(start!, lang: localeController.isArabic ? 'ar' : 'en');
    if (!mounted || !identical(_selectedStart, start)) return;
    setState(() => _selectedStart = named);
  }

  Future<void> _calculateRoute() async {
    if (_isNavigating || _selectedStart == null || _selectedEnd == null) return;
    _maybePrefetchRoute();
    setState(() => _isNavigating = true);
    final isArabic = Localizations.maybeLocaleOf(context)?.languageCode == 'ar';
    final cached = ApiService.getCachedRoute(
      startLat: (_selectedStart!['lat'] as num).toDouble(),
      startLon: (_selectedStart!['lon'] as num).toDouble(),
      endLat: (_selectedEnd!['lat'] as num).toDouble(),
      endLon: (_selectedEnd!['lon'] as num).toDouble(),
      lang: isArabic ? 'ar' : 'en',
    );
    // Pushed, not replacing this screen: back from the options returns here
    // with both places still filled in.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RouteOptionsScreen(
        startLat: _selectedStart!['lat'],
        startLon: _selectedStart!['lon'],
        startName: SearchHistoryService.nameFor(_selectedStart!, Localizations.localeOf(context).languageCode),
        endLat: _selectedEnd!['lat'],
        endLon: _selectedEnd!['lon'],
        endName: SearchHistoryService.nameFor(_selectedEnd!, Localizations.localeOf(context).languageCode),
        initialData: cached,
      )),
    );
    if (mounted) setState(() => _isNavigating = false);
  }

  Future<void> _openMapPinDropper({required bool forStart}) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const LocationPickerScreen(pickOnly: true),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        if (forStart) {
          _selectedStart = result;
          _startController.clear();
          _endFocusNode.requestFocus();
        } else {
          _selectedEnd = result;
          _endController.clear();
          _endFocusNode.unfocus();
        }
        _searchResults = [];
      });
      SearchHistoryService.addSearch(
        result['name']?.toString() ?? 'Pinned Location',
        (result['lat'] as num).toDouble(),
        (result['lon'] as num).toDouble(),
      );
      _maybePrefetchRoute();
    }
  }

  Widget _buildResultsArea(AppLocalizations l10n) {
    final activeController = _isEditingStart ? _startController : _endController;
    final hasQuery = activeController.text.isNotEmpty;

    if (!hasQuery) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _quickDestinations(l10n),
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.recentSearchesLabel.toUpperCase(),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: context.textSecondary, letterSpacing: 0.6)),
                TextButton(
                  style: simpleMode.value ? TextButton.styleFrom(minimumSize: const Size(64, SimpleModeController.minTarget)) : null,
                  onPressed: () async {
                    // Simple mode asks before wiping the list.
                    if (simpleMode.value &&
                        !await SimpleUi.confirm(
                          context,
                          title: l10n.simpleClearTitle,
                          body: l10n.simpleClearBody,
                          yes: l10n.simpleClearYes,
                          no: l10n.simpleKeepGoing,
                        )) {
                      return;
                    }
                    await SearchHistoryService.clear();
                    if (mounted) setState(() => _recentSearches = []);
                  },
                  child: Text(l10n.clearHistoryLabel, style: const TextStyle(color: AppColors.primaryTeal)),
                ),
              ],
            ),
            ..._recentSearches.map((place) => ListTile(
                  minTileHeight: simpleMode.value ? SimpleModeController.minTarget : null,
                  leading: CircleAvatar(
                    backgroundColor: context.fieldFill,
                    child: Icon(Icons.history, color: context.textSecondary),
                  ),
                  title: Text(SearchHistoryService.nameFor(place, Localizations.localeOf(context).languageCode),
                      style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                  onTap: () => _selectLocation(place),
                )),
          ],
        ],
      );
    }

    if (hasQuery &&
        _resultsForQuery == activeController.text &&
        _searchResults.isEmpty &&
        !_isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                PlacesService.isConfigured ? l10n.noSearchResultsFound : l10n.placeSearchUnavailable,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final place = _searchResults[index];
        return ListTile(
          minTileHeight: simpleMode.value ? SimpleModeController.minTarget : null,
          leading: CircleAvatar(
            backgroundColor: context.fieldFill,
            child: Icon(Icons.location_on, color: context.textSecondary),
          ),
          title: Text(place['name'], style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
          subtitle: Text(place['full_name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.textSecondary)),
          onTap: () => _selectLocation(place),
        );
      },
    );
  }

  /// A big text box for simple mode: large type, a clear outline.
  Widget _simpleField({
    required Key key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
  }) {
    final edge = context.isDark ? Colors.white54 : const Color(0xFF0B1B2B);
    OutlineInputBorder border(double width) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: edge, width: width));
    return TextField(
      key: key,
      controller: controller,
      focusNode: focusNode,
      onChanged: _onSearchChanged,
      style: TextStyle(fontSize: 22, color: context.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintMaxLines: 2,
        hintStyle: TextStyle(fontSize: 20, color: context.textSecondary, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, size: 30, color: context.textPrimary),
        filled: true,
        fillColor: context.fieldFill,
        contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        border: border(2),
        enabledBorder: border(2),
        focusedBorder: border(3),
      ),
    );
  }

  /// Simple mode: "Where do you want to go?", one big box, the starting
  /// point as a sentence with one labelled button to change it, then the
  /// places to pick from, and "Find routes" and "Back" at the bottom.
  Widget _buildSimple(AppLocalizations l10n) {
    final ready = _selectedStart != null && _selectedEnd != null;
    final showStart = _simpleEditStart || _selectedStart == null;
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    return Scaffold(
      backgroundColor: context.surfaceCard,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.simpleWhereToGo,
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: context.textPrimary, height: 1.2)),
                  const SizedBox(height: 12),
                  _simpleField(
                    key: const ValueKey('simple_end_field'),
                    controller: _endController,
                    focusNode: _endFocusNode,
                    hint: _label(_selectedEnd, l10n.whereTo),
                    icon: Icons.place_rounded,
                  ),
                  const SizedBox(height: 12),
                  if (showStart) ...[
                    _simpleField(
                      key: const ValueKey('simple_start_field'),
                      controller: _startController,
                      focusNode: _startFocusNode,
                      hint: _label(_selectedStart, l10n.pickupLocation),
                      icon: Icons.my_location_rounded,
                    ),
                    const SizedBox(height: 10),
                    SimpleButton(
                      key: const ValueKey('simple_use_my_location'),
                      icon: Icons.my_location_rounded,
                      label: l10n.simpleUseMyLocation,
                      onPressed: _fetchCurrentLocationForStart,
                    ),
                  ] else ...[
                    Text(l10n.simpleFrom(_label(_selectedStart, l10n.myCurrentLocation)),
                        key: const ValueKey('simple_from'),
                        style: TextStyle(fontSize: 18, color: context.textSecondary, height: 1.3)),
                    const SizedBox(height: 8),
                    SimpleButton(
                      key: const ValueKey('simple_change_start'),
                      icon: Icons.edit_location_alt_rounded,
                      label: l10n.simpleChangeStart,
                      onPressed: () {
                        setState(() => _simpleEditStart = true);
                        _startFocusNode.requestFocus();
                      },
                    ),
                  ],
                ],
              ),
            ),
            if (_isLoading) const LinearProgressIndicator(color: AppColors.primaryTeal),
            Expanded(child: _buildResultsArea(l10n)),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (ready)
                    SimpleButton(
                      key: const ValueKey('simple_find_routes'),
                      icon: Icons.search_rounded,
                      label: l10n.findRoutes,
                      primary: true,
                      onPressed: _isNavigating ? null : _calculateRoute,
                    ),
                  if (ready && !keyboardOpen) const SizedBox(height: 10),
                  if (!keyboardOpen)
                    SimpleButton(
                      key: const ValueKey('simple_search_back'),
                      icon: Icons.arrow_back_rounded,
                      label: l10n.simpleBack,
                      onPressed: () => Navigator.pop(context),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (simpleMode.value) return _buildSimple(l10n);
    return Scaffold(
      backgroundColor: context.surfaceCard,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.surfaceCard,
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.05), blurRadius: 10, offset: const Offset(0, 5))],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back, color: context.textPrimary),
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          decoration: BoxDecoration(color: context.fieldFill, borderRadius: BorderRadius.circular(10)),
                          child: TextField(
                            controller: _startController,
                            focusNode: _startFocusNode,
                            onChanged: _onSearchChanged,
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              // The chosen place lives in the hint, styled
                              // like a real value. Typing replaces it; there
                              // is nothing to delete first.
                              hintText: _label(_selectedStart, l10n.pickupLocation),
                              // A long chosen place wraps instead of being cut off.
                              hintMaxLines: 2,
                              hintStyle: TextStyle(
                                color: _selectedStart != null
                                    ? context.textSecondary.withValues(alpha: 0.85)
                                    : context.textSecondary.withValues(alpha: 0.55),
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: const Icon(Icons.circle, size: 12, color: Colors.blue),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.my_location, color: context.textSecondary, size: 20),
                                    tooltip: l10n.useCurrentLocationTooltip,
                                    onPressed: _fetchCurrentLocationForStart,
                                  ),
                                  IconButton(
                                    key: const ValueKey('pin_start'),
                                    icon: const Icon(Icons.pin_drop_outlined, color: AppColors.primaryTeal, size: 20),
                                    tooltip: l10n.pinnedLocation,
                                    onPressed: () => _openMapPinDropper(forStart: true),
                                  ),
                                ],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          decoration: BoxDecoration(color: context.fieldFill, borderRadius: BorderRadius.circular(10)),
                          child: TextField(
                            controller: _endController,
                            focusNode: _endFocusNode,
                            onChanged: _onSearchChanged,
                            style: TextStyle(color: context.textPrimary),
                            decoration: InputDecoration(
                              hintText: _label(_selectedEnd, l10n.whereTo),
                              hintMaxLines: 2,
                              hintStyle: TextStyle(
                                color: _selectedEnd != null
                                    ? context.textSecondary.withValues(alpha: 0.85)
                                    : context.textSecondary.withValues(alpha: 0.55),
                                fontWeight: FontWeight.w500,
                              ),
                              prefixIcon: Icon(Icons.square, size: 12, color: context.textPrimary),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_selectedEnd != null)
                                    IconButton(
                                      icon: Icon(Icons.close, color: context.textSecondary, size: 18),
                                      tooltip: l10n.clearHistoryLabel,
                                      onPressed: () => setState(() {
                                        _selectedEnd = null;
                                        _endController.clear();
                                        _searchResults = [];
                                      }),
                                    ),
                                  IconButton(
                                    key: const ValueKey('pin_end'),
                                    icon: const Icon(Icons.pin_drop_outlined, color: AppColors.primaryTeal, size: 20),
                                    tooltip: l10n.pinnedLocation,
                                    onPressed: () => _openMapPinDropper(forStart: false),
                                  ),
                                ],
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (_isLoading) const LinearProgressIndicator(color: AppColors.primaryTeal),

            Expanded(
              child: _buildResultsArea(l10n),
            ),

            if (_selectedStart != null && _selectedEnd != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.surfaceCard,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    )
                  ]
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _isNavigating ? null : _calculateRoute,
                    child: Text(
                      l10n.findRoutes,
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}