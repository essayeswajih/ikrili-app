import 'package:flutter/material.dart';
import 'package:ikrili/config/app_localizations.dart';
import 'package:ikrili/data/services/local_auth_service.dart';
import 'package:ikrili/presentation/pages/debug_database_page.dart';

class MyDrawer extends StatelessWidget {
  const MyDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = LocalAuthService.instance.currentUser;
    final strings = AppLocalizations.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.blue),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.account_circle, color: Colors.white, size: 44),
                const SizedBox(height: 8),
                Text(
                  user?.name ?? strings.t('menu'),
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
                if (user != null)
                  Text(
                    UserRoles.label(user.role, strings.locale),
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          ),
          if (user != null)
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: Text(strings.t('dashboard')),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, 'account');
              },
            ),
          if (user?.role == UserRoles.carRenter)
            ListTile(
              leading: const Icon(Icons.near_me_outlined),
              title: const Text('Nearby owners'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, 'nearby');
              },
            ),
          if (user?.role == UserRoles.carOwner)
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: const Text('My pickup location'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, 'ownerLocation');
              },
            ),
          if (user != null)
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, 'notifications');
              },
            ),
          ListTile(
            leading: Icon(user == null ? Icons.login : Icons.person_outline),
            title: Text(
              user == null ? strings.t('login') : strings.t('account_settings'),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, user == null ? 'login' : 'account');
            },
          ),
          if (user == null)
            ListTile(
              leading: const Icon(Icons.person_add),
              title: Text(strings.t('register')),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, 'register');
              },
            ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: Text(strings.t('preferences')),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, 'preferences');
            },
          ),
          if (user?.role == UserRoles.admin)
            ListTile(
              leading: const Icon(Icons.bug_report_outlined),
              title: const Text('Debug database'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DebugDatabasePage(),
                  ),
                );
              },
            ),
          if (user != null)
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(strings.t('logout')),
              onTap: () async {
                await LocalAuthService.instance.logout();
                if (!context.mounted) return;
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  'login',
                  (route) => false,
                );
              },
            ),
        ],
      ),
    );
  }
}
