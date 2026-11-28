import 'dart:async';
import '../models/product.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import 'local_repository.dart';

/// مستودع المنتجات
/// مسؤول عن جلب البيانات وتحويلها إلى نماذج قوية
class ProductRepository {
  final ApiService _apiService = ApiService();
  final LocalRepository _localRepo;

  ProductRepository(AppDatabase db) : _localRepo = LocalRepository(db);

  bool get _requiresFreshPrices {
    final user = _apiService.currentUser ?? const <String, dynamic>{};
    final role = user['role']?.toString().trim().toLowerCase();
    final permission = user['can_view_wholesale_price'] == true ||
        user['can_view_wholesale_price'] == 1 ||
        user['can_view_wholesale_price'] == '1' ||
        user['can_view_wholesale_price'] == 'true';
    return role == 'admin' || role == 'accountant' || permission;
  }

  /// جلب قائمة المنتجات
  Future<List<Product>> getProducts({bool forceRefresh = false}) async {
    final requestToken = _apiService.token;
    try {
      if (!forceRefresh && !_requiresFreshPrices) {
        final localData = await _localRepo.getProducts();
        if (localData.isNotEmpty) return _visibleProducts(localData);
      }

      final response =
          await _apiService.products.getProducts(forceRefresh: forceRefresh);
      if (_apiService.token != requestToken) {
        throw StateError('تغير الحساب أثناء تحميل المنتجات');
      }
      final items = response['products'] ?? response['data'] ?? [];
      if (items is! List) {
        throw const ApiException(
          code: 'INVALID_RESPONSE',
          message: 'استجابة المنتجات لا تحتوي على قائمة صالحة',
        );
      }

      final products = items.map((item) => Product.fromJson(item)).toList();
      await _localRepo.saveProducts(products);
      await _localRepo.updateLastSync('products');

      return _visibleProducts(products);
    } catch (e) {
      print('Error fetching products: $e');
      if (_apiService.token != requestToken) rethrow;
      if (forceRefresh) rethrow;
      final cachedProducts = await _localRepo.getProducts();
      if (cachedProducts.isNotEmpty) {
        return _requiresFreshPrices
            ? cachedProducts
                .map((product) => product.withoutRestrictedPricing())
                .toList()
            : _visibleProducts(cachedProducts);
      }
      rethrow;
    }
  }

  List<Product> _visibleProducts(List<Product> products) {
    if (_requiresFreshPrices) return products;
    return products.map((product) => product.withoutRestrictedPricing()).toList();
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

      return products
          .where((p) =>
              p.name.toLowerCase().contains(lowerQuery) ||
              p.code.toLowerCase().contains(lowerQuery) ||
              p.oem.toLowerCase().contains(lowerQuery) ||
              p.group.toLowerCase().contains(lowerQuery) ||
              p.subGroup.toLowerCase().contains(lowerQuery) ||
              p.origin.toLowerCase().contains(lowerQuery))
          .toList();
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
