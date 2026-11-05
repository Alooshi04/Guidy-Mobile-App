import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/guidy_ui.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/places_service.dart';
import '../services/maps_link_parser.dart';
import '../services/map_marker_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

class LocationPickerScreen extends StatefulWidget {
  // Legacy single-slot mode ("Home" / "Work"): provide saveKey.
  final String? saveKey;
  // Multi-place mode (Saved Places screen): provide onCustomSave instead.
  final Future<void> Function(String label, String name, double lat, double lon,
      String? placeId)? onCustomSave;
  // Pick-only mode (returns selected location map directly to caller)
  final bool pickOnly;

  const LocationPickerScreen({super.key, this.saveKey, this.onCustomSave, this.pickOnly = false})
      : assert(pickOnly || saveKey != null || onCustomSave != null, 'Provide saveKey, onCustomSave, or pickOnly: true');

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  LatLng? _selectedPoint;
  String _selectedName = "";

  /// Set only when the current selection came from a Places search
  /// result. Cleared by every other way of choosing a point, because a
  /// map tap's coordinates are the rider's own and must not be labelled
  /// as Places content -- see PlacesCoordsPolicy.
  String? _selectedPlaceId;
  Timer? _debounceTimer;
  int _searchRequestId = 0;
  // See LocationSearchScreen.dart / places_service.dart for why this
  // exists -- one token per search (not per keystroke), consumed exactly
  // once by the Place Details call that resolves a tapped result.
  String? _sessionToken;
  BitmapDescriptor? _pinIcon;

  @override
  void initState() {
    super.initState();
    _initPinIcon();
  }

  Future<void> _initPinIcon() async {
    final icon = await MapMarkerService.getLocationPinMarker();
    if (mounted) {
      setState(() => _pinIcon = icon);
    }
  }

  // widget.saveKey is always the stable English storage key ("Home" /
  // "Work" / "Saved") so this maps it to the localized label to display.
  // Not used in custom-save (multi-place) mode.
  String _localizedKeyLabel(AppLocalizations l10n) {
    switch (widget.saveKey) {
      case "Home":
        return l10n.quickAccessHome;
      case "Work":
        return l10n.quickAccessWork;
      case "Saved":
        return l10n.quickAccessSaved;
      default:
        return widget.saveKey ?? '';
    }
  }

  void _searchPlaces(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    if (query.isEmpty) {
      _sessionToken = null;
      setState(() => _searchResults = []);
      return;
    }

    if (MapsLinkParser.looksLikeMapsInput(query)) {
      _handlePastedMapsLink(query);
      return;
    }

    // Nothing below the minimum ever reaches the network, so don't show a
    // spinner for a request that will not be made. Clearing the results
    // also matches what the rider sees: backspacing past three characters
    // means the old suggestions no longer match what is in the field.
    if (PlacesService.isQueryTooShort(query)) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      return;
    }

