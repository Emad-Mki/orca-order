import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/test/test_flutter_secure_storage_platform.dart';
import 'package:flutter_secure_storage_platform_interface/flutter_secure_storage_platform_interface.dart';
import 'package:orca_order/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FlutterSecureStoragePlatform originalPlatform;

  setUp(() {
    originalPlatform = FlutterSecureStoragePlatform.instance;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    FlutterSecureStoragePlatform.instance = originalPlatform;
  });

  test('startup recovers when Android secure storage cannot decrypt session',
      () async {
    final storage = _UnreadableSessionStorage();
    FlutterSecureStoragePlatform.instance = storage;

    await ApiService().init();

    expect(storage.resetCount, 1);
    expect(storage.data, isEmpty);
    expect(ApiService().token, isNull);
    expect(ApiService().currentUser, isNull);
  });

  test('startup discards malformed saved session data', () async {
    final storage = TestFlutterSecureStoragePlatform({
      'orca_session': 'not-json',
    });
    FlutterSecureStoragePlatform.instance = storage;

    await ApiService().init();

    expect(storage.data, isEmpty);
    expect(ApiService().token, isNull);
    expect(ApiService().currentUser, isNull);
  });
}

class _UnreadableSessionStorage extends TestFlutterSecureStoragePlatform {
  _UnreadableSessionStorage() : super({'orca_session': 'unreadable'});

  int resetCount = 0;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) async {
    throw PlatformException(code: 'key_unwrap_failed');
  }

  @override
  Future<void> deleteAll({required Map<String, String> options}) async {
    resetCount++;
    await super.deleteAll(options: options);
  }
}
