import 'permissions.dart';

class OrderEditPolicy {
  static bool canEdit(AppRole role, String status) {
    final normalizedStatus = status.trim().toLowerCase();
    switch (role) {
      case AppRole.customer:
        return const {
          'pending',
          'submitted',
          'processing',
          'customer_changed',
          'priced',
        }.contains(normalizedStatus);
      case AppRole.admin:
      case AppRole.manager:
      case AppRole.accountant:
        return const {
          'pending',
          'submitted',
          'processing',
          'customer_changed',
          'priced',
          'customer_confirmed',
          'approved',
        }.contains(normalizedStatus);
      case AppRole.warehouse:
        return const {'approved', 'preparing'}.contains(normalizedStatus);
      case AppRole.salesperson:
      case AppRole.user:
        return false;
    }
  }
}
