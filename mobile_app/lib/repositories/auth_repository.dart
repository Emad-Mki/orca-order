import '../services/api_service.dart';
import '../models/user.dart';

class AuthRepository {
  final ApiService _apiService = ApiService();

  Future<User> login(String username, String password) async {
    try {
      final response = await _apiService.auth.login(username, password);
      final userData = response['user'] ?? response['data'];
      if (userData == null) {
        throw Exception('بيانات المستخدم غير موجودة في الرد');
      }
      return User.fromJson(userData);
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _apiService.auth.logout();
    } catch (e) {
      print('Logout error: $e');
    }
  }
}
