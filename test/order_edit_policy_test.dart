import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/utils/order_edit_policy.dart';
import 'package:orca_order/utils/permissions.dart';

void main() {
  test('customers may edit processing and priced orders only', () {
    expect(OrderEditPolicy.canEdit(AppRole.customer, 'pending'), isTrue);
    expect(OrderEditPolicy.canEdit(AppRole.customer, 'processing'), isTrue);
    expect(OrderEditPolicy.canEdit(AppRole.customer, 'priced'), isTrue);
    expect(OrderEditPolicy.canEdit(AppRole.customer, 'customer_changed'), isTrue);
    expect(OrderEditPolicy.canEdit(AppRole.customer, 'approved'), isFalse);
    expect(OrderEditPolicy.canEdit(AppRole.customer, 'preparing'), isFalse);
  });

  test('finance roles may edit through approval without changing stage', () {
    for (final role in [
      AppRole.admin,
      AppRole.manager,
      AppRole.accountant,
    ]) {
      for (final status in [
        'pending',
        'priced',
        'customer_confirmed',
        'approved',
      ]) {
        expect(OrderEditPolicy.canEdit(role, status), isTrue);
      }
      expect(OrderEditPolicy.canEdit(role, 'preparing'), isFalse);
    }
  });

  test('warehouse may edit preparation only', () {
    expect(OrderEditPolicy.canEdit(AppRole.warehouse, 'preparing'), isTrue);
    expect(OrderEditPolicy.canEdit(AppRole.warehouse, 'approved'), isFalse);
    expect(OrderEditPolicy.canEdit(AppRole.warehouse, 'prepared'), isFalse);
  });
}
