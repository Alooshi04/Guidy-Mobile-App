import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'commute_planner.dart';

/// The rider's commute notification settings: on by default (owner,
/// 2026-10-14), each kind with its own switch in Settings.
class CommuteSettings {
  final bool enabled;
  final bool easier;
  final bool lastService;

  const CommuteSettings({this.enabled = true, this.easier = true, this.lastService = true});

  CommuteSettings copyWith({bool? enabled, bool? easier, bool? lastService}) => CommuteSettings(
        enabled: enabled ?? this.enabled,
        easier: easier ?? this.easier,
        lastService: lastService ?? this.lastService,
      );
}

/// The lines of the saved Home <-> Work route, kept on the phone, and the
/// settings. Everything the notifications need lives here, so they are
/// planned and scheduled without asking the server anything.
class CommuteStore {
  static const _linesKey = 'commute_lines_v1';
  static const _onKey = 'commute_notifs_on';
  static const _easierKey = 'commute_notifs_easier';
  static const _lastKey = 'commute_notifs_last';
  static const _askedKey = 'commute_notifs_permission_asked';

  /// Lines older than this are looked up again: timetables change.
  static const Duration staleAfter = Duration(days: 14);

  static final ValueNotifier<CommuteSettings> settings = ValueNotifier(const CommuteSettings());

  static Future<void> loadSettings() async {
    try {
      final p = await SharedPreferences.getInstance();
      settings.value = CommuteSettings(
        enabled: p.getBool(_onKey) ?? true,
        easier: p.getBool(_easierKey) ?? true,
        lastService: p.getBool(_lastKey) ?? true,
      );
    } catch (_) {}
  }

  static Future<void> saveSettings(CommuteSettings s) async {
    settings.value = s;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_onKey, s.enabled);
      await p.setBool(_easierKey, s.easier);
      await p.setBool(_lastKey, s.lastService);
    } catch (_) {}
  }

  static Future<({List<CommuteLine> lines, DateTime? capturedAt, String? key})> loadLines() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_linesKey);
      if (raw == null) return (lines: const <CommuteLine>[], capturedAt: null, key: null);
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return (
        lines: [for (final l in (j['lines'] as List? ?? const [])) ?CommuteLine.fromJson(l)],
        capturedAt: DateTime.fromMillisecondsSinceEpoch((j['captured_at'] as num?)?.toInt() ?? 0),
        key: j['home_work'] as String?,
      );
    } catch (_) {
      return (lines: const <CommuteLine>[], capturedAt: null, key: null);
    }
  }

  /// [homeWorkKey] names the Home and Work the lines were found for, so
  /// moving either one makes them stale.
  static Future<void> saveLines(List<CommuteLine> lines, {required String homeWorkKey, DateTime? at}) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _linesKey,
        jsonEncode({
          'captured_at': (at ?? DateTime.now()).millisecondsSinceEpoch,
          'home_work': homeWorkKey,
          'lines': [for (final l in lines) l.toJson()],
        }),
      );
    } catch (_) {}
  }

  /// Whether the notification permission was asked for already (asked once,
  /// when there is first something to notify about).
  static Future<bool> takePermissionAsk() async {
    try {
      final p = await SharedPreferences.getInstance();
      if (p.getBool(_askedKey) ?? false) return false;
      await p.setBool(_askedKey, true);
      return true;
    } catch (_) {
      return false;
    }
  }
}
