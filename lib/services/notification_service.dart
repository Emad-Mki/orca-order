import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_model.dart';
import 'api_service.dart';

class NotificationService {
  Future<List<NotificationModel>> fetchNotifications() async {
    final preferences = await SharedPreferences.getInstance();
    final userId =
        ApiService().currentUser?['user_id']?.toString() ?? 'unknown';
    final lastReceivedKey = 'orca_notifications_last_received_at_$userId';
    final lastReceived = preferences.getString(lastReceivedKey);
    final response = await ApiService().post({
      'action': 'notification_list',
      if (lastReceived != null) 'since_time': lastReceived,
    });
    final records = response['notifications'];
    if (records is! List) {
      throw const FormatException('استجابة الإشعارات غير صالحة');
    }
    final notifications = records
        .whereType<Map>()
        .map((item) => NotificationModel.fromJson(
              Map<String, dynamic>.from(item),
            ))
        .where((item) => item.id.isNotEmpty)
        .toList()
      ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));

    final latest = notifications
        .map((item) => item.createdAt)
        .whereType<DateTime>()
        .fold<DateTime?>(
            null,
            (latest, date) =>
                latest == null || date.isAfter(latest) ? date : latest);
    if (latest != null) {
      await preferences.setString(
        lastReceivedKey,
        latest.toUtc().toIso8601String(),
      );
    }
    return notifications;
  }

  Future<void> markRead(String notificationId) async {
    await ApiService().post({
      'action': 'notification_read',
      'notification_id': notificationId,
    });
  }

  Future<void> markAllRead() async {
    await ApiService().post({'action': 'notification_mark_all_read'});
  }

  Future<void> retry(String notificationId) async {
    await ApiService().post({
      'action': 'notification_retry',
      'notification_id': notificationId,
    });
  }
}
