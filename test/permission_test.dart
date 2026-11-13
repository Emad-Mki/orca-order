import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/utils/permissions.dart';

void main() {
  test('manager role is distinct from administrator', () {
    expect(PermissionHelper.fromString('manager'), AppRole.manager);
    expect(
      PermissionHelper.hasPermission(AppRole.manager, AppPermission.viewOrders),
      isTrue,
    );
    expect(
      PermissionHelper.hasPermission(
          AppRole.manager, AppPermission.manageUsers),
      isFalse,
    );
  });

  test('warehouse and customer cannot view available product quantities', () {
    expect(
      PermissionHelper.hasPermission(
        AppRole.warehouse,
        AppPermission.viewProductQuantities,
      ),
      isFalse,
    );
    expect(
      PermissionHelper.hasPermission(
        AppRole.customer,
        AppPermission.viewProductQuantities,
      ),
      isFalse,
    );
  });

  test('accountant can financially approve orders', () {
    expect(
      PermissionHelper.hasPermission(
        AppRole.accountant,
        AppPermission.approveOrder,
      ),
      isTrue,
    );
  });
}
