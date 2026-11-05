import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../services/better_route.dart';
import '../services/route_report_service.dart';
import '../services/route_summary.dart';
import '../services/transit_modes.dart';
import '../theme/app_theme.dart';
import '../theme/guidy_ui.dart';
import '../widgets/error_state.dart';
import '../widgets/route_options/better_route_sheet.dart';
import '../widgets/route_options/route_card.dart' show RouteLineChip;

/// Sends a better route; RouteReportService.submitBetterRoute in the app.
typedef BetterRouteSubmit = Future<RouteReportOutcome> Function(BetterRouteReport report);

/// "Build it from the transport network": the rider puts together the
/// route they know, leg by leg. A walk (how far, if they know), a ride on
/// a line from the network (searched like the Lines screen) or one they
/// type because we don't have it, where they board and get off and what
/// it cost. Legs can be dragged into order and removed.
///
/// It sends a structured report (`legs`, both ends, what we offered), so a
/// route that beats ours can be checked against the feed rather than read
/// out of a paragraph. Pops with the outcome once the report is sent or
/// queued; a report that couldn't go stays here, so nothing typed is lost.
class BetterRouteBuilderScreen extends StatefulWidget {
  const BetterRouteBuilderScreen({
    super.key,
    required this.startLat,
    required this.startLon,
    required this.startName,
    required this.endLat,
    required this.endLon,
    required this.endName,
    this.shownOptions = const [],
    this.submit = RouteReportService.submitBetterRoute,
    this.api,
  });

  final double startLat;
  final double startLon;
  final String startName;
  final double endLat;
  final double endLon;
  final String endName;

  /// BetterRouteReport.summarize of the routes the rider was shown.
  final List<Map<String, dynamic>> shownOptions;

  final BetterRouteSubmit submit;

  /// Tests pass a fake; the app uses the real one.
  @visibleForTesting
  final ApiService? api;

  @override
  State<BetterRouteBuilderScreen> createState() => _BetterRouteBuilderScreenState();
}

class _BetterRouteBuilderScreenState extends State<BetterRouteBuilderScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  final List<BetterRouteLeg> _legs = [];
  final TextEditingController _note = TextEditingController();
  bool _sending = false;

  /// Sent, or the rider chose to leave: back no longer asks.
  bool _done = false;

  bool get _hasRide => _legs.any((l) => !l.isWalk);
  bool get _dirty => _legs.isNotEmpty || _note.text.trim().isNotEmpty;
  bool get _full => _legs.length >= BetterRouteReport.maxLegs;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _addWalk() {
    HapticFeedback.selectionClick();
    setState(() => _legs.add(BetterRouteLeg.walk()));
  }

  /// Picks a line for a new ride, or for the ride at [replace] (keeping
  /// what the rider already said about where they board and the fare).
  Future<void> _pickLine({int? replace}) async {
    final picked = await Navigator.push<BetterRouteLeg>(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => BetterRouteLinePicker(api: _api)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (replace == null) {
        _legs.add(picked);
        return;
      }
      final old = _legs[replace];
      _legs[replace] = picked
        ..boardAt = old.boardAt
        ..alightAt = old.alightAt
        ..fare = old.fare;
    });
  }

  void _reorder(int from, int to) => setState(() => _legs.insert(to, _legs.removeAt(from)));

  Future<void> _send() async {
    if (!_hasRide || _sending) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    final outcome = await widget.submit(BetterRouteReport(
      startLat: widget.startLat,
      startLon: widget.startLon,
      endLat: widget.endLat,
      endLon: widget.endLon,
      startName: widget.startName,
      endName: widget.endName,
      locale: Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en',
      comment: _note.text,
      legs: [for (final l in _legs) l.toReport()],
      shownOptions: widget.shownOptions,
    ));
    if (!mounted) return;
    setState(() => _sending = false);
    if (outcome == RouteReportOutcome.sent || outcome == RouteReportOutcome.queuedOffline) {
      _done = true;
      Navigator.pop(context, outcome);
    } else {
      messenger.showSnackBar(SnackBar(content: Text(reportOutcomeText(l10n, outcome))));
    }
  }

  Future<void> _confirmLeave() async {
    final l10n = AppLocalizations.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.betterRouteDiscardTitle),
        content: Text(l10n.betterRouteDiscardBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.betterRouteDiscardStay)),
          TextButton(
            key: const ValueKey('better-route-leave'),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.betterRouteDiscardLeave),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      setState(() => _done = true);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final muted = GuidyUi.mutedText(context);
    return PopScope(
      canPop: _done || !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        backgroundColor: context.surfaceCard,
        body: Column(
          children: [
            SafeArea(
              bottom: false,
              child: GuidyHeader(
                title: l10n.betterRouteBuilderTitle,
                showLanguageToggle: false,
                below: GuidyTripEndpoints(start: widget.startName, end: widget.endName),
              ),
            ),
            Expanded(
              child: ReorderableListView(
                key: const ValueKey('better-route-legs'),
                buildDefaultDragHandles: false,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                onReorderItem: _reorder,
                header: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(l10n.betterRouteBuilderIntro, style: TextStyle(fontSize: 13.5, height: 1.35, color: muted)),
                ),
                footer: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_full)
                      Row(children: [
                        Expanded(
                          child: _addButton(const ValueKey('better-route-add-walk'), Icons.directions_walk_rounded,
                              l10n.betterRouteAddWalk, _addWalk),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _addButton(const ValueKey('better-route-add-ride'), Icons.directions_bus_rounded,
                              l10n.betterRouteAddRide, () => _pickLine()),
                        ),
                      ]),
                    const SizedBox(height: 16),
                    TextField(
                      key: const ValueKey('better-route-note'),
                      controller: _note,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: RouteReportService.maxCommentLength,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(hintText: l10n.betterRouteNoteHint, border: const OutlineInputBorder()),
                    ),
                  ],
                ),
                children: [
                  for (var i = 0; i < _legs.length; i++)
                    _LegCard(
                      key: ValueKey('better-route-leg-${_legs[i].id}'),
                      leg: _legs[i],
                      index: i,
                      onRemove: () => setState(() => _legs.removeAt(i)),
                      onChangeLine: () => _pickLine(replace: i),
                      onMoveUp: i == 0 ? null : () => _reorder(i, i - 1),
                      onMoveDown: i == _legs.length - 1 ? null : () => _reorder(i, i + 1),
                    ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!_hasRide)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(l10n.betterRouteNeedRide,
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: muted)),
                      ),
                    GuidyGradientButton(
                      key: const ValueKey('better-route-submit'),
                      height: 52,
                      fontSize: 15,
                      icon: Icons.send_rounded,
                      label: l10n.betterRouteSubmit,
                      loading: _sending,
                      onPressed: _hasRide ? _send : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _addButton(Key key, IconData icon, String label, VoidCallback onTap) => OutlinedButton.icon(
        key: key,
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(label, maxLines: 2, textAlign: TextAlign.center),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandBlue,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: AppColors.brandBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GuidyUi.radius)),
        ),
      );
}

