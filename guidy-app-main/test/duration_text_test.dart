import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations_ar.dart';
import 'package:guidy_app/l10n/app_localizations_en.dart';
import 'package:guidy_app/utils/duration_text.dart';

// "Instead of 78 mins make it 1 hour 18 minutes" (beta reviewer,
// 2026-11): over an hour the trip time reads in hours and minutes.
void main() {
  final en = AppLocalizationsEn();
  final ar = AppLocalizationsAr();

  test('under an hour it stays in minutes', () {
    expect(en.duration(44), '44 min');
    expect(en.duration(59), '59 min');
    expect(ar.duration(44), '44 دقيقة');
    expect(ar.duration(5), '5 دقائق');
    expect(en.duration(null), '0 min');
  });

  test('English: hours and minutes', () {
    expect(en.duration(78), '1 h 18 min');
    expect(en.duration(125), '2 h 5 min');
    expect(en.duration(61), '1 h 1 min');
  });

  test('English: whole hours have no minutes part', () {
    expect(en.duration(60), '1 h');
    expect(en.duration(180), '3 h');
  });

  test('Arabic: one, two, a few and many hours, joined with و', () {
    expect(ar.duration(78), 'ساعة و18 دقيقة');
    expect(ar.duration(125), 'ساعتين و5 دقائق');
    expect(ar.duration(190), '3 ساعات و10 دقائق');
    expect(ar.duration(61), 'ساعة ودقيقة');
    expect(ar.duration(122), 'ساعتين ودقيقتين');
    expect(ar.duration(11 * 60 + 30), '11 ساعة و30 دقيقة');
  });

  test('Arabic: whole hours have no minutes part', () {
    expect(ar.duration(60), 'ساعة');
    expect(ar.duration(120), 'ساعتين');
    expect(ar.duration(180), '3 ساعات');
  });

  test('a fractional total rounds like the minutes do', () {
    expect(en.duration(77.6), '1 h 18 min');
    expect(en.duration(59.4), '59 min');
  });

  test('the two-line form splits hours from minutes', () {
    expect(ar.durationLines(78), ['ساعة', 'و18 دقيقة']);
    expect(en.durationLines(78), ['1 h', '18 min']);
    expect(en.durationLines(120), ['2 h']);
    expect(en.durationLines(41), ['41 min']);
  });

  test('no middle dot or tilde', () {
    for (final m in [5, 44, 60, 78, 125, 190]) {
      for (final s in [en.duration(m), ar.duration(m)]) {
        expect(s, isNot(contains('·')));
        expect(s, isNot(contains('~')));
      }
    }
  });
}
