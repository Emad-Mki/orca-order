import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _service;
  NotificationProvider(this._service);

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  String? _loadedUserId;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((item) => !item.isRead).length;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    if (_isLoading) return;
    final userId = ApiService().currentUser?['user_id']?.toString();
    if (_loadedUserId != userId) {
      _notifications = [];
      _loadedUserId = userId;
    }
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final fetched = await _service.fetchNotifications();
      final currentById = {for (final item in _notifications) item.id: item};
      for (final item in fetched) {
        currentById[item.id] = item;
      }
      _notifications = currentById.values.toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    } catch (error) {
      _error = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _notifications = [];
    _error = null;
    _loadedUserId = null;
    notifyListeners();
  }

  Future<bool> markRead(String notificationId) async {
    final index =
        _notifications.indexWhere((item) => item.id == notificationId);
    if (index < 0 || _notifications[index].isRead) return true;
    try {
      await _service.markRead(notificationId);
      final current = _notifications[index];
      _notifications[index] = NotificationModel(
        id: current.id,
        eventType: current.eventType,
        title: current.title,
        body: current.body,
        deepLink: current.deepLink,
        isRead: true,
        status: 'read',
        lastError: current.lastError,
        retryCount: current.retryCount,
        targetRole: current.targetRole,
        targetUserId: current.targetUserId,
        customerId: current.customerId,
        orderId: current.orderId,
        invoiceId: current.invoiceId,
        productId: current.productId,
        createdAt: current.createdAt,
        sentAt: current.sentAt,
        readAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAllRead() async {
    try {
      await _service.markAllRead();
      final currentUserId =
          ApiService().currentUser?['user_id']?.toString() ?? '';
      _notifications = _notifications
          .map((item) => item.targetUserId != currentUserId
              ? item
              : NotificationModel(
                  id: item.id,
                  eventType: item.eventType,
                  title: item.title,
                  body: item.body,
                  deepLink: item.deepLink,
                  isRead: true,
                  status: 'read',
                  lastError: item.lastError,
                  retryCount: item.retryCount,
                  targetRole: item.targetRole,
                  targetUserId: item.targetUserId,
                  customerId: item.customerId,
                  orderId: item.orderId,
                  invoiceId: item.invoiceId,
                  productId: item.productId,
                  createdAt: item.createdAt,
                  sentAt: item.sentAt,
                  readAt: DateTime.now(),
                ))
          .toList();
      notifyListeners();
      return true;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> retry(String notificationId) async {
    try {
      await _service.retry(notificationId);
      await load();
      return true;
    } catch (error) {
      _error = error.toString();
      notifyListeners();
      return false;
    }
  }
}
