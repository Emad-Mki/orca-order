import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';

enum AppUpdateStatus {
  idle,
  checking,
  noUpdate,
  available,
  downloading,
  paused,
  verifying,
  ready,
  error,
}

class UpdateManifest {
  final int schemaVersion;
  final String versionName;
  final int buildNumber;
  final int minimumSupportedBuild;
  final Uri apkUri;
  final String sha256;
  final int sizeBytes;
  final String releaseNotes;
  final DateTime publishedAt;
  final String packageName;

  const UpdateManifest({
    required this.schemaVersion,
    required this.versionName,
    required this.buildNumber,
    required this.minimumSupportedBuild,
    required this.apkUri,
    required this.sha256,
    required this.sizeBytes,
    required this.releaseNotes,
    required this.publishedAt,
    required this.packageName,
  });

  bool isRequiredFor(int installedBuild) =>
      installedBuild < minimumSupportedBuild;

  static UpdateManifest fromJson(
    Object? value, {
    required String expectedPackageName,
  }) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('ملف التحديث ليس كائن JSON صالحًا');
    }

    int requiredInt(String key) {
      final field = value[key];
      if (field is! int || field <= 0) {
        throw FormatException('الحقل $key يجب أن يكون عددًا صحيحًا موجبًا');
      }
      return field;
    }

    String requiredString(String key) {
      final field = value[key];
      if (field is! String || field.trim().isEmpty) {
        throw FormatException('الحقل $key مطلوب');
      }
      return field.trim();
    }

    final schemaVersion = requiredInt('schemaVersion');
    if (schemaVersion != 1) {
      throw const FormatException('نسخة مخطط التحديث غير مدعومة');
    }
    final versionName = requiredString('versionName');
    final buildNumber = requiredInt('buildNumber');
    final minimumSupportedBuild = requiredInt('minimumSupportedBuild');
    if (minimumSupportedBuild > buildNumber) {
      throw const FormatException(
          'الحد الأدنى المدعوم لا يمكن أن يتجاوز رقم البناء المنشور');
    }
    final packageName = requiredString('packageName');
    if (packageName != expectedPackageName) {
      throw const FormatException('التحديث مخصص لحزمة تطبيق مختلفة');
    }
    final apkUrlValue = value['apkUrl'];
    if (apkUrlValue is! String || apkUrlValue.trim().isEmpty) {
      throw const FormatException('الحقل apkUrl مطلوب');
    }
    if (RegExp(r'\s').hasMatch(apkUrlValue)) {
      throw const FormatException('رابط APK يحتوي على مسافات غير صالحة');
    }
    final apkUri = Uri.tryParse(apkUrlValue);
    final apkPath = apkUri?.pathSegments;
    if (apkUri == null ||
        apkUri.scheme != 'https' ||
        apkUri.host.isEmpty ||
        apkUri.userInfo.isNotEmpty ||
        apkUri.fragment.isNotEmpty ||
        apkUri.query.isNotEmpty ||
        apkUri.host.toLowerCase() != 'github.com' ||
        apkPath == null ||
        apkPath.length != 6 ||
        apkPath[0].toLowerCase() != 'emad-mki' ||
        apkPath[1].toLowerCase() != 'orca-order-updates' ||
        apkPath[2] != 'releases' ||
        apkPath[3] != 'download' ||
        apkPath[4].isEmpty ||
        apkPath[4].toLowerCase() == 'latest' ||
        apkPath[5] != 'app-release.apk') {
      throw const FormatException(
          'رابط APK يجب أن يشير إلى app-release.apk ضمن وسم Release ثابت في مستودع التحديثات');
    }
    final hash = requiredString('sha256').toLowerCase();
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const FormatException('قيمة SHA-256 غير صالحة');
    }
    final sizeBytes = requiredInt('sizeBytes');
    final notes = requiredString('releaseNotes');
    final publishedAt = DateTime.tryParse(requiredString('publishedAt'));
    if (publishedAt == null) {
      throw const FormatException('تاريخ النشر غير صالح');
    }

    return UpdateManifest(
      schemaVersion: schemaVersion,
      versionName: versionName,
      buildNumber: buildNumber,
      minimumSupportedBuild: minimumSupportedBuild,
      apkUri: apkUri,
      sha256: hash,
      sizeBytes: sizeBytes,
      releaseNotes: notes,
      publishedAt: publishedAt,
      packageName: packageName,
    );
  }
}

