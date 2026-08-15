import 'package:flutter/foundation.dart';
import '../repositories/order_repository.dart';
import '../models/order.dart';

/// Provider لإدارة قائمة الطلبات والفلترة
class OrdersProvider extends ChangeNotifier {
  final OrderRepository _orderRepository;
  
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentFilter = 'all';
  String _searchQuery = '';

  OrdersProvider(this._orderRepository);

  List<Order> get orders => _filteredOrders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentFilter => _currentFilter;
  String get searchQuery => _searchQuery;

  /// الحصول على القائمة بعد تطبيق الفلتر والبحث
  List<Order> get _filteredOrders {
    var filtered = _orders;

    // تطبيق الفلتر حسب الحالة
    if (_currentFilter != 'all') {
      filtered = filtered.where((order) => order.status == _currentFilter).toList();
    }

    // تطبيق البحث
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((order) {
        final orderId = order.orderNumber?.toLowerCase() ?? '';
        final customerName = order.customerName?.toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return orderId.contains(query) || customerName.contains(query);
      }).toList();
    }

    return filtered;
  }

  /// جلب جميع الطلبات
  Future<void> fetchOrders({String? status}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _orders = await _orderRepository.getOrders(status: status);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// تحديث فلتر الحالات
  void setFilter(String filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  /// تحديث نص البحث
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// إعادة تعيين الفلاتر
  void resetFilters() {
    _currentFilter = 'all';
    _searchQuery = '';
    notifyListeners();
  }

  /// إضافة طلب جديد للقائمة
  void addOrder(Order order) {
    _orders.insert(0, order);
    notifyListeners();
  }

  /// تحديث طلب موجود
  void updateOrder(Order updatedOrder) {
    final index = _orders.indexWhere((o) => o.orderId == updatedOrder.orderId);
    if (index != -1) {
      _orders[index] = updatedOrder;
      notifyListeners();
    }
  }

  /// حذف طلب
  void removeOrder(String orderId) {
    _orders.removeWhere((o) => o.orderId == orderId);
    notifyListeners();
  }
}
