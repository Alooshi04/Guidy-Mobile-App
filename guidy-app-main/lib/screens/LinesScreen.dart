import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart' show TemplateType;

import 'LineDetailScreen.dart';
import '../services/api_service.dart';
import '../l10n/app_localizations.dart';
import '../services/instruction_formatter.dart';
import '../services/transit_modes.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';
import '../widgets/line_city_pill.dart';
import '../widgets/error_state.dart';
import '../widgets/marquee_text.dart';
import '../widgets/native_ad_card.dart';
import '../utils/minutes_text.dart';

/// "What does line 65 actually do?"
///
/// A rider standing at a stop watching a bus go past has a different
/// question from the one the trip planner answers. They don't want a
/// journey; they want to know whether *that* vehicle goes where they're
/// going. This screen is the table of contents for the network.
///
/// Search matches the number **and** the corridor, because roughly 300
/// microbus routes in the Cairo feed carry no number at all -- searching
/// only numbers would make a third of the network unreachable.
class LinesScreen extends StatefulWidget {
  /// How many line rows come before each in-feed ad.
  static const int adEvery = 8;

  /// The layout of one page of the feed: a row index for a line row, null
  /// for an ad slot. An ad follows every [adEvery]th row, but only when
  /// another row follows it, so there are never two ads in a row, none on
  /// a short page, and none right above the pagination controls.
  @visibleForTesting
  static List<int?> feedSlots(int rows) => [
        for (var r = 0; r < rows; r++) ...[
          r,
          if ((r + 1) % adEvery == 0 && r + 1 < rows) null,
        ],
      ];

  /// The fare line on a Lines card (see _RouteCard._fareForRoute).
  @visibleForTesting
  static String fareForRoute(Map<String, dynamic> route, bool isArabic) =>
      _RouteCard._fareForRoute(route, isArabic);

  final VoidCallback? onGoHome;

  /// Lets MainNavigator send the system back button here first.
  final LinesBackController? backController;

  /// Tests pass a fake; the app always uses the real one.
  @visibleForTesting
  final ApiService? api;

  const LinesScreen({super.key, this.onGoHome, this.backController, this.api});

  /// Whether the Alexandria-only view was on when the rider last used the
  /// Lines screen, so it survives tab switches for as long as the app runs.
  static bool _alexandriaViewOn = false;

  /// Forgets the remembered Alexandria view (tests share the static).
  @visibleForTesting
  static void resetAlexandriaView() => _alexandriaViewOn = false;

  @override
  State<LinesScreen> createState() => _LinesScreenState();
}

/// The tab screens live in one route, so a PopScope inside Lines would also
/// catch back presses made on the other tabs. MainNavigator asks this
/// instead, and only while the Lines tab is showing.
class LinesBackController {
  bool Function()? _handler;

  /// True when Lines went back a level (mode list or search to the grid),
  /// false when it is already on the grid.
  bool handleBack() => _handler?.call() ?? false;

  VoidCallback? _scrollToTop;

  /// Back to the top of the open list, for when another tab is chosen.
  void scrollToTop() => _scrollToTop?.call();
}

class _LinesScreenState extends State<LinesScreen> {
  static const int _pageSize = 20;

  late final ApiService _api = widget.api ?? ApiService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Timer? _debounce;
  String _query = '';
  String? _vehicleFilter;
  // The Alexandria view: the same Lines screen, but only Alexandria's lines
  // and the Cairo-Alexandria microbuses. They are a few of the 1,300 lines
  // and hard to find otherwise. Remembered across tab switches.
  bool _alexOnly = LinesScreen._alexandriaViewOn;
  // The vehicle types that have at least one Alexandria line, worked out
  // from the line data itself; null until loaded.
  List<String>? _alexModes;
  // The language of the last load ATTEMPT, successful or not. It used to
  // be assigned only inside the success branch, which meant a failed
  // first load left it empty -- and didChangeDependencies below guards on
  // it being non-empty, so switching language after a failure did nothing
  // at all. That is exactly what a rider sees when the backend is down:
  // the language toggle appears dead until they tap Retry.
  String _loadedLang = '';

