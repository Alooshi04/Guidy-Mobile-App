import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../services/trip_history_service.dart';
import '../services/location_localizer.dart';
import '../services/transit_modes.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';
import 'LocationSearchScreen.dart';
import 'MapScreen.dart';
import 'TripRecapScreen.dart';
import '../utils/minutes_text.dart';
import '../services/simple_mode.dart';

/// Screen displaying user commute history, calculated savings in money and time
/// compared to Cairo taxi/ride-hailing, avoided CO2 emissions, and repeatable routes.
class HistoryScreen extends StatefulWidget {
  final VoidCallback? onGoHome;
  const HistoryScreen({super.key, this.onGoHome});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<TripHistoryEntry> _allTrips = [];
  bool _isLoading = true;
  String _timeFilter = 'all'; // 'all', 'this_week', 'this_month'
  String? _modeFilter; // null, 'metro', 'bus', 'microbus'

  @override
  void initState() {
    super.initState();
    _loadHistory();
    TripHistoryService.changeNotifier.addListener(_loadHistory);
  }

  @override
  void dispose() {
    TripHistoryService.changeNotifier.removeListener(_loadHistory);
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final trips = await TripHistoryService.getHistory();
    if (mounted) {
      setState(() {
        _allTrips = trips;
        _isLoading = false;
      });
    }
  }

