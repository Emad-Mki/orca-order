import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../app_config.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'local_repository.dart';

/// Identity of one authenticated session. [sessionIdentity] changes on login.
class OrderDetailSession {
  const OrderDetailSession({
    required this.environment,
    required this.apiUrl,
    required this.userId,
    required this.role,
    required this.token,
    required this.sessionIdentity,
  });

  final String environment;
  final String apiUrl;
  final String userId;
  final String role;
  final String? token;
  final Object? sessionIdentity;

  bool get canCache =>
      token != null &&
      token!.isNotEmpty &&
      sessionIdentity != null &&
      [environment, apiUrl, userId, role].every((s) => s.trim().isNotEmpty);

  bool matches(OrderDetailSession other) =>
      token == other.token &&
      identical(sessionIdentity, other.sessionIdentity) &&
      environment == other.environment &&
      apiUrl == other.apiUrl &&
      userId == other.userId &&
      role == other.role;
}

/// مستودع الطلبات المحسن
/// يدعم العمل بدون إنترنت والمزامنة التلقائية
class OrderRepository {
  final ApiService _apiService = ApiService();
  final AppDatabase? _db;
  final Future<Map<String, dynamic>> Function(String)? _detailFetcher;
  final OrderDetailSession Function()? _detailSession;
  final Directory? _detailCacheDirectory;
  String? lastFetchError;
  String? detailCacheError;
  bool lastDetailFromCache = false;

  OrderRepository({
    AppDatabase? db,
    Future<Map<String, dynamic>> Function(String)? detailFetcher,
    OrderDetailSession Function()? detailSession,
    Directory? detailCacheDirectory,
  })  : _db = db,
        _detailFetcher = detailFetcher,
        _detailSession = detailSession,
        _detailCacheDirectory = detailCacheDirectory;

  OrderDetailSession _session() {
    if (_detailSession != null) return _detailSession();
    final user = _apiService.currentUser;
    return OrderDetailSession(
      environment: AppConfig.environmentName,
      apiUrl: AppConfig.apiUrl,
      userId: (user?['user_id'] ??
              user?['id'] ??
              user?['customer_id'] ??
              user?['username'] ??
              '')
          .toString(),
      role: (user?['role'] ?? '').toString(),
      token: _apiService.token,
      sessionIdentity: user,
    );
  }

  void _checkSession(OrderDetailSession session) {
    if (!session.matches(_session())) {
      throw StateError('تغير الحساب أثناء تحميل تفاصيل الطلب');
    }
  }

  Future<File> _detailFile(OrderDetailSession session, String orderId) async {
    final root =
        _detailCacheDirectory ?? await getApplicationSupportDirectory();
    final hash = sha256.convert(utf8.encode(jsonEncode([
      session.environment,
      session.apiUrl,
      session.userId,
      session.role,
      orderId
    ])));
    return File(path.join(root.path, 'order_details', '$hash.json'));
  }

  bool _containsCredentials(dynamic value, String token) {
    if (value is Map) {
      return value.entries.any((entry) {
        final key = entry.key.toString().toLowerCase().replaceAll('_', '');
        return key.endsWith('token') ||
            _containsCredentials(entry.value, token);
      });
    }
    if (value is List) {
      return value.any((element) => _containsCredentials(element, token));
    }
    return value is String && value.contains(token);
  }

