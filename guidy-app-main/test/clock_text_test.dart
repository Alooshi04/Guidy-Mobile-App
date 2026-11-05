import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/utils/clock_text.dart';

void main() {
  testWidgets('clock times use the same digits as the minutes and fares around them, in Arabic too', (tester) async {
    late String text;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('ar'),
      home: Builder(builder: (context) {
        text = clockText(context, const TimeOfDay(hour: 6, minute: 32));
        return const SizedBox();
      }),
    ));
    expect(text, contains('6:32'));
    expect(RegExp('[\u0660-\u0669\u06F0-\u06F9]').hasMatch(text), isFalse);
  });

  test('westernDigits converts Arabic-Indic and Persian digits and leaves the rest', () {
    expect(westernDigits('٧:٠٤ ص'), '7:04 ص');
    expect(westernDigits('۱۲:۳۰'), '12:30');
    expect(westernDigits('7:04 AM'), '7:04 AM');
  });
}
