import 'package:flutter/foundation.dart';
import 'async_session_notifier.dart';
import '../models/order.dart';
import '../order_status_mapper.dart';
import '../repositories/order_repository.dart';
import '../utils/smart_product_search.dart';

enum OrderSortOption { newest, oldest, valueHighToLow, valueLowToHigh }

/// Provider for the full, permission-scoped order list and local view filters.
class OrdersProvider extends ChangeNotifier with AsyncSessionNotifier {
  static const Duration minimumManualRefreshInterval = Duration(seconds: 15);

  final OrderRepository _orderRepository;
  List<Order> _orders = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _currentFilter = 'all';
  String _searchQuery = '';
  OrderSortOption _sortOption = OrderSortOption.newest;
  DateTime? _lastFetchTime;
  DateTime? _fromDate;
  DateTime? _toDate;
  Future<void>? _fetchRequest;
  int _mutationVersion = 0;
  bool _lastRefreshThrottled = false;

  OrdersProvider(this._orderRepository);

  List<Order> get orders => _filteredOrders;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get currentFilter => _currentFilter;
  String get searchQuery => _searchQuery;
  OrderSortOption get sortOption => _sortOption;
  DateTime? get fromDate => _fromDate;
  DateTime? get toDate => _toDate;
  bool get lastRefreshThrottled => _lastRefreshThrottled;
  bool get canRefresh =>
      _lastFetchTime == null ||
      DateTime.now().difference(_lastFetchTime!) >=
          minimumManualRefreshInterval;

  List<Order> get _filteredOrders {
    var filtered = _orders;
    if (_currentFilter != 'all') {
      filtered = filtered
          .where((order) =>
              OrderStatusMapper.normalizeStatus(order.status) == _currentFilter)
          .toList();
    }
    if (_fromDate != null) {
      final start = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
      filtered = filtered.where((order) {
        final date = order.createdAt;
        return date != null && !date.isBefore(start);
      }).toList();
    }
    if (_toDate != null) {
      final end = DateTime(
        _toDate!.year,
        _toDate!.month,
        _toDate!.day,
        23,
        59,
        59,
        999,
      );
      filtered = filtered.where((order) {
        final date = order.createdAt;
        return date != null && !date.isAfter(end);
      }).toList();
    }

    final query = SmartProductSearchIndex.normalize(_searchQuery);
    if (query.isNotEmpty) {
      filtered = filtered.where((order) {
        return [
          order.orderNumber,
          order.orderId,
          order.customerName,
          order.accountingInvoiceNo ?? '',
        ].any((value) =>
            SmartProductSearchIndex.normalize(value).contains(query));
      }).toList();
    }

    filtered.sort((a, b) {
      int result;
      switch (_sortOption) {
        case OrderSortOption.oldest:
          result = (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
          break;
        case OrderSortOption.valueHighToLow:
          result = (b.totalAmount ?? 0).compareTo(a.totalAmount ?? 0);
          break;
        case OrderSortOption.valueLowToHigh:
          result = (a.totalAmount ?? 0).compareTo(b.totalAmount ?? 0);
          break;
        case OrderSortOption.newest:
          result = (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
              .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
          break;
      }
      return result == 0 ? a.orderId.compareTo(b.orderId) : result;
    });
    return filtered;
  }

  /// Same-resource refreshes share one request. The cooldown begins only when
  /// a manual refresh is accepted, not when it is rejected.
  Future<void> fetchOrders({
    String? status,
    bool forceRefresh = false,
    bool bypassMinimumInterval = false,
  }) {
    final activeRequest = _fetchRequest;
    if (activeRequest != null) return activeRequest;

    if (forceRefresh && !bypassMinimumInterval && !canRefresh) {
      _lastRefreshThrottled = true;
      notifyListeners();
      return Future<void>.value();
    }

    if (forceRefresh && !bypassMinimumInterval) {
      _lastFetchTime = DateTime.now();
    }
    if (forceRefresh) {
      _lastRefreshThrottled = false;
    }
    final mutationVersionAtStart = _mutationVersion;
    final request = _performFetch(
      status: status,
      forceRefresh: forceRefresh,
      mutationVersionAtStart: mutationVersionAtStart,
    );
    _fetchRequest = request;
    return request.whenComplete(() {
      if (identical(_fetchRequest, request)) _fetchRequest = null;
    });
  }

  Future<void> _performFetch({
    required String? status,
    required bool forceRefresh,
    required int mutationVersionAtStart,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final fetched = await _orderRepository.getOrders(
        status: status,
        forceRefresh: forceRefresh,
      );
      if (mutationVersionAtStart == _mutationVersion) {
        _orders = fetched;
        _errorMessage = _orderRepository.lastFetchError;
      }
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(String filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSortOption(OrderSortOption option) {
    _sortOption = option;
    notifyListeners();
  }

  void setDateRange({DateTime? from, DateTime? to}) {
    _fromDate = from;
    _toDate = to;
    notifyListeners();
  }

  void resetFilters() {
    _currentFilter = 'all';
    _searchQuery = '';
    _sortOption = OrderSortOption.newest;
    _fromDate = null;
    _toDate = null;
    notifyListeners();
  }

  void addOrder(Order order) {
    _orders.insert(0, order);
    _mutationVersion++;
    notifyListeners();
  }

  void updateOrder(Order updatedOrder) {
    final index = _orders.indexWhere((order) =>
        order.orderId == updatedOrder.orderId ||
        order.orderNumber == updatedOrder.orderNumber);
    if (index != -1) {
      _orders[index] = updatedOrder;
      _mutationVersion++;
      notifyListeners();
    }
  }

  void removeOrder(String orderId) {
    _orders.removeWhere((order) => order.orderId == orderId);
    _mutationVersion++;
    notifyListeners();
  }

  Future<bool> cancelOrder(String orderId, {String? reason}) async {
    await _orderRepository.cancelOrder(orderId, reason: reason);
    final index = _orders.indexWhere((order) => order.orderId == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(
        status: 'cancelled',
        updatedAt: DateTime.now(),
      );
      _mutationVersion++;
      notifyListeners();
    }
    return true;
  }

  Future<void> syncAfterMutation({
    String? orderId,
    String? status,
  }) async {
    if (orderId != null && status != null) {
      updateOrderStatusLocally(orderId, status);
    } else {
      _mutationVersion++;
    }
    final activeRequest = _fetchRequest;
    if (activeRequest != null) await activeRequest;
    await fetchOrders(
      forceRefresh: true,
      bypassMinimumInterval: true,
    );
  }

  void updateOrderStatusLocally(String orderId, String status) {
    _mutationVersion++;
    final index = _orders.indexWhere((order) => order.orderId == orderId);
    if (index == -1) return;
    _orders[index] = _orders[index].copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<String> createOrder(Order order, {String? customerId}) =>
      _orderRepository.createOrder(order, customerId: customerId);
}
