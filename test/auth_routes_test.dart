import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:guidy_app/main.dart';
import 'package:guidy_app/screens/AuthGate.dart';

// The sign-in screens leave with pushReplacementNamed('/home'), and the
// email-verification screen's sign-out goes to '/signin'. Both used to build
// their screen directly, which replaced AuthGate -- the only thing listening
// to sign-in state -- so Log Out signed Firebase out but nothing on screen
// changed until the app was restarted. Every route that ends up showing the
// app or the sign-in screen has to be AuthGate itself.
void main() {
  testWidgets('/home and /signin are AuthGate, so sign-out is still heard', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(Builder(builder: (c) {
      context = c;
      return const SizedBox();
    }));

    expect(appRoutes['/home']!(context), isA<AuthGate>());
    expect(appRoutes['/signin']!(context), isA<AuthGate>());
  });
}
