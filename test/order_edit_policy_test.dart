import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/utils/order_edit_policy.dart';
import 'package:orca_order/utils/permissions.dart';
import 'package:orca_order/order_status_mapper.dart';

void main() {
  test('customers may edit processing and priced orders only', () {
    expect(OrderEditPolicy.canEdit(AppRole.customer, 'pending'), isTrue);
    expect(OrderEditPolicy.canEdit(AppRole.customer, 'processing'), isTrue);
    expect(OrderEditPolicy.canEdit(AppRole.customer, 'priced'), isTrue);
    expect(
        OrderEditPolicy.canEdit(AppRole.customer, 'customer_changed'), isTrue);
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

  test('warehouse may edit approved and in-progress preparation', () {
    expect(OrderEditPolicy.canEdit(AppRole.warehouse, 'preparing'), isTrue);
    expect(OrderEditPolicy.canEdit(AppRole.warehouse, 'approved'), isTrue);
    expect(OrderEditPolicy.canEdit(AppRole.warehouse, 'prepared'), isFalse);
  });

  test('warehouse only sees orders from approval onwards', () {
    for (final status in [
      'approved',
      'customer_confirmed',
      'preparing',
      'prepared',
      'shipping',
      'delivered',
      'completed',
    ]) {
      expect(OrderStatusMapper.isVisibleToWarehouse(status), isTrue);
    }
    for (final status in [
      'pending',
      'processing',
      'priced',
      'cancelled',
      'unknown',
    ]) {
      expect(OrderStatusMapper.isVisibleToWarehouse(status), isFalse);
    }
  });
}
