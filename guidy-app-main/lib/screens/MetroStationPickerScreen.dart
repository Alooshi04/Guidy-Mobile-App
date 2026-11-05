import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/api_service.dart';
import '../theme/guidy_ui.dart';
import '../theme/app_theme.dart';

/// Pick one of the 84 metro stations.
///
/// The whole list is fetched once by [MetroScreen] and filtered here in
/// memory -- 84 rows is small enough that a network round-trip per
/// keystroke would only make it slower.
class MetroStationPickerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stations;
  final String title;
  final String? excludeStopId;

  /// Builds the title in the current language, so it follows a language
  /// switch made on this screen; [title] is used without it.
  final String Function(AppLocalizations l10n)? titleOf;

  const MetroStationPickerScreen({
    super.key,
    required this.stations,
    required this.title,
    this.excludeStopId,
    this.titleOf,
  });

  @override
  State<MetroStationPickerScreen> createState() => _MetroStationPickerScreenState();
}

class _MetroStationPickerScreenState extends State<MetroStationPickerScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The list shown: [MetroStationPickerScreen.stations] until the language
  /// is switched here, then the same stations fetched in the new language.
  late List<Map<String, dynamic>> _stations = widget.stations;
  String? _lang;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : 'en';
    final switched = _lang != null && _lang != lang;
    _lang = lang;
    if (switched) _reloadIn(lang);
  }

  Future<void> _reloadIn(String lang) async {
    try {
      final stations = await ApiService().fetchMetroStations(lang: lang);
      if (mounted && lang == _lang) setState(() => _stations = stations);
    } catch (_) {
      // Keep the names already shown; they still pick the right station.
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    return _stations.where((s) {
      if (s['stop_id'] == widget.excludeStopId) return false;
      if (q.isEmpty) return true;
      return (s['name'] ?? '').toString().toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final stations = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.titleOf?.call(l10n) ?? widget.title),
        actions: GuidyLanguageToggle.appBarActions,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: l10n.metroSearchStationHint,
                prefixIcon: const Icon(Icons.search, color: AppColors.primaryTeal),
                filled: true,
                fillColor: context.fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: stations.isEmpty
                ? Center(
                    child: Text(l10n.noSearchResultsFound,
                        style: TextStyle(color: context.textSecondary)),
                  )
                : ListView.separated(
                    itemCount: stations.length,
                    separatorBuilder: (_, _) => Divider(
                        height: 1, color: context.textSecondary.withValues(alpha: 0.12)),
                    itemBuilder: (context, i) {
                      final station = stations[i];
                      final lines = List<Map<String, dynamic>>.from(
                          station['lines'] ?? const []);
                      final isInterchange = station['is_interchange'] == true;
                      return ListTile(
                        leading: Icon(
                          isInterchange ? Icons.swap_calls_rounded : Icons.subway_rounded,
                          color: AppColors.primaryTeal,
                        ),
                        title: Text(
                          (station['name'] ?? '').toString(),
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: context.textPrimary),
                        ),
                        subtitle: lines.isEmpty
                            ? null
                            : Text(
                                l10n.metroLinesServing(lines
                                    .map((l) => (l['name'] ?? '').toString())
                                    .where((n) => n.isNotEmpty)
                                    .join(l10n.listSeparator)),
                                style: TextStyle(
                                    fontSize: 12, color: context.textSecondary),
                              ),
                        trailing: isInterchange
                            ? Chip(
                                label: Text(l10n.metroInterchangeBadge,
                                    style: const TextStyle(fontSize: 10)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                backgroundColor:
                                    AppColors.primaryTeal.withValues(alpha: 0.12),
                                side: BorderSide.none,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, station),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