  Future<void> _saveDetail(OrderDetailSession session, String orderId,
      Map<String, dynamic> data) async {
    if (!session.canCache ||
        _containsCredentials(data, session.token!) ||
        (data['items'] is! List && data['order_items'] is! List)) {
      return;
    }
    final file = await _detailFile(session, orderId);
    _checkSession(session);
    await file.parent.create(recursive: true);
    _checkSession(session);
    final random = Random.secure();
    final nonce = List.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final temp = File('${file.path}.$nonce.tmp');
    try {
      await temp.writeAsString(jsonEncode({'version': 1, 'order': data}),
          flush: true);
      // No asynchronous gap between checking the session and committing.
      _checkSession(session);
      temp.renameSync(file.path);
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<Order?> _readDetail(OrderDetailSession session, String orderId) async {
    if (!session.canCache) return null;
    final file = await _detailFile(session, orderId);
    _checkSession(session);
    if (!await file.exists()) {
      _checkSession(session);
      return null;
    }
    final decoded = jsonDecode(await file.readAsString());
    _checkSession(session);
    if (decoded is! Map ||
        decoded['version'] != 1 ||
        decoded['order'] is! Map) {
      throw const FormatException('بيانات تفاصيل الطلب المحفوظة غير صالحة');
    }
    final data = Map<String, dynamic>.from(decoded['order'] as Map);
    if ((data['items'] ?? data['order_items']) is! List ||
        (data['order_id'] ?? data['id'])?.toString() != orderId) {
      throw const FormatException('بيانات تفاصيل الطلب المحفوظة غير صالحة');
    }
    return Order.fromJson(data);
  }

  Future<Order?> getCachedOrderDetails(String orderId) =>
      _readDetail(_session(), orderId);

  /// جلب قائمة الطلبات مع دعم التخزين المحلي
  Future<List<Order>> getOrders(
      {String? customerId, String? status, bool forceRefresh = false}) async {
    final requestToken = _apiService.token;
    // 1. محاولة القراءة من التخزين المحلي إذا لم يطلب التحديث القسري
    if (!forceRefresh && _db != null) {
      final localOrders = await LocalRepository(_db).getOrders(
        customerId: customerId,
        status: status,
      );
      if (_apiService.token != requestToken) {
        throw StateError('تغير الحساب أثناء تحميل الطلبات');
      }
      if (localOrders.isNotEmpty) return localOrders;
    }

    try {
      lastFetchError = null;
      final response = await _apiService.orders.getOrders(
        customerId: customerId,
        status: status,
      );
      if (_apiService.token != requestToken) {
        throw StateError('تغير الحساب أثناء تحميل الطلبات');
      }

      final items = response['orders'] ?? response['data'] ?? [];
      if (items is! List) {
        throw const FormatException(
          'استجابة الطلبات لا تحتوي على قائمة صالحة',
        );
      }

      final orders = items.map((item) {
        if (item is! Map) {
          throw const FormatException(
            'عنصر قائمة الطلبات ليس كائن بيانات صالحًا',
          );
        }
        return Order.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      // حفظ في التخزين المحلي
      if (_db != null) {
        await LocalRepository(_db).saveOrders(orders);
        await LocalRepository(_db).updateLastSync('orders');
      }

      return orders;
    } catch (e) {
      lastFetchError = e.toString();
      print('Error fetching orders: $e');
      if (_apiService.token != requestToken) rethrow;
      if (e is FormatException) rethrow;

      // محاولة العودة للبيانات المحلية في حال فشل الاتصال
      if (_db != null) {
        return await LocalRepository(_db).getOrders(
          customerId: customerId,
          status: status,
        );
      }
      rethrow;
    }
  }

  /// جلب تفاصيل طلب محدد
  Future<Order?> getOrderDetails(String orderId) async {
    final session = _session();
    detailCacheError = null;
    lastDetailFromCache = false;
    try {
      // استخدام الخدمة المنفصلة للطلبات
      final response = await (_detailFetcher?.call(orderId) ??
          _apiService.orders.getOrderDetails(orderId));
      _checkSession(session);

      if (response['ok'] != true && response['success'] != true) {
        throw Exception(response['error'] ?? 'فشل جلب تفاصيل الطلب');
      }

      final orderData = response['order'] ?? response['data'];
      if (orderData == null) return null;

      final orderWithShipment = Map<String, dynamic>.from(orderData);
      if (response.containsKey('shipment')) {
        orderWithShipment['shipment_data'] = response['shipment'];
      }
      final order = Order.fromJson(orderWithShipment);
      if (order.orderId == orderId) {
        try {
          await _saveDetail(session, orderId, orderWithShipment);
        } on StateError {
          rethrow;
        } catch (error) {
          detailCacheError = 'تعذر حفظ تفاصيل الطلب للاستخدام دون اتصال';
          debugPrint('Order detail cache write failed: ${error.runtimeType}');
        }
      }
      _checkSession(session);
      return order;
    } catch (e) {
      _checkSession(session);
      if (e is ApiException && e.transportFailure) {
        final cached = await _readDetail(session, orderId);
        _checkSession(session);
        if (cached != null) {
          lastDetailFromCache = true;
          return cached;
        }
      }
      rethrow;
    }
  }

  /// إنشاء طلب جديد مع معالجة تكرار الإرسال (Idempotency)
  Future<String> createOrder(Order order, {String? customerId}) async {
    try {
      final orderJson = order.toJson();

      // توليد معرف فريد للطلب من جهة العميل لمنع التكرار في حال إعادة المحاولة
      final String clientRequestId = order.clientRequestId ??
          'REQ-${DateTime.now().millisecondsSinceEpoch}-${_generateRandomString(6)}';

      orderJson['action'] = 'create_order';
      orderJson['client_request_id'] = clientRequestId;

      if (customerId != null) {
        orderJson['customerId'] = customerId;
      }

      final response = await _apiService.orders.createOrder(orderJson);

      if (response['ok'] != true && response['success'] != true) {
        throw Exception(
            response['error'] ?? response['message'] ?? 'فشل إنشاء الطلب');
      }

      // إذا كان الطلب مكرراً، سيظل الخادم يعيد نفس معرف الطلب (order_id)
      return response['order_id'] ?? response['id'] ?? '';
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  String _generateRandomString(int len) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = DateTime.now().microsecondsSinceEpoch;
    return List.generate(len, (index) => chars[(rnd + index) % chars.length])
        .join();
  }

  /// تحديث حالة الطلب
  Future<bool> updateOrderStatus(String orderId, String status,
      {String? reason, bool proxyForCustomer = false}) async {
    try {
      // استخدام الخدمة المنفصلة للطلبات
      final response = await _apiService.orders.updateOrderStatus(
        orderId,
        status,
        reason: reason,
        proxyForCustomer: proxyForCustomer,
      );
      return response['ok'] == true || response['success'] == true;
    } catch (e) {
      print('Error updating order status: $e');
      rethrow;
    }
  }

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    final response = await _apiService.orders.cancelOrder(orderId, reason);
    if (response['ok'] != true && response['success'] != true) {
      final error = response['error'];
      final message = error is Map
          ? error['message']?.toString()
          : response['message']?.toString();
      throw Exception(message ?? 'تعذر إلغاء الطلب');
    }
  }

  Future<void> editOrder({
    required String orderId,
    required String note,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await _apiService.orders.editOrder(
      orderId: orderId,
      note: note,
      items: items,
    );
    if (response['ok'] != true && response['success'] != true) {
      throw Exception(response['error'] ?? 'فشل حفظ تعديلات الطلب');
    }
  }

  Future<bool> confirmWarehousePrep({
    required String orderId,
    required List<Map<String, dynamic>> items,
    required String warehouseNote,
  }) async {
    final response = await _apiService.orders.confirmWarehousePrep(
      orderId: orderId,
      items: items,
      warehouseNote: warehouseNote,
    );
    return response['ok'] == true || response['success'] == true;
  }

  /// حفظ تسعير الطلب
  Future<bool> saveOrderPricing({
    required String orderId,
    required List<Map<String, dynamic>> items,
    double? subtotal,
    double? total,
    String? notes,
    bool submitForCustomer = false,
    Map<String, dynamic>? extraParams,
  }) async {
    try {
      // استخدام الخدمة المنفصلة للطلبات مع المعايير الموسعة
      final response = await _apiService.orders.saveOrderPricing(
        orderId: orderId,
        items: items,
        subtotal: subtotal,
        total: total,
        notes: notes,
        submitForCustomer: submitForCustomer,
        extraParams: extraParams,
      );
      return response['ok'] == true || response['success'] == true;
    } catch (e) {
      print('Error saving order pricing: $e');
      rethrow;
    }
  }
}
