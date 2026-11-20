import 'package:flutter/services.dart';
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
import 'widgets/order_items_list_view.dart';
import 'widgets/order_actions_widget.dart';
import 'widgets/order_shipping_widget.dart';
import 'widgets/order_empty_state_widget.dart';
import '../widgets/order_skeleton.dart';
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
  bool _isCancelling = false;

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

  Future<void> _updateStatus(String newStatus,
      {String? reason, bool proxyForCustomer = false}) async {
    if (_provider == null) return;
    final success = await _provider!.updateStatus(
      newStatus,
      reason: reason,
      proxyForCustomer: proxyForCustomer,
    );

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

  Future<void> _showProxyCustomerConfirm(OrderDetailProvider provider) async {
    final order = provider.currentOrder;
    if (order == null) return;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تأكيد السعر نيابةً عن الزبون'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الطلب: ${order.orderNumber.isNotEmpty ? order.orderNumber : order.orderId}\n'
                  'الزبون: ${order.customerName.isNotEmpty ? order.customerName : order.customerId}',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'سبب تنفيذ الإجراء نيابةً عن الزبون',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: reasonController.text.trim().length >= 3
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('تأكيد نيابةً عنه'),
            ),
          ],
        ),
      ),
    );
    final proxyReason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed == true && mounted) {
      await _updateStatus(
        'customer_confirmed',
        reason: proxyReason,
        proxyForCustomer: true,
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
          if (!_isInitialized ||
              (provider.isLoading && provider.currentOrder == null)) {
            return Scaffold(
              appBar: AppBar(title: Text('طلب #${widget.orderId}')),
              body: OrderDetailsSkeleton(),
            );
          }

          if (provider.errorMessage != null && provider.currentOrder == null) {
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
                  tooltip: 'نسخ رقم الطلب',
                  icon: const Icon(Icons.copy),
                  onPressed: () async {
                    await Clipboard.setData(
                        ClipboardData(text: order.orderNumber));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نسخ رقم الطلب')),
                    );
                  },
                ),
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
                if (provider.isLoading)
                  const LinearProgressIndicator(minHeight: 2),
                if (provider.errorMessage != null)
                  MaterialBanner(
                    content:
                        Text('تعذر تحديث التفاصيل: ${provider.errorMessage}'),
                    actions: [
                      TextButton(
                        onPressed: _fetchDetails,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withValues(alpha: 0.3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            order.customerName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          _buildStatusBadge(order.status),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant),
                          const SizedBox(width: 4),
                          Text(
                            'تاريخ الطلب: ${order.createdAt?.toString().split(' ')[0] ?? ''}',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 13),
                          ),
                        ],
                      ),
                      if (order.createdByRole?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.person_outline,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              'أدخل الطلب: ${order.createdBy ?? ''} (${PermissionHelper.getRoleNameAr(PermissionHelper.fromString(order.createdByRole!))})',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                      if (order.note?.isNotEmpty == true) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.note,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  order.note!,
                                  style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                      fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
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
                isBusy: provider.isLoading || _isCancelling,
                onPrice: () => _navigateToPricing(provider),
                onApprove: () => _updateStatus(
                  userRole == AppRole.customer
                      ? 'customer_confirmed'
                      : 'approved',
                ),
                onProxyCustomerConfirm: () =>
                    _showProxyCustomerConfirm(provider),
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
    final hasHistoricalPrices = provider.items.every(
      (item) => item.hasConfiguredUnitPrice || item.isUnavailable,
    );

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
            if (!hasPricing && hasHistoricalPrices)
              _summaryRow('إجمالي الكميات المطلوبة:',
                  '${initialTotal.toStringAsFixed(2)} ${order.currency}'),
            if (!hasHistoricalPrices && provider.items.isNotEmpty)
              Text(
                'لا تتوفر أسعار محفوظة لبعض البنود.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (hasPricing && hasHistoricalPrices)
              _summaryRow('إجمالي الفاتورة المسعرة:',
                  '${approvedTotal.toStringAsFixed(2)} ${order.currency}',
                  color: Theme.of(context).colorScheme.primary),
            if (discount > 0)
              _summaryRow(
                  'الخصم:', '-${discount.toStringAsFixed(2)} ${order.currency}',
                  color: Theme.of(context).colorScheme.error),
            if (shipping > 0)
              _summaryRow('تكلفة الشحن:',
                  '+${shipping.toStringAsFixed(2)} ${order.currency}'),
            const Divider(),
            _summaryRow('صافي الفاتورة:',
                '${finalAmount.toStringAsFixed(2)} ${order.currency}',
                isBold: true, color: Theme.of(context).primaryColor),
            if (order.previousBalance != null) ...[
              const SizedBox(height: 8),
              _summaryRow('رصيد الحساب السابق:',
                  '${order.previousBalance!.toStringAsFixed(2)} ${order.currency}'),
              _summaryRow('الرصيد النهائي المتوقع:',
                  '${(order.previousBalance! + finalAmount).toStringAsFixed(2)} ${order.currency}',
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

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        _getStatusText(status),
        style:
            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Color _getStatusColor(String status) {
    return Color(OrderStatusMapper.getStatusColorHex(status));
  }

  String _getStatusText(String status) {
    return OrderStatusMapper.getArabicStatus(status);
  }

  Future<void> _showCancelConfirmation(OrderDetailProvider provider) async {
    if (_isCancelling) return;
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تأكيد إلغاء الطلب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('سيُحفظ سبب الإلغاء وسجل العملية.'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'سبب الإلغاء (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('رجوع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () =>
                Navigator.pop(dialogContext, reasonController.text.trim()),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;

    setState(() => _isCancelling = true);
    final success = await provider.cancelOrder(
      reason: reason.isEmpty ? null : reason,
    );
    if (!mounted) return;
    setState(() => _isCancelling = false);
    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر إلغاء الطلب: ${provider.errorMessage}'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
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
                  data: provider.items.map((item) {
                    final qty = hasPricing
                        ? item.pricedQuantity
                        : (item.quantityRequested ?? 0);
                    String qtyStr = '$qty ${item.unit}';
                    if (item.unitFactor != null && item.unitFactor! != 1.0) {
                      final baseQty =
                          (qty * item.unitFactor!).toStringAsFixed(2);
                      qtyStr += ' ($baseQty ${item.unit1 ?? ''})';
                    }

                    return [
                      item.name,
                      item.isUnavailable && hasPricing ? 'غير متوفر' : qtyStr,
                      item.isUnavailable && hasPricing
                          ? '-'
                          : formatMoneyShort(
                              hasPricing
                                  ? item.pricedUnitPrice
                                  : item.displayPrice,
                              currency: item.currency,
                            ),
                      formatMoneyShort(
                        hasPricing ? item.pricedLineTotal : item.total,
                        currency: item.currency,
                      ),
                    ];
                  }).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerRight,
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    'الإجمالي: ${formatMoneyShort(order?.totalAmount ?? provider.total, currency: order?.currency ?? 'USD')}',
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
