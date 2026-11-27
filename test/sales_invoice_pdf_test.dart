import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
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

  test(
    'builds short and multipage invoices with no image data',
    () async {
      final output = Platform.environment['PDF_TEST_OUTPUT'];
      for (final count in [1, 100]) {
        final bytes = await SalesInvoicePdf.build(invoice(count));
        expect(bytes.length, greaterThan(1000));
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        if (output != null) {
          await File('$output\\invoice-$count.pdf').writeAsBytes(bytes);
        }
      }
    },
    skip: InAppWebViewPlatform.instance == null
        ? 'requires a native WebView implementation'
        : false,
  );

  test('rejects a missing invoice item snapshot', () async {
    final data = invoice(1)..remove('items');
    await expectLater(SalesInvoicePdf.build(data), throwsFormatException);
  });

  test(
    'renders draft without requiring a final invoice number',
    () async {
      final data = invoice(1)
        ..remove('invoice_number')
        ..['status'] = 'draft';
      final bytes = await SalesInvoicePdf.build(data);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    },
    skip: InAppWebViewPlatform.instance == null
        ? 'requires a native WebView implementation'
        : false,
  );

  test('template validates text size and exposes its ready gate', () async {
    final template = await rootBundle.loadString('Invoice.html');
    expect(template, contains('@page{size:A4 portrait;margin:12.7mm}'));
    expect(template, contains('height:16mm'));
    expect(template, contains('width:28mm;height:27mm'));
    expect(template, contains('object-fit:contain'));
    expect(template, contains('.cell{height:15.4mm;overflow:visible}'));
    expect(template, contains('.product-picture{width:25mm;height:14mm}'));
    expect(template, contains('.text-wrap .en{display:inline'));
    expect(template, contains('الحد الأدنى المقروء'));
    expect(template, contains('window.invoiceReady=true'));
    expect(template, contains('window.prepareInvoice=async function'));
    expect(template, contains('.discount-value,.net-value{color:#f00000}'));
    expect(template, contains('{{#shipment_summary}}'));
    expect(template, contains('الشحن: {{shipment_summary}}'));
    expect(template, isNot(contains('رصيد السابق:')));
    expect(template, isNot(contains('رصيد نهائي مع السابق:')));
    expect(template, isNot(contains('المدفوع:')));
  });

  test('resolves invoice totals, phone and print date from app data', () {
    final values = SalesInvoicePdf.invoiceValuesForTesting(
      {
        'buyer_phone': '+963 955 123456',
        'discount': '1.25',
        'items': [
          {'quantity': 2, 'unit_price': '5.00'},
          {'quantity': 1, 'unit_price': 10, 'total_price': '10.00'},
        ],
      },
      exportedAt: DateTime(2026, 11, 23),
    );
    expect(values['line_total'], '10.0');
    expect(values['subtotal'], '20.0');
    expect(values['discount'], '1.25');
    expect(values['net_total'], '18.75');
    expect(values['customer_phone'], '+963 955 123456');
    expect(values['print_date'], '2026/11/23');

    final storedValues = SalesInvoicePdf.invoiceValuesForTesting({
      'subtotal': '462.500',
      'discount': '0.00',
      'net_total': '462.50',
      'items': [
        {'line_total': '462.50'}
      ],
    });
    expect(storedValues['subtotal'], '462.500');
    expect(storedValues['net_total'], '462.50');
  });

  test('names exported PDFs with invoice number and export date', () {
    expect(
      SalesInvoicePdf.exportFileName(
        {'invoice_number': 'INV/2451'},
        DateTime(2026, 11, 23),
      ),
      'invoice_INV_2451_2026-11-23.pdf',
    );
  });

  test(
    'applies custom column ordering and hides optional fields',
    () async {
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
    },
    skip: InAppWebViewPlatform.instance == null
        ? 'requires a native WebView implementation'
        : false,
  );

  test(
    'preserves stored precision and does not repeat currency',
    () async {
      final data = invoice(1)
        ..['net_total'] = '193.4567 USD'
        ..['balance_due_usd'] = '133.0123 USD';
      final bytes = await SalesInvoicePdf.build(data);
      final output = Platform.environment['PDF_TEST_OUTPUT'];
      if (output != null) {
        await File('$output\\invoice-precision.pdf').writeAsBytes(bytes);
      }
      expect(bytes, isNotEmpty);
    },
    skip: InAppWebViewPlatform.instance == null
        ? 'requires a native WebView implementation'
        : false,
  );

  test(
    'embeds a locally supplied product image',
    () async {
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
    },
    skip: InAppWebViewPlatform.instance == null
        ? 'requires a native WebView implementation'
        : false,
  );
}
