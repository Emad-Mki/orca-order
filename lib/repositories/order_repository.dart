import 'dart:async';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'local_repository.dart';

/// مستودع الطلبات المحسن
/// يدعم العمل بدون إنترنت والمزامنة التلقائية
class OrderRepository {
  final ApiService _apiService = ApiService();
  final AppDatabase? _db;
  String? lastFetchError;

  OrderRepository({AppDatabase? db}) : _db = db;

  /// جلب قائمة الطلبات مع دعم التخزين المحلي
  Future<List<Order>> getOrders(
      {String? customerId, String? status, bool forceRefresh = false}) async {
    // 1. محاولة القراءة من التخزين المحلي إذا لم يطلب التحديث القسري
    if (!forceRefresh && _db != null) {
      final localOrders = await LocalRepository(_db).getOrders(
        customerId: customerId,
        status: status,
      );
      if (localOrders.isNotEmpty) return localOrders;
    }

    try {
      lastFetchError = null;
      final response = await _apiService.orders.getOrders(
        customerId: customerId,
        status: status,
      );

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
    try {
      // استخدام الخدمة المنفصلة للطلبات
      final response = await _apiService.orders.getOrderDetails(orderId);

      if (response['ok'] != true && response['success'] != true) {
        throw Exception(response['error'] ?? 'فشل جلب تفاصيل الطلب');
      }

      final orderData = response['order'] ?? response['data'];
      if (orderData == null) return null;

      final orderWithShipment = Map<String, dynamic>.from(orderData);
      orderWithShipment['shipment_data'] = response['shipment'];
      return Order.fromJson(orderWithShipment);
    } catch (e) {
      print('Error fetching order details: $e');
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
  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      // استخدام الخدمة المنفصلة للطلبات
      final response =
          await _apiService.orders.updateOrderStatus(orderId, status);
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
