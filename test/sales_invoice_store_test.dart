import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/services/sales_invoice_store.dart';

Map<String, dynamic> invoice(
  String id, {
  String seller = 's1',
  String customer = 'c1',
  String date = '2026-01-02T10:00:00',
  String status = 'posted',
  String financial = 'partial',
  String method = 'cash_usd',
}) =>
    {
      'invoice_id': id,
      'invoice_number': 'number-$id',
      'invoice_date': date,
      'seller_id': seller,
      'seller_name': 'Seller $seller',
      'customer_id': customer,
      'customer_name': 'Customer $customer',
      'buyer_name': 'Buyer $id',
      'buyer_phone': '123',
      'status': status,
      'financial_status': financial,
      'payment_method': 'mixed',
      'subtotal': '123.456',
      'discount': 3,
      'net_total': '120.456',
      'total_paid_usd': '10.123',
      'balance_due_usd': '110.333',
      'items': [
        {'product_id': 'p', 'price': '123.456'}
      ],
      'payments': [
        {'method': method, 'amount': '10.123'}
      ],
    };

void main() {
  late Directory directory;
  late SalesInvoiceStore store;

  setUp(() async {
    directory = Directory(
        '.dart_tool${Platform.pathSeparator}invoice_store_test_${DateTime.now().microsecondsSinceEpoch}');
    await directory.create(recursive: true);
    store = SalesInvoiceStore(
        environment: 'production',
        userId: 's1',
        role: 'salesperson',
        directory: directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('merges filtered snapshots and preserves exact server values', () async {
    final first = invoice('one');
    final second = invoice('two', date: '2026-02-02T10:00:00');
    await store.merge([first]);
    await store.merge([second]);
    final reopened = SalesInvoiceStore(
        environment: 'production',
        userId: 's1',
        role: 'salesperson',
        directory: directory);
    expect(await reopened.list(), [second, first]);
    final updated = invoice('one')..['net_total'] = '99.999';
    await reopened.merge([updated]);
    expect(await store.list(query: 'number-one'), [updated]);
    expect((await store.list()).length, 2);
    final files = await directory.list().toList();
    expect(files.length, 1);
    expect(files.single.path, isNot(contains('s1')));
  });

  test('filters match server fields, dates and payment lines', () async {
    final one = invoice('one');
    final two = invoice('two',
        customer: 'c2',
        date: '2026-02-02T10:00:00',
        status: 'voided',
        financial: 'voided',
        method: 'cash_syp');
    await store.merge([one, two]);
    expect(await store.list(query: 'buyer ONE'), [one]);
    expect(await store.list(query: 'seller s1'), [two, one]);
    expect(await store.list(fromDate: DateTime(2026, 2, 1)), [two]);
    expect(await store.list(toDate: DateTime(2026, 1, 2, 10)), [one]);
    expect(
        await store.list(
            status: 'voided',
            financialStatus: 'voided',
            paymentMethod: 'cash_syp',
            sellerId: 's1',
            customerId: 'c2'),
        [two]);
    expect(await store.list(paymentMethod: 'mixed'), isEmpty);
    expect(await store.list(sellerId: 'other'), isEmpty);
  });

  test('isolates environments accounts and roles, enforcing ownership',
      () async {
    await store.merge([invoice('one')]);
    SalesInvoiceStore scoped(String env, String user, String role) =>
        SalesInvoiceStore(
            environment: env, userId: user, role: role, directory: directory);
    expect(await scoped('testing', 's1', 'salesperson').list(), isEmpty);
    expect(await scoped('production', 's2', 'salesperson').list(), isEmpty);
    expect(await scoped('production', 's1', 'admin').list(), isEmpty);
    await expectLater(
        store.merge([invoice('other', seller: 's2')]), throwsFormatException);
    expect((await store.list()).length, 1);
    expect(() => scoped('production', 's1', 'customer'), throwsArgumentError);
  });

  test('rejects incomplete snapshots without changing stored data', () async {
    await store.merge([invoice('one')]);
    final incomplete = invoice('two')..remove('payments');
    await expectLater(store.merge([incomplete]), throwsFormatException);
    expect(await store.list(), [invoice('one')]);
  });

  test('serializes overlapping merges', () async {
    await Future.wait([
      store.merge([invoice('one')]),
      store.merge([invoice('two')])
    ]);
    expect((await store.list()).length, 2);
  });

  test('rejects corrupt cache instead of replacing it', () async {
    await store.merge([invoice('one')]);
    final file = (await directory.list().toList()).single as File;
    await file.writeAsString('not json');
    await expectLater(store.list(), throwsFormatException);
    await expectLater(store.merge([invoice('two')]), throwsFormatException);
    expect(await file.readAsString(), 'not json');
  });
}
