import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ikrili/config/app_localizations.dart';
import 'package:ikrili/main.dart';
import 'package:ikrili/presentation/pages/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app shows welcome page on first launch', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const MyApp(showWelcome: true));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text("Let's Start A New Experience"), findsOneWidget);
    expect(find.text("Let's Start"), findsOneWidget);
    expect(find.text('Available Cars'), findsNothing);
  });

  testWidgets('login form starts empty for local testers', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Work email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);

    final fields = tester.widgetList<TextFormField>(find.byType(TextFormField));
    expect(fields.first.controller?.text, isEmpty);
    expect(fields.last.controller?.text, isEmpty);
  });
}
