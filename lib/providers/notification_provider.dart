import 'package:flutter/foundation.dart';

import '../models/notification_model.dart';
import '../services/api_service.dart';
import '../repositories/notification_repository.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationRepository _repository;
  NotificationProvider(this._repository);

  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  String? _error;
  String? _loadedUserId;
  int _generation = 0;

  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);
  int get unreadCount => _notifications.where((item) => !item.isRead).length;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load({bool forceRefresh = false}) async {
    if (_isLoading) return;

    final userId = ApiService().currentUser?['user_id']?.toString();
    if (_loadedUserId != userId) {
      _notifications = [];
      _loadedUserId = userId;
    }

    final generation = _generation;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final fetched =
          await _repository.getNotifications(forceRefresh: forceRefresh);
      if (generation != _generation) return;

      final currentById = {for (final item in _notifications) item.id: item};
      for (final item in fetched) {
        currentById[item.id] = item;
      }

      _notifications = currentById.values.toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)));
    } catch (error) {
      if (generation == _generation) _error = error.toString();
    } finally {
      if (generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void reset() {
    _generation++;
    _notifications = [];
    _error = null;
    _loadedUserId = null;
    _isLoading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<bool> markRead(String notificationId) async {
    final index =
        _notifications.indexWhere((item) => item.id == notificationId);
    if (index < 0 || _notifications[index].isRead) return true;
    final generation = _generation;
    try {
      await _repository.markRead(notificationId);
      if (generation != _generation) return false;
      final currentIndex =
          _notifications.indexWhere((item) => item.id == notificationId);
      if (currentIndex < 0) return false;
      final current = _notifications[currentIndex];
      _notifications[currentIndex] = current.copyWith(
        isRead: true,
        readAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    } catch (error) {
      if (generation != _generation) return false;
      _error = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> markAllRead() async {
    final generation = _generation;
    try {
      await _repository.markAllRead();
      if (generation != _generation) return false;
      final currentUserId =
          ApiService().currentUser?['user_id']?.toString() ?? '';
      _notifications = _notifications
          .map((item) => item.targetUserId != currentUserId
              ? item
              : item.copyWith(
                  isRead: true,
                  readAt: DateTime.now(),
                ))
          .toList();
      notifyListeners();
      return true;
    } catch (error) {
      if (generation != _generation) return false;
      _error = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> retry(String notificationId) async {
    final generation = _generation;
    try {
      await _repository.retry(notificationId);
      if (generation != _generation) return false;
      await load(forceRefresh: true);
      return generation == _generation;
    } catch (error) {
      if (generation != _generation) return false;
      _error = error.toString();
      notifyListeners();
      return false;
    }
  }
}
