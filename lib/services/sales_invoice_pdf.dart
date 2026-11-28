import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mustache_template/mustache_template.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../utils/shipment_summary.dart';

/// Renders the invoice using the HTML template and Headless WebView for PDF generation.
class SalesInvoicePdf {
  static const templateVersion = 'orca-invoice-a4-v3';

  // Keep these constants for backward compatibility if referenced elsewhere.
  static const defaultColumns = [
    'index',
    'image',
    'name',
    'quantity',
    'unit',
    'price',
    'total',
    'note'
  ];
  static const defaultWidths = <String, double>{
    'index': .5,
    'image': 1,
    'name': 2.5,
    'quantity': .8,
    'unit': .8,
    'price': 1.2,
    'total': 1.2,
    'note': 1.2,
  };

  static String exportFileName(
    Map<String, dynamic> invoice,
    DateTime exportedAt,
  ) {
    final invoiceNumber =
        (_firstPresent([invoice['invoice_number'], invoice['invoice_id']]) ??
                '')
            .toString();
    final safeInvoiceNumber = invoiceNumber
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return 'invoice_${safeInvoiceNumber.isEmpty ? 'invoice' : safeInvoiceNumber}_'
        '${DateFormat('yyyy-MM-dd').format(exportedAt)}.pdf';
  }

  static Future<Uint8List> build(
    Map<String, dynamic> invoice, {
    Map<String, dynamic>? template,
    Uint8List? logoBytes,
    Map<String, Uint8List> productImages = const {},
    DateTime? exportedAt,
  }) async {
    // 1. Load HTML and Assets
    final htmlTemplate = await rootBundle.loadString('Invoice.html');

    final fontCalibriRegular =
        await _getAssetAsDataUri('assets/fonts/calibri.ttf', 'font/ttf');
    final fontCalibriBold =
        await _getAssetAsDataUri('assets/fonts/calibrib.ttf', 'font/ttf');
    final fontTimesRegular =
        await _getAssetAsDataUri('assets/fonts/times.ttf', 'font/ttf');
    final fontTimesBold =
        await _getAssetAsDataUri('assets/fonts/timesbd.ttf', 'font/ttf');
    final productPlaceholderUri = await _getAssetAsDataUri(
      'assets/images/product_placeholder.png',
      'image/png',
    );

    String companyLogoUri;
    if (logoBytes != null) {
      companyLogoUri = _imageDataUri(logoBytes);
    } else {
      companyLogoUri =
          await _getAssetAsDataUri('assets/icon/app_logo.png', 'image/png');
    }

    // 2. Data Mapping
    final isUnsynced = invoice['is_unsynced'] == true;
    final isOrder =
        invoice['kind'] == 'order' || invoice['kind'] == 'order_draft';
    final isDraft =
        isUnsynced || invoice['status']?.toString().toLowerCase() == 'draft';

    final invoiceType = invoice['sync_uncertain'] == true
        ? 'مسودة محلية - حالة الإرسال غير مؤكدة'
        : isUnsynced
            ? (invoice['kind'] == 'order_draft'
                ? 'مسودة طلب غير متزامنة'
                : 'مسودة غير متزامنة')
            : (isDraft ? 'مسودة' : (isOrder ? 'كشف طلب' : 'فاتورة مبيعات'));

    final currency = (invoice['currency'] ?? r'$').toString();
    final itemsValue = invoice['items'];
    if (itemsValue is! List) {
      throw const FormatException('بنود الفاتورة غير متوفرة');
    }
    final rawItems = itemsValue
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();

    final mappedItems = rawItems.map((item) {
      final code = (item['code'] ?? '').toString();
      return {
        'image_src':
            _getImageDataUri(code, productImages) ?? productPlaceholderUri,
        'name_parts': _splitMixedText(
            (item['name_snapshot'] ?? item['name'] ?? '').toString()),
        'code': code,
        'quantity': _invoiceValue(item['quantity']),
        'unit': (item['unit'] ?? '').toString(),
        'unit_price': _invoiceValue(_firstPresent([
          item['unit_price'],
          item['price'],
          item['unit_price_snapshot'],
        ])),
        'line_total': _invoiceValue(_lineTotal(item)),
        'note_parts': _splitMixedText((item['note'] ?? '').toString()),
      };
    }).toList();

    const itemsPerPage = 8;
    final totalPages =
        mappedItems.isEmpty ? 1 : (mappedItems.length / itemsPerPage).ceil();
    final pages = <Map<String, dynamic>>[];

    final totalQuantity = rawItems.fold<double>(0.0, (sum, item) {
      final qtyStr = item['quantity']?.toString() ?? '0';
      return sum + (double.tryParse(qtyStr.replaceAll(',', '')) ?? 0.0);
    });

    for (int i = 0; i < totalPages; i++) {
      final start = i * itemsPerPage;
      final end = (start + itemsPerPage) > mappedItems.length
          ? mappedItems.length
          : (start + itemsPerPage);
      final pageItems =
          mappedItems.sublist(start, end).asMap().entries.map((entry) {
        final item = Map<String, dynamic>.from(entry.value);
        item['index'] = start + entry.key + 1;
        return item;
      }).toList();

      pages.add({
        'page_number': i + 1,
        'is_last_page': i == totalPages - 1,
        'items': pageItems,
      });
    }

    final data = {
      'company_logo_src': companyLogoUri,
      'font_calibri_regular_src': fontCalibriRegular,
      'font_calibri_bold_src': fontCalibriBold,
      'font_times_regular_src': fontTimesRegular,
      'font_times_bold_src': fontTimesBold,
      'invoice_number': (invoice['invoice_number'] ?? '').toString(),
      'accounting_invoice_no':
          (invoice['accounting_invoice_no'] ?? '').toString().trim(),
      'invoice_date': (invoice['invoice_date'] ?? '').toString(),
      'customer_name': (invoice['customer_name'] ?? '').toString(),
      'invoice_type': invoiceType,
      'invoice_statement': (invoice['notes'] ?? '').toString(),
      'shipment_summary': _shipmentSummary(invoice),
      'currency': currency,
      'payment_method': (invoice['payment_method'] ?? 'آجل').toString(),
      ..._financialValues(invoice, rawItems, exportedAt),
      'total_quantity': invoice['total_quantity'] == null
          ? NumberFormat('#,##0.00').format(totalQuantity)
          : _invoiceValue(invoice['total_quantity']),
      'total_pages': totalPages,
      'pages': pages,
    };

    // 3. Mustache Rendering
    final templateEngine = Template(htmlTemplate, htmlEscapeValues: true);
    final renderedHtml = templateEngine.renderString(data);

    // 4. Headless Rendering and PDF Generation
    return await _convertHtmlToPdf(renderedHtml);
  }

