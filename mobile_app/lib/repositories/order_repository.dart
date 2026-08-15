import 'dart:async';
import '../models/models.dart';
import '../services/api_service.dart';

/// مستودع الطلبات
/// يعمل كطبقة وسيطة بين الـ Models و الـ ApiService
/// مسؤول عن جلب البيانات وتحويلها إلى نماذج قوية
class OrderRepository {
  final ApiService _apiService = ApiService();

  /// جلب قائمة الطلبات
  Future<List<Order>> getOrders({String? customerId, String? status}) async {
    try {
      // استخدام الخدمة المنفصلة للطلبات
      final response = await _apiService.orders.getOrders(
        customerId: customerId,
        status: status,
      );

      final items = response['orders'] ?? response['data'] ?? [];
      if (items is! List) return [];

      return items.map((item) => Order.fromJson(item)).toList();
    } catch (e) {
      print('Error fetching orders: $e');
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

      return Order.fromJson(orderData);
    } catch (e) {
      print('Error fetching order details: $e');
      rethrow;
    }
  }

  /// إنشاء طلب جديد
  Future<String> createOrder(Order order) async {
    try {
      // استخدام الخدمة المنفصلة للطلبات
      final response = await _apiService.orders.createOrder(order.toJson());
      
      if (response['ok'] != true && response['success'] != true) {
        throw Exception(response['error'] ?? 'فشل إنشاء الطلب');
      }

      return response['order_id'] ?? response['id'] ?? '';
    } catch (e) {
      print('Error creating order: $e');
      rethrow;
    }
  }

  /// تحديث حالة الطلب
  Future<bool> updateOrderStatus(String orderId, String status) async {
    try {
      // استخدام الخدمة المنفصلة للطلبات
      final response = await _apiService.orders.updateOrderStatus(orderId, status);
      return response['ok'] == true || response['success'] == true;
    } catch (e) {
      print('Error updating order status: $e');
      rethrow;
    }
  }

  /// حفظ تسعير الطلب
  Future<bool> saveOrderPricing(String orderId, List<Map<String, dynamic>> items) async {
    try {
      // استخدام الخدمة المنفصلة للطلبات
      final response = await _apiService.orders.saveOrderPricing(orderId, items);
      return response['ok'] == true || response['success'] == true;
    } catch (e) {
      print('Error saving order pricing: $e');
      rethrow;
    }
  }
}
