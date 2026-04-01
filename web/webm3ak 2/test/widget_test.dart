// Smoke test for Ma3ak backoffice.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:webm3ak/providers/auth_provider.dart';
import 'package:webm3ak/screens/login_screen.dart';

void main() {
  testWidgets('Login screen shows connect button', (WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: AuthProvider(),
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    expect(find.text('Se connecter'), findsOneWidget);
  });
}
