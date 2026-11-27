import 'package:provider/provider.dart';
import '../repositories/order_repository.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../services/api_service.dart';
import 'auth_provider.dart';
import 'async_session_notifier.dart';
import 'package:flutter/material.dart';
import '../utils/order_discount.dart';

/// Provider لإدارة تفاصيل طلب معين وعمليات التسعير
class OrderDetailProvider extends ChangeNotifier with AsyncSessionNotifier {
  final OrderRepository _orderRepository;

  Order? _currentOrder;
  List<OrderItem> _items = [];
  bool _isLoading = false;
  bool _isStale = false;
  String? _errorMessage;
  Map<String, dynamic>? _shipmentData;
  Map<String, dynamic>? _balanceInfo;
  double? _discount;
  double? _shippingCost;
  Future<void>? _fetchRequest;
  String? _fetchingOrderId;
  int _fetchGeneration = 0;

  OrderDetailProvider(this._orderRepository);

  Order? get currentOrder => _currentOrder;
  List<OrderItem> get items => _items;
  bool get isLoading => _isLoading;
  bool get isStale => _isStale;
  String? get errorMessage => _errorMessage;
  Map<String, dynamic>? get shipmentData => _shipmentData;
  Map<String, dynamic>? get balanceInfo => _balanceInfo;
  double? get discount => _discount;
  double? get shippingCost => _shippingCost;

  double get subtotal {
    return _items.fold(0, (sum, item) => sum + item.total);
  }

  double get total {
    return subtotal - (discount ?? 0) + (shippingCost ?? 0);
  }

  /// جلب تفاصيل طلب معين
  Future<void> fetchOrderDetails(String orderId) {
    if (_fetchRequest != null && _fetchingOrderId == orderId) {
      return _fetchRequest!;
    }

    final generation = ++_fetchGeneration;
    _fetchingOrderId = orderId;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    final request = _performFetchOrderDetails(orderId, generation);
    _fetchRequest = request;
    return request.whenComplete(() {
      if (identical(_fetchRequest, request)) {
        _fetchRequest = null;
        _fetchingOrderId = null;
      }
    });
  }