class AppUpdateService extends ChangeNotifier {
  AppUpdateService({String? manifestUrl})
      : _manifestUrl = manifestUrl ?? AppConfig.updateManifestUrl;

  static const Duration automaticCheckInterval = Duration(hours: 6);
  static const Duration requestTimeout = Duration(seconds: 20);
  static const Duration downloadReadTimeout = Duration(seconds: 60);
  static const MethodChannel _platform =
      MethodChannel('orca_order/apk_updates');
  static const String _manifestCacheKey = 'orca_update.cached_manifest';
  static const String _lastAutomaticCheckKey = 'orca_update.last_auto_check';
  static const String _pendingInstallKey = 'orca_update.pending_install';
  static const String _lastDismissedBuildKey = 'orca_update.dismissed_build';

  final String _manifestUrl;
  AppUpdateStatus _status = AppUpdateStatus.idle;
  PackageInfo? _packageInfo;
  UpdateManifest? _manifest;
  String? _errorMessage;
  String? _errorStage;
  File? _readyApk;
  HttpClient? _activeClient;
  Future<void>? _checkRequest;
  Future<void>? _downloadRequest;
  int _downloadedBytes = 0;
  DateTime? _lastProgressNotification;
  bool _cancelRequested = false;
  bool _automaticPromptShown = false;
  bool _installationConfirmed = false;
  bool _installPermissionRequired = false;
  bool _restoredManifest = false;
  Future<void>? _initializationRequest;

  AppUpdateStatus get status => _status;
  UpdateManifest? get manifest => _manifest;
  String? get errorMessage => _errorMessage;
  String? get errorStage => _errorStage;
  bool get isDownloading => _status == AppUpdateStatus.downloading;
  bool get isRequired =>
      _manifest?.isRequiredFor(installedBuildNumber) ?? false;
  int get installedBuildNumber =>
      int.tryParse(_packageInfo?.buildNumber ?? '') ?? 0;
  String get installedVersionName => _packageInfo?.version ?? 'غير معروف';
  int get downloadedBytes => _downloadedBytes;
  int? get totalBytes => _manifest?.sizeBytes;
  double? get progress {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (_downloadedBytes / total).clamp(0, 1).toDouble();
  }

  String? get readyApkPath => _readyApk?.path;
  bool get installationConfirmed => _installationConfirmed;
  bool get installPermissionRequired => _installPermissionRequired;

  Future<void> initialize() {
    final activeRequest = _initializationRequest;
    if (activeRequest != null) return activeRequest;
    final request = _performInitialization();
    _initializationRequest = request;
    return request.whenComplete(() {
      if (identical(_initializationRequest, request)) {
        _initializationRequest = null;
      }
    });
  }

  Future<void> _performInitialization() async {
    try {
      _packageInfo = await PackageInfo.fromPlatform();
      if (_packageInfo!.packageName != AppConfig.androidPackageName) {
        throw StateError('معرّف التطبيق لا يطابق إعداد محدث APK');
      }
      await _restoreSavedUpdate();
      notifyListeners();
    } catch (error) {
      _setError('initialization', 'تعذر قراءة بيانات إصدار التطبيق: $error');
    }
  }

  Future<void> checkForUpdates({bool manual = false}) {
    final activeRequest = _checkRequest;
    if (activeRequest != null) return activeRequest;
    if (_downloadRequest != null || _status == AppUpdateStatus.ready) {
      return Future<void>.value();
    }

    final request = _checkForUpdates(manual: manual);
    _checkRequest = request;
    return request.whenComplete(() {
      if (identical(_checkRequest, request)) _checkRequest = null;
    });
  }

  Future<void> _checkForUpdates({required bool manual}) async {
    if (_packageInfo == null) await initialize();
    if (_packageInfo == null ||
        _downloadRequest != null ||
        _status == AppUpdateStatus.ready) {
      return;
    }
    if (!manual && !(await _automaticCheckDue())) return;
    await _performCheck(manual: manual);
  }

