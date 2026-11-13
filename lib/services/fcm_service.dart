import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'deep_link_service.dart';
import 'local_notification_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const _deviceIdKey = 'orca_fcm_device_id';
  static const _lastTokenKey = 'orca_fcm_last_token';

  Map<String, dynamic>? _session;
  String? _deviceId;
  Map<String, dynamic>? _pendingTap;
  bool _initialized = false;
  Future<void> Function()? onForegroundMessage;

  bool get _supportsPushPlatform => Platform.isAndroid || Platform.isIOS;

  Future<void> initialize() async {
    if (_initialized) return;
    await LocalNotificationService.instance.initialize();
    LocalNotificationService.instance.onTap = DeepLinkService.openNotification;
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => DeepLinkService.openNotification(message.data),
    );
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _registerToken(token);
    });
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      _pendingTap = Map<String, dynamic>.from(initial.data);
    }
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('FCM notification permission was denied by the user.');
      return false;
    }
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> bindUser(Map<String, dynamic> session) async {
    _session = Map<String, dynamic>.from(session);
    if (!_supportsPushPlatform) return;
    if (!await requestPermission()) {
      await _deactivateCurrentDevice();
      return;
    }
    await _registerCurrentToken();
  }

  Future<void> refreshRegistration() async {
    if (!_supportsPushPlatform || _session == null) return;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      await _deactivateCurrentDevice();
      return;
    }
    await _registerCurrentToken();
  }

  Future<void> _deactivateCurrentDevice() async {
    try {
      _deviceId ??= await _getDeviceId();
      await ApiService().post({
        'action': 'user_device_deactivate',
        'device_id': _deviceId,
      });
    } catch (error) {
      debugPrint('Unable to disable notifications for this device: $error');
    }
  }

  Future<void> unbindUser() async {
    final session = _session;
    try {
      if (session != null) {
        _deviceId ??= await _getDeviceId();
        await ApiService().post({
          'action': 'user_device_deactivate',
          'device_id': _deviceId,
        });
      }
    } finally {
      _session = null;
    }
  }

  void clearUserSession() {
    _session = null;
  }

  Future<String> getDeviceId() => _getDeviceId();

  Future<void> handlePendingTap() async {
    await LocalNotificationService.instance.handlePendingTap();
    final data = _pendingTap;
    if (data == null) return;
    _pendingTap = null;
    await DeepLinkService.openNotification(data);
  }

  Future<void> _registerToken(String token) async {
    final session = _session;
    if (session == null || token.isEmpty) return;
    try {
      _deviceId ??= await _getDeviceId();
      final preferences = await SharedPreferences.getInstance();
      final previousToken = preferences.getString(_lastTokenKey);
      final info = await PackageInfo.fromPlatform();
      await ApiService().post({
        'action': 'user_device_upsert',
        'device_id': _deviceId,
        'fcm_token': token,
        if (previousToken != null && previousToken != token)
          'previous_fcm_token': previousToken,
        'platform': Platform.isAndroid ? 'android' : 'ios',
        'app_version': info.version,
      });
      await preferences.setString(_lastTokenKey, token);
    } catch (error) {
      debugPrint('Unable to register FCM device: $error');
    }
  }

  Future<void> _registerCurrentToken() async {
    try {
      if (Platform.isIOS) {
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken == null || apnsToken.isEmpty) {
          debugPrint('APNs token is not available yet; FCM registration deferred.');
          return;
        }
      }
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
    } catch (error) {
      debugPrint('Unable to retrieve FCM token: $error');
    }
  }

  Future<String> _getDeviceId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final id = List<int>.generate(32, (_) => random.nextInt(16))
        .map((digit) => digit.toRadixString(16))
        .join();
    await preferences.setString(_deviceIdKey, id);
    return id;
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = Map<String, dynamic>.from(message.data);
    final id = (data['notification_id'] ?? message.messageId ?? '').toString();
    final notification = message.notification;
    final title = notification?.title ?? data['title']?.toString() ?? '';
    final body = notification?.body ?? data['body']?.toString() ?? '';
    if (id.isNotEmpty && (title.isNotEmpty || body.isNotEmpty)) {
      await LocalNotificationService.instance.show(
        notificationId: id,
        title: title,
        body: body,
        channelId: data['channel_id']?.toString() ?? 'general',
        payload: data,
      );
    }
    await onForegroundMessage?.call();
  }
}
