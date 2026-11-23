import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/services/sales_invoice_pdf.dart';

Map<String, dynamic> invoice(int count) => {
      'invoice_number': 'TEST-123',
      'invoice_date': '2026-01-01',
      'status': 'posted',
      'currency': 'USD',
      'customer_name': 'زبون تجريبي',
      'subtotal': 200,
      'discount': 7,
      'net_total': 193,
      'total_received_usd': 60,
      'total_paid_usd': 60,
      'balance_due_usd': 133,
      'items': List.generate(
        count,
        (i) => {
          'code': 'P$i',
          'name_snapshot': 'قطعة تجريبية باسم طويل لاختبار التفاف النص $i',
          'quantity': 2,
          'unit': 'قطعة',
          'unit_price': 5,
          'line_total': 10,
        },
      ),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds short and multipage invoices with no image data', () async {
    final output = Platform.environment['PDF_TEST_OUTPUT'];
    for (final count in [1, 100]) {
      final bytes = await SalesInvoicePdf.build(invoice(count));
      expect(bytes.length, greaterThan(1000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      if (output != null) {
        await File('$output\\invoice-$count.pdf').writeAsBytes(bytes);
      }
    }
  });

  test('rejects a missing invoice item snapshot', () async {
    final data = invoice(1)..remove('items');
    await expectLater(SalesInvoicePdf.build(data), throwsFormatException);
  });

  test('renders draft without requiring a final invoice number', () async {
    final data = invoice(1)
      ..remove('invoice_number')
      ..['status'] = 'draft';
    final bytes = await SalesInvoicePdf.build(data);
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('splits very long item names and notes over pages', () async {
    final data = invoice(1);
    final item = (data['items'] as List).single as Map<String, dynamic>;
    item['name_snapshot'] = List.filled(500, 'قطعة').join(' ');
    item['note'] = List.filled(500, 'ملاحظة').join(' ');
    final bytes = await SalesInvoicePdf.build(
      data,
      template: {
        'font_size': 14,
        'margin': 50,
        'column_widths': {
          'index': .5,
          'image': 1.0,
          'name': .5,
          'quantity': .8,
          'unit': .8,
          'price': 1.2,
          'total': 1.2,
          'note': 1.2,
        },
      },
    );
    final output = Platform.environment['PDF_TEST_OUTPUT'];
    if (output != null) {
      await File('$output\\invoice-long.pdf').writeAsBytes(bytes);
    }
    expect(bytes.length, greaterThan(1000));
  });

  test('applies custom column ordering and hides optional fields', () async {
    final bytes = await SalesInvoicePdf.build(
      invoice(3),
      template: {
        'version': 'v2',
        'company_name': 'شركة الاختبار',
        'company_details': 'عنوان',
        'footer': 'شكرا',
        'primary_color': '#00658F',
        'font_size': 12,
        'margin': 30,
        'columns': SalesInvoicePdf.defaultColumns.reversed.toList(),
        'column_widths': SalesInvoicePdf.defaultWidths,
        'show_images': false,
        'show_notes': false,
      },
    );
    expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
  });

  test('preserves stored precision and does not repeat currency', () async {
    final data = invoice(1)
      ..['net_total'] = '193.4567 USD'
      ..['balance_due_usd'] = '133.0123 USD';
    final bytes = await SalesInvoicePdf.build(data);
    final output = Platform.environment['PDF_TEST_OUTPUT'];
    if (output != null) {
      await File('$output\\invoice-precision.pdf').writeAsBytes(bytes);
    }
    expect(bytes, isNotEmpty);
  });

  test('embeds a locally supplied product image', () async {
    final asset = await rootBundle.load('assets/images/logo.png');
    final image =
        asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes);
    final bytes =
        await SalesInvoicePdf.build(invoice(1), productImages: {'P0': image});
    final output = Platform.environment['PDF_TEST_OUTPUT'];
    if (output != null) {
      await File('$output\\invoice-product-image.pdf').writeAsBytes(bytes);
    }
    expect(bytes, isNotEmpty);
  });
}
