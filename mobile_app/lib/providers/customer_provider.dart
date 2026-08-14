import 'package:flutter/foundation.dart';
import '../repositories/customer_repository.dart';
import '../models/customer.dart';

/// Provider لإدارة بيانات العملاء والأرصدة
class CustomerProvider extends ChangeNotifier {
  final CustomerRepository _customerRepository;
  
  List<Customer> _customers = [];
  Customer? _selectedCustomer;
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  CustomerProvider(this._customerRepository);

  List<Customer> get customers => _filteredCustomers;
  Customer? get selectedCustomer => _selectedCustomer;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;

  /// الحصول على القائمة بعد تطبيق البحث
  List<Customer> get _filteredCustomers {
    if (_searchQuery.isEmpty) {
      return _customers;
    }
    
    final query = _searchQuery.toLowerCase();
    return _customers.where((c) {
      final name = c.name?.toLowerCase() ?? '';
      final phone = c.phone?.toLowerCase() ?? '';
      final company = c.company?.toLowerCase() ?? '';
      return name.contains(query) || phone.contains(query) || company.contains(query);
    }).toList();
  }

  /// جلب جميع العملاء
  Future<void> fetchCustomers() async {
    _isLoading = true;
    notifyListeners();

    try {
      _customers = await _customerRepository.getCustomers();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// جلب تفاصيل عميل معين
  Future<void> fetchCustomerById(String customerId) async {
    _isLoading = true;
    notifyListeners();

    try {
      _selectedCustomer = await _customerRepository.getCustomerById(customerId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  /// تحديث نص البحث
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// تحديد عميل
  void selectCustomer(Customer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  /// تحديث رصيد العميل
  Future<bool> updateCustomerBalance(String customerId, double newBalance) async {
    _isLoading = true;
    notifyListeners();

    try {
      final customer = await _customerRepository.updateCustomerBalance(customerId, newBalance);
      final index = _customers.indexWhere((c) => c.id == customerId);
      if (index != -1) {
        _customers[index] = customer;
      }
      if (_selectedCustomer?.id == customerId) {
        _selectedCustomer = customer;
      }
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

  /// تسجيل دفعة جديدة
  Future<bool> recordPayment(String customerId, double amount, {String? notes}) async {
    _isLoading = true;
    notifyListeners();

    try {
      await _customerRepository.recordPayment(customerId, amount, notes: notes);
      // إعادة تحميل بيانات العميل
      await fetchCustomerById(customerId);
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

  /// إضافة عميل جديد
  void addCustomer(Customer customer) {
    _customers.add(customer);
    notifyListeners();
  }

  /// تحديث عميل
  void updateCustomer(Customer updatedCustomer) {
    final index = _customers.indexWhere((c) => c.id == updatedCustomer.id);
    if (index != -1) {
      _customers[index] = updatedCustomer;
      if (_selectedCustomer?.id == updatedCustomer.id) {
        _selectedCustomer = updatedCustomer;
      }
      notifyListeners();
    }
  }
}
