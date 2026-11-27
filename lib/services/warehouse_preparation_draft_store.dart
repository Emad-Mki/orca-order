import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class WarehousePreparationDraftStore {
  const WarehousePreparationDraftStore();

  String _key(String scope) {
    final value = scope.trim();
    if (value.isEmpty) throw ArgumentError.value(scope, 'scope');
    return 'warehouse_preparation_draft_v1_'
        '${base64Url.encode(utf8.encode(value))}';
  }

  Future<Map<String, dynamic>?> load(String scope) async {
    final value =
        (await SharedPreferences.getInstance()).getString(_key(scope));
    if (value == null) return null;
    final decoded = jsonDecode(value);
    if (decoded is! Map) {
      throw const FormatException('مسودة التجهيز المحفوظة غير صالحة');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> save(String scope, Map<String, dynamic> draft) async {
    final encoded = jsonEncode(draft);
    await (await SharedPreferences.getInstance())
        .setString(_key(scope), encoded);
  }

  Future<void> clear(String scope) async {
    await (await SharedPreferences.getInstance()).remove(_key(scope));
  }
}
