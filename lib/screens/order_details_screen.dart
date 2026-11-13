import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../order_status_mapper.dart';
import '../providers/order_detail_provider.dart';
import '../repositories/order_repository.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../utils/number_utils.dart';
import '../utils/permissions.dart';
import '../utils/order_edit_policy.dart';
import 'widgets/order_header_widget.dart';
import 'widgets/order_items_list_view.dart';
import 'widgets/order_actions_widget.dart';
import 'widgets/order_shipping_widget.dart';
import 'widgets/order_empty_state_widget.dart';
import 'order_pricing_screen.dart';
import 'order_edit_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final String orderId;
  final Map<String, dynamic>? session;

  const OrderDetailsScreen({super.key, required this.orderId, this.session});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  OrderDetailProvider? _provider;
  String? _role;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _role =
        (widget.session?['role'] ?? ApiService().currentUser?['role'] ?? 'user')
            .toString()
            .toLowerCase();
    _initializeData();
  }

  void _initializeData() {
    final repository = OrderRepository(db: context.read<AppDatabase>());
    _provider = OrderDetailProvider(repository);

    // Start fetching
    _fetchDetails();

    // Mark as read for management roles
    if (['admin', 'manager', 'accountant'].contains(_role)) {
      _markOrderAsRead();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-fetch if we navigated back to this screen
    // but initState only runs once. Using a route observer is better,
    // but here we rely on the .then() in navigation.
  }

  Future<void> _fetchDetails() async {
    if (_provider == null) return;

    await _provider!.fetchOrderDetails(widget.orderId);

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  Future<void> _markOrderAsRead() async {
    try {
      // Logic for marking order as read could be added here or in provider
    } catch (e) {
      debugPrint('Error marking order as read: $e');
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_provider == null) return;
    final success = await _provider!.updateStatus(newStatus);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('تم تحديث حالة الطلب إلى: ${_getStatusText(newStatus)}'),
            backgroundColor: Theme.of(context).colorScheme.primary),
      );
      await _fetchDetails();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التحديث: ${_provider!.errorMessage}')),
      );
    }
  }

  Future<void> _startOrResumeWarehousePrep(OrderDetailProvider provider) async {
    final order = provider.currentOrder;
    if (order == null) return;
    if (order.status.toLowerCase() == 'approved') {
      await _updateStatus('preparing');
      if (!mounted ||
          provider.currentOrder?.status.toLowerCase() != 'preparing') {
        return;
      }
    }
    if (provider.currentOrder?.status.toLowerCase() == 'preparing') {
      await _showWarehousePrepDialog(provider);
    }
  }

  Future<void> _showWarehousePrepDialog(OrderDetailProvider provider) async {
    final items = provider.items;
    final quantityControllers = items
        .map((item) => TextEditingController(
              text: (item.isUnavailable
                      ? 0
                      : item.quantityPrepared ??
                          item.quantityApproved ??
                          item.quantityRequested ??
                          0)
                  .toString(),
            ))
        .toList();
    final packageNumberControllers = items
        .map((item) => TextEditingController(
              text: item.warehousePackageNumbers ?? '',
            ))
        .toList();
    final noteControllers = items
        .map((item) => TextEditingController(text: item.warehouseNote ?? ''))
        .toList();
    final customTypeControllers = items
        .map((item) => TextEditingController(
              text: item.warehouseCustomPackageType ?? '',
            ))
        .toList();
    final packageTypes = items.map((item) {
      final type = item.warehousePackageType;
      return ['carton', 'bag', 'other'].contains(type) ? type : null;
    }).toList();
    final generalNoteController = TextEditingController(
      text: provider.shipmentData?['warehouse_note']?.toString() ?? '',
    );
    var saving = false;
    String? errorText;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعبئة وتجهيز الفاتورة'),
          content: SizedBox(
            width: 560,
            height: MediaQuery.of(context).size.height * 0.65,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final packageType = packageTypes[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'الكمية المعتمدة: ${item.quantityApproved ?? item.quantityRequested ?? 0} ${item.unit}',
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: quantityControllers[index],
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                  decimal: true,
                                ),
                                decoration: InputDecoration(
                                  labelText:
                                      'الكمية التي تم تجهيزها (${item.unit})',
                                ),
                              ),
                              TextField(
                                controller: packageNumberControllers[index],
                                decoration: const InputDecoration(
                                  labelText: 'رقم الطرد (مثال: 1 أو 1-2)',
                                ),
                              ),
                              DropdownButtonFormField<String>(
                                initialValue: packageType,
                                decoration: const InputDecoration(
                                  labelText: 'نوع الطرد',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'carton',
                                    child: Text('كرتونة'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'bag',
                                    child: Text('كيس'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'other',
                                    child: Text('أخرى'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setDialogState(
                                      () => packageTypes[index] = value);
                                },
                              ),
                              if (packageType == 'other')
                                TextField(
                                  controller: customTypeControllers[index],
                                  decoration: const InputDecoration(
                                    labelText: 'اكتب نوع الطرد',
                                  ),
                                ),
                              TextField(
                                controller: noteControllers[index],
                                decoration: const InputDecoration(
                                  labelText: 'ملاحظة على هذا البند',
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                TextField(
                  controller: generalNoteController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات عامة للمستودع',
                  ),
                  maxLines: 2,
                ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      errorText!,
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  saving ? null : () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      final payload = <Map<String, dynamic>>[];
                      for (var index = 0; index < items.length; index++) {
                        final quantity = double.tryParse(
                          quantityControllers[index].text.trim(),
                        );
                        if (quantity == null || quantity < 0) {
                          setDialogState(() {
                            errorText = 'تحقق من الكميات المدخلة لكل بند';
                          });
                          return;
                        }
                        payload.add({
                          'item_id': items[index].itemId,
                          'quantity_prepared': quantity,
                          'warehouse_package_numbers':
                              packageNumberControllers[index].text.trim(),
                          'warehouse_package_type': packageTypes[index] ?? '',
                          'warehouse_custom_package_type':
                              customTypeControllers[index].text.trim(),
                          'warehouse_note': noteControllers[index].text.trim(),
                        });
                      }

                      setDialogState(() {
                        saving = true;
                        errorText = null;
                      });
                      final success = await provider.confirmWarehousePrep(
                        items: payload,
                        warehouseNote: generalNoteController.text.trim(),
                      );
                      if (!context.mounted) return;
                      if (success) {
                        Navigator.pop(dialogContext, true);
                      } else {
                        setDialogState(() {
                          saving = false;
                          errorText = provider.errorMessage ??
                              'تعذر حفظ بيانات التعبئة';
                        });
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('تم التجهيز'),
            ),
          ],
        ),
      ),
    );

    for (final controller in [
      ...quantityControllers,
      ...packageNumberControllers,
      ...noteControllers,
      ...customTypeControllers,
      generalNoteController,
    ]) {
      controller.dispose();
    }
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تم حفظ التعبئة ونقل الطلب إلى جاهز للشحن')),
      );
      await _fetchDetails();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_provider == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final userRole = PermissionHelper.fromString(_role ?? 'user');
    final canPrice =
        PermissionHelper.hasPermission(userRole, AppPermission.priceOrder);

    return ChangeNotifierProvider.value(
      value: _provider!,
      child: Consumer<OrderDetailProvider>(
        builder: (context, provider, child) {
          if (!_isInitialized || provider.isLoading) {
            return Scaffold(
              appBar: AppBar(title: Text('طلب #${widget.orderId}')),
              body: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('جاري جلب تفاصيل الطلبية...'),
                  ],
                ),
              ),
            );
          }

          if (provider.errorMessage != null) {
            return Scaffold(
              appBar: AppBar(title: const Text('خطأ')),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          color: Theme.of(context).colorScheme.error, size: 60),
                      const SizedBox(height: 16),
                      Text('خطأ: ${provider.errorMessage}',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchDetails,
                        child: const Text('إعادة المحاولة'),
                      )
                    ],
                  ),
                ),
              ),
            );
          }

          final order = provider.currentOrder;
          if (order == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('طلب غير موجود')),
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    const Text('الطلب غير موجود'),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('العودة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final status = order.status.toLowerCase();
          final canSeeFinancials = PermissionHelper.hasPermission(
                  userRole, AppPermission.viewProductPrices) ||
              PermissionHelper.hasPermission(
                  userRole, AppPermission.viewFinancials);

          return Scaffold(
            appBar: AppBar(
              title: Text('طلب #${order.orderNumber}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: () => _exportOrderPdf(provider),
                  tooltip: 'تصدير PDF',
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _fetchDetails,
                  tooltip: 'تحديث',
                ),
                if (canPrice)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'price') _navigateToPricing(provider);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'price',
                        child: ListTile(
                          leading: Icon(Icons.monetization_on),
                          title: Text('تسعير الطلب'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            body: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withAlpha(50),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('الحالة: ${_getStatusText(order.status)}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _getStatusColor(order.status),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              order.status,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onPrimary,
                                  fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                          'تاريخ الطلب: ${order.createdAt?.toString().split(' ')[0] ?? ''}'),
                      if (order.createdByRole?.isNotEmpty == true)
                        Text(
                          'أدخل الطلب: ${order.createdBy ?? ''} (${PermissionHelper.getRoleNameAr(PermissionHelper.fromString(order.createdByRole!))})',
                        ),
                      if (order.note?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text('ملاحظة: ${order.note}',
                            style:
                                const TextStyle(fontStyle: FontStyle.italic)),
                      ]
                    ],
                  ),
                ),
                Expanded(
                  child: provider.items.isEmpty
                      ? const OrderEmptyStateWidget()
                      : ListView(
                          padding: const EdgeInsets.all(8),
                          children: [
                            OrderHeaderWidget(
                              order: order,
                              statusText: _getStatusText(order.status),
                              statusColor: _getStatusColor(order.status),
                            ),
                            const Divider(),
                            OrderItemsListView(role: _role ?? 'user'),
                            if (provider.shipmentData != null)
                              OrderShippingWidget(
                                  shipmentData: provider.shipmentData!,
                                  role: _role ?? 'user'),
                            if (canSeeFinancials && provider.items.isNotEmpty)
                              _buildOrderFinancialSummary(provider),
                          ],
                        ),
                ),
              ],
            ),
            bottomNavigationBar: SafeArea(
              child: OrderActionsWidget(
                status: status,
                userRole: userRole,
                onPrice: () => _navigateToPricing(provider),
                onApprove: () => _updateStatus(
                  userRole == AppRole.customer
                      ? 'customer_confirmed'
                      : 'approved',
                ),
                onCancel: () => _showCancelConfirmation(provider),
                onPrepare: () => _startOrResumeWarehousePrep(provider),
                onShip: () => _showShippingDialog(provider),
                onPrint: () => _exportOrderPdf(provider),
                onEdit: () => _editOrder(provider, userRole),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrderFinancialSummary(OrderDetailProvider provider) {
    final order = provider.currentOrder;
    if (order == null) return const SizedBox.shrink();

    final hasPricing = OrderStatusMapper.hasPricing(order.status);

    // Initial total based on requested quantities
    final initialTotal = provider.items.fold(
        0.0,
        (sum, item) =>
            sum + (item.displayPrice * (item.quantityRequested ?? 0.0)));

    // Final total based on approved quantities (if available)
    final approvedTotal = provider.subtotal;

    final discount = provider.discount ?? 0.0;
    final shipping = provider.shippingCost ?? 0.0;
    final finalAmount = order.totalAmount ?? provider.total;

    return Card(
      margin: const EdgeInsets.only(top: 16, bottom: 80),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الملخص المالي',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            if (!hasPricing)
              _summaryRow('إجمالي الكميات المطلوبة:',
                  '\$${initialTotal.toStringAsFixed(2)}'),
            if (hasPricing)
              _summaryRow('إجمالي الفاتورة المسعرة:',
                  '\$${approvedTotal.toStringAsFixed(2)}',
                  color: Theme.of(context).colorScheme.primary),
            if (discount > 0)
              _summaryRow('الخصم:', '-\$${discount.toStringAsFixed(2)}',
                  color: Theme.of(context).colorScheme.error),
            if (shipping > 0)
              _summaryRow('تكلفة الشحن:', '+\$${shipping.toStringAsFixed(2)}'),
            const Divider(),
            _summaryRow('صافي الفاتورة:', '\$${finalAmount.toStringAsFixed(2)}',
                isBold: true, color: Theme.of(context).primaryColor),
            if (order.previousBalance != null) ...[
              const SizedBox(height: 8),
              _summaryRow('رصيد الحساب السابق:',
                  '\$${order.previousBalance!.toStringAsFixed(2)}'),
              _summaryRow('الرصيد النهائي المتوقع:',
                  '\$${(order.previousBalance! + finalAmount).toStringAsFixed(2)}',
                  isBold: true, color: Theme.of(context).colorScheme.primary),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value,
      {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    final colors = Theme.of(context).colorScheme;
    switch (status.toLowerCase()) {
      case 'pending':
        return colors.tertiary;
      case 'submitted':
        return colors.primary;
      case 'processing':
      case 'preparing':
        return colors.secondary;
      case 'priced':
        return colors.primary;
      case 'customer_confirmed':
      case 'approved':
        return colors.primary;
      case 'rejected':
      case 'cancelled':
        return colors.error;
      default:
        return colors.onSurfaceVariant;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'بانتظار التسعير';
      case 'submitted':
        return 'مُرسَل';
      case 'processing':
        return 'قيد المعالجة';
      case 'priced':
        return 'بانتظار تأكيد السعر';
      case 'customer_confirmed':
        return 'مؤكدة من الزبون';
      case 'approved':
        return 'مُعتمَد';
      case 'rejected':
        return 'مرفوض';
      case 'cancelled':
        return 'مُلغى';
      case 'preparing':
        return 'قيد التجهيز';
      case 'prepared':
      case 'ready_for_shipping':
        return 'جاهز للشحن';
      case 'shipping':
        return 'تم الشحن';
      default:
        return status;
    }
  }

  void _showCancelConfirmation(OrderDetailProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الإلغاء'),
        content: const Text(
            'هل أنت متأكد من رغبتك في إلغاء هذه الطلبية؟ لا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تراجع'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus('cancelled');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
  }

  void _showShippingDialog(OrderDetailProvider provider) {
    final carrierController = TextEditingController();
    final trackingController = TextEditingController();
    final packagesController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('بيانات الشحن'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: carrierController,
              decoration:
                  const InputDecoration(labelText: 'شركة الشحن / السائق'),
            ),
            TextField(
              controller: trackingController,
              decoration:
                  const InputDecoration(labelText: 'رقم التتبع / البوليصة'),
            ),
            TextField(
              controller: packagesController,
              decoration: const InputDecoration(labelText: 'عدد الطرود'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.setShipmentData({
                'carrier': carrierController.text,
                'tracking': trackingController.text,
                'packages': packagesController.text,
                'shipped_at': DateTime.now().toIso8601String(),
              });
              Navigator.pop(context);
              _updateStatus('shipping');
            },
            child: const Text('تأكيد الشحن'),
          ),
        ],
      ),
    );
  }

  void _navigateToPricing(OrderDetailProvider provider) {
    if (provider.currentOrder == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderPricingScreen(
          order: provider.currentOrder!,
        ),
      ),
    ).then((_) => _fetchDetails()); // Refresh when back
  }

  Future<void> _editOrder(
      OrderDetailProvider provider, AppRole userRole) async {
    final order = provider.currentOrder;
    if (order == null || !OrderEditPolicy.canEdit(userRole, order.status)) {
      return;
    }

    if (userRole == AppRole.warehouse) {
      await _startOrResumeWarehousePrep(provider);
      return;
    }

    final updated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => OrderEditScreen(order: order, role: userRole),
      ),
    );
    if (updated == true && mounted) await _fetchDetails();
  }

  Future<void> _exportOrderPdf(OrderDetailProvider provider) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.almaraiRegular();
    final fontBold = await PdfGoogleFonts.almaraiBold();
    final order = provider.currentOrder;
    final hasPricing = OrderStatusMapper.hasPricing(order?.status);

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
                    pw.Text('فاتورة طلبية',
                        style: pw.TextStyle(
                            fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('ORCA ORDER',
                        style:
                            pw.TextStyle(fontSize: 18, color: PdfColors.blue)),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Text('رقم الطلب: ${order?.orderNumber ?? widget.orderId}'),
                pw.Text(
                    'التاريخ: ${order?.createdAt?.toString().split(' ')[0] ?? ''}'),
                pw.Text('الحالة: ${_getStatusText(order?.status ?? '')}'),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: [
                    'الصنف',
                    hasPricing ? 'الكمية المسعرة' : 'الكمية',
                    'السعر',
                    'الإجمالي'
                  ],
                  data: provider.items
                      .map((item) => [
                            item.name,
                            item.isUnavailable && hasPricing
                                ? 'غير متوفر'
                                : '${hasPricing ? item.pricedQuantity : item.quantityRequested} ${item.unit}',
                            item.isUnavailable && hasPricing
                                ? '-'
                                : formatMoneyShort(
                                    hasPricing
                                        ? item.pricedUnitPrice
                                        : item.displayPrice,
                                  ),
                            formatMoneyShort(
                              hasPricing ? item.pricedLineTotal : item.total,
                            ),
                          ])
                      .toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerRight,
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    'الإجمالي: ${(order?.totalAmount ?? provider.total).toStringAsFixed(2)} USD',
                    style: pw.TextStyle(
                        fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
