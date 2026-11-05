import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'places_coords_policy.dart';

class SearchHistoryService {
  static const String _prefsKey = 'guidy_search_history';
  static const int _maxEntries = 5;

  /// Entries older than the Places retention window are dropped on read,
  /// coordinates and all. See PlacesCoordsPolicy for why. Nothing is lost
  /// that a rider would miss -- a search from over a month ago is not a
  /// "recent" search by any reading of the word.
  static Future<List<Map<String, dynamic>>> getRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> decoded = json.decode(raw);
      final all = decoded.cast<Map<String, dynamic>>();
      final kept = all.where((e) => !PlacesCoordsPolicy.isExpired(e['at'])).toList();
      // Rewrite only when something actually aged out, so an ordinary
      // read stays a read.
      if (kept.length != all.length) {
        await prefs.setString(_prefsKey, json.encode(kept));
      }
      return kept;
    } catch (_) {
      return [];
    }
  }

  static final RegExp _arabic = RegExp(r'[؀-ۿ]');

  /// The name to show for [entry] (a recent search or a selected place) in
  /// [lang] ('en'/'ar'): that language's name when known, otherwise whatever
  /// name exists -- old entries only have one.
  static String nameFor(Map<String, dynamic> entry, String lang) {
    final preferred = (entry[lang == 'ar' ? 'nameAr' : 'nameEn'] ?? '').toString();
    if (preferred.isNotEmpty) return preferred;
    final other = (entry[lang == 'ar' ? 'nameEn' : 'nameAr'] ?? '').toString();
    final plain = (entry['name'] ?? '').toString();
    return plain.isNotEmpty ? plain : other;
  }

  /// [entry] with its English/Arabic slots filled from [name] (placed by
  /// script) and any explicitly known [nameEn]/[nameAr]. Existing slots are
  /// kept unless a new value is given.
  static Map<String, dynamic> withNames(
    Map<String, dynamic> entry, {
    String? name,
    String? nameEn,
    String? nameAr,
  }) {
    String? en = nameEn ?? (entry['nameEn'] as String?);
    String? ar = nameAr ?? (entry['nameAr'] as String?);
    final n = name ?? entry['name']?.toString();
    if (n != null && n.isNotEmpty) {
      if (_arabic.hasMatch(n)) {
        ar ??= n;
      } else {
        en ??= n;
      }
    }
    return {
      ...entry,
      if (en != null && en.isNotEmpty) 'nameEn': en,
      if (ar != null && ar.isNotEmpty) 'nameAr': ar,
    };
  }

  static Future<void> addSearch(
    String name,
    double lat,
    double lon, {
    String? placeId,
    String? nameEn,
    String? nameAr,
  }) async {
    final current = await getRecent();
    var fresh = withNames({'name': name}, nameEn: nameEn, nameAr: nameAr);
    // De-dupe by place id when there is one (the same place found in either
    // language), else by name; keep the names the older entry knew.
    bool same(Map<String, dynamic> e) =>
        (placeId != null && e['placeId'] == placeId) ||
        e['name'] == name ||
        (fresh['nameEn'] != null && e['nameEn'] == fresh['nameEn']) ||
        (fresh['nameAr'] != null && e['nameAr'] == fresh['nameAr']);
    for (final e in current.where(same)) {
      fresh = {
        ...fresh,
        if (fresh['nameEn'] == null) 'nameEn': ?e['nameEn'],
        if (fresh['nameAr'] == null) 'nameAr': ?e['nameAr'],
      };
    }
    current.removeWhere(same);
    current.insert(0, {
      ...fresh,
      'placeId': ?placeId,
      'lat': lat,
      'lon': lon,
      'at': DateTime.now().millisecondsSinceEpoch,
    });
    final trimmed = current.take(_maxEntries).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, json.encode(trimmed));
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}
