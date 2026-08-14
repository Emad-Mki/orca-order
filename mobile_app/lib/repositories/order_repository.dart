import 'dart:async';
import '../models/order.dart';
import '../models/balance_info.dart';
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

/// مستودع العملاء
/// مسؤول عن جلب بيانات العملاء وكشف الحساب
class CustomerRepository {
  final ApiService _apiService = ApiService();

  /// جلب قائمة العملاء
  Future<List<Map<String, dynamic>>> getCustomers() async {
    try {
      // استخدام الخدمة المنفصلة للعملاء
      final response = await _apiService.customers.getCustomers();
      return List<Map<String, dynamic>>.from(response['customers'] ?? response['data'] ?? []);
    } catch (e) {
      print('Error fetching customers: $e');
      rethrow;
    }
  }

  /// جلب كشف حساب العميل
  Future<BalanceInfo?> getCustomerStatement(String customerId) async {
    try {
      // استخدام الخدمة المنفصلة للعملاء
      final response = await _apiService.customers.getCustomerStatement(customerId);
      
      if (response['ok'] != true && response['success'] != true) {
        throw Exception(response['error'] ?? 'فشل جلب كشف الحساب');
      }

      final data = response['statement'] ?? response['data'] ?? {};
      return BalanceInfo.fromJson(data);
    } catch (e) {
      print('Error fetching customer statement: $e');
      rethrow;
    }
  }

  /// إضافة عميل جديد
  Future<Map<String, dynamic>> addCustomer(Map<String, dynamic> customerData) async {
    try {
      // استخدام الخدمة المنفصلة للعملاء
      final response = await _apiService.customers.addCustomer(customerData);
      
      if (response['ok'] != true && response['success'] != true) {
        throw Exception(response['error'] ?? 'فشل إضافة العميل');
      }

      return response;
    } catch (e) {
      print('Error adding customer: $e');
      rethrow;
    }
  }

  /// تحديث بيانات عميل
  Future<Map<String, dynamic>> updateCustomer(String customerId, Map<String, dynamic> customerData) async {
    try {
      // استخدام الخدمة المنفصلة للعملاء
      final response = await _apiService.customers.updateCustomer(customerId, customerData);
      
      if (response['ok'] != true && response['success'] != true) {
        throw Exception(response['error'] ?? 'فشل تحديث بيانات العميل');
      }

      return response;
    } catch (e) {
      print('Error updating customer: $e');
      rethrow;
    }
  }
}