  Future<void> _performFetchOrderDetails(String orderId, int generation) async {
    try {
      try {
        final cached = await _orderRepository.getCachedOrderDetails(orderId);
        if (generation != _fetchGeneration) return;
        if (cached != null) {
          _currentOrder = cached;
          _items = cached.items ?? [];
          _discount = cached.discount;
          _shippingCost = cached.shippingCost;
          _shipmentData = cached.shipmentData;
          _isStale = true;
          notifyListeners();
        }
      } catch (error) {
        debugPrint('Order detail cache read failed: ${error.runtimeType}');
      }
      final order = await _orderRepository.getOrderDetails(orderId);
      if (generation != _fetchGeneration) return;
      if (order != null) {
        _currentOrder = order;
        _items = order.items ?? [];
        _discount = order.discount;
        _shippingCost = order.shippingCost;
        _shipmentData = order.shipmentData;
        _isStale = _orderRepository.lastDetailFromCache;
        _errorMessage = _orderRepository.detailCacheError;
      }
    } catch (e) {
      if (generation == _fetchGeneration) {
        _errorMessage = e.toString();
        if (e is! ApiException || !e.transportFailure) {
          _currentOrder = null;
          _items = [];
        }
      }
    } finally {
      if (generation == _fetchGeneration) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> cancelOrder({String? reason}) async {
    final order = _currentOrder;
    if (order == null || _isLoading) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _orderRepository.cancelOrder(order.orderId, reason: reason);
      ++_fetchGeneration;
      _currentOrder = order.copyWith(
        status: 'cancelled',
        updatedAt: DateTime.now(),
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// تحديث سعر صنف
  void updateItemPrice(String itemId, double newPrice) {
    final index = _items.indexWhere((item) => item.itemId == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(finalPrice: newPrice);
      notifyListeners();
    }
  }

  /// تحديث كمية صنف
  void updateItemQuantity(String itemId, double newQuantity) {
    final index = _items.indexWhere((item) => item.itemId == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(quantityApproved: newQuantity);
      notifyListeners();
    }
  }

  /// تحديث حالة بند (متوفر/غير متوفر)
  void updateItemStatus(String itemId, String status) {
    final index = _items.indexWhere((item) => item.itemId == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(status: status);
      notifyListeners();
    }
  }

  /// إضافة صنف جديد
  void addItem(OrderItem item) {
    _items.add(item);
    notifyListeners();
  }

  /// تحديث قائمة الأصناف بالكامل
  void setItems(List<OrderItem> newItems) {
    _items = List.from(newItems);
    notifyListeners();
  }

  /// حذف صنف
  void removeItem(String itemId) {
    _items.removeWhere((item) => item.itemId == itemId);
    notifyListeners();
  }

  /// تحديث الخصم
  void setDiscount(double value) {
    _discount = value;
    notifyListeners();
  }

  /// تحديث تكلفة الشحن
  void setShippingCost(double value) {
    _shippingCost = value;
    notifyListeners();
  }

  /// حفظ تسعير الطلب
  Future<bool> savePricing({
    required BuildContext context,
    double? subtotal,
    double? total,
    String? discountInput,
    String? discountReason,
    String? notes,
    bool submitForCustomer = false,
    bool confirmOfferPriceOverride = false,
  }) async {
    if (_currentOrder == null) return false;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    // currentUser check slightly more relaxed to avoid false negatives if AuthProvider state is out of sync but user is logged in
    if (currentUser == null || currentUser.id.isEmpty) {
      // Try to get user from repository if not in provider (extra robustness)
      if (currentUser == null) {
        _errorMessage = 'انتهت جلسة الدخول، يرجى تسجيل الدخول مرة أخرى';
        notifyListeners();
        return false;
      }
    }

    _isLoading = true;
    notifyListeners();

    try {
      final calculatedDiscount = calculateOrderDiscount(
        input: discountInput ??
            _currentOrder!.discountInput ??
            (_currentOrder!.discount?.toString() ?? ''),
        subtotal: subtotal ?? _items.fold(0, (sum, item) => sum + item.total),
      );
      // تجهيز البيانات بالتنسيق الذي يتوقعه Backend
      final itemsData = _items
          .map((item) => {
                'code': item.code,
                'quantity_approved':
                    item.quantityApproved ?? item.quantityRequested ?? 0,
                'final_price': item.finalPrice ??
                    item.priceOffer ??
                    item.defaultPrice ??
                    0,
                'status':
                    item.status == 'unavailable' ? 'unavailable' : 'available',
                'accountant_note': item.accountantNote ?? '',
                'unit': item.unit,
                'unit_factor': item.unitFactor,
                'base_price_snapshot': item.basePriceSnapshot,
                'unit_1': item.unit1,
                'unit_2': item.unit2,
                'factor_2': item.factor2,
                'unit_3': item.unit3,
                'factor_3': item.factor3,
              })
          .toList();

      await _orderRepository.saveOrderPricing(
        orderId: _currentOrder!.orderId,
        items: itemsData,
        subtotal: subtotal,
        total: total,
        discountInput: calculatedDiscount.input,
        discountReason: discountReason,
        notes: notes,
        submitForCustomer: submitForCustomer,
        extraParams: confirmOfferPriceOverride
            ? {'confirm_offer_price_override': true}
            : null,
      );

      _discount = calculatedDiscount.amount;
      _currentOrder = _currentOrder!.copyWith(
        discount: calculatedDiscount.amount,
        discountType: calculatedDiscount.type,
        discountInput: calculatedDiscount.input,
        discountReason: discountReason,
        totalAmount: calculatedDiscount.netTotal,
        items: _items,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// تحديث حالة الطلب
  Future<bool> updateStatus(String newStatus,
      {String? reason, bool proxyForCustomer = false}) async {
    if (_currentOrder == null || _isLoading) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _orderRepository.updateOrderStatus(
        _currentOrder!.orderId,
        newStatus,
        reason: reason,
        proxyForCustomer: proxyForCustomer,
      );

      if (success) {
        _currentOrder = _currentOrder!.copyWith(
          status: newStatus,
          updatedAt: DateTime.now(),
          items: _items,
        );
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> confirmWarehousePrep({
    required List<Map<String, dynamic>> items,
    required String warehouseNote,
  }) async {
    if (_currentOrder == null) return false;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final orderId = _currentOrder!.orderId;
      final success = await _orderRepository.confirmWarehousePrep(
        orderId: orderId,
        items: items,
        warehouseNote: warehouseNote,
      );
      if (success) {
        await fetchOrderDetails(orderId);
      } else {
        _errorMessage = 'فشل حفظ بيانات تجهيز الطلب';
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// تعيين بيانات الشحن
  void setShipmentData(Map<String, dynamic> data) {
    _shipmentData = data;
    notifyListeners();
  }

  /// تعيين معلومات الرصيد
  void setBalanceInfo(Map<String, dynamic> data) {
    _balanceInfo = data;
    notifyListeners();
  }

  /// إعادة تعيين البيانات
  void reset() {
    _currentOrder = null;
    _items = [];
    _discount = null;
    _shippingCost = null;
    _shipmentData = null;
    _balanceInfo = null;
    _errorMessage = null;
    notifyListeners();
  }
}
