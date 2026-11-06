import 'package:flutter/material.dart';
import 'package:ikrili/config/app_localizations.dart';
import 'package:ikrili/config/app_preferences.dart';
import 'package:ikrili/presentation/widgets/app_bar.dart';

class PreferencesPage extends StatelessWidget {
  const PreferencesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final preferences = AppPreferencesController.instance;

    return Scaffold(
      appBar: MyAppBar(title: strings.t('preferences'), showBackButton: true),
      body: AnimatedBuilder(
        animation: preferences,
        builder: (context, _) {
          final selectedLanguage = preferences.locale?.languageCode ?? 'system';
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              PreferenceSection(
                title: strings.t('language'),
                children: [
                  PreferenceDropdown<String>(
                    icon: Icons.language,
                    title: strings.t('language'),
                    value: selectedLanguage,
                    items: [
                      DropdownMenuItem(
                        value: 'system',
                        child: Text(strings.t('language_system')),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(strings.t('english')),
                      ),
                      DropdownMenuItem(
                        value: 'fr',
                        child: Text(strings.t('french')),
                      ),
                      DropdownMenuItem(
                        value: 'ar',
                        child: Text(strings.t('arabic')),
                      ),
                    ],
                    onChanged: preferences.setLanguageCode,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              PreferenceSection(
                title: strings.t('appearance'),
                children: [
                  PreferenceDropdown<ThemeMode>(
                    icon: Icons.contrast,
                    title: strings.t('theme_mode'),
                    value: preferences.themeMode,
                    items: [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text(strings.t('theme_system')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text(strings.t('theme_light')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text(strings.t('theme_dark')),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) preferences.setThemeMode(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 18),
              PreferenceSection(
                title: strings.t('preferences'),
                children: [
                  SwitchListTile(
                    value: preferences.notificationsEnabled,
                    onChanged: preferences.setNotificationsEnabled,
                    title: Text(strings.t('booking_alerts')),
                    secondary: const Icon(Icons.notifications_outlined),
                  ),
                  PreferenceDropdown<String>(
                    icon: Icons.payments_outlined,
                    title: strings.t('currency'),
                    value: preferences.preferredCurrency,
                    items: const [
                      DropdownMenuItem(value: 'DT', child: Text('DT')),
                      DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        preferences.setPreferredCurrency(value);
                      }
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class PreferenceSection extends StatelessWidget {
  const PreferenceSection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class PreferenceDropdown<T> extends StatelessWidget {
  const PreferenceDropdown({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: DropdownButton<T>(
        value: value,
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}
