import '../models/models.dart';
import '../services/api_service.dart';

/// مستودع العملاء
/// مسؤول عن جلب بيانات العملاء وكشف الحساب
class CustomerRepository {
  final ApiService _apiService = ApiService();

  /// جلب قائمة العملاء
  Future<List<Customer>> getCustomers() async {
    try {
      final response = await _apiService.customers.getCustomers();
      final List data = response['customers'] ?? response['data'] ?? [];
      return data.map((item) => Customer.fromJson(item)).toList();
    } catch (e) {
      print('Error fetching customers: $e');
      rethrow;
    }
  }

  /// جلب عميل بواسطة المعرف
  Future<Customer?> getCustomerById(String customerId) async {
    // يمكن تنفيذها عبر جلب كل العملاء أو طلب خاص
    final customers = await getCustomers();
    try {
      return customers.firstWhere((c) => c.id == customerId);
    } catch (e) {
      return null;
    }
  }

  /// جلب كشف حساب العميل
  Future<BalanceInfo?> getCustomerStatement(String customerId) async {
    try {
      final response = await _apiService.customers.getCustomerStatement(customerId);
      
      if (response['ok'] != true && response['success'] != true) {
        throw Exception(response['error'] ?? 'فشل جلب كشف الحساب');
      }

      final data = response['statement'] ?? response['data'] ?? {};
      return BalanceInfo.fromJson(data);
    } catch (e) {
      print('Error fetching customer statement: $e');
      rethrow;
    }
  }

  /// تحديث رصيد العميل (تجريبي)
  Future<Customer> updateCustomerBalance(String customerId, double newBalance) async {
    final response = await _apiService.customers.updateCustomer(customerId, {'balance': newBalance});
    return Customer.fromJson(response['customer'] ?? response['data']);
  }

  /// تسجيل دفعة
  Future<void> recordPayment(String customerId, double amount, {String? notes}) async {
    await _apiService.post({
      'action': 'record_payment',
      'customer_id': customerId,
      'amount': amount,
      'notes': notes,
    });
  }
}
