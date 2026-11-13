import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/product_repository.dart';
import '../models/product.dart';
import '../services/api_service.dart';

enum ProductViewMode { grid, list }

enum ProductSortOption { name, priceLowHigh, priceHighLow, newest }

/// Provider لإدارة كتالوج المنتجات والبحث والفرز ووضع العرض
class ProductsProvider extends ChangeNotifier {
  static const Duration minimumManualRefreshInterval =
      ApiService.minimumManualRefreshInterval;

  final ProductRepository _productRepository;
  static const String _viewModeKey = 'product_view_mode';

  List<Product> _products = [];
  List<Product> _filteredProducts = [];
  bool _isLoading = false;
  bool _isInitialLoading = true;
  String? _errorMessage;
  String _searchQuery = '';
  String? _selectedCategory;
  String? _selectedSubGroup;
  ProductViewMode _viewMode = ProductViewMode.grid;
  ProductSortOption _sortOption = ProductSortOption.name;
  
  Future<void>? _fetchRequest;
  DateTime? _lastManualRefresh;
  bool _lastRefreshThrottled = false;

  ProductsProvider(this._productRepository) {
    _loadSettings();
  }

  List<Product> get products => _filteredProducts;
  List<Product> get allProducts => _products;
  bool get isLoading => _isLoading;
  bool get isInitialLoading => _isInitialLoading && _isLoading && _products.isEmpty;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  String? get selectedSubGroup => _selectedSubGroup;
  ProductViewMode get viewMode => _viewMode;
  ProductSortOption get sortOption => _sortOption;
  bool get lastRefreshThrottled => _lastRefreshThrottled;

  Duration get manualRefreshRemaining {
    final lastRefresh = _lastManualRefresh;
    if (lastRefresh == null) return Duration.zero;
    final remaining =
        minimumManualRefreshInterval - DateTime.now().difference(lastRefresh);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_viewModeKey);
    if (savedMode == 'list') {
      _viewMode = ProductViewMode.list;
    } else {
      _viewMode = ProductViewMode.grid;
    }
    notifyListeners();
  }

  void setViewMode(ProductViewMode mode) async {
    if (_viewMode == mode) return;
    _viewMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_viewModeKey, mode == ProductViewMode.list ? 'list' : 'grid');
  }

  void setSortOption(ProductSortOption option) {
    _sortOption = option;
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// جلب المنتجات
  Future<void> fetchProducts({bool forceRefresh = false}) {
    _lastRefreshThrottled = false;
    final activeRequest = _fetchRequest;
    if (activeRequest != null) return activeRequest;

    if (forceRefresh && manualRefreshRemaining > Duration.zero) {
      _lastRefreshThrottled = true;
      notifyListeners();
      return Future<void>.value();
    }
    if (forceRefresh) _lastManualRefresh = DateTime.now();

    final request = _performFetch(forceRefresh: forceRefresh);
    _fetchRequest = request;
    return request.whenComplete(() {
      if (identical(_fetchRequest, request)) _fetchRequest = null;
    });
  }

  Future<void> _performFetch({required bool forceRefresh}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _products =
          await _productRepository.getProducts(forceRefresh: forceRefresh);
      _isInitialLoading = false;
      
      // التخلص من الفئات المحددة إذا لم تعد موجودة
      if (_selectedCategory != null &&
          !categories.any((category) =>
              _normalizeGroup(category).toLowerCase() ==
              _normalizeGroup(_selectedCategory!).toLowerCase())) {
        _selectedCategory = null;
        _selectedSubGroup = null;
      } else if (_selectedSubGroup != null &&
          !subGroups.any((subGroup) =>
              _normalizeGroup(subGroup).toLowerCase() ==
              _normalizeGroup(_selectedSubGroup!).toLowerCase())) {
        _selectedSubGroup = null;
      }
      
      _applyFiltersAndSort();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  List<String> get categories {
    final uniqueCategories = <String, String>{};
    for (final product in _products) {
      final category = _normalizeGroup(product.group);
      if (category.isNotEmpty) {
        uniqueCategories.putIfAbsent(category.toLowerCase(), () => category);
      }
    }
    return uniqueCategories.values.toList()..sort();
  }

  String _normalizeGroup(String group) =>
      group.trim().replaceAll(RegExp(r'\s+'), ' ');

  List<String> getSubGroupsForCategory(String categoryName) {
    final normalized = _normalizeGroup(categoryName).toLowerCase();
    final uniqueSubGroups = <String, String>{};
    for (final product in _products) {
      if (_normalizeGroup(product.group).toLowerCase() != normalized) continue;
      final subGroup = _normalizeGroup(product.subGroup);
      if (subGroup.isNotEmpty) {
        uniqueSubGroups.putIfAbsent(subGroup.toLowerCase(), () => subGroup);
      }
    }
    return uniqueSubGroups.values.toList()..sort();
  }

  List<String> get subGroups => _selectedCategory == null 
      ? [] : getSubGroupsForCategory(_selectedCategory!);

  void _applyFiltersAndSort() {
    var filtered = List<Product>.from(_products);

    // فلترة المجموعات
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      final cat = _normalizeGroup(_selectedCategory!).toLowerCase();
      filtered = filtered.where((p) => _normalizeGroup(p.group).toLowerCase() == cat).toList();
    }

    if (_selectedSubGroup != null && _selectedSubGroup!.isNotEmpty) {
      final sub = _normalizeGroup(_selectedSubGroup!).toLowerCase();
      filtered = filtered.where((p) => _normalizeGroup(p.subGroup).toLowerCase() == sub).toList();
    }

    // البحث
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(query) ||
               p.code.toLowerCase().contains(query) ||
               p.oem.toLowerCase().contains(query);
      }).toList();
    }

    // الفرز
    switch (_sortOption) {
      case ProductSortOption.name:
        filtered.sort((a, b) => a.name.compareTo(b.name));
        break;
      case ProductSortOption.priceLowHigh:
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case ProductSortOption.priceHighLow:
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case ProductSortOption.newest:
        filtered.sort((a, b) {
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          return b.createdAt!.compareTo(a.createdAt!);
        });
        break;
    }

    _filteredProducts = filtered;
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void setCategory(String? category) {
    _selectedCategory = (category == null || category.isEmpty) ? null : category;
    _selectedSubGroup = null;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void setSubGroup(String? subGroup) {
    _selectedSubGroup = (subGroup == null || subGroup.isEmpty) ? null : subGroup;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void resetFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _selectedSubGroup = null;
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// البحث عن منتج معين
  Product? getProductById(String productId) {
    try {
      final id = int.tryParse(productId);
      if (id == null) return null;
      return _products.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// إضافة منتج جديد
  void addProduct(Product product) {
    _products.add(product);
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// تحديث منتج
  void updateProduct(Product updatedProduct) {
    final index = _products.indexWhere((p) => p.id == updatedProduct.id);
    if (index != -1) {
      _products[index] = updatedProduct;
      _applyFiltersAndSort();
      notifyListeners();
    }
  }
}
