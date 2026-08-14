import 'package:flutter/foundation.dart';
import '../repositories/auth_repository.dart';
import '../models/user.dart';

/// Provider لإدارة حالة المصادقة وتسجيل الدخول
class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  
  User? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider(this._authRepository);

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  String? get userRole => _currentUser?.role;
  String? get userId => _currentUser?.id;

  /// تسجيل الدخول
  Future<bool> login(String username, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepository.login(username, password);
      _currentUser = user;
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

  /// تسجيل الخروج
  Future<void> logout() async {
    await _authRepository.logout();
    _currentUser = null;
    notifyListeners();
  }

  /// تحديث بيانات المستخدم الحالي
  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }
}
