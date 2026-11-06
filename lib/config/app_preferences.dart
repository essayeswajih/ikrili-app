import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppPreferencesController extends ChangeNotifier {
  AppPreferencesController._();

  static final AppPreferencesController instance = AppPreferencesController._();

  static const _languageKey = 'ikrili_language_code';
  static const _themeModeKey = 'ikrili_theme_mode';
  static const _notificationsKey = 'ikrili_notifications_enabled';
  static const _currencyKey = 'ikrili_preferred_currency';

  Locale? _locale;
  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = true;
  String _preferredCurrency = 'DT';

  Locale? get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _notificationsEnabled;
  String get preferredCurrency => _preferredCurrency;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey);
    if (languageCode != null && languageCode != 'system') {
      _locale = Locale(languageCode);
    }

    _themeMode = _themeModeFromString(
      prefs.getString(_themeModeKey) ?? ThemeMode.system.name,
    );
    _notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
    _preferredCurrency = prefs.getString(_currencyKey) ?? 'DT';
  }

  Future<void> setLanguageCode(String? languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (languageCode == null || languageCode == 'system') {
      _locale = null;
      await prefs.setString(_languageKey, 'system');
    } else {
      _locale = Locale(languageCode);
      await prefs.setString(_languageKey, languageCode);
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, themeMode.name);
    notifyListeners();
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
    notifyListeners();
  }

  Future<void> setPreferredCurrency(String value) async {
    _preferredCurrency = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, value);
    notifyListeners();
  }

  ThemeMode _themeModeFromString(String value) {
    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }
}

Locale resolveSupportedLocale(Locale? deviceLocale) {
  const supported = {'en', 'fr', 'ar'};
  final languageCode = deviceLocale?.languageCode.toLowerCase();
  if (languageCode != null && supported.contains(languageCode)) {
    return Locale(languageCode);
  }
  return const Locale('en');
}
