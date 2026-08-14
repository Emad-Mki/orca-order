import 'package:flutter/foundation.dart';
import '../repositories/product_repository.dart';
import '../models/product.dart';

/// Provider لإدارة كتالوج المنتجات والبحث
class ProductsProvider extends ChangeNotifier {
  final ProductRepository _productRepository;
  
  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String? _selectedCategory;

  ProductsProvider(this._productRepository);

  List<Product> get products => _filteredProducts;
  List<Product> get allProducts => _products;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;

  /// جلب جميع المنتجات
  Future<void> fetchProducts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _products = await _productRepository.getProducts();
      _applyFilters();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// الحصول على التصنيفات الفريدة
  List<String> get categories {
    final categories = _products.map((p) => p.category).whereType<String>().toSet().toList();
    categories.sort();
    return categories;
  }

  /// تطبيق الفلاتر
  void _applyFilters() {
    var filtered = _products;

    // فلترة حسب التصنيف
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      filtered = filtered.where((p) => p.category == _selectedCategory).toList();
    }

    // فلترة حسب البحث
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((p) {
        final name = p.name?.toLowerCase() ?? '';
        final code = p.code?.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || code.contains(query);
      }).toList();
    }

    _filteredProducts = filtered;
  }

  /// تحديث نص البحث
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  /// تحديد تصنيف
  void setCategory(String? category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  /// إعادة تعيين الفلاتر
  void resetFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _applyFilters();
    notifyListeners();
  }

  /// البحث عن منتج معين
  Product? getProductById(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// إضافة منتج جديد
  void addProduct(Product product) {
    _products.add(product);
    _applyFilters();
    notifyListeners();
  }

  /// تحديث منتج
  void updateProduct(Product updatedProduct) {
    final index = _products.indexWhere((p) => p.id == updatedProduct.id);
    if (index != -1) {
      _products[index] = updatedProduct;
      _applyFilters();
      notifyListeners();
    }
  }
}
