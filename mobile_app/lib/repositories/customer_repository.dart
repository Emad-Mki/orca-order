import 'dart:async';
import '../models/balance_info.dart';
import '../services/api_service.dart';

/// مستودع العملاء
/// مسؤول عن جلب بيانات العملاء وكشف الحساب
class CustomerRepository {
  final ApiService _apiService = ApiService();

  /// جلب قائمة العملاء
  Future<List<Map<String, dynamic>>> getCustomers() async {
    try {
      final response = await _apiService.getCustomers();
      return List<Map<String, dynamic>>.from(response['customers'] ?? response['data'] ?? []);
    } catch (e) {
      print('Error fetching customers: $e');
      rethrow;
    }
  }

  /// جلب كشف حساب العميل
  Future<BalanceInfo?> getCustomerStatement(String customerId) async {
    try {
      final response = await _apiService.getCustomerStatement(customerId);
      
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
}