    _sessionToken ??= PlacesService.startSession();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final int requestId = ++_searchRequestId;
      setState(() => _isLoading = true);
      final results = await PlacesService.autocomplete(query, _sessionToken!);
      if (mounted && requestId == _searchRequestId) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
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
      return;
    }

    final name = parsed.name ?? await MapsLinkParser.reverseGeocodeName(parsed.lat, parsed.lon,
            fallbackLabel: l10n.pinnedLocation, lang: lang);
    if (!mounted || requestId != _searchRequestId) return;

    final pt = LatLng(parsed.lat, parsed.lon);
    setState(() {
      _isLoading = false;
      _selectedPoint = pt;
      _selectedName = name;
      _selectedPlaceId = null;
      _searchController.text = name;
      _searchResults = [];
      FocusScope.of(context).unfocus();
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pt, 16.0));
  }

  Future<void> _selectSearchResult(Map<String, dynamic> place) async {
    final sessionToken = _sessionToken;
    _sessionToken = null;
    if (sessionToken == null) return;

    setState(() => _isLoading = true);
    final details = await PlacesService.getPlace(place['placeId'], sessionToken,
        lang: Localizations.localeOf(context).languageCode);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (details == null) return; // silently no-op, matches the previous Nominatim-error behavior here

    final pt = LatLng(details.lat, details.lon);
    final String name = details.name ?? place['name'];
    setState(() {
      _selectedPoint = pt;
      _selectedName = name;
      _selectedPlaceId = place['placeId'] as String?;
      _searchController.text = name;
      _searchResults = [];
      FocusScope.of(context).unfocus();
    });
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(pt, 16.0));
  }

  // REVERSE GEOCODING (Converts map taps to addresses)
  Future<void> _handleMapTap(LatLng point) async {
    setState(() {
      _selectedPoint = point;
      _selectedPlaceId = null;
      _isLoading = true;
      _searchResults = [];
      FocusScope.of(context).unfocus(); // Close keyboard
    });

    // Was a second, uncached copy of the same Nominatim lookup that
    // MapsLinkParser already owns. Routing through it removes the
    // duplicate request path and picks up its cache -- and fixes a
    // quieter bug: on a failed lookup the old code left the PREVIOUS
    // place's name in the field while _selectedPoint had already moved,
    // so the rider could save a pin labelled as somewhere else.
    final l10n = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final locationName = await MapsLinkParser.reverseGeocodeName(
      point.latitude,
      point.longitude,
      fallbackLabel: l10n.pinnedLocation,
      lang: lang,
    );
    if (!mounted) return;
    setState(() {
      _selectedName = locationName;
      _searchController.text = locationName;
      _isLoading = false;
    });
  }

  Future<void> _saveLegacySlotAndExit(String name, double lat, double lon) async {
    final l10n = AppLocalizations.of(context);
    final prefs = await SharedPreferences.getInstance();
    String dataString = "$name|$lat|$lon";
    await prefs.setString(widget.saveKey!, dataString);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.locationSavedAs(_localizedKeyLabel(l10n), name)),
        backgroundColor: Colors.green,
      ));
      Navigator.pop(context);
    }
  }

  Future<String?> _promptForLabel(AppLocalizations l10n) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.addPlaceButton),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.placeNameHint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancelButton)),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryTeal, foregroundColor: Colors.white),
            child: Text(l10n.addPlaceButton),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSelection() async {
    final l10n = AppLocalizations.of(context);
    final point = _selectedPoint!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (widget.pickOnly) {
      Navigator.pop(context, {
        'name': _selectedName.isNotEmpty
            ? _selectedName
            : (isArabic ? 'مكان على الخريطة' : 'Pinned Location'),
        'lat': point.latitude,
        'lon': point.longitude,
      });
      return;
    }

    if (widget.onCustomSave != null) {
      final label = await _promptForLabel(l10n);
      if (label != null && label.trim().isNotEmpty) {
        await widget.onCustomSave!(
            label.trim(), _selectedName, point.latitude, point.longitude, _selectedPlaceId);
        if (mounted) Navigator.pop(context);
      }
    } else {
      await _saveLegacySlotAndExit(_selectedName, point.latitude, point.longitude);
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final keyLabel = _localizedKeyLabel(l10n);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: context.surfaceCard,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.pickOnly
              ? (isArabic ? 'اختار مكان من الخريطة' : 'Drop Pin on Map')
              : (widget.onCustomSave != null ? l10n.addPlaceButton : l10n.setLocationTitle(keyLabel)),
          style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: context.surfaceCard,
        iconTheme: IconThemeData(color: context.textPrimary),
        elevation: 0,
        actions: GuidyLanguageToggle.appBarActions,
      ),
      body: Stack(
        children: [
          // THE INTERACTIVE MAP
          GoogleMap(
            compassEnabled: false,
            rotateGesturesEnabled: false,
            // Open where the rider is (Cairo or Alexandria); Cairo only
            // when the app hasn't had a position yet.
            initialCameraPosition: CameraPosition(
              target: PlacesService.riderLocation != null
                  ? LatLng(PlacesService.riderLocation!.lat, PlacesService.riderLocation!.lon)
                  : const LatLng(30.0444, 31.2357),
              zoom: 13.0,
            ),
            onTap: _handleMapTap, // Enables tap-to-drop
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            markers: _selectedPoint != null
                ? {
                    Marker(
                      markerId: const MarkerId('selected_point'),
                      position: _selectedPoint!,
                      icon: _pinIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      anchor: MapMarkerService.pinAnchor,
                    ),
                  }
                : {},
            // Map style is declarative now: GoogleMap(style: ...) replaced the
            // deprecated controller.setMapStyle(). The old imperative version needed
            // a _mapStyleIsDark latch and a post-frame callback to push the style
            // after every theme change; the property just rebuilds with the widget.
            style: isDark ? darkMapStyleJson : null,
            onMapCreated: (controller) => _mapController = controller,
          ),

          // THE FLOATING SEARCH BAR
          Positioned(
            top: 16, left: 16, right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: context.surfaceCard,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: context.isDark ? 0.5 : 0.15), blurRadius: 8)],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchPlaces,
                    style: TextStyle(color: context.textPrimary),
                    decoration: InputDecoration(
                      hintText: l10n.searchOrTapMap,
                      prefixIcon: Icon(Icons.search, color: context.textSecondary),
                      suffixIcon: _isLoading ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),

                // DROPDOWN RESULTS
                if (_searchResults.isNotEmpty)
                  // Background color lives on the inner Material, not this
                  // Container's decoration -- otherwise it sits as an opaque
                  // DecoratedBox between each ListTile and the nearest
                  // Material ancestor, hiding their background/ink-splash
                  // painting. The outer Container keeps the margin and
                  // drop-shadow, which Material's own elevation doesn't
                  // replicate.
                  Container(
                    margin: const EdgeInsets.only(top: 8), // <-- THE SYNTAX FIX IS HERE
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: context.isDark ? 0.5 : 0.15), blurRadius: 8)],
                    ),
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: Material(
                      color: context.surfaceCard,
                      borderRadius: BorderRadius.circular(12),
                      clipBehavior: Clip.antiAlias,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final place = _searchResults[index];
                          return ListTile(
                            leading: Icon(Icons.location_city, color: context.textSecondary),
                            title: Text(place['name'], style: TextStyle(fontWeight: FontWeight.bold, color: context.textPrimary)),
                            subtitle: Text(place['full_name'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: context.textSecondary)),
                            onTap: () => _selectSearchResult(place),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // THE CONFIRMATION BUTTON
          if (_selectedPoint != null)
            Positioned(
              bottom: 30, left: 20, right: 20,
              child: ElevatedButton(
                onPressed: _confirmSelection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                child: Text(
                  widget.pickOnly
                      ? (isArabic ? 'تأكيد المكان ده' : 'Confirm This Location')
                      : (widget.onCustomSave != null ? l10n.addPlaceButton : l10n.saveAsKey(keyLabel)),
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
