import 'package:flutter/material.dart';
import 'package:ikrili/data/repositories/notification_repository.dart';
import 'package:ikrili/data/services/local_auth_service.dart';

class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBackButton;
  final Color? backgroundColor; // Add a parameter for background color

  const MyAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBackButton = false,
    this.backgroundColor, // Initialize the new parameter
  });

  @override
  Widget build(BuildContext context) {
    final currentUser = LocalAuthService.instance.currentUser;
    final resolvedActions =
        actions ??
        [
          if (currentUser != null)
            FutureBuilder<int>(
              future: NotificationRepository.instance.getUnreadCount(
                currentUser.id,
              ),
              builder: (context, snapshot) {
                final count = snapshot.data ?? 0;
                return IconButton(
                  tooltip: 'Notifications',
                  onPressed: () =>
                      Navigator.pushNamed(context, 'notifications'),
                  icon: Badge.count(
                    isLabelVisible: count > 0,
                    count: count,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                );
              },
            ),
          IconButton(
            tooltip: currentUser != null ? 'Account' : 'Login',
            onPressed: () => Navigator.pushNamed(
              context,
              currentUser != null ? 'account' : 'login',
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ];

    return AppBar(
      title: Text(title), // Remove the Container, as it only affects the title
      centerTitle: true,
      automaticallyImplyLeading: showBackButton,
      actions: resolvedActions,
      backgroundColor:
          backgroundColor ??
          Colors.white70, // Use the provided color or a default
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
