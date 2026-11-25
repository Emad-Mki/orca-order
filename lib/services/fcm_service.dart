import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';
import 'deep_link_service.dart';
import 'local_notification_service.dart';
import '../utils/permissions.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  final notificationId =
      message.data['notification_id']?.toString() ?? 'unknown';
  debugPrint(
    '[FCM] background receive id=$notificationId '
    'has_notification=${message.notification != null}',
  );
}

class FcmDiagnostics {
  final bool supported;
  final bool firebaseReady;
  final AuthorizationStatus? authorization;
  final bool? systemNotificationsEnabled;
  final bool registered;
  final DateTime? lastSyncAt;
  final String? lastResult;
  final List<String> channelWarnings;

  const FcmDiagnostics({
    required this.supported,
    required this.firebaseReady,
    required this.authorization,
    required this.systemNotificationsEnabled,
    required this.registered,
    required this.lastSyncAt,
    required this.lastResult,
    required this.channelWarnings,
  });

  String get permissionLabel => switch (authorization) {
        AuthorizationStatus.authorized => 'مسموح',
        AuthorizationStatus.provisional => 'مسموح مؤقتاً',
        AuthorizationStatus.denied => 'مرفوض',
        AuthorizationStatus.deniedPermanently => 'مرفوض',
        AuthorizationStatus.notDetermined => 'لم يُطلب بعد',
        null => 'غير متاح',
      };
}

class FcmService {
  FcmService._();
  static final FcmService instance = FcmService._();

  static const _deviceIdKey = 'orca_fcm_device_id';
  static const _lastTokenHashKey = 'orca_fcm_last_token_hash';
  static const _registeredUserIdKey = 'orca_fcm_registered_user_id';
  static const _registeredKey = 'orca_fcm_registered';
  static const _permissionPromptedKey = 'orca_fcm_permission_prompted';
  static const _lastSyncAtKey = 'orca_fcm_last_sync_at';
  static const _lastResultKey = 'orca_fcm_last_result';
  static const _roleTopicKey = 'orca_fcm_role_topic';

  Map<String, dynamic>? _session;
  String? _deviceId;
  Map<String, dynamic>? _pendingTap;
  bool _initialized = false;
  Future<void>? _initialization;
  Future<void> Function()? onForegroundMessage;
  String? _currentInstallationId;
  Completer<String>? _installationIdCompleter;
  String? _registeringInstallationId;
  Future<bool>? _registrationFuture;
  Future<void> _topicOperation = Future<void>.value();

  bool get _supportsPushPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @visibleForTesting
  static bool shouldRequestPermission({
    required AuthorizationStatus status,
    required bool prompted,
    required bool isAndroid,
  }) =>
      !prompted &&
      (status == AuthorizationStatus.notDetermined ||
          (isAndroid && status == AuthorizationStatus.denied));

  String get _platformName =>
      defaultTargetPlatform == TargetPlatform.android ? 'android' : 'ios';

