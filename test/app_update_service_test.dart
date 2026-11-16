import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/app_config.dart';
import 'package:orca_order/services/app_update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RealHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context)
      ..connectionTimeout = const Duration(seconds: 20);
    return client;
  }
}

Map<String, Object> _manifest({
  int buildNumber = 3,
  int minimumSupportedBuild = 2,
  String apkUrl =
      'https://github.com/Emad-Mki/Orca-Order-updates/releases/download/V1.0.0.03/app-release.apk',
  String sha256Value =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
  String packageName = 'com.example.orca_order',
}) {
  return {
    'schemaVersion': 1,
    'versionName': '1.0.0.02',
    'buildNumber': buildNumber,
    'minimumSupportedBuild': minimumSupportedBuild,
    'apkUrl': apkUrl,
    'sha256': sha256Value,
    'sizeBytes': 1024,
    'releaseNotes': 'إصلاحات وتحسينات',
    'publishedAt': '2026-01-01T00:00:00Z',
    'packageName': packageName,
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('default manifest URL uses the public GitHub latest stable Release', () {
    expect(
      AppConfig.updateManifestUrl,
      'https://github.com/Emad-Mki/orca-order-updates/releases/latest/download/update.json',
    );
  });

  group('UpdateManifest', () {
    test('preserves the case-sensitive GitHub release tag from apkUrl', () {
      final manifest = UpdateManifest.fromJson(
        _manifest(
          buildNumber: 3,
          apkUrl:
              'https://github.com/Emad-Mki/Orca-Order-updates/releases/download/V1.0.0.01/app-release.apk',
        ),
        expectedPackageName: 'com.example.orca_order',
      );

      expect(
        manifest.apkUri.toString(),
        'https://github.com/Emad-Mki/Orca-Order-updates/releases/download/V1.0.0.01/app-release.apk',
      );
    });

    test('rejects whitespace in APK URLs instead of silently normalizing it',
        () {
      expect(
        () => UpdateManifest.fromJson(
          _manifest(
            apkUrl:
                'https://github.com/Emad-Mki/Orca-Order-updates/releases/download/V1.0.0.01/app-release.apk ',
          ),
          expectedPackageName: 'com.example.orca_order',
        ),
        throwsFormatException,
      );
    });

    test('validates required and optional updates by numeric build', () {
      final optional = UpdateManifest.fromJson(
        _manifest(minimumSupportedBuild: 2),
        expectedPackageName: 'com.example.orca_order',
      );
      final required = UpdateManifest.fromJson(
        _manifest(minimumSupportedBuild: 3),
        expectedPackageName: 'com.example.orca_order',
      );

      expect(optional.buildNumber, 3);
      expect(optional.isRequiredFor(2), isFalse);
      expect(required.isRequiredFor(2), isTrue);
      expect(required.isRequiredFor(3), isFalse);
    });

    test('rejects invalid hashes, non-HTTPS URLs, and package mismatch', () {
      expect(
        () => UpdateManifest.fromJson(
          _manifest(sha256Value: 'not-a-hash'),
          expectedPackageName: 'com.example.orca_order',
        ),
        throwsFormatException,
      );
      expect(
        () => UpdateManifest.fromJson(
          _manifest(apkUrl: 'http://downloads.example.invalid/app.apk'),
          expectedPackageName: 'com.example.orca_order',
        ),
        throwsFormatException,
      );
      expect(
        () => UpdateManifest.fromJson(
          _manifest(
            apkUrl:
                'https://github.com/Emad-Mki/orca-order-updates/releases/latest/download/app-release.apk',
          ),
          expectedPackageName: 'com.example.orca_order',
        ),
        throwsFormatException,
      );
      expect(
        () => UpdateManifest.fromJson(
          _manifest(
            apkUrl:
                'https://github.com/Emad-Mki/orca-order-updates/releases/download/v1.0.0.03/orca.apk',
          ),
          expectedPackageName: 'com.example.orca_order',
        ),
        throwsFormatException,
      );
      expect(
        () => UpdateManifest.fromJson(
          _manifest(packageName: 'com.other.app'),
          expectedPackageName: 'com.example.orca_order',
        ),
        throwsFormatException,
      );
    });

    test('rejects inconsistent minimum and published build numbers', () {
      expect(
        () => UpdateManifest.fromJson(
          _manifest(buildNumber: 3, minimumSupportedBuild: 4),
          expectedPackageName: 'com.example.orca_order',
        ),
        throwsFormatException,
      );
    });

    test('rejects missing fields and unsupported schema', () {
      final incomplete = _manifest()..remove('sha256');
      expect(
        () => UpdateManifest.fromJson(
          incomplete,
          expectedPackageName: 'com.example.orca_order',
        ),
        throwsFormatException,
      );
      expect(
        () => UpdateManifest.fromJson(
          {..._manifest(), 'schemaVersion': 2},
          expectedPackageName: 'com.example.orca_order',
        ),
        throwsFormatException,
      );
    });
  });

  test(
    'downloads the published APK through the app updater and verifies its SHA-256',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'orca-update-integration-',
      );
      const pathProviderChannel = MethodChannel(
        'plugins.flutter.io/path_provider',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        pathProviderChannel,
        (call) async => directory.path,
      );
      PackageInfo.setMockInitialValues(
        appName: 'Orca Order',
        packageName: 'com.example.orca_order',
        version: '1.0.0.00',
        buildNumber: '2',
        buildSignature: '',
      );
      SharedPreferences.setMockInitialValues({
        'orca_update.cached_manifest': jsonEncode({
          'schemaVersion': 1,
          'versionName': '1.0.0.01',
          'buildNumber': 3,
          'minimumSupportedBuild': 2,
          'apkUrl':
              'https://github.com/Emad-Mki/Orca-Order-updates/releases/download/V1.0.0.01/app-release.apk',
          'sha256':
              '3d9681ce38aec375183899991ca9a79a53d5264f5a6598278aa95014f08680ce',
          'sizeBytes': 76561458,
          'releaseNotes': 'تحسينات جديدة وإصلاحات الأخطاء.',
          'publishedAt': '2026-11-14T06:10:01Z',
          'packageName': 'com.example.orca_order',
        }),
      });

      final updater = AppUpdateService();
      Future<void>? downloadRequest;
      addTearDown(() async {
        await updater.cancelDownload();
        await downloadRequest;
        updater.dispose();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(pathProviderChannel, null);
        await directory.delete(recursive: true);
      });

      await updater.initialize();
      expect(updater.status, AppUpdateStatus.available);
      downloadRequest = HttpOverrides.runWithHttpOverrides(
        updater.downloadUpdate,
        _RealHttpOverrides(),
      );
      await downloadRequest;

      expect(updater.status, AppUpdateStatus.error);
      expect(updater.errorStage, 'verification', reason: updater.errorMessage);
      expect(
        updater.errorMessage,
        contains('تثبيت APK مدعوم على Android فقط'),
        reason: 'The service should reach the platform-only step only after '
            'the downloaded APK size and SHA-256 have both passed.',
      );
    },
    skip: Platform.environment['ORCA_TEST_RELEASE_DOWNLOAD'] == '1'
        ? false
        : 'Set ORCA_TEST_RELEASE_DOWNLOAD=1 to download the public 76 MB APK.',
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
