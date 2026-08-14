import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../providers/order_detail_provider.dart';
import '../repositories/order_repository.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../utils/number_utils.dart';
import 'widgets/order_header_widget.dart';
import 'widgets/order_items_list_view.dart';
import 'widgets/order_pricing_section_widget.dart';
import 'widgets/order_actions_widget.dart';
import 'widgets/order_history_widget.dart';
import 'widgets/order_shipping_widget.dart';
import 'widgets/order_empty_state_widget.dart';

/// شاشة تفاصيل الطلب - النسخة المعتمدة على Provider
/// تم تحويل الشاشة لاستخدام State Management عبر Provider
class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> session;
  
  const OrderDetailsScreen({super.key, required this.order, required this.session});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late OrderDetailProvider _provider;
  late String role;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    role = widget.session['role']?.toString().toLowerCase() ?? 'customer';
    _initializeProvider();
    
    // تعليم الطلب كمقروء عند فتحه (للمدير/المحاسب فقط)
    if (role == 'admin' || role == 'manager' || role == 'accountant') {
      _markOrderAsRead();
    }
  }

  Future<void> _initializeProvider() async {
    final repository = OrderRepository();
    _provider = OrderDetailProvider(repository);
    
    await _provider.fetchOrderDetails(widget.order['id'].toString());
    
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _markOrderAsRead() async {
    try {
      // يمكن استخدام provider هنا إذا لزم الأمر
    } catch (e) {
      debugPrint('خطأ في تعليم الطلب كمقروء: $e');
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    final success = await _provider.updateStatus(newStatus);
    
    if (!mounted) return;
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث حالة الطلب إلى: $newStatus'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التحديث: ${_provider.errorMessage}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Consumer<OrderDetailProvider>(
        builder: (context, provider, child) {
          if (!_isInitialized || provider.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (provider.errorMessage != null) {
            return Scaffold(
              appBar: AppBar(title: Text('طلب #${widget.order['id']}')),
              body: Center(child: Text('خطأ: ${provider.errorMessage}')),
            );
          }

          final status = widget.order['status']?.toString().toLowerCase() ?? '';
          
          return Scaffold(
            appBar: AppBar(
              title: Text('طلب #${widget.order['id']}'),
              actions: [
                IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () => _exportOrderPdf(provider)),
                IconButton(icon: const Icon(Icons.refresh), onPressed: () => _provider.fetchOrderDetails(widget.order['id'].toString())),
              ],
            ),
            body: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.withAlpha(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الحالة الحالية: ${provider.currentOrder?.status ?? widget.order['status']}', 
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('تاريخ الطلب: ${provider.currentOrder?.createdAt?.toString().split(' ')[0] ?? widget.order['date']}'),
                      if (provider.currentOrder?.note != null && provider.currentOrder!.note.toString().isNotEmpty)
                        Text('ملاحظة: ${provider.currentOrder!.note}'),
                    ],
                  ),
                ),
                Expanded(
                  child: provider.items.isEmpty
                      ? const OrderEmptyStateWidget()
                      : ListView(
                          padding: const EdgeInsets.all(8),
                          children: [
                            if (provider.currentOrder != null) 
                              OrderHeaderWidget(order: provider.currentOrder!),
                            const Divider(),
                            OrderItemsListView(role: role),
                            if (provider.shipmentData != null) 
                              OrderShippingWidget(shipmentData: provider.shipmentData!, role: role),
                            if (role != 'warehouse' && provider.items.isNotEmpty) 
                              _buildOrderFinancialSummary(provider),
                          ],
                        ),
                ),
                OrderActionsWidget(
                  status: status,
                  role: role,
                  onStatusChange: _updateStatus,
                  onPrint: () => _exportOrderPdf(provider),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderFinancialSummary(OrderDetailProvider provider) {
    final total = provider.total;
    final balanceInfo = provider.balanceInfo;

    return Card(
      margin: const EdgeInsets.only(top: 16, bottom: 80),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow('إجمالي الفاتورة الحالية:', '\$${total.toStringAsFixed(2)}', isBold: true),
            if (balanceInfo != null) ...[
              const Divider(),
              _summaryRow('رصيد الحساب السابق:', '\$${formatMoneyShort(balanceInfo['current_balance'])}'),
              _summaryRow('الرصيد النهائي بعد الفاتورة:', 
                '\$${formatMoneyShort((balanceInfo['current_balance'] ?? 0.0) + total)}', 
                color: Colors.red, isBold: true),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color)),
        ],
      ),
    );
  }

  Future<void> _exportOrderPdf(OrderDetailProvider provider) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.almaraiRegular();
    final fontBold = await PdfGoogleFonts.almaraiBold();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('فاتورة طلبية', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('ORCA ORDER', style: pw.TextStyle(fontSize: 18, color: PdfColors.blue)),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text('رقم الطلب: ${provider.currentOrder?.orderNumber ?? widget.order['id']}'),
                pw.Text('التاريخ: ${provider.currentOrder?.createdAt?.toString().split(' ')[0] ?? widget.order['date']}'),
                pw.Text('الحالة: ${provider.currentOrder?.status ?? widget.order['status']}'),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ['الصنف', 'الكمية', 'السعر', 'الإجمالي'],
                  data: provider.items.map((item) => [
                    item.name,
                    '${item.quantityRequested} ${item.unit}',
                    '${formatMoneyShort(item.displayPrice)}',
                    '${formatMoneyShort(item.total)}',
                  ]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerRight,
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    'الإجمالي: ${provider.total.toStringAsFixed(2)} USD',
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