  static String _invoiceValue(dynamic value) =>
      value == null || value == '' ? '0.00' : value.toString();

  static String _shipmentSummary(Map<String, dynamic> invoice) {
    final stored = invoice['shipment_summary']?.toString().trim() ?? '';
    if (stored.isNotEmpty) return stored;
    final shipmentData = invoice['shipment_data'];
    if (shipmentData is Map) {
      return ShipmentSummary.formatAll(
        Map<String, dynamic>.from(shipmentData),
      );
    }
    return '';
  }

  static dynamic _firstPresent(Iterable<dynamic> values) {
    for (final value in values) {
      if (value != null && (value is! String || value.trim().isNotEmpty)) {
        return value;
      }
    }
    return null;
  }

  static dynamic _lineTotal(Map<String, dynamic> item) {
    final stored = _firstPresent(
      [item['line_total'], item['total_price'], item['total']],
    );
    if (stored != null) return stored;
    final quantity = _parseAmount(item['quantity']);
    final price = _parseAmount(
      _firstPresent(
        [item['unit_price'], item['price'], item['unit_price_snapshot']],
      ),
    );
    return quantity * price;
  }

  static double _sumLineTotals(List<Map<String, dynamic>> items) => items.fold(
        0,
        (sum, item) => sum + _parseAmount(_lineTotal(item)),
      );

