import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ikrili/data/repositories/car_repository.dart';
import 'package:ikrili/data/services/local_auth_service.dart';
import 'package:ikrili/presentation/pages/account_page.dart';
import 'package:ikrili/presentation/pages/debug_database_page.dart';
import 'package:ikrili/presentation/pages/home.dart';
import 'package:ikrili/presentation/pages/login.dart';
import 'package:ikrili/presentation/pages/notifications_page.dart';
import 'package:ikrili/presentation/pages/nearby_map_page.dart';
import 'package:ikrili/presentation/pages/owner_location_page.dart';
import 'package:ikrili/presentation/pages/preferences_page.dart';
import 'package:ikrili/presentation/pages/register.dart';
import 'package:ikrili/presentation/pages/welcome.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_localizations.dart';
import 'config/app_preferences.dart';
import 'config/theme/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalAuthService.instance.restoreSession();
  await AppPreferencesController.instance.load();
  if (!kIsWeb) await CarRepository.instance.initialize();
  final prefs = await SharedPreferences.getInstance();
  final showWelcome = prefs.getBool('ikrili_welcome_seen') != true;
  runApp(ProviderScope(child: MyApp(showWelcome: showWelcome)));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.showWelcome = false});

  final bool showWelcome;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppPreferencesController.instance,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: myTheme,
          darkTheme: darkTheme,
          themeMode: AppPreferencesController.instance.themeMode,
          locale: AppPreferencesController.instance.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (deviceLocale, supportedLocales) {
            return resolveSupportedLocale(deviceLocale);
          },
          builder: (context, child) {
            final locale = Localizations.localeOf(context);
            return Directionality(
              textDirection: locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            );
          },
          title: 'Ikrili App',
          initialRoute: showWelcome ? 'welcome' : '/',
          routes: {
            '/': (context) => const MyHomePage(),
            'welcome': (context) => const WelcomeScreen(),
            'login': (context) => const LoginScreen(),
            'register': (context) => const RegisterScreen(),
            'account': (context) => const AccountPage(),
            'notifications': (context) => const NotificationsPage(),
            'nearby': (context) => const NearbyMapPage(),
            'ownerLocation': (context) => const OwnerLocationPage(),
            'preferences': (context) => const PreferencesPage(),
            'debugDatabase': (context) => const DebugDatabasePage(),
          },
        );
      },
    );
  }
}
