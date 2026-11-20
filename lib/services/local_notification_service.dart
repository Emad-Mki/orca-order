import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalNotificationService {
  LocalNotificationService._();
  static final LocalNotificationService instance = LocalNotificationService._();

  static const _seenIdsKey = 'orca_seen_notification_ids';
  final FlutterLocalNotificationsPlugin plugin =
      FlutterLocalNotificationsPlugin();
  Future<void> Function(Map<String, dynamic>)? onTap;
  Map<String, dynamic>? pendingTap;
  bool _initialized = false;

  static const channels = <String, AndroidNotificationChannel>{
    'orders': AndroidNotificationChannel(
      'orders',
      'الطلبات',
      description: 'الطلبات الجديدة وتحديثات الطلبات',
      importance: Importance.high,
    ),
    'invoices': AndroidNotificationChannel(
      'invoices',
      'الفواتير والمدفوعات',
      description: 'الفواتير والمدفوعات وكشف الحساب',
      importance: Importance.defaultImportance,
    ),
    'warehouse': AndroidNotificationChannel(
      'warehouse',
      'المستودع',
      description: 'تجهيز الطلبات واستلام المواد',
      importance: Importance.defaultImportance,
    ),
    'shipping': AndroidNotificationChannel(
      'shipping',
      'الشحن والتسليم',
      description: 'تحديثات شحن وتسليم الطلبات',
      importance: Importance.high,
    ),
    'alerts': AndroidNotificationChannel(
      'alerts',
      'التنبيهات',
      description: 'تنبيهات المخزون والمشكلات',
      importance: Importance.high,
    ),
    'general': AndroidNotificationChannel(
      'general',
      'عام',
      description: 'الإعلانات والتحديثات العامة',
      importance: Importance.low,
    ),
  };

  Future<void> initialize() async {
    if (_initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) {
          onTap?.call(decoded);
        }
      },
    );
    final launchDetails = await plugin.getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      final decoded = jsonDecode(launchPayload);
      if (decoded is Map<String, dynamic>) {
        pendingTap = decoded;
      }
    }
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      for (final channel in channels.values) {
        await android.createNotificationChannel(channel);
      }
    }
    _initialized = true;
  }

  Future<List<String>> getChannelWarnings() async {
    await initialize();
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return const [];
    final current = await android.getNotificationChannels();
    if (current == null) return const ['تعذر قراءة قنوات Android'];
    final warnings = <String>[];
    for (final expected in channels.values) {
      final actual = current.where((channel) => channel.id == expected.id);
      if (actual.isEmpty) {
        warnings.add('قناة ${expected.name} غير موجودة');
      } else if (actual.first.importance.value < expected.importance.value) {
        warnings.add('قناة ${expected.name} منخفضة الأهمية أو معطلة');
      }
    }
    return warnings;
  }

  Future<bool?> areNotificationsEnabled() async {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return android?.areNotificationsEnabled();
  }

  Future<void> openAppNotificationSettings() async {
    final android = plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.openAppNotificationSettings();
  }

  Future<bool> remember(String notificationId) async {
    if (notificationId.isEmpty) return true;
    final preferences = await SharedPreferences.getInstance();
    final seen = preferences.getStringList(_seenIdsKey) ?? <String>[];
    if (seen.contains(notificationId)) return false;
    seen.add(notificationId);
    if (seen.length > 500) {
      seen.removeRange(0, seen.length - 500);
    }
    await preferences.setStringList(_seenIdsKey, seen);
    return true;
  }

  Future<void> show({
    required String notificationId,
    required String title,
    required String body,
    required String channelId,
    required Map<String, dynamic> payload,
  }) async {
    await initialize();
    if (!await remember(notificationId)) return;
    final channel = channels[channelId] ?? channels['general']!;
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        tag: notificationId,
        importance: channel.importance,
        priority: channel.importance == Importance.high
            ? Priority.high
            : Priority.defaultPriority,
        playSound: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await plugin.show(
      id: notificationId.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: details,
      payload: jsonEncode(payload),
    );
  }

  Future<void> handlePendingTap() async {
    final data = pendingTap;
    if (data == null) return;
    pendingTap = null;
    await onTap?.call(data);
  }

  void clearPendingTap() {
    pendingTap = null;
  }
}
