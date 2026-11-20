import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/notification_model.dart';
import '../services/api_service.dart';

class NotificationRepository {
  final ApiService _apiService;

  NotificationRepository({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  Future<List<NotificationModel>> getNotifications({bool forceRefresh = false}) async {
    final preferences = await SharedPreferences.getInstance();
    final userId = _apiService.currentUser?['user_id']?.toString() ?? 'unknown';
    final lastReceivedKey = 'orca_notifications_last_received_at_$userId';
    
    String? lastReceived;
    if (!forceRefresh) {
      lastReceived = preferences.getString(lastReceivedKey);
    }

    final response = await _apiService.notifications.getNotifications(
      sinceTime: lastReceived,
    );

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
        .toList();

    // تحديث طابع آخر استلام
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
    await _apiService.notifications.markRead(notificationId);
  }

  Future<void> markAllRead() async {
    await _apiService.notifications.markAllRead();
  }

  Future<void> retry(String notificationId) async {
    await _apiService.notifications.retry(notificationId);
  }
}
