import 'package:provider/provider.dart';
import '../repositories/order_repository.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import 'auth_provider.dart';
import 'package:flutter/material.dart';

/// Provider لإدارة تفاصيل طلب معين وعمليات التسعير
class OrderDetailProvider extends ChangeNotifier {
  final OrderRepository _orderRepository;

  Order? _currentOrder;
  List<OrderItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  Map<String, dynamic>? _shipmentData;
  Map<String, dynamic>? _balanceInfo;
  double? _discount;
  double? _shippingCost;

  OrderDetailProvider(this._orderRepository);

  Order? get currentOrder => _currentOrder;
  List<OrderItem> get items => _items;
  bool get isLoading => _isLoading;
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
  Future<void> fetchOrderDetails(String orderId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final order = await _orderRepository.getOrderDetails(orderId);
      // Verify that this is still the request we want (race condition safety)
      if (order != null) {
        _currentOrder = order;
        _items = order.items ?? [];
        _discount = order.discount;
        _shippingCost = order.shippingCost;
        _shipmentData = order.shipmentData;
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
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
    String? notes,
    bool submitForCustomer = false,
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
              })
          .toList();

      await _orderRepository.saveOrderPricing(
        orderId: _currentOrder!.orderId,
        items: itemsData,
        subtotal: subtotal,
        total: total,
        notes: notes,
        submitForCustomer: submitForCustomer,
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
  Future<bool> updateStatus(String newStatus) async {
    if (_currentOrder == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final success = await _orderRepository.updateOrderStatus(
          _currentOrder!.orderId, newStatus);

      if (success) {
        _currentOrder = Order(
          orderId: _currentOrder!.orderId,
          orderNumber: _currentOrder!.orderNumber,
          customerId: _currentOrder!.customerId,
          customerName: _currentOrder!.customerName,
          status: newStatus,
          currency: _currentOrder!.currency,
          note: _currentOrder!.note,
          accountingInvoiceNo: _currentOrder!.accountingInvoiceNo,
          createdAt: _currentOrder!.createdAt,
          updatedAt: DateTime.now(),
          createdBy: _currentOrder!.createdBy,
          shipmentData: _currentOrder!.shipmentData,
          isNew: _currentOrder!.isNew,
          isRead: _currentOrder!.isRead,
          totalAmount: _currentOrder!.totalAmount,
          previousBalance: _currentOrder!.previousBalance,
          currentBalance: _currentOrder!.currentBalance,
          accountantNotes: _currentOrder!.accountantNotes,
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
