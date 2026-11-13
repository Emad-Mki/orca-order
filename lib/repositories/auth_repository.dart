import '../services/api_service.dart';
import '../models/user.dart';

class AuthRepository {
  final ApiService _apiService = ApiService();

  Future<User> login(String username, String password) async {
    try {
      final response = await _apiService.auth.login(username, password);
      final session = response['session'];
      final userData = response['user'] ?? session;
      if (userData is! Map) {
        throw Exception('بيانات المستخدم غير موجودة في الرد');
      }
      return User.fromJson(Map<String, dynamic>.from(userData));
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    await _apiService.auth.logout();
  }
}
