import 'package:flutter/foundation.dart';
import 'async_session_notifier.dart';
import '../settings/setting_definitions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/product_repository.dart';
import '../models/product.dart';
import '../services/api_service.dart';

enum ProductViewMode { grid, list }

enum ProductSortOption { name, priceLowHigh, priceHighLow, newest }

/// Provider لإدارة كتالوج المنتجات والبحث والفرز ووضع العرض
class ProductsProvider extends ChangeNotifier with AsyncSessionNotifier {
  static const Duration minimumManualRefreshInterval =
      ApiService.minimumManualRefreshInterval;

  final ProductRepository _productRepository;
  static final String _viewModeKey = SettingDefinitions.productView.key;

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
  bool _hasChangedViewMode = false;

  Future<void>? _fetchRequest;
  DateTime? _lastManualRefresh;
  bool _lastRefreshThrottled = false;

  ProductsProvider(this._productRepository) {
    _loadSettings();
  }

  List<Product> get products => _filteredProducts;
  List<Product> get allProducts => _products;
  bool get isLoading => _isLoading;
  bool get isInitialLoading => _isInitialLoading && _products.isEmpty;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;
  String? get selectedSubGroup => _selectedSubGroup;
  ProductViewMode get viewMode => _viewMode;
  ProductSortOption get sortOption => _sortOption;
  bool get lastRefreshThrottled => _lastRefreshThrottled;

  Duration get manualRefreshRemaining {
    final lastFetch = _lastManualRefresh;
    if (lastFetch == null) return Duration.zero;
    final remaining =
        minimumManualRefreshInterval - DateTime.now().difference(lastFetch);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get hasValidCreationDates =>
      _products.any((product) => product.createdAt != null);

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_viewModeKey);
    if (!_hasChangedViewMode) {
      _viewMode =
          savedMode == 'list' ? ProductViewMode.list : ProductViewMode.grid;
    }
    notifyListeners();
  }

  Future<void> setViewMode(ProductViewMode mode) async {
    if (_viewMode == mode) return;
    final previousMode = _viewMode;
    _hasChangedViewMode = true;
    _viewMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = await prefs.setString(
        _viewModeKey,
        mode == ProductViewMode.list ? 'list' : 'grid',
      );
      if (!saved) throw StateError('تعذر حفظ طريقة عرض المنتجات');
    } catch (_) {
      _viewMode = previousMode;
      notifyListeners();
      rethrow;
    }
  }

  void setSortOption(ProductSortOption option) {
    _sortOption = option;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void selectCategory(String? category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    _selectedSubGroup = null;
    _applyFiltersAndSort();
    notifyListeners();
  }

  void selectSubGroup(String? subGroup) {
    if (_selectedSubGroup == subGroup) return;
    _selectedSubGroup = subGroup;
    _applyFiltersAndSort();
    notifyListeners();
  }

  /// جلب المنتجات مع حماية التحديث المتكرر
  Future<void> fetchProducts({bool forceRefresh = false}) async {
    // 1. منع الطلبات المتزامنة
    if (_fetchRequest != null) return _fetchRequest!;

    // 2. منع التحديث المتكرر (أقل من 15 ثانية)
    if (forceRefresh && manualRefreshRemaining > Duration.zero) {
      _lastRefreshThrottled = true;
      notifyListeners();
      return;
    }

    if (forceRefresh) {
      _lastManualRefresh = DateTime.now();
      _lastRefreshThrottled = false;
    } else {
      _lastRefreshThrottled = false;
    }

    final request = _performFetch(forceRefresh: forceRefresh);
    _fetchRequest = request;

    try {
      await request;
    } finally {
      _fetchRequest = null;
      notifyListeners();
    }
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
      ? []
      : getSubGroupsForCategory(_selectedCategory!);

  void _applyFiltersAndSort() {
    var filtered = List<Product>.from(_products);
    final sourceOrder = <Product, int>{
      for (var index = 0; index < _products.length; index++)
        _products[index]: index,
    };

    // فلترة المجموعات
    if (_selectedCategory != null && _selectedCategory!.isNotEmpty) {
      final cat = _normalizeGroup(_selectedCategory!).toLowerCase();
      filtered = filtered
          .where((p) => _normalizeGroup(p.group).toLowerCase() == cat)
          .toList();
    }

    if (_selectedSubGroup != null && _selectedSubGroup!.isNotEmpty) {
      final sub = _normalizeGroup(_selectedSubGroup!).toLowerCase();
      filtered = filtered
          .where((p) => _normalizeGroup(p.subGroup).toLowerCase() == sub)
          .toList();
    }

    // البحث
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(query) ||
            p.code.toLowerCase().contains(query) ||
            p.oem.toLowerCase().contains(query) ||
            p.group.toLowerCase().contains(query) ||
            p.subGroup.toLowerCase().contains(query) ||
            p.origin.toLowerCase().contains(query) ||
            (p.brand?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    // الفرز
    switch (_sortOption) {
      case ProductSortOption.name:
        filtered.sort((a, b) {
          final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          return byName != 0 ? byName : _stableProductOrder(a, b, sourceOrder);
        });
        break;
      case ProductSortOption.priceLowHigh:
        filtered.sort((a, b) {
          final byPrice = a.price.compareTo(b.price);
          return byPrice != 0
              ? byPrice
              : _stableProductOrder(a, b, sourceOrder);
        });
        break;
      case ProductSortOption.priceHighLow:
        filtered.sort((a, b) {
          final byPrice = b.price.compareTo(a.price);
          return byPrice != 0
              ? byPrice
              : _stableProductOrder(a, b, sourceOrder);
        });
        break;
      case ProductSortOption.newest:
        filtered.sort((a, b) {
          if (a.createdAt == null && b.createdAt == null) {
            return _stableProductOrder(a, b, sourceOrder);
          }
          if (a.createdAt == null) return 1;
          if (b.createdAt == null) return -1;
          final byDate = b.createdAt!.compareTo(a.createdAt!);
          return byDate != 0 ? byDate : _stableProductOrder(a, b, sourceOrder);
        });
        break;
    }

    _filteredProducts = filtered;
  }

  int _stableProductOrder(
    Product a,
    Product b,
    Map<Product, int> sourceOrder,
  ) {
    final byCode = a.code.toLowerCase().compareTo(b.code.toLowerCase());
    if (byCode != 0) return byCode;
    final byId = (a.id ?? 0).compareTo(b.id ?? 0);
    return byId != 0 ? byId : sourceOrder[a]!.compareTo(sourceOrder[b]!);
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