  Future<bool> _automaticCheckDue() async {
    final lastCheck = (await _preferences).getInt(_lastAutomaticCheckKey);
    if (lastCheck == null) return true;
    return DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch(lastCheck),
        ) >=
        automaticCheckInterval;
  }

  Future<SharedPreferences> get _preferences => SharedPreferences.getInstance();

  Future<void> _performCheck({required bool manual}) async {
    _status = AppUpdateStatus.checking;
    _errorMessage = null;
    _errorStage = null;
    notifyListeners();

    final prefs = await _preferences;
    if (!manual) {
      await prefs.setInt(
        _lastAutomaticCheckKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }

    try {
      final bytes = await _fetchManifestBytes();
      final decoded = jsonDecode(utf8.decode(bytes));
      final manifest = UpdateManifest.fromJson(
        decoded,
        expectedPackageName: _packageInfo!.packageName,
      );
      _manifest = manifest;
      _restoredManifest = false;
      await prefs.setString(_manifestCacheKey, jsonEncode(decoded));
      await _setManifestResult(manifest, manual: manual);
    } catch (error) {
      final cached = await _readCachedManifest();
      if (cached != null) {
        _manifest = cached;
        _restoredManifest = true;
        if (cached.buildNumber > installedBuildNumber) {
          _status = AppUpdateStatus.available;
          _errorStage = 'check';
          _errorMessage =
              'تعذر الاتصال؛ تُستخدم آخر بيانات تحديث موثوقة تم التحقق منها.';
          notifyListeners();
          return;
        }
      }
      _setError('check', 'تعذر التحقق من وجود تحديث: $error');
    }
  }

  Future<UpdateManifest> _fetchFreshManifest() async {
    final bytes = await _fetchManifestBytes();
    final decoded = jsonDecode(utf8.decode(bytes));
    final manifest = UpdateManifest.fromJson(
      decoded,
      expectedPackageName: _packageInfo!.packageName,
    );
    await (await _preferences)
        .setString(_manifestCacheKey, jsonEncode(decoded));
    _manifest = manifest;
    _restoredManifest = false;
    await _setManifestResult(manifest, manual: true);
    return manifest;
  }

  Future<void> _setManifestResult(
    UpdateManifest manifest, {
    required bool manual,
  }) async {
    if (manifest.buildNumber > installedBuildNumber) {
      final dismissedBuild =
          (await _preferences).getInt(_lastDismissedBuildKey);
      if (!manifest.isRequiredFor(installedBuildNumber) &&
          dismissedBuild == manifest.buildNumber &&
          !manual) {
        _status = AppUpdateStatus.noUpdate;
      } else {
        _status = AppUpdateStatus.available;
      }
    } else {
      _status = AppUpdateStatus.noUpdate;
    }
    notifyListeners();
  }

  Future<Uint8List> _fetchManifestBytes() async {
    final uri = Uri.tryParse(_manifestUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FormatException('رابط ملف التحديث يجب أن يستخدم HTTPS');
    }
    final client = HttpClient()..connectionTimeout = requestTimeout;
    try {
      final result = await _getFollowingHttpsRedirects(client, uri)
          .timeout(requestTimeout);
      final response = result.response;
      debugPrint(
        '[APK updater] Manifest HTTP ${response.statusCode}; '
        'requested=${_safeUriForLog(uri)}; '
        'final=${_safeUriForLog(result.finalUri)}',
      );
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        throw HttpException('استجابة ملف التحديث: HTTP ${response.statusCode}');
      }
      final contentType =
          response.headers.contentType?.mimeType.toLowerCase() ?? '';
      if (contentType == 'text/html') {
        await response.drain<void>();
        throw const FormatException('رابط التحديث أعاد صفحة HTML');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(requestTimeout)) {
        bytes.addAll(chunk);
        if (bytes.length > 256 * 1024) {
          throw const FormatException('ملف التحديث أكبر من الحجم المسموح');
        }
      }
      if (bytes.isEmpty) throw const FormatException('ملف التحديث فارغ');
      return Uint8List.fromList(bytes);
    } finally {
      client.close(force: true);
    }
  }

  Future<_UpdateHttpResponse> _getFollowingHttpsRedirects(
    HttpClient client,
    Uri initialUri, {
    Map<String, String> headers = const {},
  }) async {
    var uri = initialUri;
    for (var redirects = 0; redirects <= 5; redirects++) {
      if (uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty) {
        throw const FormatException('تم رفض تحويل غير آمن لرابط التحديث');
      }
      final request = await client.getUrl(uri).timeout(requestTimeout);
      headers.forEach(request.headers.set);
      request.followRedirects = false;
      final response = await request.close().timeout(requestTimeout);
      if (![301, 302, 303, 307, 308].contains(response.statusCode)) {
        debugPrint(
          '[APK updater] HTTP ${response.statusCode}; '
          'requested=${_safeUriForLog(initialUri)}; '
          'final=${_safeUriForLog(uri)}',
        );
        return _UpdateHttpResponse(response, uri);
      }
      final location = response.headers.value(HttpHeaders.locationHeader);
      final nextUri = location == null ? null : uri.resolve(location);
      debugPrint(
        '[APK updater] HTTP ${response.statusCode}; '
        'redirect=${_safeUriForLog(uri)}; '
        'destination=${nextUri == null ? 'missing' : _safeUriForLog(nextUri)}',
      );
      await response.drain<void>();
      if (location == null) {
        throw const HttpException('تحويل HTTPS بلا وجهة صالحة');
      }
      uri = nextUri!;
    }
    throw const HttpException('تجاوز رابط التحديث عدد التحويلات المسموح');
  }

  String _safeUriForLog(Uri uri) {
    final port = uri.hasPort ? ':${uri.port}' : '';
    return '${uri.scheme}://${uri.host}$port${uri.path}';
  }

  Future<UpdateManifest?> _readCachedManifest() async {
    final value = (await _preferences).getString(_manifestCacheKey);
    if (value == null || _packageInfo == null) return null;
    try {
      return UpdateManifest.fromJson(
        jsonDecode(value),
        expectedPackageName: _packageInfo!.packageName,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> dismissOptionalUpdate() async {
    final update = _manifest;
    if (update == null || isRequired) return;
    await (await _preferences)
        .setInt(_lastDismissedBuildKey, update.buildNumber);
    if (_downloadRequest == null && _readyApk == null) {
      _status = AppUpdateStatus.noUpdate;
    }
    notifyListeners();
  }

  bool consumeAutomaticPrompt() {
    if (_status != AppUpdateStatus.available || _automaticPromptShown) {
      return false;
    }
    if (!isRequired && _restoredManifest) return false;
    _automaticPromptShown = true;
    return true;
  }

  Future<void> downloadUpdate() {
    final activeRequest = _downloadRequest;
    if (activeRequest != null) return activeRequest;
    if (_status == AppUpdateStatus.ready) return Future<void>.value();
    final update = _manifest;
    if (update == null) {
      return Future<void>.error(
        StateError('لا توجد بيانات تحديث صالحة لتنزيلها'),
      );
    }

    _cancelRequested = false;
    final request = _downloadWithRetries(update);
    _downloadRequest = request;
    return request.whenComplete(() {
      if (identical(_downloadRequest, request)) _downloadRequest = null;
    });
  }

  Future<void> _downloadWithRetries(UpdateManifest update) async {
    _status = AppUpdateStatus.downloading;
    _errorMessage = null;
    _errorStage = null;
    notifyListeners();
    Object? lastError;
    bool manifestRefreshed = false;

    for (var attempt = 0; attempt < 3; attempt++) {
      if (_cancelRequested) break;
      _status = AppUpdateStatus.downloading;
      notifyListeners();
      try {
        await _downloadOnce(update);
        return;
      } catch (error) {
        if (_cancelRequested) break;
        lastError = error;

        // A 404 triggers one network-only manifest refresh; stale cache is not
        // eligible to authorize a retry.
        if (error is _UpdateHttpException &&
            error.statusCode == HttpStatus.notFound &&
            !manifestRefreshed) {
          manifestRefreshed = true;
          try {
            final freshManifest = await _fetchFreshManifest();
            if (freshManifest.buildNumber == update.buildNumber &&
                freshManifest.apkUri != update.apkUri) {
              update = freshManifest;
              attempt = -1;
              continue;
            }
          } catch (refreshError) {
            lastError = _UpdateManifestRefreshException(
              error,
              refreshError,
            );
          }
          break;
        }

        if (error is _UpdateVerificationException ||
            error is _InsufficientStorageException ||
            !_isTransientDownloadError(error) ||
            attempt == 2) {
          break;
        }
        await Future<void>.delayed(
          Duration(milliseconds: 500 * (1 << attempt)),
        );
      }
    }

    if (_cancelRequested) {
      _status = AppUpdateStatus.paused;
      _errorMessage = 'تم إيقاف التنزيل؛ يمكن استئنافه لاحقًا.';
      notifyListeners();
      return;
    }
    _status = AppUpdateStatus.error;
    _errorStage =
        lastError is _UpdateVerificationException ? 'verification' : 'download';

    if (lastError is _UpdateManifestRefreshException) {
      final original = lastError.originalError;
      _errorMessage = 'أعاد رابط APK HTTP 404 ولم يتوفر رابط مصحح بعد تحديث '
          'بيانات الإصدار مرة واحدة. ${original.toString()} '
          'تعذر التحديث: ${lastError.refreshError}';
    } else if (lastError is _UpdateHttpException &&
        lastError.statusCode == HttpStatus.notFound) {
      _errorMessage = 'أعاد الخادم HTTP 404 لطلب APK. الرابط المطلوب: '
          '${_safeUriForLog(lastError.requestedUri)}؛ '
          'الرابط النهائي: ${_safeUriForLog(lastError.responseUri)}. '
          'تحقق من apkUrl ووسم الإصدار في update.json.';
    } else if (lastError is _UpdateHttpException) {
      _errorMessage = 'فشل تنزيل APK: HTTP ${lastError.statusCode}. '
          'الرابط المطلوب: ${_safeUriForLog(lastError.requestedUri)}؛ '
          'الرابط النهائي: ${_safeUriForLog(lastError.responseUri)}.';
    } else {
      _errorMessage = 'تعذر تنزيل التحديث: $lastError';
    }
    notifyListeners();
  }

  bool _isTransientDownloadError(Object error) {
    if (error is _UpdateHttpException) {
      return error.statusCode == HttpStatus.requestTimeout ||
          error.statusCode == 429 ||
          error.statusCode >= 500;
    }
    return error is SocketException ||
        error is TimeoutException ||
        error is _TransientDownloadException;
  }

  Future<void> _downloadOnce(UpdateManifest update) async {
    final directory = await getTemporaryDirectory();
    final updateDirectory =
        Directory('${directory.path}${Platform.pathSeparator}apk_updates');
    await updateDirectory.create(recursive: true);
    final apkName = 'orca-order-${update.buildNumber}.apk';
    final partFile =
        File('${updateDirectory.path}${Platform.pathSeparator}$apkName.part');
    final finalFile =
        File('${updateDirectory.path}${Platform.pathSeparator}$apkName');
    final prefs = await _preferences;
    final etagKey = 'orca_update.etag.${update.buildNumber}';
    final resumeIdentityKey = 'orca_update.resume.${update.buildNumber}';
    final resumeIdentity = jsonEncode({
      'apkUrl': update.apkUri.toString(),
      'sha256': update.sha256,
      'sizeBytes': update.sizeBytes,
    });
    var etag = prefs.getString(etagKey);
    var offset = await partFile.exists() ? await partFile.length() : 0;

    if (offset > 0 && prefs.getString(resumeIdentityKey) != resumeIdentity) {
      await partFile.delete();
      offset = 0;
      etag = null;
      await prefs.remove(etagKey);
      await prefs.remove(resumeIdentityKey);
    }

    if (offset > update.sizeBytes ||
        (offset > 0 && (offset < 4 || etag == null || etag.isEmpty))) {
      await partFile.delete();
      offset = 0;
      etag = null;
      await prefs.remove(etagKey);
      await prefs.remove(resumeIdentityKey);
    }

    if (Platform.isAndroid) {
      final availableBytes =
          await _platform.invokeMethod<int>('availableUpdateSpaceBytes');
      final requiredBytes = update.sizeBytes - offset + 2 * 1024 * 1024;
      if (availableBytes != null && availableBytes < requiredBytes) {
        throw const _InsufficientStorageException(
            'مساحة التخزين المؤقت غير كافية لتنزيل التحديث');
      }
    }

    final client = HttpClient()..connectionTimeout = requestTimeout;
    final transferTimeout =
        Timer(const Duration(minutes: 10), () => client.close(force: true));
    _activeClient = client;
    try {
      _UpdateHttpResponse result;
      late HttpClientResponse response;
      if (offset > 0 && etag != null) {
        result = await _getFollowingHttpsRedirects(
          client,
          update.apkUri,
          headers: {
            HttpHeaders.rangeHeader: 'bytes=$offset-',
            HttpHeaders.ifRangeHeader: etag,
          },
        ).timeout(requestTimeout);
        response = result.response;
        final responseEtag = response.headers.value(HttpHeaders.etagHeader);
        final range = response.headers.value(HttpHeaders.contentRangeHeader);
        final rangeMatches = range != null &&
            RegExp('^bytes $offset-\\d+/${update.sizeBytes}\$').hasMatch(range);
        if (response.statusCode != HttpStatus.partialContent ||
            responseEtag == null ||
            responseEtag != etag ||
            !rangeMatches) {
          await response.drain<void>();
          await partFile.delete();
          offset = 0;
          etag = null;
          await prefs.remove(etagKey);
          result = await _getFollowingHttpsRedirects(client, update.apkUri)
              .timeout(requestTimeout);
          response = result.response;
        }
      } else {
        result = await _getFollowingHttpsRedirects(client, update.apkUri)
            .timeout(requestTimeout);
        response = result.response;
      }

      if (response.statusCode != HttpStatus.ok &&
          response.statusCode != HttpStatus.partialContent) {
        final statusCode = response.statusCode;
        final responseUri = result.finalUri;
        await response.drain<void>();
        throw _UpdateHttpException(
          statusCode: statusCode,
          requestedUri: update.apkUri,
          responseUri: responseUri,
        );
      }
      if (response.statusCode == HttpStatus.partialContent && offset == 0) {
        await response.drain<void>();
        throw const HttpException('استجابة Range غير متوقعة');
      }
      final contentType =
          response.headers.contentType?.mimeType.toLowerCase() ?? '';
      if (contentType == 'text/html') {
        await response.drain<void>();
        throw const FormatException('رابط APK أعاد صفحة HTML');
      }
      if (response.statusCode == HttpStatus.ok && offset > 0) {
        await partFile.delete();
        offset = 0;
      }
      final responseEtag = response.headers.value(HttpHeaders.etagHeader);
      if (responseEtag != null && responseEtag.isNotEmpty) {
        etag = responseEtag;
        await prefs.setString(etagKey, responseEtag);
        await prefs.setString(resumeIdentityKey, resumeIdentity);
      } else {
        etag = null;
        await prefs.remove(etagKey);
        await prefs.remove(resumeIdentityKey);
      }

      _downloadedBytes = offset;
      _notifyDownloadProgress(force: true);
      final sink = partFile.openWrite(
        mode: offset > 0 ? FileMode.append : FileMode.write,
      );
      var firstBytes =
          offset > 0 ? await partFile.openRead(0, 4).first : <int>[];
      try {
        await for (final chunk in response.timeout(downloadReadTimeout)) {
          if (_cancelRequested) {
            throw const _DownloadCancelledException();
          }
          if (offset == 0 && firstBytes.length < 4) {
            firstBytes.addAll(chunk.take(4 - firstBytes.length));
            if (firstBytes.length == 4 &&
                !(firstBytes[0] == 0x50 &&
                    firstBytes[1] == 0x4b &&
                    firstBytes[2] == 0x03 &&
                    firstBytes[3] == 0x04)) {
              throw const _UpdateVerificationException(
                  'محتوى التنزيل ليس ملف APK/ZIP صالحًا');
            }
          }
          sink.add(chunk);
          _downloadedBytes += chunk.length;
          if (_downloadedBytes > update.sizeBytes) {
            throw const _UpdateVerificationException(
                'حجم الملف المنزّل أكبر من الحجم المنشور');
          }
          _notifyDownloadProgress();
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      if (_downloadedBytes != update.sizeBytes || firstBytes.length < 4) {
        throw _TransientDownloadException(
          'حجم APK غير مكتمل ($_downloadedBytes من ${update.sizeBytes} بايت)',
        );
      }

      _status = AppUpdateStatus.verifying;
      _errorStage = null;
      notifyListeners();
      final digest = await sha256.bind(partFile.openRead()).first;
      if (digest.toString() != update.sha256) {
        await partFile.delete();
        await prefs.remove(etagKey);
        throw const _UpdateVerificationException(
            'فشل التحقق من SHA-256؛ حُذف الملف غير المطابق');
      }
      if (!Platform.isAndroid) {
        throw const _UpdateVerificationException(
            'تثبيت APK مدعوم على Android فقط');
      }
      final Map<String, dynamic>? archive;
      try {
        archive = await _platform.invokeMapMethod<String, dynamic>(
          'validateApk',
          {
            'path': partFile.path,
            'packageName': update.packageName,
            'buildNumber': update.buildNumber,
          },
        );
      } on PlatformException catch (error) {
        throw _UpdateVerificationException(
          error.message ?? 'فشل التحقق من حزمة التطبيق وتوقيعها',
        );
      }
      if (archive == null ||
          archive['packageName'] != update.packageName ||
          archive['buildNumber'] != update.buildNumber ||
          archive['versionName'] != update.versionName) {
        throw const _UpdateVerificationException(
            'بيانات APK الداخلية لا تطابق ملف التحديث');
      }
      if (await finalFile.exists()) await finalFile.delete();
      await partFile.rename(finalFile.path);
      _readyApk = finalFile;
      await prefs.remove(etagKey);
      await prefs.remove(resumeIdentityKey);
      await _removeOldUpdateFiles(keepBuild: update.buildNumber);
      _status = AppUpdateStatus.ready;
      _downloadedBytes = update.sizeBytes;
      notifyListeners();
    } on _DownloadCancelledException {
      rethrow;
    } on _UpdateVerificationException {
      if (await partFile.exists()) await partFile.delete();
      await prefs.remove(etagKey);
      await prefs.remove(resumeIdentityKey);
      rethrow;
    } finally {
      _activeClient = null;
      transferTimeout.cancel();
      client.close(force: true);
    }
  }

  void _notifyDownloadProgress({bool force = false}) {
    final now = DateTime.now();
    if (force ||
        _lastProgressNotification == null ||
        now.difference(_lastProgressNotification!) >=
            const Duration(milliseconds: 100)) {
      _lastProgressNotification = now;
      notifyListeners();
    }
  }

  Future<void> cancelDownload() async {
    if (_downloadRequest == null) return;
    _cancelRequested = true;
    _activeClient?.close(force: true);
  }

  Future<bool> installReadyApk() async {
    final apk = _readyApk;
    final update = _manifest;
    if (apk == null || update == null || _status != AppUpdateStatus.ready) {
      throw StateError('لا يوجد ملف تحديث متحقق منه للتثبيت');
    }
    if (!Platform.isAndroid) {
      throw UnsupportedError('تثبيت APK مدعوم على Android فقط');
    }
    final canInstall =
        await _platform.invokeMethod<bool>('canRequestInstallPackages') ??
            false;
    if (!canInstall) {
      _installPermissionRequired = true;
      notifyListeners();
      await _platform.invokeMethod<bool>('openInstallPermissionSettings');
      return false;
    }
    _installPermissionRequired = false;
    notifyListeners();
    await (await _preferences).setInt(
      _pendingInstallKey,
      update.buildNumber,
    );
    await _platform.invokeMethod<bool>(
      'installApk',
      {'path': apk.path},
    );
    return true;
  }

  Future<void> _restoreSavedUpdate() async {
    final prefs = await _preferences;
    final cached = await _readCachedManifest();
    if (cached == null) {
      await _removeOldUpdateFiles();
      return;
    }
    _manifest = cached;

    final pendingBuild = prefs.getInt(_pendingInstallKey);
    if (pendingBuild != null && installedBuildNumber >= pendingBuild) {
      _installationConfirmed = true;
      await prefs.remove(_pendingInstallKey);
      await _removeOldUpdateFiles(keepBuild: installedBuildNumber);
      _status = AppUpdateStatus.noUpdate;
      return;
    }

    if (cached.buildNumber <= installedBuildNumber) {
      _status = AppUpdateStatus.noUpdate;
      await _removeOldUpdateFiles();
      return;
    }
    final directory = await getTemporaryDirectory();
    final apk = File(
      '${directory.path}${Platform.pathSeparator}apk_updates${Platform.pathSeparator}orca-order-${cached.buildNumber}.apk',
    );
    final part = File('${apk.path}.part');
    if (await apk.exists()) {
      final length = await apk.length();
      if (length == cached.sizeBytes &&
          await sha256
              .bind(apk.openRead())
              .first
              .then((hash) => hash.toString() == cached.sha256)) {
        try {
          if (Platform.isAndroid) {
            await _platform.invokeMethod<Map<dynamic, dynamic>>(
              'validateApk',
              {
                'path': apk.path,
                'packageName': cached.packageName,
                'buildNumber': cached.buildNumber,
              },
            );
          }
          _readyApk = apk;
          _downloadedBytes = cached.sizeBytes;
          _status = AppUpdateStatus.ready;
          return;
        } on PlatformException {
          await apk.delete();
        }
      } else {
        await apk.delete();
      }
    }
    if (await part.exists() && await part.length() > 0) {
      final etag = prefs.getString('orca_update.etag.${cached.buildNumber}');
      _downloadedBytes = await part.length();
      _status =
          etag == null ? AppUpdateStatus.available : AppUpdateStatus.paused;
      return;
    }
    _status = AppUpdateStatus.available;
  }

  Future<void> _removeOldUpdateFiles({int? keepBuild}) async {
    final base = await getTemporaryDirectory();
    final directory =
        Directory('${base.path}${Platform.pathSeparator}apk_updates');
    if (!await directory.exists()) return;
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      final match = RegExp(r'^orca-order-(\d+)\.apk(?:\.part)?$').firstMatch(
        entity.uri.pathSegments.last,
      );
      if (match == null) continue;
      final build = int.tryParse(match.group(1) ?? '');
      if (build != null && build != keepBuild) {
        await entity.delete();
      }
    }
  }

  Future<void> onAppResumed() async {
    final previousBuild = installedBuildNumber;
    try {
      _packageInfo = await PackageInfo.fromPlatform();
      final pendingBuild = (await _preferences).getInt(_pendingInstallKey);
      if (pendingBuild != null && installedBuildNumber >= pendingBuild) {
        _installationConfirmed = true;
        await (await _preferences).remove(_pendingInstallKey);
        await _removeOldUpdateFiles(keepBuild: installedBuildNumber);
        _status = AppUpdateStatus.noUpdate;
      } else if (installedBuildNumber != previousBuild &&
          _status == AppUpdateStatus.ready) {
        _status = AppUpdateStatus.noUpdate;
      }
      notifyListeners();
    } catch (error) {
      debugPrint('Unable to verify installed app version: $error');
    }
  }

  void _setError(String stage, String message) {
    _status = AppUpdateStatus.error;
    _errorStage = stage;
    _errorMessage = message;
    notifyListeners();
  }
}

class _UpdateVerificationException implements Exception {
  final String message;
  const _UpdateVerificationException(this.message);

  @override
  String toString() => message;
}

class _DownloadCancelledException implements Exception {
  const _DownloadCancelledException();
}

class _TransientDownloadException implements Exception {
  final String message;
  const _TransientDownloadException(this.message);

  @override
  String toString() => message;
}

class _UpdateManifestRefreshException implements Exception {
  final _UpdateHttpException originalError;
  final Object refreshError;

  const _UpdateManifestRefreshException(
    this.originalError,
    this.refreshError,
  );
}

class _InsufficientStorageException implements Exception {
  final String message;
  const _InsufficientStorageException(this.message);

  @override
  String toString() => message;
}

class _UpdateHttpException implements Exception {
  final int statusCode;
  final Uri requestedUri;
  final Uri responseUri;

  const _UpdateHttpException({
    required this.statusCode,
    required this.requestedUri,
    required this.responseUri,
  });

  @override
  String toString() =>
      'HTTP $statusCode for $requestedUri (response: $responseUri)';
}

class _UpdateHttpResponse {
  final HttpClientResponse response;
  final Uri finalUri;

  const _UpdateHttpResponse(this.response, this.finalUri);
}
