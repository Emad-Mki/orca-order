import 'dart:async';
import '../models/product.dart';
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
      final response = await _apiService.getOrders(
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
      final response = await _apiService.getOrderDetails(orderId);
      
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
      final response = await _apiService.createOrder(order.toJson());
      
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
      final response = await _apiService.updateOrderStatus(orderId, status);
      return response['ok'] == true || response['success'] == true;
    } catch (e) {
      print('Error updating order status: $e');
      rethrow;
    }
  }

  /// حفظ تسعير الطلب
  Future<bool> saveOrderPricing(String orderId, List<Map<String, dynamic>> items) async {
    try {
      final response = await _apiService.saveOrderPricing(orderId, items);
      return response['ok'] == true || response['success'] == true;
    } catch (e) {
      print('Error saving order pricing: $e');
      rethrow;
    }
  }
}

/// مستودع المنتجات
class ProductRepository {
  final ApiService _apiService = ApiService();

  /// جلب قائمة المنتجات
  Future<List<Product>> getProducts({bool forceRefresh = false}) async {
    try {
      final response = await _apiService.getProducts(forceRefresh: forceRefresh);
      
      final items = response['products'] ?? response['data'] ?? [];
      if (items is! List) return [];

      return items.map((item) => Product.fromJson(item)).toList();
    } catch (e) {
      print('Error fetching products: $e');
      rethrow;
    }
  }

  /// البحث عن منتج
  Future<List<Product>> searchProducts(String query) async {
    try {
      final products = await getProducts();
      final lowerQuery = query.toLowerCase();
      
      return products.where((p) => 
        p.name.toLowerCase().contains(lowerQuery) ||
        p.code.toLowerCase().contains(lowerQuery) ||
        p.category.toLowerCase().contains(lowerQuery)
      ).toList();
    } catch (e) {
      print('Error searching products: $e');
      return [];
    }
  }

  /// التحقق من حالة الكاش
  Future<DateTime?> getLastCacheTimestamp() async {
    return _apiService.getLastCacheTimestamp();
  }

  /// التحقق من وجود اتصال
  Future<bool> isOnline() async {
    return _apiService.isOnline();
  }
}

/// مستودع العملاء
class CustomerRepository {
  final ApiService _apiService = ApiService();

  /// جلب قائمة العملاء
  Future<List<Map<String, dynamic>>> getCustomers() async {
    try {
      final response = await _apiService.getCustomers();
      return List<Map<String, dynamic>>.from(response['customers'] ?? response['data'] ?? []);
    } catch (e) {
      print('Error fetching customers: $e');
      rethrow;
    }
  }

  /// جلب كشف حساب العميل
  Future<BalanceInfo?> getCustomerStatement(String customerId) async {
    try {
      final response = await _apiService.getCustomerStatement(customerId);
      
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
}
