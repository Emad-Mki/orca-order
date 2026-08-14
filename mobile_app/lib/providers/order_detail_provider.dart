import 'package:flutter/foundation.dart';
import '../repositories/order_repository.dart';
import '../models/order.dart';
import '../models/order_item.dart';

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
    return _items.fold(0, (sum, item) => sum + (item.displayPrice * item.quantityRequested));
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
      if (order != null) {
        _currentOrder = order;
        _items = order.items ?? [];
        _discount = order.totalAmount > 0 ? null : null;
        _shippingCost = order.shippingCost;
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
      // ملاحظة: OrderItem غير قابل للتعديل، نحتاج لإنشاء نسخة جديدة
      // هذا يتطلب تعديل النموذج أو استخدام طريقة أخرى
      notifyListeners();
    }
  }

  /// تحديث كمية صنف
  void updateItemQuantity(String itemId, double newQuantity) {
    final index = _items.indexWhere((item) => item.itemId == itemId);
    if (index != -1) {
      notifyListeners();
    }
  }

  /// إضافة صنف جديد
  void addItem(OrderItem item) {
    _items.add(item);
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
  Future<bool> savePricing() async {
    if (_currentOrder == null) return false;
    
    _isLoading = true;
    notifyListeners();

    try {
      final itemsData = _items.map((item) => item.toJson()).toList();
      await _orderRepository.saveOrderPricing(_currentOrder!.orderId, itemsData.cast<Map<String, dynamic>>());
      
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
      final success = await _orderRepository.updateOrderStatus(_currentOrder!.orderId, newStatus);
      
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
          isNew: _currentOrder!.isNew,
          isRead: _currentOrder!.isRead,
          totalAmount: _currentOrder!.totalAmount,
          previousBalance: _currentOrder!.previousBalance,
          currentBalance: _currentOrder!.currentBalance,
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
