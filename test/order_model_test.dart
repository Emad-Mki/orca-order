import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/order.dart';
import 'package:orca_order/models/order_item.dart';

void main() {
  test('legacy boolean cells do not crash textual order fields', () {
    final order = Order.fromJson({
      'order_id': 123,
      'order_number': false,
      'customer_id': 55,
      'customer_name': true,
      'status': false,
      'currency': true,
      'note': false,
      'accountant_notes': true,
      'accounting_invoice_no': false,
      'created_by': true,
      'created_by_role': false,
      'is_new': true,
      'is_read': false,
    });

    expect(order.orderId, '123');
    expect(order.orderNumber, '123');
    expect(order.customerId, '55');
    expect(order.customerName, 'غير معروف');
    expect(order.status, '');
    expect(order.currency, 'USD');
    expect(order.note, isNull);
    expect(order.accountantNotes, isNull);
    expect(order.accountingInvoiceNo, isNull);
    expect(order.createdBy, isNull);
    expect(order.createdByRole, isNull);
    expect(order.isNew, isTrue);
    expect(order.isRead, isFalse);
  });

  test('accounting invoice numbers are preserved from text or numeric cells',
      () {
    final legacyOrder = Order.fromJson({'order_id': 'OLD-1'});
    final textNumber = Order.fromJson({
      'order_id': 'ORD-1',
      'accounting_invoice_no': '  INV-0021  ',
    });
    final numericNumber = Order.fromJson({
      'order_id': 'ORD-2',
      'accounting_invoice_no': 12345.0,
    });

    expect(legacyOrder.accountingInvoiceNo, isNull);
    expect(textNumber.accountingInvoiceNo, '  INV-0021  ');
    expect(numericNumber.accountingInvoiceNo, '12345');
  });

  test('malformed order item structures are reported, not dropped', () {
    expect(
      () => Order.fromJson({
        'order_id': 'ORD-1',
        'items': {'invalid': true},
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => Order.fromJson({
        'order_id': 'ORD-1',
        'items': [true],
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('legacy boolean cells in order item text fields are ignored', () {
    final item = OrderItem.fromJson({
      'item_id': true,
      'code': 123,
      'name': false,
      'unit': true,
      'currency': false,
      'unit_1': true,
      'unit_2': false,
    });

    expect(item.itemId, '');
    expect(item.code, '123');
    expect(item.name, 'منتج غير معروف');
    expect(item.unit, '');
    expect(item.currency, 'USD');
    expect(item.unit1, isNull);
    expect(item.unit2, isNull);
  });
}
