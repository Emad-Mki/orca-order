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
  double? _discount;
  double? _shippingCost;

  OrderDetailProvider(this._orderRepository);

  Order? get currentOrder => _currentOrder;
  List<OrderItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double? get discount => _discount;
  double? get shippingCost => _shippingCost;
  
  double get subtotal {
    return _items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }
  
  double get total {
    return subtotal - (discount ?? 0) + (shippingCost ?? 0);
  }

  /// جلب تفاصيل طلب معين
  Future<void> fetchOrderDetails(String orderId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentOrder = await _orderRepository.getOrderById(orderId);
      if (_currentOrder != null) {
        _items = _currentOrder!.items ?? [];
        _discount = _currentOrder?.discount;
        _shippingCost = _currentOrder?.shippingCost;
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
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(price: newPrice);
      notifyListeners();
    }
  }

  /// تحديث كمية صنف
  void updateItemQuantity(String itemId, double newQuantity) {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(quantity: newQuantity);
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
    _items.removeWhere((item) => item.id == itemId);
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

  /// حفظ التسعير
  Future<bool> savePricing() async {
    if (_currentOrder == null) return false;
    
    _isLoading = true;
    notifyListeners();

    try {
      final updatedOrder = _currentOrder!.copyWith(
        items: _items,
        discount: _discount,
        shippingCost: _shippingCost,
        status: 'priced',
      );
      
      await _orderRepository.updateOrder(updatedOrder);
      _currentOrder = updatedOrder;
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

  /// إعادة تعيين البيانات
  void reset() {
    _currentOrder = null;
    _items = [];
    _discount = null;
    _shippingCost = null;
    _errorMessage = null;
    notifyListeners();
  }
}
