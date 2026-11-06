import 'package:sqflite/sqflite.dart';

import '../../domain/entities/app_notification.dart';
import '../datasources/app_database.dart';
import '../models/app_notification_model.dart';

class NotificationRepository {
  NotificationRepository._();

  static final NotificationRepository instance = NotificationRepository._();
  static int _idSequence = 0;

  Future<Database> get _db async => AppDatabase.instance.database;

  Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? reservationId,
  }) async {
    final now = DateTime.now();
    final notification = AppNotificationModel(
      id: 'notification-${now.microsecondsSinceEpoch}-${_idSequence++}',
      userId: userId,
      title: title,
      message: message,
      type: type,
      isRead: false,
      createdAt: now,
      reservationId: reservationId,
    );
    final db = await _db;
    await db.insert(AppDatabase.tableNotifications, notification.toRow());
  }

  Future<List<AppNotification>> getNotificationsForUser(String userId) async {
    final db = await _db;
    final rows = await db.query(
      AppDatabase.tableNotifications,
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
    return rows.map(AppNotificationModel.fromRow).toList();
  }

  Future<int> getUnreadCount(String userId) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) FROM ${AppDatabase.tableNotifications} WHERE user_id = ? AND is_read = 0',
      [userId],
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  Future<void> markRead(String id) async {
    final db = await _db;
    await db.update(
      AppDatabase.tableNotifications,
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllRead(String userId) async {
    final db = await _db;
    await db.update(
      AppDatabase.tableNotifications,
      {'is_read': 1},
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}
