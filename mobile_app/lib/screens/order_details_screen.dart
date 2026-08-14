import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../services/api_service.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../utils/number_utils.dart';
import 'widgets/order_header_widget.dart';
import 'widgets/order_items_list_widget.dart';
import 'widgets/order_pricing_section_widget.dart';
import 'widgets/order_actions_widget.dart';
import 'widgets/order_history_widget.dart';
import 'widgets/order_shipping_widget.dart';
import 'widgets/order_empty_state_widget.dart';

/// شاشة تفاصيل الطلب - النسخة المُحسّنة والمقسّمة
/// تم تقسيم الشاشة إلى مكونات منفصلة لتحسين الصيانة والأداء
class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> session;
  const OrderDetailsScreen({super.key, required this.order, required this.session});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  List<OrderItem> _items = [];
  bool _isLoading = true;
  String? _error;
  Order? _fullOrder;
  Map<String, dynamic>? _shipmentData;
  Map<String, dynamic>? _balanceInfo;
  late String role;

  // دالة مساعدة آمنة لتنسيق الأسعار ومنع null
  String _safePrice(dynamic value) {
    return formatMoneyShort(value);
  }

  @override
  void initState() {
    super.initState();
    role = widget.session['role']?.toString().toLowerCase() ?? 'customer';
    _fetchOrderItems();
    // تعليم الطلب كمقروء عند فتحه (للمدير/المحاسب فقط)
    if (role == 'admin' || role == 'manager' || role == 'accountant') {
      _markOrderAsRead();
    }
  }

  Future<void> _markOrderAsRead() async {
    try {
      await ApiService().post({
        'action': 'markOrderAsRead',
        'orderId': widget.order['id'],
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
    } catch (e) {
      debugPrint('خطأ في تعليم الطلب كمقروء: $e');
    }
  }

  Future<void> _fetchOrderItems() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ApiService().post({
        'action': 'getOrderDetails',
        'orderId': widget.order['id'],
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      
      if (mounted) {
        setState(() {
          if (data['items'] != null) {
            _items = (data['items'] as List).map((i) => OrderItem.fromJson(i)).toList();
          }
          if (data['order'] != null) {
            _fullOrder = Order.fromJson(data['order']);
          }
          _shipmentData = data['shipment'];
          _balanceInfo = data['balanceInfo'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isLoading = true);
    try {
      await ApiService().post({
        'action': 'updateOrderStatus',
        'orderId': widget.order['id'],
        'status': newStatus,
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديث حالة الطلب إلى: $newStatus'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التحديث: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.order['status']?.toString().toLowerCase() ?? '';
    final role = widget.session['role']?.toString().toLowerCase() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('طلب #${widget.order['id']}'),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: _exportOrderPdf),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchOrderItems),
        ],
      ),
      body: _isLoading && _items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.blue.withAlpha(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الحالة الحالية: ${widget.order['status']}', 
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('تاريخ الطلب: ${widget.order['date']}'),
                      if (widget.order['note'] != null && widget.order['note'].toString().isNotEmpty)
                        Text('ملاحظة: ${widget.order['note']}'),
                    ],
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                Expanded(
                  child: _items.isEmpty
                      ? const Center(child: Text('لا توجد أصناف في هذا الطلب'))
                      : ListView(
                          padding: const EdgeInsets.all(8),
                          children: [
                            if (_fullOrder != null) _buildOrderHeader(),
                            const Divider(),
                            ..._items.map((item) {
                              final bool showPrices = role != 'warehouse';
                              return Card(
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('المطلوب: ${item.quantityRequested} ${item.unit}'),
                                      if (item.quantityApproved > 0)
                                        Text('المعتمد: ${item.quantityApproved} ${item.unit}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                                      if (item.quantityPrepared > 0)
                                        Text('المجهز: ${item.quantityPrepared} ${item.unit}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                                      if (item.customerNote?.toString().isNotEmpty == true)
                                        Text('ملاحظة الزبون: ${item.customerNote}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                                      if (item.accountantNote?.toString().isNotEmpty == true)
                                        Text('ملاحظة المحاسب: ${item.accountantNote}', style: const TextStyle(fontSize: 12, color: Colors.blue)),
                                      if (item.warehouseNote?.toString().isNotEmpty == true)
                                        Text('ملاحظة المستودع: ${item.warehouseNote}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                                    ],
                                  ),
                                  trailing: showPrices ? Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text('\$' + _safePrice(item.finalPrice > 0 ? item.finalPrice : item.priceOffer),
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      if (item.finalPrice > 0)
                                        Text('الإجمالي: \$' + _safePrice(item.finalPrice * (item.quantityApproved > 0 ? item.quantityApproved : item.quantityRequested)),
                                            style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                    ],
                                  ) : null,
                                ),
                              );
                            }).toList(),
                            if (_shipmentData != null) _buildShipmentInfo(role),
                            if (role != 'warehouse' && _items.isNotEmpty) _buildOrderFinancialSummary(),
                          ],
                        ),
                ),
                _buildActionButtons(status, role),
              ],
            ),
    );
  }

  Future<void> _exportOrderPdf() async {
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
                pw.Text('رقم الطلب: ${_fullOrder?.orderNumber ?? widget.order['id']}'),
                pw.Text('التاريخ: ${_fullOrder?.createdAt?.toString().split(' ')[0] ?? widget.order['date']}'),
                pw.Text('الحالة: ${_fullOrder?.status ?? widget.order['status']}'),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ['الصنف', 'الكمية', 'السعر', 'الإجمالي'],
                  data: _items.map((item) => [
                    item.name,
                    '${item.quantityRequested} ${item.unit}',
                    '${formatMoneyShort(item.finalPrice > 0 ? item.finalPrice : item.priceOffer)}',
                    '${formatMoneyShort((item.finalPrice > 0 ? item.finalPrice : item.priceOffer) * item.quantityRequested)}',
                  ]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerRight,
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    'الإجمالي: ${_items.fold(0.0, (sum, item) => sum + ((item.finalPrice > 0 ? item.finalPrice : item.priceOffer) * item.quantityRequested))} USD',
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

  Widget _buildOrderHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('طلب رقم: ${_fullOrder!.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
              _buildStatusChip(_fullOrder!.status),
            ],
          ),
          Text('التاريخ: ${_fullOrder!.createdAt?.toString().split(' ')[0] ?? ''}'),
          if (_fullOrder!.note?.toString().isNotEmpty == true)
             Padding(
               padding: const EdgeInsets.only(top: 8.0),
               child: Text('ملاحظة الطلب: ${_fullOrder!.note}', style: const TextStyle(fontStyle: FontStyle.italic)),
             ),
        ],
      ),
    );
  }

  Widget _buildShipmentInfo(String role) {
    return Card(
      color: Colors.indigo.shade50,
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('بيانات الشحن والتجهيز', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            const Divider(),
            Text('طريقة الاستلام: ${_shipmentData!['delivery_method'] ?? 'غير محدد'}'),
            if (_shipmentData!['carrier']?.toString().isNotEmpty == true)
               Text('شركة الشحن: ${_shipmentData!['carrier']}'),
            if (_shipmentData!['province']?.toString().isNotEmpty == true)
               Text('الوجهة: ${_shipmentData!['province']}'),
            Text('الطرود: ${_shipmentData!['package_count']} (كراتين: ${_shipmentData!['carton_count']}, أكياس: ${_shipmentData!['bag_count']})'),
            if (role == 'admin')
               Text('تكلفة الشحن الداخلية: \$${_shipmentData!['shipping_cost_internal']}', style: const TextStyle(color: Colors.red)),
            if (_shipmentData!['tracking_no']?.toString().isNotEmpty == true)
               Text('رقم التتبع: ${_shipmentData!['tracking_no']}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderFinancialSummary() {
    double total = 0;
    for (var item in _items) {
      final qty = item.quantityApproved > 0 ? item.quantityApproved : item.quantityRequested;
      final price = item.finalPrice > 0 ? item.finalPrice : item.priceOffer;
      total += qty * price;
    }

    return Card(
      margin: const EdgeInsets.only(top: 16, bottom: 80),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow('إجمالي الفاتورة الحالية:', '\$${total.toStringAsFixed(2)}', isBold: true),
            if (_balanceInfo != null) ...[
              const Divider(),
              _summaryRow('رصيد الحساب السابق:', '\$${formatMoneyShort(_balanceInfo!['current_balance'])}'),
              _summaryRow('الرصيد النهائي بعد الفاتورة:', 
                '\$${formatMoneyShort(toSafeDouble(_balanceInfo!['current_balance'], fallback: 0.0) + total)}', 
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

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'submitted': color = Colors.orange; break;
      case 'priced': color = Colors.blue; break;
      case 'approved': color = Colors.green; break;
      case 'prepared': color = Colors.purple; break;
      case 'shipping': color = Colors.indigo; break;
      case 'delivered': color = Colors.teal; break;
      default: color = Colors.grey;
    }
    return Chip(
      label: Text(_getStatusText(status), style: const TextStyle(color: Colors.white, fontSize: 12)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'submitted': return 'قيد المراجعة';
      case 'priced': return 'تم التسعير';
      case 'customer_changed': return 'تم التعديل';
      case 'customer_confirmed': return 'مؤكد من الزبون';
      case 'approved': return 'معتمد';
      case 'prepared': return 'جاهز';
      case 'shipping': return 'قيد الشحن';
      case 'delivered': return 'تم التسليم';
      default: return status;
    }
  }

  void _showCreateShipmentDialog() {
    final carrierCtrl = TextEditingController();
    final trackingCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final provinceCtrl = TextEditingController();
    bool loading = false;
    final role = (widget.session['role']?.toString().toLowerCase() ?? 'customer');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إنشاء شحنة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: carrierCtrl, decoration: const InputDecoration(labelText: 'شركة الشحن / السائق')),
                TextField(controller: trackingCtrl, decoration: const InputDecoration(labelText: 'رقم التتبع / الجوال')),
                TextField(controller: provinceCtrl, decoration: const InputDecoration(labelText: 'المحافظة / الوجهة')),
                if (role == 'admin')
                  TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تكلفة الشحن (ليرة/دولار)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: loading ? null : () async {
                setDialogState(() => loading = true);
                try {
                  // 1. إنشاء الشحنة
                  await ApiService().post({
                    'action': 'shipment',
                    'order_id': widget.order['id'],
                    'carrier': carrierCtrl.text,
                    'tracking_no': trackingCtrl.text,
                    'province': provinceCtrl.text,
                    'shipping_cost_internal': role == 'admin' ? (double.tryParse(costCtrl.text) ?? 0) : 0,
                    'status': 'shipping',
                    'username': widget.session['username'],
                    'token': widget.session['token'],
                  });

                  // 2. تحديث حالة الطلب إلى "قيد الشحن"
                  await ApiService().post({
                    'action': 'updateOrderStatus',
                    'orderId': widget.order['id'],
                    'status': 'shipping',
                    'username': widget.session['username'],
                    'token': widget.session['token'],
                  });

                  if (!mounted) return;
                  Navigator.pop(context, true);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء الشحنة وتحديث حالة الطلب'), backgroundColor: Colors.indigo));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                } finally {
                  setDialogState(() => loading = false);
                }
              },
              child: loading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('تأكيد الشحن'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(String status, String role) {
    List<Widget> buttons = [];

    // زبون: مراجعة الأسعار والتأكيد أو التعديل
    if (role == 'customer' && status == 'priced') {
      buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _updateStatus('approved'),
            icon: const Icon(Icons.check_circle),
            label: const Text('تأكيد الفاتورة'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
          ),
        ),
      );
      buttons.add(const SizedBox(width: 8));
      buttons.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showCustomerEditDialog(),
            icon: const Icon(Icons.edit),
            label: const Text('تعديل الطلب'),
          ),
        ),
      );
    }

    // محاسب: تسعير الطلبية
    if ((role == 'admin' || role == 'manager' || role == 'accountant') && (status == 'pending' || status == 'submitted' || status == 'customer_changed')) {
       buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showPricingDialog(),
            icon: const Icon(Icons.calculate),
            label: const Text('تسعير الفاتورة'),
          ),
        ),
      );
    }
    
    // محاسب/مدير: اعتماد نهائي
    if ((role == 'admin' || role == 'manager' || role == 'accountant') && status == 'customer_confirmed') {
       buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _updateStatus('approved'),
            icon: const Icon(Icons.verified),
            label: const Text('اعتماد نهائي وحجز المخزون'),
            style: FilledButton.styleFrom(backgroundColor: Colors.blue.shade800),
          ),
        ),
      );
    }

    // مستودع: تجهيز الطلبية
    if ((role == 'admin' || role == 'manager' || role == 'warehouse') && status == 'approved') {
      buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showWarehousePrepDialog(),
            icon: const Icon(Icons.inventory),
            label: const Text('تجهيز الطلبية'),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange.shade700),
          ),
        ),
      );
    }

    // شحن (بعد التجهيز)
    if ((role == 'admin' || role == 'manager' || role == 'accountant') && status == 'prepared') {
      buttons.add(
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _showCreateShipmentDialog(),
            icon: const Icon(Icons.local_shipping),
            label: const Text('تأكيد الشحن'),
            style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
          ),
        ),
      );
    }

    // إلغاء الطلب (للمدير والمحاسب فقط) - يظهر في حالات معينة
    if ((role == 'admin' || role == 'manager' || role == 'accountant') && 
        (status == 'pending' || status == 'priced' || status == 'customer_changed')) {
      buttons.add(const SizedBox(width: 8));
      buttons.add(
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showCancelOrderDialog(),
            icon: const Icon(Icons.cancel, color: Colors.red),
            label: const Text('إلغاء الطلب', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(children: buttons),
    );
  }

  // حوار إلغاء الطلب مع سبب الإلغاء
  void _showCancelOrderDialog() {
    final reasonCtrl = TextEditingController();
    bool isDeletePermanent = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إلغاء الطلب'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('هل أنت متأكد من إلغاء هذا الطلب؟', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'سبب الإلغاء',
                  hintText: 'مثال: طلب مكرر، زبون تراجع...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Checkbox(
                    value: isDeletePermanent,
                    onChanged: (val) => setDialogState(() => isDeletePermanent = val ?? false),
                  ),
                  const Expanded(
                    child: Text('حذف نهائي (بدلاً من الإلغاء)', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
            FilledButton(
              onPressed: () async {
                if (reasonCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يرجى إدخال سبب الإلغاء'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                try {
                  setState(() => _isLoading = true);
                  await ApiService().post({
                    'action': isDeletePermanent ? 'deleteOrder' : 'cancelOrder',
                    'orderId': widget.order['id'],
                    'cancellation_reason': reasonCtrl.text,
                    'username': widget.session['username'],
                    'token': widget.session['token'],
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isDeletePermanent ? 'تم حذف الطلب نهائياً' : 'تم إلغاء الطلب بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.pop(context, true);
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: Text(isDeletePermanent ? 'حذف نهائي' : 'إلغاء الطلب'),
            ),
          ],
        ),
      ),
    );
  }

  void _showPricingDialog() {
    List<Map<String, dynamic>> editedItems = _items.map((i) => {
      'item_id': i.itemId,
      'name': i.name,
      'quantity_requested': i.quantityRequested,
      'quantity_approved': i.quantityApproved == 0 ? i.quantityRequested : i.quantityApproved,
      'final_price': i.finalPrice == 0 ? (i.priceOffer > 0 ? i.priceOffer : i.defaultPrice) : i.finalPrice,
      'default_price': i.defaultPrice,
      'currency': i.currency,
      'accountant_note': i.accountantNote ?? '',
      'stock': i.stockAvailable,
      'image_url': i.imageUrl,
      'image_file_id': i.imageFileId,
      'image_name': i.imageName,
    }).toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.calculate, color: Colors.blue.shade700),
              ),
              const SizedBox(width: 12),
              const Text('تسعير واعتماد الكميات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ملخص سريع
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('${editedItems.length}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                          const Text('مواد', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      Container(width: 1, height: 30, color: Colors.blue.shade200),
                      Column(
                        children: [
                          FutureBuilder<double>(
                            future: _calculateTotal(editedItems),
                            builder: (context, snapshot) {
                              final total = snapshot.data ?? 0;
                              return Text(
                                '${total.toStringAsFixed(2)}',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade700),
                              );
                            },
                          ),
                          const Text('الإجمالي', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // قائمة المواد
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: editedItems.length,
                    itemBuilder: (context, index) {
                      final item = editedItems[index];
                      final hasStock = (item['stock'] ?? 0) > 0;
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: hasStock ? Colors.green.shade100 : Colors.red.shade100,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // عرض صورة المنتج إذا كانت موجودة
                                  if (item['image_url']?.toString().isNotEmpty == true)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(
                                        item['image_url'],
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                          width: 60,
                                          height: 60,
                                          color: Colors.grey.shade200,
                                          child: Icon(Icons.image_not_supported, color: Colors.grey),
                                        ),
                                        loadingBuilder: (context, child, loadingProgress) {
                                          if (loadingProgress == null) return child;
                                          return Container(
                                            width: 60,
                                            height: 60,
                                            color: Colors.grey.shade100,
                                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                          );
                                        },
                                      ),
                                    )
                                  else
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(Icons.image, color: Colors.grey.shade400),
                                    ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['name'],
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 4),
                                        if (item['default_price'] != null && (item['default_price'] ?? 0) > 0)
                                          Text(
                                            'السعر الافتراضي: ${item['default_price']} ${item['currency'] ?? 'USD'}',
                                            style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontWeight: FontWeight.w500),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: hasStock ? Colors.green.shade100 : Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      hasStock ? 'متوفر' : 'غير متوفر',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: hasStock ? Colors.green.shade800 : Colors.red.shade800,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'المطلوب: ${item['quantity_requested']} | المتوفر: ${item['stock']}',
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        labelText: 'الكمية المعتمدة',
                                        labelStyle: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                                        filled: true,
                                        fillColor: Colors.blue.shade50,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: Colors.blue.shade200),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                                        ),
                                        prefixIcon: const Icon(Icons.production_quantity_limits, size: 20),
                                      ),
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      onChanged: (val) => item['quantity_approved'] = double.tryParse(val) ?? 0,
                                      controller: TextEditingController(text: item['quantity_approved'].toString()),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      decoration: InputDecoration(
                                        labelText: 'السعر النهائي',
                                        labelStyle: TextStyle(fontSize: 12, color: Colors.green.shade700),
                                        filled: true,
                                        fillColor: Colors.green.shade50,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: Colors.green.shade200),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(10),
                                          borderSide: BorderSide(color: Colors.green.shade400, width: 2),
                                        ),
                                        prefixIcon: const Icon(Icons.attach_money, size: 20),
                                      ),
                                      keyboardType: TextInputType.number,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      onChanged: (val) => item['final_price'] = double.tryParse(val) ?? 0,
                                      controller: TextEditingController(text: item['final_price'].toString()),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: item['currency'] == 'USD' ? Colors.blue.shade100 : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: item['currency'] == 'USD' ? Colors.blue.shade300 : Colors.orange.shade300,
                                      ),
                                    ),
                                    child: DropdownButton<String>(
                                      value: item['currency'],
                                      underline: const SizedBox(),
                                      items: ['USD', 'SYP'].map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
                                      onChanged: (val) => setDialogState(() => item['currency'] = val!),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                decoration: InputDecoration(
                                  labelText: 'ملاحظات المحاسب (اختياري)',
                                  labelStyle: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide(color: Colors.grey.shade300),
                                  ),
                                  prefixIcon: const Icon(Icons.note_alt, size: 20),
                                ),
                                maxLines: 2,
                                onChanged: (val) => item['accountant_note'] = val,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.all(16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    label: const Text('إلغاء'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => _confirmAndSubmitPricing(editedItems, context),
                    icon: const Icon(Icons.send),
                    label: const Text('إرسال التسعير للزبون'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<double> _calculateTotal(List<Map<String, dynamic>> items) async {
    double total = 0;
    for (var item in items) {
      final qty = (item['quantity_approved'] ?? 0).toDouble();
      final price = (item['final_price'] ?? 0).toDouble();
      total += qty * price;
    }
    return total;
  }

  void _confirmAndSubmitPricing(List<Map<String, dynamic>> editedItems, BuildContext dialogContext) {
    // التحقق من البيانات
    bool hasError = false;
    String errorMsg = '';
    
    for (var item in editedItems) {
      if ((item['quantity_approved'] ?? 0) <= 0) {
        hasError = true;
        errorMsg = 'يجب تحديد كمية معتمدة لكل مادة';
        break;
      }
      if ((item['final_price'] ?? 0) <= 0) {
        hasError = true;
        errorMsg = 'يجب تحديد سعر نهائي لكل مادة';
        break;
      }
    }

    if (hasError) {
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(
          content: Text(errorMsg),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    // إغلاق حوار التسعير
    Navigator.pop(dialogContext);

    // عرض حوار التأكيد النهائي
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
            ),
            const SizedBox(width: 12),
            const Text('تأكيد إرسال التسعير', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'هل أنت متأكد من إرسال هذا التسعير للزبون؟',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('عدد المواد:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${editedItems.length}', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                    ],
                  ),
                  const Divider(),
                  FutureBuilder<double>(
                    future: _calculateTotal(editedItems),
                    builder: (context, snapshot) {
                      final total = snapshot.data ?? 0;
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('القيمة الإجمالية:', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            '${total.toStringAsFixed(2)}',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700, fontSize: 18),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '⚠️ ملاحظة: بعد الإرسال لا يمكن تعديل التسعيرة إلا بإنشاء تسعيرة جديدة',
              style: TextStyle(fontSize: 12, color: Colors.red, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('عودة للتعديل'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(context); // إغلاق حوار التأكيد
                    await _submitPricingToServer(editedItems);
                  },
                  icon: const Icon(Icons.check_circle),
                  label: const Text('تأكيد وإرسال'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _submitPricingToServer(List<Map<String, dynamic>> editedItems) async {
    try {
      // عرض مؤشر تحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.blue.shade600),
                  const SizedBox(height: 16),
                  const Text('جاري إرسال التسعير...', style: TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ),
        ),
      );

      final response = await ApiService().post({
        'action': 'updateOrderPricing',
        'orderId': widget.order['id'],
        'items': editedItems,
        'username': widget.session['username'],
        'token': widget.session['token'],
      });

      if (!mounted) return;
      Navigator.pop(context); // إغلاق مؤشر التحميل

      if (response['success'] == true) {
        // عرض رسالة نجاح
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.check_circle, color: Colors.green.shade700, size: 28),
                ),
                const SizedBox(width: 12),
                const Text('تم بنجاح', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: const Text(
              'تم إرسال التسعير للزبون بنجاح.\nسيتم إشعار الزبون بمراجعة الفاتورة.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            actions: [
              Center(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _fetchOrderItems();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('تحديث'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        throw Exception(response['error'] ?? 'حدث خطأ غير معروف');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // إغلاق مؤشر التحميل في حال الخطأ
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('خطأ: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showWarehousePrepDialog() {
    List<Map<String, dynamic>> prepItems = _items.map((i) => {
      'item_id': i.itemId,
      'name': i.name,
      'quantity_approved': i.quantityApproved,
      'quantity_prepared': i.quantityPrepared == 0 ? i.quantityApproved : i.quantityPrepared,
      'warehouse_note': i.warehouseNote ?? '',
      'unit': i.unit
    }).toList();

    final pkgCtrl = TextEditingController();
    final ctnCtrl = TextEditingController();
    final bagCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تجهيز الطلبية للمستودع'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: prepItems.length,
                    itemBuilder: (context, index) {
                      final item = prepItems[index];
                      return Card(
                        child: ListTile(
                          title: Text(item['name']),
                          subtitle: Column(
                            children: [
                              Text('الكمية المعتمدة: ${item['quantity_approved']} ${item['unit']}'),
                              TextField(
                                decoration: const InputDecoration(labelText: 'الكمية المجهزة فعلياً'),
                                keyboardType: TextInputType.number,
                                controller: TextEditingController(text: item['quantity_prepared'].toString()),
                                onChanged: (val) => item['quantity_prepared'] = double.tryParse(val) ?? 0,
                              ),
                              TextField(
                                decoration: const InputDecoration(labelText: 'ملاحظات التجهيز (نقص، بديل...)'),
                                onChanged: (val) => item['warehouse_note'] = val,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(),
                Row(
                  children: [
                    Expanded(child: TextField(controller: pkgCtrl, decoration: const InputDecoration(labelText: 'إجمالي الطرود'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 4),
                    Expanded(child: TextField(controller: ctnCtrl, decoration: const InputDecoration(labelText: 'كراتين'), keyboardType: TextInputType.number)),
                    const SizedBox(width: 4),
                    Expanded(child: TextField(controller: bagCtrl, decoration: const InputDecoration(labelText: 'أكياس'), keyboardType: TextInputType.number)),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                try {
                  await ApiService().post({
                    'action': 'confirmWarehousePrep',
                    'orderId': widget.order['id'],
                    'items': prepItems,
                    'package_count': int.tryParse(pkgCtrl.text) ?? 0,
                    'carton_count': int.tryParse(ctnCtrl.text) ?? 0,
                    'bag_count': int.tryParse(bagCtrl.text) ?? 0,
                    'username': widget.session['username'],
                    'token': widget.session['token'],
                  });
                  if (!mounted) return;
                  Navigator.pop(context);
                  _fetchOrderItems();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
              child: const Text('إتمام التجهيز'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerEditDialog() {
    // Clone items locally for editing
    List<Map<String, dynamic>> localItems = _items.map((i) => {
      'item_id': i.itemId,
      'name': i.name,
      'quantity_requested': i.quantityRequested,
      'quantity_approved': i.quantityApproved,
      'unit': i.unit,
    }).toList();
    List<String> deletedItemIds = [];
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل بنود الطلبية'),
          content: SizedBox(
            width: double.maxFinite,
            child: localItems.isEmpty 
              ? const Center(child: Text('تم حذف جميع البنود أو لا يوجد بنود لتعديلها'))
              : ListView.builder(
              itemCount: localItems.length,
              itemBuilder: (context, index) {
                final item = localItems[index];
                final double approved = (item['quantity_approved'] ?? 0).toDouble();
                final double requested = (item['quantity_requested'] ?? 0).toDouble();
                
                return ListTile(
                  title: Text(item['name'] ?? 'منتج', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                            onPressed: requested > (approved > 0 ? approved : 1)
                              ? () => setDialogState(() => item['quantity_requested']--)
                              : null,
                          ),
                          Text('$requested', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                            onPressed: () => setDialogState(() => item['quantity_requested']++),
                          ),
                          const SizedBox(width: 8),
                          Text(item['unit'] ?? ''),
                        ],
                      ),
                      if (approved > 0)
                        Text('الحد الأدنى (المعتمد): $approved', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_sweep, color: Colors.red),
                    onPressed: () {
                      setDialogState(() {
                        deletedItemIds.add(localItems[index]['item_id']);
                        localItems.removeAt(index);
                      });
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                try {
                  List<Map<String, dynamic>> payload = [];
                  
                  // Add updates
                  for (var item in localItems) {
                    payload.add({
                      'item_id': item['item_id'],
                      'quantity': item['quantity_requested'],
                      'action': 'update'
                    });
                  }
                  
                  // Add deletions
                  for (var id in deletedItemIds) {
                    payload.add({
                      'item_id': id,
                      'action': 'delete'
                    });
                  }
                  
                  if (payload.isEmpty) {
                    Navigator.pop(context);
                    return;
                  }

                  setState(() => _isLoading = true);
                  await ApiService().post({
                    'action': 'updateCustomerOrder',
                    'orderId': widget.order['id'],
                    'items': payload,
                    'username': widget.session['username'],
                    'token': widget.session['token'],
                  });
                  
                  if (!mounted) return;
                  Navigator.pop(context);
                  _fetchOrderItems();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تحديث الطلبية بنجاح'), backgroundColor: Colors.green)
                  );
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red));
                  }
                }
              },
              child: const Text('حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }
}