/// One leg being built: the walk or the line (drawn like the route cards
/// draw it) and its optional details, with a rail to move it at the start.
/// Up and down buttons as well as the drag handle: a ride card is twice a
/// walk's height, and Flutter's drag only sometimes moves a tall item past
/// a short one.
class _LegCard extends StatefulWidget {
  const _LegCard({
    super.key,
    required this.leg,
    required this.index,
    required this.onRemove,
    required this.onChangeLine,
    this.onMoveUp,
    this.onMoveDown,
  });

  final BetterRouteLeg leg;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChangeLine;

  /// Null at the top (or the bottom).
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  State<_LegCard> createState() => _LegCardState();
}

class _LegCardState extends State<_LegCard> {
  late final TextEditingController _meters = TextEditingController(text: widget.leg.meters?.toString() ?? '');
  late final TextEditingController _board = TextEditingController(text: widget.leg.boardAt ?? '');
  late final TextEditingController _alight = TextEditingController(text: widget.leg.alightAt ?? '');
  late final TextEditingController _fare = TextEditingController(text: widget.leg.fare?.toString() ?? '');

  static final _digits = FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹]'));
  static final _decimal = FilteringTextInputFormatter.allow(RegExp(r'[0-9٠-٩۰-۹.,٫]'));

  @override
  void dispose() {
    for (final c in [_meters, _board, _alight, _fare]) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _field(String label) =>
      InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder());

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final leg = widget.leg;
    final muted = GuidyUi.mutedText(context);
    final color = leg.isWalk ? GuidyModeStyle.walkStep : GuidyModeStyle.forRide(leg.asRide, dark: context.isDark);
    final description = leg.routeDescription?.trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: context.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: color.withValues(alpha: 0.55)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(2, 4, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(children: [
                _railButton(Icons.keyboard_arrow_up_rounded, l10n.betterRouteMoveUp, widget.onMoveUp),
                ReorderableDragStartListener(
                  index: widget.index,
                  child: Tooltip(
                    message: l10n.betterRouteReorderHint,
                    child: SizedBox(
                      key: ValueKey('better-route-drag-${leg.id}'),
                      width: 40,
                      height: 36,
                      child: Icon(Icons.drag_indicator_rounded, color: muted),
                    ),
                  ),
                ),
                _railButton(Icons.keyboard_arrow_down_rounded, l10n.betterRouteMoveDown, widget.onMoveDown),
              ]),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(
                        child: leg.isWalk
                            ? Row(children: [
                                Icon(Icons.directions_walk_rounded, size: 22, color: color),
                                const SizedBox(width: 6),
                                Text(l10n.vehicleWalk,
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary)),
                              ])
                            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                  RouteLineChip(
                                    leg: RouteLeg.ride(
                                        step: leg.asRide, stepIndex: -1, lineLabels: const [], line: leg.label(l10n)),
                                  ),
                                  if (!leg.fromNetwork)
                                    GuidyPill(label: l10n.betterRouteTypedBadge, icon: Icons.add_road_rounded, fontSize: 11),
                                ]),
                                if (description.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(description,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12, color: muted)),
                                  ),
                              ]),
                      ),
                      if (!leg.isWalk)
                        IconButton(
                          key: ValueKey('better-route-change-${leg.id}'),
                          icon: const Icon(Icons.swap_horiz_rounded),
                          color: AppColors.brandBlue,
                          tooltip: l10n.betterRouteChangeLine,
                          onPressed: widget.onChangeLine,
                        ),
                      IconButton(
                        key: ValueKey('better-route-remove-${leg.id}'),
                        icon: const Icon(Icons.close_rounded),
                        color: muted,
                        tooltip: l10n.betterRouteRemoveLeg,
                        onPressed: widget.onRemove,
                      ),
                    ]),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: leg.isWalk
                          ? TextField(
                              key: ValueKey('better-route-meters-${leg.id}'),
                              controller: _meters,
                              keyboardType: TextInputType.number,
                              inputFormatters: [_digits, LengthLimitingTextInputFormatter(5)],
                              decoration: _field(l10n.betterRouteWalkMeters),
                              onChanged: (v) => leg.meters = BetterRouteLeg.parseNumber(v)?.round(),
                            )
                          : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                              TextField(
                                key: ValueKey('better-route-board-${leg.id}'),
                                controller: _board,
                                inputFormatters: [LengthLimitingTextInputFormatter(80)],
                                decoration: _field(l10n.betterRouteBoardAt),
                                onChanged: (v) => leg.boardAt = v,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                key: ValueKey('better-route-alight-${leg.id}'),
                                controller: _alight,
                                inputFormatters: [LengthLimitingTextInputFormatter(80)],
                                decoration: _field(l10n.betterRouteGetOffAt),
                                onChanged: (v) => leg.alightAt = v,
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                key: ValueKey('better-route-fare-${leg.id}'),
                                controller: _fare,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [_decimal, LengthLimitingTextInputFormatter(6)],
                                decoration: _field(l10n.betterRouteFare),
                                // Decimal: 7.5 stays 7.5.
                                onChanged: (v) => leg.fare = BetterRouteLeg.parseNumber(v),
                              ),
                            ]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _railButton(IconData icon, String tooltip, VoidCallback? onPressed) => IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        color: AppColors.brandBlue,
        disabledColor: GuidyUi.mutedText(context).withValues(alpha: 0.35),
        visualDensity: VisualDensity.compact,
        onPressed: onPressed,
      );
}

