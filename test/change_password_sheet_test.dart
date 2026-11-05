import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/l10n/app_localizations.dart';
import 'package:guidy_app/services/account_service.dart';
import 'package:guidy_app/widgets/change_password_sheet.dart';
import 'package:guidy_app/widgets/password_strength_field.dart';

void main() {
  late List<(String, String)> submitted;
  late ChangePasswordResult nextResult;
  late bool? closedWith;

  setUp(() {
    submitted = [];
    nextResult = ChangePasswordResult.success;
    closedWith = null;
  });

  Future<void> pumpSheet(WidgetTester tester, {Locale locale = const Locale('en')}) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: locale,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              closedWith = await showChangePasswordSheet(context, onSubmit: (current, next) async {
                submitted.add((current, next));
                return nextResult;
              });
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field(int i) => find.byType(TextField).at(i);
  ElevatedButton saveButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Update password'));

  Future<void> fill(WidgetTester tester, String current, String next, String confirm) async {
    await tester.enterText(field(0), current);
    await tester.enterText(
        find.descendant(of: find.byType(PasswordStrengthField), matching: find.byType(TextField)), next);
    await tester.enterText(field(2), confirm);
    await tester.pump();
  }

  testWidgets('update stays off until current is filled and the new one passes and matches', (tester) async {
    await pumpSheet(tester);
    expect(find.text('Current password'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await fill(tester, '', 'Guidy#2026', 'Guidy#2026');
    expect(saveButton(tester).onPressed, isNull, reason: 'no current password');

    await fill(tester, 'old-one', 'guidy2026', 'guidy2026');
    expect(saveButton(tester).onPressed, isNull, reason: 'weak new password');

    await fill(tester, 'old-one', 'Guidy#2026', 'Guidy#2027');
    expect(saveButton(tester).onPressed, isNull, reason: 'mismatch');

    await fill(tester, 'old-one', 'Guidy#2026', 'Guidy#2026');
    expect(saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('a successful change closes the sheet with true', (tester) async {
    await pumpSheet(tester);
    await fill(tester, 'old-one', 'Guidy#2026', 'Guidy#2026');
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(submitted, [('old-one', 'Guidy#2026')]);
    expect(closedWith, isTrue);
    expect(find.text('Update password'), findsNothing);
  });

  testWidgets('a wrong current password keeps the sheet open with an error', (tester) async {
    nextResult = ChangePasswordResult.wrongCurrent;
    await pumpSheet(tester);
    await fill(tester, 'nope', 'Guidy#2026', 'Guidy#2026');
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();
    expect(find.text('Your current password is incorrect.'), findsOneWidget);
    expect(find.text('Update password'), findsOneWidget);
    expect(closedWith, isNull);
  });

  testWidgets('renders in Arabic', (tester) async {
    await pumpSheet(tester, locale: const Locale('ar'));
    expect(find.text('الباسورد الحالي'), findsOneWidget);
    expect(find.text('حدّث الباسورد'), findsOneWidget);
  });
}