  bool _loading = true;
  // A FLAG, not a translated sentence. This used to hold
  // AppLocalizations.of(context).linesLoadFailed, captured at the moment
  // the request failed -- so the error text stayed frozen in whichever
  // language was active when it broke. Switching to English left an
  // Arabic error on screen until something forced a refetch. The string
  // is now resolved in build(), which reruns on every locale change.
  bool _failed = false;
  List<Map<String, dynamic>> _routes = const [];
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    // Post-frame, not inline: _load() reads Localizations.localeOf(context),
    // and an inherited-widget lookup in initState throws.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    widget.backController?._handler = _handleBack;
    widget.backController?._scrollToTop = () {
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    };
  }

  bool _handleBack() {
    if (_showGrid) {
      if (!_alexOnly) return false;
      _setAlexOnly(false);
      return true;
    }
    _openMode(null);
    return true;
  }

  /// Enters or leaves the Alexandria view. Either way the rider lands on the
  /// tile grid of that view, with no mode picked and nothing typed.
  void _setAlexOnly(bool on) {
    _debounce?.cancel();
    _searchController.clear();
    setState(() {
      _alexOnly = on;
      _vehicleFilter = null;
      _query = '';
    });
    LinesScreen._alexandriaViewOn = on;
    _load();
  }

  /// Vehicle types of the Alexandria lines, in the grid's order and then any
  /// other type the data has (the Alexandria tram, say).
  List<String> _alexModesOf(List<Map<String, dynamic>> routes) {
    final present = <String>{
      for (final r in routes)
        if (lineCityOf(r) != LineCity.cairo) (r['vehicle_type'] as String?) ?? 'bus',
    };
    final known = [..._gridModes, _extraMode];
    return [
      for (final m in known)
        if (present.contains(m)) m,
      ...(present.difference(known.toSet()).toList()..sort()),
    ];
  }

  Future<void> _loadAlexModes(int id) async {
    if (_alexModes != null) {
      setState(() {
        _loading = false;
        _failed = false;
        _routes = const [];
        _loadedLang = '';
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
      _loadedLang = '';
    });
    try {
      final fetched = await _api.searchRoutes(lang: _langCode(), limit: 2000);
      if (!mounted || id != _requestId) return;
      setState(() {
        _alexModes = _alexModesOf(fetched);
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    widget.backController?._handler = null;
    widget.backController?._scrollToTop = null;
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Switching language has to re-query rather than just re-render: the
    // stop names in each row come from the backend already localized.
    final lang = Localizations.localeOf(context).languageCode;
    if (_loadedLang.isNotEmpty && _loadedLang != lang) _load();
  }

  void _onSearchChanged(String value) {
    // Rebuild immediately so the clear button appears on the first
    // keystroke rather than 350ms later with the results.
    setState(() {});
    _debounce?.cancel();
    // 350ms: long enough that typing "Maadi" is one request rather than
    // five, short enough that it still feels like live search.
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
      _load();
    });
  }

  /// Bumped on every load; a response for an older one is dropped, so a
  /// slow earlier search can't replace the list the rider is looking at.
  int _requestId = 0;

  Future<void> _load({bool resetPage = true}) async {
    final id = ++_requestId;
    if (_showGrid && _alexOnly) {
      await _loadAlexModes(id);
      return;
    }
    if (_showGrid) {
      // The tile grid shows no list, so there is nothing to fetch. An
      // empty _loadedLang also stops a language switch from fetching.
      setState(() {
        _loading = false;
        _failed = false;
        _routes = const [];
        _loadedLang = '';
      });
      return;
    }
    final lang = _langCode();
    setState(() {
      _loading = true;
      _failed = false;
      // Recorded up front, so a failed attempt still counts as "we tried
      // this language" and a later switch re-triggers the load.
      _loadedLang = lang;
      if (resetPage) {
        _currentPage = 1;
      }
    });
    try {
      final fetched = await _api.searchRoutes(query: _query, vehicleType: _vehicleFilter, lang: lang, limit: 2000);
      if (!mounted || id != _requestId) return;
      final results = _alexOnly ? fetched.where((r) => lineCityOf(r) != LineCity.cairo).toList() : fetched;
      setState(() {
        _routes = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  void _goToPage(int targetPage, int totalPages) {
    final safePage = targetPage.clamp(1, totalPages);
    if (safePage == _currentPage) return;
    setState(() {
      _currentPage = safePage;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeInOut);
    }
  }

  void _showJumpToPageDialog(BuildContext context, int totalPages, bool isArabic) {
    final controller = TextEditingController(text: '$_currentPage');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isArabic ? 'روح لصفحة' : 'Jump to Page',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: context.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? 'اكتب رقم الصفحة (من 1 إلى $totalPages):' : 'Enter page number (1 to $totalPages):',
              style: TextStyle(fontSize: 13, color: context.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: context.fieldFill,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              onSubmitted: (val) {
                final page = int.tryParse(val.trim());
                if (page != null) {
                  Navigator.pop(ctx);
                  _goToPage(page, totalPages);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: TextStyle(color: context.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final page = int.tryParse(controller.text.trim());
              if (page != null) {
                Navigator.pop(ctx);
                _goToPage(page, totalPages);
              }
            },
            child: Text(
              isArabic ? 'روح' : 'Go',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _langCode() {
    if (!mounted) return 'en';
    return Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
  }

  /// Modes shown as tiles on the Lines landing grid, in the design's order.
  static const List<String> _gridModes = ['bus', 'microbus', 'minibus', 'monorail', 'metro', 'lrt'];

  /// The seventh tile, centred under the grid.
  static const String _extraMode = 'brt';

  /// The landing grid shows when no mode is picked and nothing is typed.
  bool get _showGrid => _vehicleFilter == null && _query.isEmpty;

  /// Opens a mode's list, or with null goes back to the tile grid (which
  /// also clears the search, so the grid really shows).
  void _openMode(String? mode) {
    setState(() {
      _vehicleFilter = mode;
      if (mode == null) {
        _debounce?.cancel();
        _searchController.clear();
        _query = '';
      }
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mode = _vehicleFilter;
    final modeColor = mode == null ? null : GuidyModeStyle.color(mode, dark: context.isDark);
    // Inside a mode (or a search), back returns to the tile grid; on the
    // grid it goes Home like every other tab. The system back button does
    // the same, through MainNavigator and [LinesBackController].
    final backToGrid = !_showGrid;
    final alex = _alexOnly;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          GuidyHeader(
            title: mode == null
                ? (alex ? l10n.linesAlexandriaTitle : l10n.navLines)
                : (alex
                      ? l10n.linesAlexandriaOfMode(InstructionFormatter.vehicleTypeLabel(l10n, mode))
                      : l10n.linesOfMode(InstructionFormatter.vehicleTypeLabel(l10n, mode))),
            subtitle: mode != null ? l10n.linesTapHint : (alex ? l10n.linesAlexandriaHint : null),
            titleColor: modeColor,
            onBack: backToGrid ? () => _openMode(null) : (alex ? () => _setAlexOnly(false) : widget.onGoHome),
            showBack: backToGrid || alex || widget.onGoHome != null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: context.surfaceCard,
                borderRadius: BorderRadius.circular(GuidyUi.radius),
                boxShadow: GuidyUi.cardShadow(context),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  setState(() => _query = v.trim());
                  _load();
                },
                style: TextStyle(fontSize: 14, color: GuidyUi.heading(context)),
                decoration: InputDecoration(
                  hintText: l10n.linesSearchHint,
                  hintStyle: TextStyle(fontSize: 13, color: GuidyUi.mutedText(context)),
                  suffixIcon: _searchController.text.isEmpty
                      ? Icon(Icons.search, color: context.isDark ? context.textSecondary : GuidyUi.mist)
                      : IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: l10n.clearHistoryLabel,
                          onPressed: () {
                            _searchController.clear();
                            _debounce?.cancel();
                            setState(() => _query = '');
                            _load();
                          },
                        ),
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilterChip(
                key: const ValueKey('lines-alexandria-toggle'),
                avatar: Icon(Icons.location_city_rounded, size: 16, color: _alexOnly ? Colors.white : context.accentAmber),
                label: Text(l10n.lineCityAlexandria),
                selected: _alexOnly,
                showCheckmark: false,
                selectedColor: AppColors.brandBlue,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _alexOnly ? Colors.white : GuidyUi.heading(context),
                ),
                onSelected: _setAlexOnly,
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              child: _showGrid
                  ? KeyedSubtree(
                      key: ValueKey(alex ? 'alex-grid' : 'grid'),
                      child: alex ? _buildAlexGrid(l10n) : _buildModeGrid(_gridModes, _extraMode),
                    )
                  : KeyedSubtree(key: ValueKey('list-$mode'), child: _buildBody(l10n)),
            ),
          ),
        ],
      ),
    );
  }

  /// The Alexandria landing page: tiles for the modes the data says run there.
  Widget _buildAlexGrid(AppLocalizations l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) return ErrorState(message: l10n.linesLoadFailed, onRetry: _load);
    final modes = _alexModes ?? const <String>[];
    if (modes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l10n.linesAlexandriaEmpty,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
        ),
      );
    }
    final paired = modes.length - modes.length % 2;
    return _buildModeGrid(modes.sublist(0, paired), modes.length.isOdd ? modes.last : null);
  }

  /// The Lines landing page: one tile per transport mode, plus an optional
  /// last tile centred under them.
  Widget _buildModeGrid(List<String> modes, String? extraMode) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 10, 26, 24),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 24,
          crossAxisSpacing: 24,
          childAspectRatio: 134 / 117,
          children: [for (final m in modes) _ModeTile(mode: m, onTap: () => _openMode(m))],
        ),
        if (extraMode != null) ...[
          const SizedBox(height: 24),
          // The odd tile out (Ring Road BRT on the full grid), same size as
          // the others, centred.
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - 24) / 2;
              return Center(
                child: SizedBox(
                  width: width,
                  height: width * 117 / 134,
                  child: _ModeTile(mode: extraMode, onTap: () => _openMode(extraMode)),
                ),
              );
            },
          ),
        ],
        // Foot of the page, clear of the tiles (24 below them plus the
        // card's own gap).
        const NativeAdCard(template: TemplateType.small),
      ],
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_failed) return ErrorState(message: l10n.linesLoadFailed, onRetry: _load);
    if (_routes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            _query.isEmpty ? l10n.linesSearchPrompt : l10n.linesNoResults,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final totalItems = _routes.length;
    final totalPages = (totalItems == 0) ? 1 : ((totalItems - 1) ~/ _pageSize) + 1;
    final validPage = _currentPage.clamp(1, totalPages);
    final startIndex = (validPage - 1) * _pageSize;
    final endIndex = (startIndex + _pageSize < totalItems) ? startIndex + _pageSize : totalItems;
    final pageItems = _routes.sublist(startIndex, endIndex);
    final slots = LinesScreen.feedSlots(pageItems.length);

    return Column(
      children: [
        // Top summary indicator: clear finite indicator
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isArabic
                    ? (totalPages > 1 ? '${startIndex + 1} إلى $endIndex من $totalItems خط' : '$totalItems خطوط متاحة')
                    : (totalPages > 1 ? 'Showing ${startIndex + 1} to $endIndex of $totalItems lines' : '$totalItems lines available'),
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSecondary),
              ),
              if (totalPages > 1)
                InkWell(
                  onTap: () => _showJumpToPageDialog(context, totalPages, isArabic),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primaryTeal.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isArabic ? 'صفحة $validPage من $totalPages' : 'Page $validPage of $totalPages',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primaryTeal),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.swap_vert_rounded, size: 13, color: AppColors.primaryTeal),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Finite Page List
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            itemCount: slots.length + 1,
            itemBuilder: (context, i) {
              if (i < slots.length) {
                final row = slots[i];
                // A separate card per slot (one request each), keyed by page
                // so turning the page asks for fresh ones. Google's own "Ad"
                // badge labels it; its gap keeps it from passing as a row.
                if (row == null) {
                  return NativeAdCard(
                    key: ValueKey('lines_feed_ad_${validPage}_$i'),
                    template: TemplateType.small,
                  );
                }
                final route = pageItems[row];
                return _RouteCard(
                  route: route,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LineDetailScreen(routeId: route['route_id'] as String, fallbackTitle: _titleFor(route, l10n)),
                    ),
                  ),
                );
              }
              // Pagination controls at bottom of current page
              return _buildPaginationControls(
                context: context,
                isArabic: isArabic,
                currentPage: validPage,
                totalPages: totalPages,
                totalItems: totalItems,
                startIndex: startIndex,
                endIndex: endIndex,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationControls({
    required BuildContext context,
    required bool isArabic,
    required int currentPage,
    required int totalPages,
    required int totalItems,
    required int startIndex,
    required int endIndex,
  }) {
    if (totalPages <= 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: context.surfaceCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0)),
            ),
            child: Text(
              isArabic ? 'كل الخطوط قدامك ($totalItems خط)' : 'All $totalItems lines displayed',
              style: TextStyle(fontSize: 12.5, color: context.textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );
    }

    // Build list of visible page buttons (e.g. 1 ... 4 5 6 ... 55)
    final pageButtons = <Widget>[];
    final visiblePages = <int>{};
    visiblePages.add(1);
    visiblePages.add(totalPages);
    for (int offset = -1; offset <= 1; offset++) {
      final p = currentPage + offset;
      if (p >= 1 && p <= totalPages) visiblePages.add(p);
    }
    final sortedPages = visiblePages.toList()..sort();

    int? prevPage;
    for (final p in sortedPages) {
      if (prevPage != null && p > prevPage + 1) {
        final jumpTarget = ((prevPage + p) ~/ 2);
        pageButtons.add(
          InkWell(
            onTap: () => _goToPage(jumpTarget, totalPages),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: 30,
              height: 38,
              alignment: Alignment.center,
              child: Text(
                '…',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: context.textSecondary),
              ),
            ),
          ),
        );
      }

      final isSelected = (p == currentPage);
      pageButtons.add(
        InkWell(
          onTap: isSelected ? null : () => _goToPage(p, totalPages),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            constraints: const BoxConstraints(minWidth: 36),
            height: 38,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryTeal : context.surfaceCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryTeal
                    : (context.isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: AppColors.primaryTeal.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
                  : null,
            ),
            child: Text(
              '$p',
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : context.textPrimary,
              ),
            ),
          ),
        ),
      );
      prevPage = p;
    }

    final hasPrev = currentPage > 1;
    final hasNext = currentPage < totalPages;

    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 24),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Previous button
                InkWell(
                  onTap: hasPrev ? () => _goToPage(currentPage - 1, totalPages) : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Opacity(
                    opacity: hasPrev ? 1.0 : 0.35,
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chevron_left_rounded,
                            size: 18,
                            color: hasPrev ? AppColors.primaryTeal : context.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isArabic ? 'السابق' : 'Prev',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: hasPrev ? context.textPrimary : context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Page numbers
                ...pageButtons,

                const SizedBox(width: 6),

                // Next button
                InkWell(
                  onTap: hasNext ? () => _goToPage(currentPage + 1, totalPages) : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Opacity(
                    opacity: hasNext ? 1.0 : 0.35,
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.surfaceCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: context.isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isArabic ? 'التالي' : 'Next',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: hasNext ? context.textPrimary : context.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: hasNext ? AppColors.primaryTeal : context.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Tappable Page count summary for quick jumping
          InkWell(
            onTap: totalPages > 2 ? () => _showJumpToPageDialog(context, totalPages, isArabic) : null,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isArabic
                        ? 'صفحة $currentPage من $totalPages (${startIndex + 1} إلى $endIndex من $totalItems خط)'
                        : 'Page $currentPage of $totalPages (${startIndex + 1} to $endIndex of $totalItems lines)',
                    style: TextStyle(fontSize: 12, color: context.textSecondary, fontWeight: FontWeight.w500),
                  ),
                  if (totalPages > 2) ...[
                    const SizedBox(width: 5),
                    const Icon(Icons.swap_vert_rounded, size: 14, color: AppColors.primaryTeal),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _titleFor(Map<String, dynamic> route, AppLocalizations l10n) {
    if (InstructionFormatter.cleanRouteNumber(route['number']?.toString()) != null) {
      return InstructionFormatter.lineLabel(l10n, _asLine(route));
    }
    final description = (route['description'] ?? '').toString();
    if (description.isNotEmpty) return description;
    return InstructionFormatter.vehicleTypeLabel(l10n, route['vehicle_type'] as String?);
  }
}

/// The Lines endpoints call the route number `number`; InstructionFormatter
/// speaks the routing payload's `route_number`.
Map<String, dynamic> _asLine(Map<String, dynamic> route) => {...route, 'route_number': route['number']};

/// One tile of the Lines landing grid: the mode's icon and name in its
/// colour, on a card outlined in the same colour.
class _ModeTile extends StatelessWidget {
  final String mode;
  final VoidCallback onTap;

  const _ModeTile({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color = GuidyModeStyle.color(mode, dark: context.isDark);
    final icon = GuidyModeStyle.icon(mode);
    return GuidyCard(
      onTap: onTap,
      borderColor: color,
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: icon == null ? Icon(TransitModes.icon(mode), color: color, size: 44) : GuidySvgIcon(icon, size: 52, color: color),
          ),
          const SizedBox(height: 6),
          // Long names (the LRT in Arabic) keep their size and slide
          // through the tile instead.
          Center(
            child: MarqueeText(
              InstructionFormatter.vehicleTypeLabel(l10n, mode),
              // Almarai has no italic, so Arabic labels stay upright.
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                fontStyle: Localizations.localeOf(context).languageCode == 'ar' ? FontStyle.normal : FontStyle.italic,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  final Map<String, dynamic> route;
  final VoidCallback onTap;

  const _RouteCard({required this.route, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mode = route['vehicle_type'] as String?;
    // Badge shows the bare code ("910", "M11", "G1"); the mode/operator is
    // spelled out beside it. The feed's short names carry prefixes
    // ("CTA 910", "Minibus 305") or are only a vehicle word ("Microbus",
    // "Tomnaya"), which put a category in the number badge.
    final number = GuidyModeStyle.badgeNumber(InstructionFormatter.cleanRouteNumber(route['number']?.toString()));
    // Metro lines get the design's big "M1 / M2 / M3" badge in the line's
    // own colour instead of a vehicle icon.
    final metroNumber = mode == 'metro' ? GuidyModeStyle.metroLineNumber(route) : null;
    final metroColor = metroNumber == null ? null : GuidyModeStyle.metroLine(metroNumber);
    final color = metroColor ?? GuidyModeStyle.color(mode, dark: context.isDark);
    final icon = GuidyModeStyle.icon(mode);
    final rawDescription = (route['description'] ?? '').toString().trim();
    // Lines sharing a number with the same ends are told apart by a stop
    // only one of them serves (backend route_variants).
    final variant = InstructionFormatter.variantOf(route);
    final description = variant != null && variant != rawDescription && !rawDescription.contains(variant)
        ? (rawDescription.isEmpty ? variant : '$rawDescription ($variant)')
        : rawDescription;
    final vehicle = InstructionFormatter.vehicleLabelFor(l10n, _asLine(route));
    final headway = route['typical_headway_min'];
    final stopCount = InstructionFormatter.asNum(route['stop_count'])?.toInt() ?? 0;
    final from = (route['from'] ?? '').toString().trim();
    final to = (route['to'] ?? '').toString().trim();
    final hasEnds = from.isNotEmpty && to.isNotEmpty;
    final hasBrand = InstructionFormatter.brandOf(_asLine(route)) != TransitBrand.none;
    final muted = GuidyUi.mutedText(context);
    final divider = context.isDark ? context.textSecondary : GuidyUi.mist;
    final city = lineCityOf(route);
    final semantic = [
      InstructionFormatter.vehicleTypeLabel(l10n, mode),
      if (metroNumber != null) 'M$metroNumber' else if (number.isNotEmpty) number,
      if (city == LineCity.alexandria) l10n.lineCityAlexandria,
      if (city == LineCity.intercity) l10n.lineCityIntercity,
    ].join(' ');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: divider.withValues(alpha: 0.45))),
          ),
          child: Row(
            children: [
              // Mode tile: icon with the line number under it. Unnumbered
              // microbus corridors get the icon alone. Read out as
              // "Bus 910" / "Metro M1", since the icon itself has no text.
              Semantics(
                label: semantic,
                excludeSemantics: true,
                child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: context.surfaceCard,
                  borderRadius: BorderRadius.circular(GuidyUi.radius),
                  border: Border.all(color: color),
                  boxShadow: GuidyUi.cardShadow(context),
                ),
                padding: const EdgeInsets.all(6),
                child: metroColor != null
                    ? Center(
                        child: Text(
                          'M$metroNumber',
                          style: GuidyUi.display(context, size: 28, color: metroColor, weight: FontWeight.w700),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (icon != null)
                            GuidySvgIcon(icon, size: number.isEmpty ? 38 : 28, color: color)
                          else
                            Icon(TransitModes.icon(mode), color: color, size: number.isEmpty ? 34 : 24),
                          if (number.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            MarqueeText(
                              number,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                fontStyle: FontStyle.italic,
                                color: color,
                              ),
                            ),
                          ],
                        ],
                      ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarqueeText(
                      (hasEnds ? from : (description.isEmpty ? vehicle : description)).toUpperCase(),
                      style: TextStyle(fontSize: 12.5, color: GuidyUi.heading(context)),
                    ),
                    if (hasEnds)
                      Row(
                        children: [
                          Icon(Icons.arrow_forward_rounded, size: 12, color: color),
                          const SizedBox(width: 3),
                          Expanded(
                            child: MarqueeText(
                              to,
                              style: TextStyle(fontSize: 12.5, color: GuidyUi.heading(context)),
                            ),
                          ),
                        ],
                      ),
                    // The variant ("via X") is what tells two lines with the
                    // same number and ends apart, so it shows under the ends.
                    if (hasEnds && description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: MarqueeText(
                          description,
                          style: TextStyle(fontSize: 11.5, color: muted),
                        ),
                      ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 10,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Alexandria / intercity lines are marked; Cairo and
                        // Giza lines get nothing and look as they always did.
                        if (city != LineCity.cairo) LineCityPill(route: route),
                        if (hasBrand) _meta(context, Icons.verified_outlined, vehicle, muted),
                        _meta(context, Icons.commit_rounded, l10n.linesStopCount(stopCount), muted),
                        if (headway != null)
                          _meta(
                            context,
                            Icons.schedule_rounded,
                            l10n.linesEveryMinutes(l10n.minutes(InstructionFormatter.asNum(headway))),
                            muted,
                          ),
                        _meta(
                          context,
                          Icons.paid_outlined,
                          _fareForRoute(route, Localizations.localeOf(context).languageCode == 'ar'),
                          muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }

  // Metro/LRT/monorail/apm ranges below are band descriptions, not a
  // single number, so they have nowhere to plug a real figure into and
  // stay as static text (kept in sync with raptor_engine.BANDED_FARE_TIERS
  // by hand -- same as LineDetailScreen._detailedFareText). Bus and
  // minibus are flat per-boarding fares, and the backend now sends the
  // real current one as `route['fare_egp']` (see lookups.py
  // search_routes) -- this used to hardcode '10 EGP'/'14 EGP' here
  // instead of reading it, which is exactly why this card could show a
  // different, stale fare than the one the detail screen showed for the
  // same route: the detail screen already read the real value, this
  // card never did.
  static String _fareForRoute(Map<String, dynamic> route, bool isArabic) {
    final mode = (route['vehicle_type'] as String? ?? 'bus').toLowerCase();
    final fare = InstructionFormatter.asNum(route['fare_egp'])?.round();

    if (mode == 'metro' || mode.contains('subway')) {
      return isArabic ? '10 لـ 20 ج.م' : '10 to 20 EGP';
    } else if (mode == 'lrt') {
      return isArabic ? '10 لـ 20 ج.م' : '10 to 20 EGP';
    } else if (mode == 'monorail') {
      return isArabic ? '20 لـ 80 ج.م' : '20 to 80 EGP';
    } else if (mode == 'minibus') {
      final n = fare ?? 20;
      return isArabic ? '$n ج.م' : '$n EGP';
    } else if (mode == 'brt') {
      // Ring Road BRT: 5 / 10 / 15 EGP for up to 4 / 9 / 14 stations.
      return isArabic ? '5 لـ 15 ج.م' : '5 to 15 EGP';
    } else if (mode == 'microbus') {
      // A line with a published fare of its own (Alexandria's tariff, the
      // Cairo-Alexandria microbuses) says it; a Cairo microbus is priced by
      // distance, so it keeps the range. An Alexandria microbus also charges
      // by distance up to its line fare: fare_from_egp is the shortest ride.
      final own = InstructionFormatter.asNum(route['fare_egp']);
      if (own != null) {
        String fmt(num v) => v % 1 == 0 ? v.toInt().toString() : v.toString();
        final from = InstructionFormatter.asNum(route['fare_from_egp']);
        if (from != null && from < own) {
          return isArabic ? '${fmt(from)} لـ ${fmt(own)} ج.م' : '${fmt(from)} to ${fmt(own)} EGP';
        }
        return isArabic ? '${fmt(own)} ج.م' : '${fmt(own)} EGP';
      }
      return isArabic ? '10 لـ 15 ج.م' : '10 to 15 EGP';
    } else if (mode == 'apm') {
      return isArabic ? 'ببلاش' : 'Free';
    } else {
      final isAC = InstructionFormatter.isAcBus(_asLine(route));
      if (fare != null) {
        return isArabic ? '$fare ج.م' : '$fare EGP';
      }
      if (isAC) {
        return isArabic ? '45 ج.م' : '45 EGP';
      }
      // Standard CTA bus fare: 20 EGP (matches 2026 tariff in raptor_engine.py)
      final n = fare ?? 20;
      return isArabic ? '$n ج.م' : '$n EGP';
    }
  }

  Widget _meta(BuildContext context, IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(text, style: TextStyle(fontSize: 11.5, color: color)),
      ],
    );
  }
}
