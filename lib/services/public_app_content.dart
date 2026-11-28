import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class PublicAppContent {
  static const _cacheKey = 'orca_public_app_content_v1';

  static Future<Map<String, dynamic>?> readCache() async {
    final preferences = await SharedPreferences.getInstance();
    final value = preferences.getString(_cacheKey);
    if (value == null) return null;
    final decoded = jsonDecode(value);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  }

  static Future<Map<String, dynamic>> refresh() async {
    final response = await ApiService().post({'action': 'contact_info_get'});
    await _writeCache(response);
    return response;
  }

  static Future<Map<String, dynamic>> save(
    Map<String, dynamic> settings,
  ) async {
    final response = await ApiService().post({
      'action': 'contact_info_update',
      'settings': settings,
    });
    final saved = response['settings'];
    if (saved is! Map) {
      throw const FormatException('إعدادات التطبيق غير موجودة في الرد');
    }
    final content = Map<String, dynamic>.from(saved)
      ..['last_updated'] = response['last_updated'] ?? '';
    await _writeCache(content);
    return content;
  }

  static Future<void> _writeCache(Map<String, dynamic> content) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = await preferences.setString(_cacheKey, jsonEncode(content));
    if (!saved) throw StateError('تعذر حفظ إعدادات التواصل محليًا');
  }
}
