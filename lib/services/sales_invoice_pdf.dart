import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mustache_template/mustache_template.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// Renders the invoice using the HTML template and Headless WebView for PDF generation.
class SalesInvoicePdf {
  static const templateVersion = 'builtin-1';

  // Keep these constants for backward compatibility if referenced elsewhere.
  static const defaultColumns = ['index', 'image', 'name', 'quantity', 'unit', 'price', 'total', 'note'];
  static const defaultWidths = <String, double>{
    'index': .5, 'image': 1, 'name': 2.5, 'quantity': .8, 'unit': .8, 'price': 1.2, 'total': 1.2, 'note': 1.2,
  };

  static Future<Uint8List> build(
    Map<String, dynamic> invoice, {
    Map<String, dynamic>? template,
    Uint8List? logoBytes,
    Map<String, Uint8List> productImages = const {},
  }) async {
    // 1. Load HTML and Assets
    final htmlTemplate = await rootBundle.loadString('Invoice.html');
    
    final fontCalibriRegular = await _getAssetAsDataUri('assets/fonts/calibri.ttf', 'font/ttf');
    final fontCalibriBold = await _getAssetAsDataUri('assets/fonts/calibrib.ttf', 'font/ttf');
    final fontTimesRegular = await _getAssetAsDataUri('assets/fonts/times.ttf', 'font/ttf');
    final fontTimesBold = await _getAssetAsDataUri('assets/fonts/timesbd.ttf', 'font/ttf');
    
    String companyLogoUri;
    if (logoBytes != null) {
      companyLogoUri = 'data:image/png;base64,${base64Encode(logoBytes)}';
    } else {
      companyLogoUri = await _getAssetAsDataUri('assets/icon/app_logo.png', 'image/png');
    }

    // 2. Data Mapping
    final isUnsynced = invoice['is_unsynced'] == true;
    final isOrder = invoice['kind'] == 'order' || invoice['kind'] == 'order_draft';
    final isDraft = isUnsynced || invoice['status']?.toString().toLowerCase() == 'draft';
    
    final invoiceType = invoice['sync_uncertain'] == true
        ? 'مسودة محلية - حالة الإرسال غير مؤكدة'
        : isUnsynced
            ? (invoice['kind'] == 'order_draft' ? 'مسودة طلب غير متزامنة' : 'مسودة غير متزامنة')
            : (isDraft ? 'مسودة' : (isOrder ? 'كشف طلب' : 'فاتورة مبيعات'));

    final currency = (invoice['currency'] ?? r'$').toString();
    final itemsValue = invoice['items'];
    final List<Map<String, dynamic>> rawItems = (itemsValue is List)
        ? itemsValue.map((item) => Map<String, dynamic>.from(item as Map)).toList()
        : [];
        
    final mappedItems = rawItems.map((item) {
      final code = (item['code'] ?? '').toString();
      return {
        'image_src': _getImageDataUri(code, productImages),
        'name_parts': _splitMixedText((item['name_snapshot'] ?? item['name'] ?? '').toString()),
        'code': code,
        'quantity': _formatNum(item['quantity']),
        'unit': (item['unit'] ?? '').toString(),
        'unit_price': _formatNum(item['unit_price']),
        'line_total': _formatNum(item['line_total']),
        'note_parts': _splitMixedText((item['note'] ?? '').toString()),
      };
    }).toList();

    const itemsPerPage = 8;
    final totalPages = (mappedItems.length / itemsPerPage).ceil().clamp(1, 999);
    final pages = <Map<String, dynamic>>[];
    
    final totalQuantity = rawItems.fold<double>(0.0, (sum, item) {
      final qtyStr = item['quantity']?.toString() ?? '0';
      return sum + (double.tryParse(qtyStr.replaceAll(',', '')) ?? 0.0);
    });

    for (int i = 0; i < totalPages; i++) {
      final start = i * itemsPerPage;
      final end = (start + itemsPerPage) > mappedItems.length ? mappedItems.length : (start + itemsPerPage);
      final pageItems = mappedItems.sublist(start, end).asMap().entries.map((entry) {
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
      'invoice_date': (invoice['invoice_date'] ?? '').toString(),
      'customer_name': (invoice['customer_name'] ?? '').toString(),
      'customer_phone': (invoice['customer_phone'] ?? invoice['buyer_phone'] ?? '').toString(),
      'invoice_type': invoiceType,
      'invoice_statement': (invoice['notes'] ?? '').toString(),
      'currency': currency,
      'payment_method': (invoice['payment_method'] ?? 'آجل').toString(),
      'total_quantity': _formatNum(totalQuantity),
      'subtotal': _formatNum(invoice['subtotal']),
      'discount': _formatNum(invoice['discount']),
      'net_total': _formatNum(invoice['net_total']),
      'paid_amount': _formatNum(invoice['total_paid_usd'] ?? invoice['total_received_usd'] ?? 0),
      'previous_balance': _formatNum(invoice['previous_balance']),
      'final_balance': _formatNum(invoice['final_balance']),
      'print_date': DateFormat('yyyy/MM/dd').format(DateTime.now()),
      'total_pages': totalPages,
      'pages': pages,
    };

    // 3. Mustache Rendering
    final templateEngine = Template(htmlTemplate, htmlEscapeValues: true);
    final renderedHtml = templateEngine.renderString(data);

    // 4. Headless Rendering and PDF Generation
    return await _convertHtmlToPdf(renderedHtml);
  }

  static final _numberFormatter = NumberFormat('#,##0.00');

  static String _formatNum(dynamic val) {
    if (val == null || val == '') return '0.00';
    final n = double.tryParse(val.toString().replaceAll(',', '')) ?? 0.0;
    return _numberFormatter.format(n);
  }

  static Future<String> _getAssetAsDataUri(String assetPath, String mimeType) async {
    final bytes = await rootBundle.load(assetPath);
    final b64 = base64Encode(bytes.buffer.asUint8List());
    return 'data:$mimeType;base64,$b64';
  }

  static String? _getImageDataUri(String code, Map<String, Uint8List> productImages) {
    if (code.isEmpty || !productImages.containsKey(code)) return null;
    return 'data:image/png;base64,${base64Encode(productImages[code]!)}';
  }

  static List<Map<String, dynamic>> _splitMixedText(String text) {
    if (text.isEmpty) return [];
    final runes = text.runes.toList();
    final List<Map<String, dynamic>> parts = [];
    
    bool isArabic(int rune) => (rune >= 0x0600 && rune <= 0x06FF);
    bool isLtr(int rune) => (rune >= 0x30 && rune <= 0x39) || 
                            (rune >= 0x41 && rune <= 0x5A) || 
                            (rune >= 0x61 && rune <= 0x7A) || 
                            (rune == 0x2E) || (rune == 0x2D) || (rune == 0x2F) || (rune == 0x5C);

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
          while (retries < 100) { // Up to 20 seconds
            final ready = await controller.evaluateJavascript(source: "window.invoiceReady") ?? false;
            if (ready) break;
            
            final errors = await controller.evaluateJavascript(source: "window.invoiceErrors");
            if (errors != null && errors is List && errors.isNotEmpty) {
              if (!completer.isCompleted) {
                completer.completeError(Exception("خطأ في تحقق الفاتورة: ${errors.join(' | ')}"));
              }
              return;
            }
            
            await Future.delayed(const Duration(milliseconds: 200));
            retries++;
          }
          
          if (retries >= 100) {
            if (!completer.isCompleted) {
              completer.completeError(Exception("تجاوز وقت تحميل الفاتورة أو التحقق منها (20 ثانية)"));
            }
            return;
          }

          final pdf = await controller.createPdf();
          if (pdf != null) {
            if (!completer.isCompleted) completer.complete(pdf);
          } else {
            if (!completer.isCompleted) completer.completeError(Exception("فشل إنشاء ملف PDF من المتصفح"));
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
