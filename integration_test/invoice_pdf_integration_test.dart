import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orca_order/services/invoice_pdf_archive.dart';
import 'package:orca_order/services/invoice_template_store.dart';
import 'package:orca_order/services/sales_invoice_pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';

const offline = bool.fromEnvironment('INVOICE_OFFLINE_TEST');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders, rasterizes, and archives invoices on device',
      (tester) async {
    final directory = await getApplicationSupportDirectory();
    final connectivity = await Connectivity().checkConnectivity();
    expect(connectivity.contains(ConnectivityResult.none), offline);
    final settings = {
      'version': 'device-test-1',
      'company_name': 'شركة الاختبار',
      'company_details': 'عنوان تجريبي',
      'footer': 'شكرا',
      'primary_color': '#00658F',
      'font_size': 10,
      'margin': 28,
      'columns': SalesInvoicePdf.defaultColumns,
      'column_widths': SalesInvoicePdf.defaultWidths,
      'show_images': true,
      'show_notes': true,
    };
    if (offline) {
      final seed = InvoiceTemplateStore(
        scope: 'device-integration-test',
        directoryProvider: () async => directory,
        fetch: () async => {'template': settings},
      );
      await seed.refresh();
    }
    final store = InvoiceTemplateStore(
      scope: 'device-integration-test',
      directoryProvider: () async => directory,
      fetch: () async {
        if (offline) throw const SocketException('network unavailable');
        return {'template': settings};
      },
    );
    if (offline) {
      await expectLater(store.refresh(), throwsA(isA<SocketException>()));
    } else {
      await store.refresh();
    }
    final template = await store.current();
    expect(template.version, 'device-test-1');
    final archive = InvoicePdfArchive(
      environment: 'device-test',
      userId: 'test',
      role: 'accountant',
      rootDirectory: directory,
    );
    for (final count in [1, 100]) {
      final invoice = <String, dynamic>{
        'invoice_id': 'device-$count',
        'invoice_number': 'TEST-$count',
        'status': 'posted',
        'currency': 'USD',
        'customer_name': 'زبون تجريبي',
        'invoice_date': '2026-01-01',
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
                  'name_snapshot': 'قطعة تجريبية طويلة $i',
                  'quantity': 2,
                  'unit': 'قطعة',
                  'unit_price': 5,
                  'line_total': 10,
                }),
      };
      final bytes = await SalesInvoicePdf.build(invoice,
          template: template.toMap(), logoBytes: template.logoBytes);
      final file = await archive.save(
          bytes: bytes,
          invoiceId: invoice['invoice_id'] as String,
          templateVersion: template.version);
      expect(await file.exists(), isTrue);
      final pages = await Printing.raster(bytes, dpi: 72).toList();
      expect(pages.length, count == 1 ? 1 : greaterThan(1));
      expect(pages.first.width, greaterThan(100));
      expect(
          (await archive.list(invoiceId: invoice['invoice_id'] as String))
              .isNotEmpty,
          isTrue);
    }
    final oversized = <String, dynamic>{
      'invoice_id': 'device-oversized',
      'invoice_number': 'TEST-OVERSIZED',
      'status': 'posted',
      'currency': 'USD',
      'customer_name': 'زبون تجريبي',
      'invoice_date': '2026-01-01',
      'subtotal': 200,
      'net_total': 200,
      'items': [
        {
          'code': 'LONG',
          'name_snapshot': List.filled(500, 'قطعة').join(' '),
          'quantity': 1,
          'unit': 'قطعة',
          'unit_price': 200,
          'line_total': 200,
          'note': List.filled(500, 'ملاحظة').join(' '),
        }
      ],
    };
    await expectLater(
      SalesInvoicePdf.build(oversized),
      throwsA(predicate(
          (error) => error.toString().contains('الحد الأدنى المقروء'))),
    );
  });
}
