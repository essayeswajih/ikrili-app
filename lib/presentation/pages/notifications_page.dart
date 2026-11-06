import 'package:flutter/material.dart';

import '../../data/repositories/notification_repository.dart';
import '../../data/services/local_auth_service.dart';
import '../../domain/entities/app_notification.dart';
import '../widgets/app_bar.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late Future<List<AppNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final user = LocalAuthService.instance.currentUser;
    _notificationsFuture = user == null
        ? Future.value(const <AppNotification>[])
        : NotificationRepository.instance.getNotificationsForUser(user.id);
  }

  Future<void> _markRead(AppNotification notification) async {
    await NotificationRepository.instance.markRead(notification.id);
    setState(_reload);
  }

  Future<void> _markAllRead() async {
    final user = LocalAuthService.instance.currentUser;
    if (user == null) return;
    await NotificationRepository.instance.markAllRead(user.id);
    setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    final user = LocalAuthService.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: const MyAppBar(title: 'Notifications', showBackButton: true),
        body: Center(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, 'login'),
            icon: const Icon(Icons.login),
            label: const Text('Sign in'),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: MyAppBar(
        title: 'Notifications',
        showBackButton: true,
        actions: [
          TextButton.icon(
            onPressed: _markAllRead,
            icon: const Icon(Icons.done_all),
            label: const Text('Mark all read'),
          ),
        ],
      ),
      body: FutureBuilder<List<AppNotification>>(
        future: _notificationsFuture,
        builder: (context, snapshot) {
          final notifications = snapshot.data ?? const <AppNotification>[];
          final unread = notifications.where((item) => !item.isRead).toList();
          final read = notifications.where((item) => item.isRead).toList();
          if (snapshot.connectionState == ConnectionState.waiting &&
              notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }
          if (notifications.isEmpty) {
            return const Center(
              child: Text(
                'No notifications yet.',
                style: TextStyle(color: Colors.black54),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _NotificationGroup(
                title: 'Unread',
                notifications: unread,
                onTap: _markRead,
              ),
              _NotificationGroup(
                title: 'Read',
                notifications: read,
                onTap: _markRead,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationGroup extends StatelessWidget {
  const _NotificationGroup({
    required this.title,
    required this.notifications,
    required this.onTap,
  });

  final String title;
  final List<AppNotification> notifications;
  final ValueChanged<AppNotification> onTap;

  @override
  Widget build(BuildContext context) {
    if (notifications.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        ...notifications.map(
          (notification) => Card(
            child: ListTile(
              leading: Icon(
                notification.isRead
                    ? Icons.notifications_none
                    : Icons.notifications_active,
              ),
              title: Text(notification.title),
              subtitle: Text(notification.message),
              trailing: notification.isRead
                  ? null
                  : IconButton(
                      tooltip: 'Mark read',
                      onPressed: () => onTap(notification),
                      icon: const Icon(Icons.check),
                    ),
              onTap: () => onTap(notification),
            ),
          ),
        ),
      ],
    );
  }
}
