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
      // استخدام الخدمة المنفصلة للمنتجات
      final response = await _apiService.products.getProducts(forceRefresh: forceRefresh);

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
      // استخدام الخدمة المنفصلة للمنتجات
      final response = await _apiService.products.searchProducts(query);

      final items = response['products'] ?? response['data'] ?? [];
      if (items is! List) return [];

      return items.map((item) => Product.fromJson(item)).toList();
    } catch (e) {
      print('Error searching products: $e');
      // Fallback to local search
      return _searchLocalProducts(query);
    }
  }

  /// البحث المحلي في المنتجات المحملة مسبقاً
  Future<List<Product>> _searchLocalProducts(String query) async {
    try {
      final products = await getProducts();
      final lowerQuery = query.toLowerCase();

      return products.where((p) =>
        p.name.toLowerCase().contains(lowerQuery) ||
        p.code.toLowerCase().contains(lowerQuery) ||
        p.category.toLowerCase().contains(lowerQuery)
      ).toList();
    } catch (e) {
      print('Error in local search: $e');
      return [];
    }
  }

  /// جلب تصنيفات المنتجات
  Future<List<String>> getProductCategories() async {
    try {
      // استخدام الخدمة المنفصلة للمنتجات
      final response = await _apiService.products.getProductCategories();

      final categories = response['categories'] ?? response['data'] ?? [];
      if (categories is! List) return [];

      return categories.map((c) => c.toString()).toList();
    } catch (e) {
      print('Error fetching product categories: $e');
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