  List<TripHistoryEntry> get _filteredTrips {
    final now = DateTime.now();
    return _allTrips.where((trip) {
      // Time filter
      if (_timeFilter == 'this_week') {
        final diff = now.difference(trip.timestamp);
        if (diff.inDays > 7) return false;
      } else if (_timeFilter == 'this_month') {
        final diff = now.difference(trip.timestamp);
        if (diff.inDays > 30) return false;
      }

      // Mode filter
      if (_modeFilter != null) {
        final match = trip.transitModes.any((m) => m.toLowerCase().contains(_modeFilter!)) ||
            (trip.primaryMode != null && trip.primaryMode!.toLowerCase().contains(_modeFilter!));
        if (!match) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _confirmClearHistory() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.clearHistoryAction),
        content: Text(l10n.clearHistoryConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text(l10n.clearHistoryAction, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TripHistoryService.clearHistory();
      await _loadHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.clearHistorySuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showSavingsInfoDialog() {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: context.surfaceCard,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.savings_rounded, color: AppColors.primaryTeal, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.savingsCalculationInfoTitle,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                l10n.savingsCalculationInfo,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: context.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    MaterialLocalizations.of(context).okButtonLabel,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openTrip(TripHistoryEntry trip) async {
    if (trip.pathData.isNotEmpty && trip.option != null) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TripRecapScreen(
            option: trip.option!,
            pathData: trip.pathData,
            startName: trip.startName,
            endName: trip.endName,
          ),
        ),
      );
      _loadHistory();
    } else if (trip.pathData.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapScreen(
            pathData: trip.pathData,
            startName: trip.startName,
            endName: trip.endName,
          ),
        ),
      );
      _loadHistory();
    } else {
      // Re-plan trip with endpoints
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LocationSearchScreen(
            initialStartLocation: trip.startLat != null && trip.startLon != null
                ? {'name': trip.startName, 'lat': trip.startLat!, 'lon': trip.startLon!}
                : null,
          ),
        ),
      );
      _loadHistory();
    }
  }

  Future<void> _deleteTrip(TripHistoryEntry trip) async {
    final l10n = AppLocalizations.of(context);
    final removed = await TripHistoryService.deleteTrip(trip.id);
    if (!mounted) return;
    if (removed) {
      setState(() {
        _allTrips.removeWhere((t) => t.id == trip.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tripDeletedToast),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  String _formatTimeSaved(AppLocalizations l10n, int minutes) {
    if (minutes < 60) {
      return l10n.minsSavedShort(l10n.minutes(minutes));
    }
    final hours = minutes ~/ 60;
    final remainingMins = minutes % 60;
    if (remainingMins == 0) {
      return '$hours h';
    }
    return l10n.hoursMinsSavedShort('$hours', '$remainingMins');
  }

  String _formatDate(DateTime dt, bool isArabic) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inDays == 0 && now.day == dt.day) {
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final period = dt.hour >= 12 ? (isArabic ? 'م' : 'PM') : (isArabic ? 'ص' : 'AM');
      final minute = dt.minute.toString().padLeft(2, '0');
      return isArabic ? 'النهارده، $hour:$minute $period' : 'Today, $hour:$minute $period';
    } else if (difference.inDays == 1 || (difference.inDays == 0 && now.day != dt.day)) {
      return isArabic ? 'امبارح' : 'Yesterday';
    } else if (difference.inDays < 7) {
      return isArabic ? 'من ${difference.inDays} أيام' : '${difference.inDays} days ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  String _localizedLocation(
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final filtered = _filteredTrips;
    final stats = TripHistoryService.getStats(_allTrips);

    final canGoBack = Navigator.canPop(context) || widget.onGoHome != null;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: SafeArea(
          bottom: false,
          child: GuidyHeader(
            title: l10n.historyTitle,
            showBack: canGoBack,
            onBack: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                widget.onGoHome?.call();
              }
            },
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!simpleMode.value)
                  IconButton(
                    icon: const Icon(Icons.info_outline_rounded, color: AppColors.brandBlue),
                    tooltip: l10n.savingsCalculationInfoTitle,
                    onPressed: _showSavingsInfoDialog,
                  ),
                // Simple mode: a button with a word, which asks before it clears.
                if (_allTrips.isNotEmpty && simpleMode.value)
                  TextButton.icon(
                    key: const ValueKey('simple_clear_history'),
                    style: TextButton.styleFrom(minimumSize: const Size(64, SimpleModeController.minTarget)),
                    icon: const Icon(Icons.delete_sweep_outlined, size: 26),
                    label: Text(l10n.clearHistoryAction, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    onPressed: _confirmClearHistory,
                  ),
                if (_allTrips.isNotEmpty && !simpleMode.value)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.brandBlue),
                    tooltip: l10n.clearHistoryAction,
                    onPressed: _confirmClearHistory,
                  ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadHistory,
              color: AppColors.primaryTeal,
              child: _allTrips.isEmpty
                  ? _buildEmptyState(l10n, isArabic)
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 30),
                      children: [
                        // --- Top Savings Pills and Filter Chips (not in simple mode) ---
                        if (!simpleMode.value) ...[
                          _buildTopSavingsPills(context, l10n, stats, isArabic),
                          const SizedBox(height: 8),
                          _buildFilterRow(l10n),
                        ],

                        const SizedBox(height: 12),

                        // --- Trip List Header ---
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                          child: Text(
                            '${l10n.navHistory} (${filtered.length})',
                            style: TextStyle(fontSize: 12.5, color: GuidyUi.mutedText(context)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // --- Trip Cards ---
                        if (filtered.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Center(
                              child: Text(
                                l10n.linesNoResults,
                                style: TextStyle(color: context.textSecondary),
                              ),
                            ),
                          )
                        else
                          ...filtered.map((trip) => _buildTripCard(context, l10n, trip, isArabic)),
                      ],
                    ),
            ),
    );
  }

  Widget _buildTopSavingsPills(
    BuildContext context,
    AppLocalizations l10n,
    TripHistoryStats stats,
    bool isArabic,
  ) {
    final moneySavedStr = stats.totalMoneySavedEgp.toStringAsFixed(0);
    final timeSavedMin = stats.totalTimeSavedMinutes;

    Widget stat(IconData icon, String label, String value, List<Color> colors) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: AlignmentDirectional.centerStart, end: AlignmentDirectional.centerEnd),
          borderRadius: BorderRadius.circular(GuidyUi.radius),
          boxShadow: GuidyUi.cardShadow(context),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(fontSize: 12, color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      value.toUpperCase(),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: stat(Icons.savings_rounded, isArabic ? 'وفّرت فلوس' : 'Money Saved', l10n.moneySavedPill(moneySavedStr),
                const [GuidyUi.green, Color(0xFF5CD3A6)]),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: stat(Icons.timer_outlined, isArabic ? 'وفّرت وقت' : 'Time Saved', _formatTimeSaved(l10n, timeSavedMin),
                const [Color(0xFFE88916), AppColors.brandAmber]),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(AppLocalizations l10n) {
    Widget chip(String label, bool selected, VoidCallback onTap, {IconData? icon}) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: GuidyPill(
            label: label,
            icon: selected && icon == null ? Icons.check_rounded : icon,
            selected: selected,
            onTap: onTap,
            color: selected ? null : (GuidyUi.mutedText(context)),
          ),
        );
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Time filters
          chip(l10n.filterAll, _timeFilter == 'all' && _modeFilter == null, () {
            setState(() {
              _timeFilter = 'all';
              _modeFilter = null;
            });
          }),
          chip(l10n.filterThisWeek, _timeFilter == 'this_week',
              () => setState(() => _timeFilter = _timeFilter == 'this_week' ? 'all' : 'this_week')),
          chip(l10n.filterThisMonth, _timeFilter == 'this_month',
              () => setState(() => _timeFilter = _timeFilter == 'this_month' ? 'all' : 'this_month')),
          // Mode filters
          chip(l10n.filterMetro, _modeFilter == 'metro', () => setState(() => _modeFilter = _modeFilter == 'metro' ? null : 'metro'),
              icon: Icons.subway_outlined),
          chip(l10n.filterBus, _modeFilter == 'bus', () => setState(() => _modeFilter = _modeFilter == 'bus' ? null : 'bus'),
              icon: Icons.directions_bus_outlined),
          chip(l10n.filterMicrobus, _modeFilter == 'microbus',
              () => setState(() => _modeFilter = _modeFilter == 'microbus' ? null : 'microbus'),
              icon: Icons.airport_shuttle_outlined),
        ],
      ),
    );
  }

  Widget _buildTripCard(
    BuildContext context,
    AppLocalizations l10n,
    TripHistoryEntry trip,
    bool isArabic,
  ) {
    final isDark = context.isDark;
    final primaryMode = trip.primaryMode ?? (trip.transitModes.isNotEmpty ? trip.transitModes.first : 'bus');

    final profile = trip.chosenProfile.toLowerCase();
    final isCustomized = profile.contains('custom') || profile.contains('تفصيل') || profile.contains('فصّل') ||
        (trip.option?['is_customized'] == true) || (trip.pathData['type'] == 'Customized');
    final isFastest = profile.contains('fastest') || profile.contains('أسرع') || profile.contains('fast');
    final isCheapest = profile.contains('cheapest') || profile.contains('أوفر') || profile.contains('ارخص') || profile.contains('cheap');
    final isWalkOnly = profile.contains('walk') || profile.contains('مشي') || (trip.transitModes.length == 1 && trip.transitModes.first == 'walk');

    // Route filter settings
    final isNoMetro = (trip.option?['exclude_metro'] == true) || (trip.pathData['exclude_metro'] == true) || profile.contains('no_metro');
    final isMinWalk = (trip.option?['min_walk'] == true) || (trip.pathData['min_walk'] == true) || profile.contains('min_walk');
    final isMinTransfers = (trip.option?['min_transfers'] == true) || (trip.pathData['min_transfers'] == true) || profile.contains('min_transfer');

    // Which kind of route this was, shown top-right as in the design.
    final String settingLabel;
    final IconData settingIcon;
    if (isCustomized) {
      settingLabel = isArabic ? 'سكة مفصّلة' : 'Customized';
      settingIcon = Icons.tune_rounded;
    } else if (isFastest) {
      settingLabel = isArabic ? 'أسرع سكة' : 'Fastest';
      settingIcon = Icons.bolt_rounded;
    } else if (isCheapest) {
      settingLabel = isArabic ? 'أوفر سكة' : 'Cheapest';
      settingIcon = Icons.savings_outlined;
    } else if (isWalkOnly) {
      settingLabel = isArabic ? 'مشي' : 'Walk';
      settingIcon = Icons.directions_walk_rounded;
    } else {
      // Default recommended / balanced transit route
      settingLabel = isArabic ? 'ترشيحنا' : 'Recommended';
      settingIcon = Icons.star_outline_rounded;
    }
    final extraTags = <String>[
      if (isNoMetro) isArabic ? 'بدون مترو' : 'No Metro',
      if (isMinWalk) isArabic ? 'أقل مشي' : 'Min Walk',
      if (isMinTransfers) isArabic ? 'أقل تحويلات' : 'Min Transfers',
    ];

    final distanceKm = (trip.transitDistanceMeters / 1000).toStringAsFixed(1);
    final fareStr = '${trip.transitFareEgp} ${isArabic ? "ج.م" : "EGP"}';
    final durationStr = l10n.minutes(trip.transitDurationMin);

    final muted = GuidyUi.mutedText(context);
    final routeNumber = (trip.routeNumber ?? '').trim();

    Widget stat(IconData icon, String label, String value, Color labelColor, Color valueColor) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: labelColor),
              const SizedBox(width: 3),
              Flexible(child: Text(label, style: TextStyle(fontSize: 11, color: labelColor), maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: valueColor)),
          ),
        ],
      );
    }

    Widget savingChip(IconData icon, String text, List<Color> colors) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: colors),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: Colors.white),
              const SizedBox(width: 4),
              Flexible(
                child: Text(text,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );

    final divider = Container(width: 1, height: 30, color: (isDark ? context.textSecondary : GuidyUi.mist).withValues(alpha: 0.5));

    return Dismissible(
      key: Key(trip.id),
      // Swiping is the only way to delete one trip; simple mode has no
      // swipe-only actions (Clear history asks first).
      direction: simpleMode.value ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: Colors.redAccent,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => _deleteTrip(trip),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(GuidyUi.radius), boxShadow: GuidyUi.cardShadow(context)),
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GuidyUi.radius)),
                elevation: 0,
                color: context.surfaceCard,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openTrip(trip),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 18, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date, then the route kind and mode on the right.
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _formatDate(trip.timestamp, isArabic),
                                style: TextStyle(fontSize: 12, color: context.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(settingIcon, size: 15, color: muted),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(settingLabel,
                                  style: TextStyle(fontSize: 12, color: muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 10),
                            Icon(
                              TransitModes.icon(primaryMode),
                              size: 18,
                              color: AppColors.brandBlue.withValues(alpha: 0.75),
                              semanticLabel: TransitModes.label(l10n, primaryMode),
                            ),
                            if (routeNumber.isNotEmpty) ...[
                              const SizedBox(width: 3),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 90),
                                child: Text(
                                  routeNumber,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.brandBlue),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (extraTags.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              for (final t in extraTags)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: GuidyUi.chipFill(context), borderRadius: BorderRadius.circular(10)),
                                  child: Text(t, style: TextStyle(fontSize: 10.5, color: context.textSecondary)),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        // Start and end, joined by the design's blue line.
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Column(
                                children: [
                                  Container(width: 11, height: 11, decoration: const BoxDecoration(color: AppColors.brandBlue, shape: BoxShape.circle)),
                                  Container(width: 2, height: 20, color: AppColors.brandBlue.withValues(alpha: 0.6)),
                                  const Icon(Icons.location_on_rounded, size: 16, color: AppColors.brandBlue),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _localizedLocation(trip.startName, isArabic,
                                        nameAr: trip.startNameAr, nameEn: trip.startNameEn, lat: trip.startLat, lon: trip.startLon),
                                    style: TextStyle(fontSize: 13, color: GuidyUi.heading(context)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _localizedLocation(trip.endName, isArabic,
                                        nameAr: trip.endNameAr, nameEn: trip.endNameEn, lat: trip.endLat, lon: trip.endLon),
                                    style: TextStyle(fontSize: 13, color: GuidyUi.heading(context)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Duration | Distance | Fare paid
                        Row(
                          children: [
                            Expanded(child: stat(Icons.schedule_rounded, isArabic ? 'المدة' : 'Duration', durationStr, AppColors.brandAmber, context.accentAmber)),
                            divider,
                            const SizedBox(width: 14),
                            Expanded(
                              child: stat(Icons.commit_rounded, isArabic ? 'المسافة' : 'Distance', '$distanceKm ${isArabic ? "كم" : "km"}', GuidyUi.heading(context),
                                  GuidyUi.heading(context)),
                            ),
                            divider,
                            const SizedBox(width: 14),
                            Expanded(child: stat(Icons.paid_outlined, l10n.tripDetailFarePaid, fareStr, GuidyUi.greenText(context), GuidyUi.greenText(context))),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Modes used, and the way into the recap.
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  for (final m in trip.transitModes.where((m) => m != 'walk'))
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: GuidyModeStyle.color(m, dark: isDark)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(TransitModes.icon(m), size: 14, color: GuidyModeStyle.color(m, dark: isDark)),
                                          const SizedBox(width: 4),
                                          Text(
                                            TransitModes.label(l10n, m),
                                            // Almarai has no italic; a slanted Arabic label is synthesized.
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontStyle: isArabic ? FontStyle.normal : FontStyle.italic,
                                                color: GuidyModeStyle.color(m, dark: isDark)),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Flexible(
                              child: Text(l10n.tripDetailOpenRecap,
                                  style: const TextStyle(fontSize: 12, color: AppColors.brandBlue), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.brandBlue),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Savings, as coloured tabs tucked under the card.
            if (trip.moneySavedEgp > 0 || trip.timeSavedMin > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    if (trip.moneySavedEgp > 0)
                      Expanded(
                        child: savingChip(
                          Icons.savings_rounded,
                          isArabic ? 'وفّرت ${trip.moneySavedEgp.toStringAsFixed(0)} ج.م' : '+${trip.moneySavedEgp.toStringAsFixed(0)} EGP saved',
                          const [GuidyUi.green, Color(0xFF5CD3A6)],
                        ),
                      ),
                    if (trip.moneySavedEgp > 0 && trip.timeSavedMin > 0) const SizedBox(width: 6),
                    if (trip.timeSavedMin > 0)
                      Expanded(
                        child: savingChip(
                          Icons.bolt_rounded,
                          isArabic ? 'وفّرت ${l10n.minutes(trip.timeSavedMin)}' : '+${l10n.minutes(trip.timeSavedMin)} saved',
                          const [Color(0xFFE88916), AppColors.brandAmber],
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, bool isArabic) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.directions_transit_filled_rounded,
                size: 64,
                color: AppColors.primaryTeal,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.emptyHistoryTitle,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.emptyHistorySubtitle,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: context.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LocationSearchScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.explore_outlined, color: Colors.white),
                label: Text(
                  l10n.planTripButton,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryTeal,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