  void registerBackgroundHandler() {
    if (_supportsPushPlatform) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;
    final pendingInitialization = _initialization;
    if (pendingInitialization != null) {
      await pendingInitialization;
      return;
    }
    final initialization = _initialize();
    _initialization = initialization;
    try {
      await initialization;
    } finally {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
    }
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    await Firebase.initializeApp();
    await LocalNotificationService.instance.initialize();
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );
    }
    LocalNotificationService.instance.onTap = DeepLinkService.openNotification;
    FirebaseMessaging.onMessage.listen(
      _handleForegroundMessage,
      onError: (Object error) {
        debugPrint('[FCM] foreground receive failed: ${_safeErrorCode(error)}');
      },
    );
    FirebaseMessaging.onMessageOpenedApp.listen(
      (message) {
        _pendingTap = Map<String, dynamic>.from(message.data);
        unawaited(handlePendingTap());
      },
      onError: (Object error) {
        debugPrint('[FCM] notification open failed: ${_safeErrorCode(error)}');
      },
    );
    FirebaseMessaging.instance.onRegistered.listen((installationId) {
      _currentInstallationId = installationId;
      final completer = _installationIdCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete(installationId);
      }
      unawaited(
        _registerTarget(installationId).then<void>(
          (_) {},
          onError: (Object error) {
            debugPrint(
              '[FCM] installation sync failed: ${_safeErrorCode(error)}',
            );
          },
        ),
      );
    }, onError: (Object error) {
      debugPrint(
          '[FCM] installation registration failed: ${_safeErrorCode(error)}');
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
    await initialize();
    var settings = await FirebaseMessaging.instance.getNotificationSettings();
    final preferences = await SharedPreferences.getInstance();
    if (shouldRequestPermission(
      status: settings.authorizationStatus,
      prompted: preferences.getBool(_permissionPromptedKey) ?? false,
      isAndroid: defaultTargetPlatform == TargetPlatform.android,
    )) {
      await requestPermission();
      await preferences.setBool(_permissionPromptedKey, true);
      settings = await FirebaseMessaging.instance.getNotificationSettings();
    }
    if (!_isPermissionGranted(settings.authorizationStatus)) {
      await _syncRoleTopic(null);
      await _deactivateCurrentDevice();
      return;
    }
    await _syncRoleTopic(null);
    if (await _registerCurrentInstallation()) {
      await _syncRoleTopic(session);
    }
  }

  Future<void> refreshRegistration() async {
    if (!_supportsPushPlatform || _session == null) return;
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (!_isPermissionGranted(settings.authorizationStatus)) {
      await _syncRoleTopic(null);
      await _deactivateCurrentDevice();
      return;
    }
    if (await _registerCurrentInstallation()) {
      await _syncRoleTopic(_session);
    }
  }

  Future<FcmDiagnostics> getDiagnostics() async {
    final preferences = await SharedPreferences.getInstance();
    final firebaseReady = Firebase.apps.isNotEmpty;
    AuthorizationStatus? authorization;
    bool? systemNotificationsEnabled;
    var channelWarnings = const <String>[];
    if (_supportsPushPlatform && firebaseReady) {
      try {
        final settings =
            await FirebaseMessaging.instance.getNotificationSettings();
        authorization = settings.authorizationStatus;
        if (defaultTargetPlatform == TargetPlatform.android) {
          systemNotificationsEnabled =
              await LocalNotificationService.instance.areNotificationsEnabled();
          channelWarnings =
              await LocalNotificationService.instance.getChannelWarnings();
        }
      } catch (error) {
        debugPrint('[FCM] diagnostics failed: ${_safeErrorCode(error)}');
      }
    }
    return FcmDiagnostics(
      supported: _supportsPushPlatform,
      firebaseReady: firebaseReady,
      authorization: authorization,
      systemNotificationsEnabled: systemNotificationsEnabled,
      registered: preferences.getBool(_registeredKey) ?? false,
      lastSyncAt:
          DateTime.tryParse(preferences.getString(_lastSyncAtKey) ?? ''),
      lastResult: preferences.getString(_lastResultKey),
      channelWarnings: channelWarnings,
    );
  }

  Future<void> syncRegistration() async {
    if (!_supportsPushPlatform || _session == null) {
      throw StateError('سجّل الدخول على جهاز Android أو iOS أولاً');
    }
    await initialize();
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    if (!_isPermissionGranted(settings.authorizationStatus)) {
      throw StateError('إذن الإشعارات غير مسموح؛ فعّله من إعدادات التطبيق');
    }
    if (!await _registerCurrentInstallation()) {
      throw StateError(
          'لم يتوفر رمز FCM صالح؛ تحقق من اتصال الجهاز بخدمات Google');
    }
    await _syncRoleTopic(_session);
  }

  Future<void> openNotificationSettings() =>
      LocalNotificationService.instance.openAppNotificationSettings();

  Future<void> _deactivateCurrentDevice() async {
    try {
      _deviceId ??= await _getDeviceId();
      await ApiService().post({
        'action': 'user_device_deactivate',
        'device_id': _deviceId,
      });
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_registeredKey, false);
      await preferences.remove(_registeredUserIdKey);
      await preferences.remove(_lastTokenHashKey);
      await _saveSyncResult('disabled');
    } catch (error) {
      await _saveSyncResult('deactivation_failed');
      debugPrint('[FCM] device deactivation failed: ${_safeErrorCode(error)}');
    }
  }

  Future<void> unbindUser() async {
    final session = _session;
    _session = null;
    _pendingTap = null;
    LocalNotificationService.instance.clearPendingTap();
    DeepLinkService.clearSession();
    try {
      if (session != null) {
        _deviceId ??= await _getDeviceId();
        await ApiService().post({
          'action': 'user_device_deactivate',
          'device_id': _deviceId,
        });
      }
    } finally {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_registeredKey, false);
      await preferences.remove(_registeredUserIdKey);
      await preferences.remove(_lastTokenHashKey);
      if (_supportsPushPlatform && _initialized) await _syncRoleTopic(null);
    }
  }

  void clearUserSession() {
    _session = null;
    _pendingTap = null;
    LocalNotificationService.instance.clearPendingTap();
    DeepLinkService.clearSession();
    if (_supportsPushPlatform && _initialized) {
      unawaited(_syncRoleTopic(null).catchError((Object error) {
        debugPrint('[FCM] topic cleanup failed: ${_safeErrorCode(error)}');
      }));
    }
  }

  Future<void> _syncRoleTopic(Map<String, dynamic>? session) {
    final operation = _topicOperation.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      final oldTopic = preferences.getString(_roleTopicKey);
      final role = PermissionHelper.fromString(
        session?['role']?.toString().trim() ?? '',
      );
      final nextTopic =
          session == null || role == AppRole.user ? null : 'role_${role.name}';
      if (oldTopic != null && oldTopic != nextTopic) {
        await FirebaseMessaging.instance.unsubscribeFromTopic(oldTopic);
        await preferences.remove(_roleTopicKey);
      }
      if (nextTopic != null &&
          _session != null &&
          _session!['user_id']?.toString() == session?['user_id']?.toString() &&
          _session!['role']?.toString() == session?['role']?.toString()) {
        // Repeat on refresh so FCM can restore a subscription after reinstall.
        await FirebaseMessaging.instance.subscribeToTopic(nextTopic);
        await preferences.setString(_roleTopicKey, nextTopic);
      }
    });
    _topicOperation = operation.catchError((Object error) {
      debugPrint('[FCM] role topic sync failed: ${_safeErrorCode(error)}');
    });
    return operation;
  }

  Future<String> getDeviceId() => _getDeviceId();

  Future<void> handlePendingTap() async {
    await LocalNotificationService.instance.handlePendingTap();
    final data = _pendingTap;
    if (data == null) return;
    _pendingTap = null;
    await DeepLinkService.openNotification(data);
  }

  Future<bool> _registerTarget(
    String installationId, {
    String targetType = 'fid',
  }) async {
    final pendingRegistration = _registrationFuture;
    if (_registeringInstallationId == installationId &&
        pendingRegistration != null) {
      return pendingRegistration;
    }
    _registeringInstallationId = installationId;
    final registration = _registerTargetImpl(installationId, targetType);
    _registrationFuture = registration;
    try {
      return await registration;
    } finally {
      if (identical(_registrationFuture, registration)) {
        _registrationFuture = null;
        _registeringInstallationId = null;
      }
    }
  }

  Future<bool> _registerTargetImpl(
    String installationId,
    String targetType,
  ) async {
    final session = _session;
    if (session == null || installationId.isEmpty) return false;
    try {
      _deviceId ??= await _getDeviceId();
      final preferences = await SharedPreferences.getInstance();
      final userId = session['user_id']?.toString() ?? '';
      final targetHash =
          sha256.convert(utf8.encode('$targetType:$installationId')).toString();
      if (userId.isNotEmpty &&
          preferences.getString(_registeredUserIdKey) == userId &&
          preferences.getString(_lastTokenHashKey) == targetHash &&
          (preferences.getBool(_registeredKey) ?? false)) {
        return true;
      }
      final info = await PackageInfo.fromPlatform();
      await ApiService().post({
        'action': 'user_device_upsert',
        'device_id': _deviceId,
        'fcm_token': installationId,
        'fcm_target_type': targetType,
        'platform': _platformName,
        'app_version': info.version,
      });
      await preferences.setString(_lastTokenHashKey, targetHash);
      await preferences.setString(_registeredUserIdKey, userId);
      await preferences.setBool(_registeredKey, true);
      await _saveSyncResult('registered');
      debugPrint('[FCM] device registration succeeded');
      return true;
    } catch (error) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool(_registeredKey, false);
      await _saveSyncResult(_safeErrorCode(error));
      debugPrint('[FCM] device registration failed: ${_safeErrorCode(error)}');
      return false;
    }
  }

  Future<bool> _registerCurrentInstallation() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        var apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        for (var attempt = 0;
            (apnsToken == null || apnsToken.isEmpty) &&
                attempt < 5 &&
                _session != null;
            attempt++) {
          await Future<void>.delayed(const Duration(seconds: 1));
          apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        }
        if (apnsToken == null || apnsToken.isEmpty) {
          await _saveSyncResult('apns_token_pending');
          debugPrint('[FCM] APNs token pending');
          return false;
        }
      }
      final registration = Completer<String>();
      _installationIdCompleter = registration;
      var registered = false;
      try {
        await FirebaseMessaging.instance.register();
        final installationId = _currentInstallationId ??
            await registration.future.timeout(const Duration(seconds: 12));
        _currentInstallationId = installationId;
        registered = await _registerTarget(installationId);
      } catch (error) {
        debugPrint(
          '[FCM] installation ID unavailable; trying FCM token: '
          '${_safeErrorCode(error)}',
        );
      } finally {
        if (identical(_installationIdCompleter, registration)) {
          _installationIdCompleter = null;
        }
      }
      if (registered) return true;

      // Older Firebase configurations or devices may not deliver onRegistered.
      // Keep notifications working through the standard registration-token path.
      // Fallback for devices where the preferred FID registration event is absent.
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        await _saveSyncResult('fcm_token_unavailable');
        return false;
      }
      return await _registerTarget(token, targetType: 'token');
    } catch (error) {
      await _saveSyncResult(_safeErrorCode(error));
      debugPrint(
        '[FCM] installation ID retrieval failed: ${_safeErrorCode(error)}',
      );
      return false;
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
    final id = (data['notification_id'] ??
            message.messageId ??
            DateTime.now().microsecondsSinceEpoch)
        .toString();
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
    debugPrint('[FCM] foreground receive id=${id.isEmpty ? 'unknown' : id}');
    await onForegroundMessage?.call();
  }

  bool _isPermissionGranted(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;

  Future<void> _saveSyncResult(String result) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_lastResultKey, result);
    await preferences.setString(
      _lastSyncAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  String _safeErrorCode(Object error) {
    final match =
        RegExp(r'\b[A-Z][A-Z0-9_]{2,}\b').firstMatch(error.toString());
    return match?.group(0) ?? 'UNKNOWN';
  }
}
