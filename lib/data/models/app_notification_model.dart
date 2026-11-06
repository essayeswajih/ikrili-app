import '../../domain/entities/app_notification.dart';

class AppNotificationModel extends AppNotification {
  const AppNotificationModel({
    required super.id,
    required super.userId,
    required super.title,
    required super.message,
    required super.type,
    required super.isRead,
    required super.createdAt,
    super.reservationId,
  });

  factory AppNotificationModel.fromRow(Map<String, dynamic> row) {
    return AppNotificationModel(
      id: row['id'] as String,
      userId: row['user_id'] as String,
      title: row['title'] as String,
      message: row['message'] as String,
      type: row['type'] as String,
      isRead: (row['is_read'] as int? ?? 0) == 1,
      createdAt: DateTime.parse(row['created_at'] as String),
      reservationId: row['reservation_id'] as String?,
    );
  }

  Map<String, dynamic> toRow() => {
    'id': id,
    'user_id': userId,
    'title': title,
    'message': message,
    'type': type,
    'is_read': isRead ? 1 : 0,
    'created_at': createdAt.toIso8601String(),
    'reservation_id': reservationId,
  };
}
