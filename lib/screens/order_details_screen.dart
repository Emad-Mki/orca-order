import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_config.dart';
import '../order_status_mapper.dart';
import '../models/order.dart';
import '../providers/order_detail_provider.dart';
import '../providers/orders_provider.dart';
import '../repositories/order_repository.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/invoice_product_images.dart';
import '../services/warehouse_preparation_draft_store.dart';
import '../utils/permissions.dart';
import '../utils/order_edit_policy.dart';
import '../utils/shipment_summary.dart';
import 'widgets/order_items_list_view.dart';
import 'widgets/order_actions_widget.dart';
import 'widgets/order_shipping_widget.dart';
import 'widgets/order_empty_state_widget.dart';
import '../widgets/order_skeleton.dart';
import 'order_pricing_screen.dart';
import 'order_edit_screen.dart';
import 'sales_invoice_pdf_screen.dart';

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

    _isInitialized = true;
    await _provider!.fetchOrderDetails(widget.orderId);

    if (mounted) {
      setState(() => _isInitialized = true);
      if (!_provider!.isStale && _provider!.currentOrder != null) {
        unawaited(_cacheOrderImages(_provider!));
      }
    }
  }

  Future<void> _cacheOrderImages(OrderDetailProvider provider) async {
    final user = ApiService().currentUser;
    final id =
        (user?['user_id'] ?? user?['id'] ?? user?['customer_id'])?.toString() ??
            '';
    final role =
        PermissionHelper.fromString(user?['role']?.toString() ?? '').name;
    if (id.isEmpty) return;
    final environment = '${AppConfig.environmentName}:${AppConfig.apiUrl}';
    final store = InvoiceProductImages(
      scope: invoiceImageScope(environment, id, role),
    );
    final urls = <String, String>{
      for (final item in provider.items)
        if (item.imageUrl?.trim().isNotEmpty == true) item.code: item.imageUrl!,
    };
    try {
      await store.cache('order-${widget.orderId}', urls);
    } catch (error) {
      debugPrint('Order image caching failed: ${error.runtimeType}');
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
    final order = _provider!.currentOrder;
    if (newStatus == 'approved' &&
        order != null &&
        _canEditAccountingInvoiceNo &&
        (order.accountingInvoiceNo?.trim().isEmpty ?? true)) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('رقم الفاتورة المحاسبي غير مضاف'),
          content: const Text(
            'يمكنك الاعتماد الآن وإضافة الرقم لاحقاً، لكن يفضّل إدخاله قبل الاعتماد.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('العودة لإضافة الرقم'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('المتابعة دون رقم'),
            ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    final success = await _provider!.updateStatus(
      newStatus,
      reason: reason,
      proxyForCustomer: proxyForCustomer,
    );

    if (!mounted) return;

    if (success) {
      final orders = context.read<OrdersProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('تم تحديث حالة الطلب إلى: ${_getStatusText(newStatus)}'),
            backgroundColor: Theme.of(context).colorScheme.primary),
      );
      await _fetchDetails();
      await orders.syncAfterMutation(
          orderId: widget.orderId, status: newStatus);
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
                if (order.totalAmount != null) ...[
                  const SizedBox(height: 8),
                  Text('مبلغ العرض: ${order.totalAmount} ${order.currency}'),
                ],
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
    final user = ApiService().currentUser ?? widget.session ?? {};
    final userId = (user['user_id'] ??
            user['id'] ??
            user['customer_id'] ??
            user['username'])
        ?.toString()
        .trim();
    final draftScope = userId == null || userId.isEmpty
        ? null
        : '${AppConfig.environmentName}:${AppConfig.apiUrl}:$userId:'
            '${user['role'] ?? _role}:${widget.orderId}';
    const draftStore = WarehousePreparationDraftStore();
    Map<String, dynamic>? savedDraft;
    String? draftLoadError;
    if (draftScope != null) {
      try {
        savedDraft = await draftStore.load(draftScope);
      } catch (error) {
        draftLoadError = error.toString();
      }
    }
    if (!mounted) return;
    final savedItems = <String, Map<String, dynamic>>{};
    final savedRows = savedDraft?['items'];
    if (savedRows is List) {
      for (final row in savedRows) {
        if (row is Map && row['item_id'] != null) {
          savedItems[row['item_id'].toString()] =
              Map<String, dynamic>.from(row);
        }
      }
    }
    String savedValue(String itemId, String key, String fallback) {
      return savedItems[itemId]?[key]?.toString() ?? fallback;
    }

    final quantityControllers = items
        .map((item) => TextEditingController(
              text: savedValue(
                item.itemId.toString(),
                'quantity_prepared',
                (item.isUnavailable
                        ? 0
                        : item.quantityPrepared ??
                            item.quantityApproved ??
                            item.quantityRequested ??
                            0)
                    .toString(),
              ),
            ))
        .toList();
    final packageNumberControllers = items
        .map((item) => TextEditingController(
              text: savedValue(
                  item.itemId.toString(),
                  'warehouse_package_numbers',
                  item.warehousePackageNumbers ?? ''),
            ))
        .toList();
    final noteControllers = items
        .map((item) => TextEditingController(
              text: savedValue(item.itemId.toString(), 'warehouse_note',
                  item.warehouseNote ?? ''),
            ))
        .toList();
    final customTypeControllers = items
        .map((item) => TextEditingController(
              text: savedValue(
                  item.itemId.toString(),
                  'warehouse_custom_package_type',
                  item.warehouseCustomPackageType ?? ''),
            ))
        .toList();
    final packageTypes = items.map((item) {
      final savedType =
          savedItems[item.itemId.toString()]?['warehouse_package_type'];
      if (['carton', 'bag', 'other'].contains(savedType)) {
        return savedType as String;
      }
      final type = item.warehousePackageType;
      return ['carton', 'bag', 'other'].contains(type) ? type : null;
    }).toList();
    final generalNoteController = TextEditingController(
      text: savedDraft?['warehouse_note']?.toString() ??
          provider.shipmentData?['warehouse_note']?.toString() ??
          '',
    );
    var saving = false;
    String? errorText;
    String? draftSaveError;
    Timer? draftTimer;
    var draftWrites = Future<void>.value();

    Future<void> persistDraft() {
      if (draftScope == null) return Future<void>.value();
      final draft = <String, dynamic>{
        'items': [
          for (var index = 0; index < items.length; index++)
            {
              'item_id': items[index].itemId,
              'quantity_prepared': quantityControllers[index].text.trim(),
              'warehouse_package_numbers':
                  packageNumberControllers[index].text.trim(),
              'warehouse_package_type': packageTypes[index] ?? '',
              'warehouse_custom_package_type':
                  customTypeControllers[index].text.trim(),
              'warehouse_note': noteControllers[index].text.trim(),
            },
        ],
        'warehouse_note': generalNoteController.text.trim(),
      };
      final nextWrite =
          draftWrites.then((_) => draftStore.save(draftScope, draft));
      draftWrites = nextWrite;
      return nextWrite;
    }

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          void scheduleDraftSave() {
            if (draftScope == null) return;
            draftTimer?.cancel();
            draftTimer = Timer(const Duration(milliseconds: 350), () async {
              try {
                await persistDraft();
                if (context.mounted) {
                  setDialogState(() => draftSaveError = null);
                }
              } catch (error) {
                if (context.mounted) {
                  setDialogState(() => draftSaveError = error.toString());
                }
              }
            });
          }

          return AlertDialog(
            title: const Text('تعبئة وتجهيز الفاتورة'),
            content: SizedBox(
              width: 560,
              height: MediaQuery.of(context).size.height * 0.65,
              child: Column(
                children: [
                  if (savedDraft != null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child:
                          Text('تم استعادة مسودة التجهيز المحفوظة على الجهاز'),
                    ),
                  if (draftScope == null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text('تعذر تحديد الحساب؛ لن تُحفظ المسودة محليًا'),
                    ),
                  if (draftLoadError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        'تعذر قراءة المسودة المحلية: $draftLoadError',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
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
                                  onChanged: (_) => scheduleDraftSave(),
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
                                  onChanged: (_) => scheduleDraftSave(),
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
                                    scheduleDraftSave();
                                  },
                                ),
                                if (packageType == 'other')
                                  TextField(
                                    controller: customTypeControllers[index],
                                    onChanged: (_) => scheduleDraftSave(),
                                    decoration: const InputDecoration(
                                      labelText: 'اكتب نوع الطرد',
                                    ),
                                  ),
                                TextField(
                                  controller: noteControllers[index],
                                  onChanged: (_) => scheduleDraftSave(),
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
                    onChanged: (_) => scheduleDraftSave(),
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
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                  if (draftSaveError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'تعذر حفظ المسودة المحلية: $draftSaveError',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
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
                        draftTimer?.cancel();
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
                            'warehouse_note':
                                noteControllers[index].text.trim(),
                          });
                        }

                        setDialogState(() {
                          saving = true;
                          errorText = null;
                        });
                        try {
                          await persistDraft();
                        } catch (error) {
                          setDialogState(() {
                            draftSaveError = error.toString();
                          });
                        }
                        final success = await provider.confirmWarehousePrep(
                          items: payload,
                          warehouseNote: generalNoteController.text.trim(),
                        );
                        if (!context.mounted) return;
                        if (success) {
                          try {
                            if (draftScope != null) {
                              await draftStore.clear(draftScope);
                            }
                          } catch (error) {
                            setDialogState(() {
                              draftSaveError = error.toString();
                            });
                          }
                          if (!dialogContext.mounted) return;
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
          );
        },
      ),
    );

    draftTimer?.cancel();
    if (saved != true && draftScope != null) {
      try {
        await persistDraft();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('تعذر حفظ المسودة المحلية: $error'),
          ));
        }
      }
    }
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
                if (canPrice && !provider.isStale && !provider.isLoading)
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
                if (provider.isStale)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'نسخة محفوظة قديمة محتملة؛ إجراءات تعديل الطلب متوقفة حتى التحديث.',
                    ),
                  ),
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
                  child: ListView(
                    padding: const EdgeInsets.all(8),
                    children: [
                      if (provider.items.isEmpty)
                        const OrderEmptyStateWidget()
                      else
                        OrderItemsListView(role: _role ?? 'user'),
                      if (provider.shipmentData != null)
                        OrderShippingWidget(
                            shipmentData: provider.shipmentData!,
                            role: _role ?? 'user'),
                      if (canSeeFinancials)
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
                isBusy: provider.isLoading || provider.isStale || _isCancelling,
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
    final discountLabel = order.discountType == 'percent' &&
            order.discountInput?.isNotEmpty == true
        ? 'الحسم (${order.discountInput})'
        : 'الحسم';
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
            if (_canEditAccountingInvoiceNo)
              _buildAccountingInvoiceNumber(order, provider),
            if (_canEditAccountingInvoiceNo) const Divider(),
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
              _summaryRow('$discountLabel:',
                  '-${discount.toStringAsFixed(2)} ${order.currency}',
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

  bool get _canEditAccountingInvoiceNo => {
        AppRole.admin,
        AppRole.manager,
        AppRole.accountant,
      }.contains(PermissionHelper.fromString(_role ?? ''));

  Widget _buildAccountingInvoiceNumber(
      Order order, OrderDetailProvider provider) {
    final theme = Theme.of(context);
    final number = order.accountingInvoiceNo?.trim() ?? '';
    final updatedAt = order.accountingInvoiceNoUpdatedAt;
    return Row(
      children: [
        const Icon(Icons.receipt_long_outlined),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('رقم الفاتورة الأصلي في البرنامج المحاسبي'),
              SelectableText(
                number.isEmpty ? 'غير مضاف' : number,
                style: theme.textTheme.titleMedium,
              ),
              if (updatedAt != null)
                Text(
                  'آخر تحديث: ${DateFormat('yyyy/MM/dd HH:mm').format(updatedAt.toLocal())}'
                  '${order.accountingInvoiceNoUpdatedBy?.isNotEmpty == true ? ' - ${order.accountingInvoiceNoUpdatedBy}' : ''}',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
        ),
        if (number.isNotEmpty)
          IconButton(
            tooltip: 'نسخ رقم الفاتورة',
            icon: const Icon(Icons.copy),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: number));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('تم نسخ رقم الفاتورة'),
                ));
              }
            },
          ),
        IconButton(
          tooltip: 'تعديل رقم الفاتورة',
          icon: const Icon(Icons.edit_outlined),
          onPressed: provider.isLoading
              ? null
              : () => _editAccountingInvoiceNo(order, provider),
        ),
      ],
    );
  }

  Future<void> _editAccountingInvoiceNo(
      Order order, OrderDetailProvider provider) async {
    final controller = TextEditingController(
      text: order.accountingInvoiceNo ?? '',
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('رقم الفاتورة الأصلي'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 64,
          decoration: const InputDecoration(
            labelText: 'رقم الفاتورة في البرنامج المحاسبي',
            helperText: 'اتركه فارغاً لإزالة الرقم',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    final invoiceNumber = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
    controller.dispose();
    if (invoiceNumber == null || !mounted) return;
    try {
      final response = await ApiService().orders.updateAccountingInvoiceNumber(
            orderId: order.orderId,
            invoiceNumber: invoiceNumber,
          );
      if (response['ok'] != true && response['success'] != true) {
        throw Exception(response['error'] ?? 'تعذر حفظ رقم الفاتورة');
      }
      await provider.fetchOrderDetails(order.orderId);
      if (mounted) {
        await context.read<OrdersProvider>().syncAfterMutation();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم حفظ رقم الفاتورة المحاسبي'),
        ));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تعذر حفظ رقم الفاتورة: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ));
      }
    }
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
    ).then((saved) async {
      await _fetchDetails();
      if (saved == true && mounted) {
        await context.read<OrdersProvider>().syncAfterMutation();
      }
    });
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
    final order = provider.currentOrder;
    if (order == null || order.items == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('تعذر التصدير: بنود الطلب المحفوظة غير متوفرة')));
      }
      return;
    }
    final role = PermissionHelper.fromString(_role ?? '');
    final canSeeFinancials = PermissionHelper.hasPermission(
            role, AppPermission.viewProductPrices) ||
        PermissionHelper.hasPermission(role, AppPermission.viewFinancials) ||
        PermissionHelper.hasPermission(
            role, AppPermission.viewSellingPriceOnly);
    final hasPricing = OrderStatusMapper.hasPricing(order.status);
    final canViewAccountingInvoiceNo = const {
      AppRole.admin,
      AppRole.manager,
      AppRole.accountant,
    }.contains(role);
    final snapshot = <String, dynamic>{
      'invoice_id': 'order-${order.orderId}',
      'invoice_number': order.orderNumber,
      'kind': 'order',
      if (canViewAccountingInvoiceNo &&
          order.accountingInvoiceNo?.trim().isNotEmpty == true)
        'accounting_invoice_no': order.accountingInvoiceNo!.trim(),
      'status': order.status,
      'status_label': _getStatusText(order.status),
      'invoice_date': order.createdAt?.toIso8601String(),
      'customer_name': order.customerName,
      'currency': order.currency,
      'subtotal': canSeeFinancials ? provider.subtotal : null,
      'discount': canSeeFinancials ? order.discount : null,
      'discount_type': canSeeFinancials ? order.discountType : null,
      'discount_input': canSeeFinancials ? order.discountInput : null,
      'shipping_cost': canSeeFinancials ? order.shippingCost : null,
      'net_total': canSeeFinancials ? order.totalAmount : null,
      'notes': order.note,
      'shipment_summary': provider.shipmentData == null
          ? ''
          : ShipmentSummary.formatAll(provider.shipmentData!),
      'items': provider.items
          .map((item) => {
                'code': item.code,
                'name_snapshot': item.name,
                'quantity': hasPricing
                    ? (item.quantityApproved ?? item.quantityRequested)
                    : item.quantityRequested,
                'unit': item.unit,
                'currency': item.currency,
                'unit_price': !canSeeFinancials || item.isUnavailable
                    ? null
                    : (hasPricing
                        ? (item.finalPrice ??
                            item.priceOffer ??
                            item.defaultPrice)
                        : (item.priceOffer ?? item.defaultPrice)),
                'line_total':
                    canSeeFinancials && hasPricing && !item.isUnavailable
                        ? item.savedLineTotal
                        : null,
                'note': item.customerNote,
              })
          .toList(),
    };
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SalesInvoicePdfScreen(invoice: snapshot),
      ),
    );
  }
}
