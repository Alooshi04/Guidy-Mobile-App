import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations_ar.dart';
import 'package:guidy_app/l10n/app_localizations_en.dart';

void main() {
  test('English: 1 change, not "1 changes"', () {
    final l10n = AppLocalizationsEn();
    expect(l10n.metroChangesCount(1), '1 change');
    expect(l10n.metroChangesCount(2), '2 changes');
  });

  test('Arabic: singular, dual and plural forms', () {
    final l10n = AppLocalizationsAr();
    expect(l10n.metroChangesCount(1), 'تغيير واحد');
    expect(l10n.metroChangesCount(2), 'تغييران');
    expect(l10n.metroChangesCount(3), '3 تغييرات');
  });
}