  static double _parseAmount(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '') ?? '') ?? 0;
  }

  static String _subtractAmounts(dynamic subtotal, dynamic discount) =>
      (_parseAmount(subtotal) - _parseAmount(discount)).toString();

  static Map<String, String> _financialValues(
    Map<String, dynamic> invoice,
    List<Map<String, dynamic>> items,
    DateTime? exportedAt,
  ) {
    final subtotal =
        _firstPresent([invoice['subtotal']]) ?? _sumLineTotals(items);
    final phone = _firstPresent([
          invoice['buyer_phone'],
          invoice['customer_phone'],
          invoice['phone'],
        ]) ??
        '';
    return {
      'customer_phone': phone.toString(),
      'subtotal': _invoiceValue(subtotal),
      'discount': _invoiceValue(invoice['discount']),
      'net_total': _invoiceValue(
        _firstPresent([invoice['net_total']]) ??
            _subtractAmounts(subtotal, invoice['discount']),
      ),
      'print_date':
          DateFormat('yyyy/MM/dd').format(exportedAt ?? DateTime.now()),
    };
  }

  @visibleForTesting
  static Map<String, String> invoiceValuesForTesting(
    Map<String, dynamic> invoice, {
    DateTime? exportedAt,
  }) {
    final itemsValue = invoice['items'];
    final items = itemsValue is List
        ? itemsValue.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : <Map<String, dynamic>>[];
    return {
      'line_total': _invoiceValue(
        items.isEmpty ? null : _lineTotal(items.first),
      ),
      ..._financialValues(invoice, items, exportedAt),
    };
  }

  static Future<String> _getAssetAsDataUri(
      String assetPath, String mimeType) async {
    final bytes = await rootBundle.load(assetPath);
    final b64 = base64Encode(bytes.buffer.asUint8List());
    return 'data:$mimeType;base64,$b64';
  }

  static String? _getImageDataUri(
      String code, Map<String, Uint8List> productImages) {
    if (code.isEmpty || !productImages.containsKey(code)) return null;
    return _imageDataUri(productImages[code]!);
  }

  static String _imageDataUri(Uint8List bytes) =>
      'data:${_imageMimeType(bytes)};base64,${base64Encode(bytes)}';

  static String _imageMimeType(Uint8List bytes) {
    const pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];
    if (bytes.length >= pngSignature.length &&
        pngSignature.indexed.every((entry) => bytes[entry.$1] == entry.$2)) {
      return 'image/png';
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff &&
        bytes[bytes.length - 2] == 0xff &&
        bytes.last == 0xd9) {
      return 'image/jpeg';
    }
    throw const FormatException('نوع صورة الفاتورة غير مدعوم');
  }

  static List<Map<String, dynamic>> _splitMixedText(String text) {
    if (text.isEmpty) return [];
    final runes = text.runes.toList();
    final List<Map<String, dynamic>> parts = [];

    bool isArabic(int rune) => (rune >= 0x0600 && rune <= 0x06FF);
    bool isLtr(int rune) =>
        (rune >= 0x30 && rune <= 0x39) ||
        (rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A) ||
        (rune == 0x2E) ||
        (rune == 0x2D) ||
        (rune == 0x2F) ||
        (rune == 0x5C);

    String currentText = "";
    bool? currentIsLtr;

    for (int i = 0; i < runes.length; i++) {
      final rune = runes[i];
      final char = String.fromCharCode(rune);

      bool direction;
      if (isArabic(rune)) {
        direction = false;
      } else if (isLtr(rune)) {
        direction = true;
      } else {
        direction = currentIsLtr ?? false;
      }

      if (currentIsLtr == null) {
        currentIsLtr = direction;
        currentText = char;
      } else if (direction == currentIsLtr) {
        currentText += char;
      } else {
        parts.add({'text': currentText, 'is_ltr': currentIsLtr});
        currentText = char;
        currentIsLtr = direction;
      }
    }
    if (currentText.isNotEmpty) {
      parts.add({'text': currentText, 'is_ltr': currentIsLtr ?? true});
    }
    return parts;
  }

  static Future<Uint8List> _convertHtmlToPdf(String html) async {
    final completer = Completer<Uint8List>();
    HeadlessInAppWebView? headlessWebView;

    headlessWebView = HeadlessInAppWebView(
      initialSize: const Size(794, 1123), // Roughly A4 portrait at 96dpi
      initialData: InAppWebViewInitialData(data: html),
      onLoadStop: (controller, url) async {
        try {
          // Trigger the preparation and validation logic
          await controller.evaluateJavascript(source: """
            (async () => {
              try {
                await window.prepareInvoice();
              } catch (e) {
                window.invoiceErrors.push(e.message || e.toString());
              }
            })();
          """);

          // Poll for completion (window.invoiceReady)
          int retries = 0;
          while (retries < 100) {
            // Up to 20 seconds
            final ready = await controller.evaluateJavascript(
                    source: "window.invoiceReady") ??
                false;
            if (ready) break;

            final errors = await controller.evaluateJavascript(
                source: "window.invoiceErrors");
            if (errors != null && errors is List && errors.isNotEmpty) {
              if (!completer.isCompleted) {
                completer.completeError(
                    Exception("خطأ في تحقق الفاتورة: ${errors.join(' | ')}"));
              }
              return;
            }

            await Future.delayed(const Duration(milliseconds: 200));
            retries++;
          }

          if (retries >= 100) {
            if (!completer.isCompleted) {
              completer.completeError(Exception(
                  "تجاوز وقت تحميل الفاتورة أو التحقق منها (20 ثانية)"));
            }
            return;
          }

          final Uint8List? pdf;
          if (defaultTargetPlatform == TargetPlatform.android) {
            final preparedHtml = await controller.evaluateJavascript(
              source: """
                (() => {
                  if (window.invoiceReady !== true) {
                    throw new Error('الفاتورة لم تجتز التحقق قبل التصدير');
                  }
                  document.documentElement.setAttribute('data-invoice-ready', 'true');
                  document.querySelectorAll('script').forEach(script => script.remove());
                  return document.documentElement.outerHTML;
                })();
              """,
            );
            if (preparedHtml is! String) {
              throw StateError('تعذر تجهيز HTML المعتمد لإنشاء PDF');
            }
            // Android's WebView plugin does not implement createPdf; the CSS owns margins.
            // ignore: deprecated_member_use
            pdf = await Printing.convertHtml(
              html: preparedHtml,
              format: PdfPageFormat.a4.copyWith(
                marginTop: 0,
                marginBottom: 0,
                marginLeft: 0,
                marginRight: 0,
              ),
            );
          } else {
            pdf = await controller.createPdf();
          }
          if (pdf != null) {
            if (!completer.isCompleted) completer.complete(pdf);
          } else {
            if (!completer.isCompleted) {
              completer
                  .completeError(Exception("فشل إنشاء ملف PDF من المتصفح"));
            }
          }
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
    );

    await headlessWebView.run();
    try {
      return await completer.future;
    } finally {
      await headlessWebView.dispose();
    }
  }
}
