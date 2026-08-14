import 'dart:async';
import '../models/product.dart';
import '../services/api_service.dart';

/// مستودع المنتجات
/// مسؤول عن جلب البيانات وتحويلها إلى نماذج قوية
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