/// Picks the line for a ride: search the network by number or place
/// (ApiService.searchRoutes, as the Lines screen does), narrow it to a
/// mode, or type a line the app doesn't have. Pops with the leg.
class BetterRouteLinePicker extends StatefulWidget {
  const BetterRouteLinePicker({super.key, required this.api});

  final ApiService api;

  /// What a rider can say a typed line is.
  static const List<String> typedModes = ['microbus', 'minibus', 'bus', 'brt', 'metro', 'monorail', 'lrt', 'tram'];

  @override
  State<BetterRouteLinePicker> createState() => _BetterRouteLinePickerState();
}

class _BetterRouteLinePickerState extends State<BetterRouteLinePicker> {
  final TextEditingController _search = TextEditingController();
  final TextEditingController _typedName = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _mode;
  bool _loading = false;
  bool _failed = false;
  List<Map<String, dynamic>> _routes = const [];
  bool _typing = false;
  String _typedMode = BetterRouteLinePicker.typedModes.first;

  /// Bumped on every load; an answer to an older one is dropped.
  int _requestId = 0;

  bool get _idle => _query.isEmpty && _mode == null;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _typedName.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _query = value.trim());
      _load();
    });
  }

  Future<void> _load() async {
    final id = ++_requestId;
    if (_idle) {
      setState(() {
        _loading = false;
        _failed = false;
        _routes = const [];
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final lang = Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
      final found = await widget.api.searchRoutes(query: _query, vehicleType: _mode, lang: lang, limit: 200);
      if (!mounted || id != _requestId) return;
      setState(() {
        _routes = found;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.surfaceCard,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: GuidyHeader(
              title: _typing ? l10n.betterRouteNotInApp : l10n.betterRoutePickLineTitle,
              showLanguageToggle: false,
              onBack: _typing ? () => setState(() => _typing = false) : null,
            ),
          ),
          Expanded(child: _typing ? _typedForm(l10n) : _searchView(l10n)),
        ],
      ),
    );
  }

  Widget _searchView(AppLocalizations l10n) {
    final muted = GuidyUi.mutedText(context);
    Widget note(String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, color: muted)),
        );
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          key: const ValueKey('better-route-line-search'),
          controller: _search,
          autofocus: true,
          onChanged: _onSearchChanged,
          textInputAction: TextInputAction.search,
          onSubmitted: (v) {
            _debounce?.cancel();
            setState(() => _query = v.trim());
            _load();
          },
          decoration: InputDecoration(
            hintText: l10n.linesSearchHint,
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: context.fieldFill,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(GuidyUi.radius), borderSide: BorderSide.none),
          ),
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          for (final m in TransitModes.browsableFilters)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: GuidyPill(
                key: ValueKey('better-route-mode-${m ?? 'all'}'),
                label: m == null ? l10n.filterAll : TransitModes.label(l10n, m),
                icon: m == null ? null : TransitModes.icon(m),
                selected: _mode == m,
                color: m == null ? null : GuidyModeStyle.color(m, dark: context.isDark),
                onTap: () {
                  setState(() => _mode = m);
                  _load();
                },
              ),
            ),
        ]),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('better-route-not-in-app'),
                onPressed: () => setState(() => _typing = true),
                icon: Icon(Icons.edit_rounded, size: 18, color: betterRouteInk(context)),
                label: Text(l10n.betterRouteNotInApp,
                    style: TextStyle(fontWeight: FontWeight.w700, color: betterRouteInk(context))),
              ),
            ),
            if (_loading)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (_failed)
              ErrorState(message: l10n.linesLoadFailed, onRetry: _load)
            else if (_idle)
              note(l10n.linesSearchPrompt)
            else if (_routes.isEmpty)
              note(l10n.linesNoResults)
            else
              for (final r in _routes) _row(l10n, r),
          ],
        ),
      ),
    ]);
  }

  Widget _row(AppLocalizations l10n, Map<String, dynamic> route) {
    final leg = BetterRouteLeg.line(route);
    final color = GuidyModeStyle.forRide(leg.asRide, dark: context.isDark);
    final from = (route['from'] ?? '').toString().trim();
    final to = (route['to'] ?? '').toString().trim();
    final muted = GuidyUi.mutedText(context);
    final description = (leg.routeDescription ?? '').trim();
    return ListTile(
      key: ValueKey('better-route-line-${leg.routeId}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(TransitModes.icon(leg.vehicleType), color: color, size: 28),
      title: Text(leg.label(l10n), style: TextStyle(fontWeight: FontWeight.w800, color: context.textPrimary)),
      // Its two ends, as the Lines screen shows them, else its corridor.
      subtitle: from.isNotEmpty && to.isNotEmpty
          ? Text.rich(
              TextSpan(children: [
                TextSpan(text: '$from '),
                WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Icon(Icons.arrow_forward_rounded, size: 13, color: color)),
                TextSpan(text: ' $to'),
              ]),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted),
            )
          : description.isEmpty
              ? null
              : Text(description, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted)),
      onTap: () => Navigator.pop(context, leg),
    );
  }

  Widget _typedForm(AppLocalizations l10n) {
    final name = _typedName.text.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Text(l10n.betterRouteTypedMode,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: GuidyUi.heading(context))),
        const SizedBox(height: 4),
        Wrap(spacing: 8, children: [
          for (final m in BetterRouteLinePicker.typedModes)
            GuidyPill(
              key: ValueKey('better-route-typed-mode-$m'),
              label: TransitModes.label(l10n, m),
              icon: TransitModes.icon(m),
              selected: _typedMode == m,
              color: GuidyModeStyle.color(m, dark: context.isDark),
              onTap: () => setState(() => _typedMode = m),
            ),
        ]),
        const SizedBox(height: 14),
        TextField(
          key: const ValueKey('better-route-typed-name'),
          controller: _typedName,
          autofocus: true,
          inputFormatters: [LengthLimitingTextInputFormatter(60)],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(labelText: l10n.betterRouteTypedName, border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        GuidyGradientButton(
          key: const ValueKey('better-route-typed-add'),
          icon: Icons.add_rounded,
          label: l10n.betterRouteTypedAdd,
          onPressed: name.isEmpty
              ? null
              : () => Navigator.pop(context, BetterRouteLeg.typed(vehicleType: _typedMode, name: name)),
        ),
      ],
    );
  }
}
