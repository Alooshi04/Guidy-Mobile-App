import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/guidy_ui.dart';
import '../services/saved_places_service.dart';
import '../services/places_coords_policy.dart';
import '../services/analytics_service.dart';
import '../theme/app_theme.dart';
import 'LocationPickerScreen.dart';
import 'LocationSearchScreen.dart';

class SavedPlacesScreen extends StatefulWidget {
  const SavedPlacesScreen({super.key});

  @override
  State<SavedPlacesScreen> createState() => _SavedPlacesScreenState();
}

class _SavedPlacesScreenState extends State<SavedPlacesScreen> {
  late Future<List<SavedPlace>> _placesFuture;

  @override
  void initState() {
    super.initState();
    _placesFuture = SavedPlacesService.getAll();
  }

  void _refresh() {
    setState(() {
      _placesFuture = SavedPlacesService.getAll();
    });
  }

  Future<void> _addPlace() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerScreen(
          onCustomSave: (label, name, lat, lon, placeId) async {
            await SavedPlacesService.add(SavedPlace(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              label: label,
              name: name,
              lat: lat,
              lon: lon,
              // Only stamped when the coordinates came from Places; a
              // map-tap place carries neither and never expires.
              placeId: placeId,
              coordsAt: placeId == null ? null : PlacesCoordsPolicy.now,
            ));
            AnalyticsService.logSavedPlaceAdded();
          },
        ),
      ),
    );
    _refresh();
  }

  Future<void> _confirmDelete(SavedPlace place, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deletePlaceConfirmTitle),
        content: Text(l10n.deletePlaceConfirmBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancelButton)),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.removeButton, style: const TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SavedPlacesService.remove(place.id);
      _refresh();
    }
  }

  void _routeTo(SavedPlace place) {
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => LocationSearchScreen(
        initialEndLocation: {'name': place.name, 'lat': place.lat, 'lon': place.lon},
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.savedPlacesTitle, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.bold)),
        actions: GuidyLanguageToggle.appBarActions,
      ),
      body: FutureBuilder<List<SavedPlace>>(
        future: _placesFuture,
        builder: (context, snapshot) {
          final places = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primaryTeal));
          }
          if (places.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l10n.noSavedPlacesYet, style: TextStyle(color: context.textSecondary), textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: places.length,
            itemBuilder: (context, index) {
              final place = places[index];
              // Background color lives on the inner Material so ListTile's
              // own background/ink-splash painting (which targets the
              // nearest Material ancestor) isn't hidden by an opaque
              // DecoratedBox sitting between it and that ancestor. The
              // outer Container only supplies the margin and drop-shadow.
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: context.isDark ? 0.3 : 0.05), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Material(
                  color: context.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryTeal.withValues(alpha: 0.15),
                      child: const Icon(Icons.place_outlined, color: AppColors.primaryTeal),
                    ),
                    title: Text(place.label, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w600)),
                    subtitle: Text(place.name, style: TextStyle(color: context.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      onPressed: () => _confirmDelete(place, l10n),
                      tooltip: l10n.removePlaceTooltip,
                    ),
                    onTap: () => _routeTo(place),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPlace,
        backgroundColor: AppColors.primaryTeal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(l10n.addPlaceButton, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}
