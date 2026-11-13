import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/drafts_provider.dart';
import '../providers/products_provider.dart';
import '../providers/orders_provider.dart';
import '../providers/customer_provider.dart';
import '../utils/permissions.dart';
import 'product_detail_screen.dart';
import '../widgets/widgets.dart';

/// شاشة إنشاء طلب جديد
class NewOrderScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  final Map<String, dynamic>? customer;
  final OrderDraft? draft;
  const NewOrderScreen(
      {super.key, required this.session, this.customer, this.draft});
  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen>
    with WidgetsBindingObserver {
  final List<OrderItem> _cart = [];
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  bool _loading = true;
  bool _isSubmitting = false;
  bool _refreshNoticeShown = false;
  final _orderNoteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _customerSearchCtrl = TextEditingController();
  String? _customerName;
  String? _customerId;
  List<Customer> _customers = [];
  int? _draftId;

  bool get _isStaffOrder {
    final role = PermissionHelper.fromString(
        widget.session['role']?.toString() ?? 'user');
    return role == AppRole.admin ||
        role == AppRole.manager ||
        role == AppRole.accountant;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _draftId = widget.draft?.id;
    _loadCustomerName();
    _loadInitialData();
    _searchCtrl.addListener(_filterProducts);
    _orderNoteCtrl.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _orderNoteCtrl.dispose();
    _searchCtrl.dispose();
    _customerSearchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _saveToDraft(immediate: true);
    }
  }

  void _onNoteChanged() {
    if (_draftId != null) _saveToDraft(immediate: false);
  }

  void _loadCustomerName() {
    if (widget.customer != null) {
      _customerId = _customerIdFromMap(widget.customer!);
      _customerName = _customerNameFromMap(widget.customer!);
    } else if (widget.draft != null) {
      _customerId =
          widget.draft!.customerId.isEmpty ? null : widget.draft!.customerId;
      _customerName = widget.draft!.customerName;
    } else if (PermissionHelper.fromString(
            widget.session['role']?.toString() ?? '') ==
        AppRole.customer) {
      _customerId = (widget.session['customer_id'] ?? widget.session['user_id'])
          ?.toString();
      _customerName = widget.session['full_name'] ??
          widget.session['name'] ??
          widget.session['username'];
    }
    if (_isStaffOrder && _customerName != null) {
      _customerSearchCtrl.text = _customerName!;
    }
  }

  String? _customerIdFromMap(Map<String, dynamic> customer) {
    final id = customer['customer_id'] ?? customer['id'];
    return id?.toString().isNotEmpty == true ? id.toString() : null;
  }

  String _customerNameFromMap(Map<String, dynamic> customer) {
    return (customer['full_name'] ??
            customer['customer_name'] ??
            customer['name'] ??
            customer['username'] ??
            '')
        .toString();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadProducts(), _loadCustomers()]);
    if (widget.draft != null) {
      setState(() {
        _cart.clear();
        for (var item in widget.draft!.items) {
          final p = _allProducts.cast<Product?>().firstWhere(
                (element) => element?.code == item.productCode,
                orElse: () => null,
              );

          if (p != null) {
            _cart.add(OrderItem.fromProduct(
              p,
              quantity: item.quantity,
              selectedUnit: item.unit,
              note: item.note,
              overridePrice: item.price, // Keep the draft price initially
            ));
          } else if (item.originalProduct != null) {
            _cart.add(OrderItem.fromProduct(
              item.originalProduct!,
              quantity: item.quantity,
              selectedUnit: item.unit,
              note: item.note,
              overridePrice: item.price,
            ));
          }
        }
        _orderNoteCtrl.text = widget.draft!.note ?? '';
      });

      // Check for changes and offer resolution
      _validateAndResolveConflicts();
    }
  }

  Future<void> _loadCustomers() async {
    if (!_isStaffOrder) return;
    final customerProvider = context.read<CustomerProvider>();
    await customerProvider.fetchCustomers(forceRefresh: true);
    if (mounted) {
      setState(() => _customers = customerProvider.customers);
    }
  }

  void _validateAndResolveConflicts() {
    if (widget.draft == null) return;
    List<Map<String, dynamic>> conflicts = [];

    for (var item in widget.draft!.items) {
      final current = _allProducts
          .cast<Product?>()
          .firstWhere((p) => p?.code == item.productCode, orElse: () => null);

      if (current == null) {
        conflicts.add({
          'type': 'missing',
          'item': item,
          'message':
              'المنتج ${item.productName} لم يعد متوفراً في القائمة الحالية.',
        });
      } else if (current.price != item.price) {
        conflicts.add({
          'type': 'price_change',
          'item': item,
          'current': current,
          'message':
              'تغير سعر ${item.productName} من ${item.price} إلى ${current.price}.',
        });
      }
    }

    if (conflicts.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showConflictResolutionDialog(conflicts);
      });
    }
  }

  void _showConflictResolutionDialog(List<Map<String, dynamic>> conflicts) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('حل تعارضات المسودة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                      'تم اكتشاف تغييرات في المنتجات منذ آخر حفظ للمسودة:'),
                  const SizedBox(height: 16),
                  ...conflicts.map((conflict) {
                    final isPriceChange = conflict['type'] == 'price_change';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(conflict['message'] as String,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.bold)),
                            if (isPriceChange) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: conflict['resolved'] == 'keep'
                                          ? null
                                          : () {
                                              setDialogState(() =>
                                                  conflict['resolved'] =
                                                      'keep');
                                            },
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor:
                                            conflict['resolved'] == 'keep'
                                                ? Colors.blue.shade50
                                                : null,
                                      ),
                                      child: const Text('إبقاء السعر القديم',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed:
                                          conflict['resolved'] == 'update'
                                              ? null
                                              : () {
                                                  setDialogState(() =>
                                                      conflict['resolved'] =
                                                          'update');
                                                },
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor:
                                            conflict['resolved'] == 'update'
                                                ? Colors.green.shade50
                                                : null,
                                      ),
                                      child: const Text('تحديث للسعر الجديد',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed:
                                          conflict['resolved'] == 'remove'
                                              ? null
                                              : () {
                                                  setDialogState(() =>
                                                      conflict['resolved'] =
                                                          'remove');
                                                },
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor:
                                            conflict['resolved'] == 'remove'
                                                ? Colors.red.shade50
                                                : null,
                                      ),
                                      child: const Text('إزالة من السلة',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: conflict['resolved'] == 'keep'
                                          ? null
                                          : () {
                                              setDialogState(() =>
                                                  conflict['resolved'] =
                                                      'keep');
                                            },
                                      style: OutlinedButton.styleFrom(
                                        backgroundColor:
                                            conflict['resolved'] == 'keep'
                                                ? Colors.orange.shade50
                                                : null,
                                      ),
                                      child: const Text(
                                          'إبقاء (قد يفشل الإرسال)',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  // Apply resolutions
                  setState(() {
                    for (var conflict in conflicts) {
                      final item = conflict['item'] as DraftItem;
                      final resolution = conflict['resolved'];
                      if (resolution == 'update' &&
                          conflict['type'] == 'price_change') {
                        final currentProduct = conflict['current'] as Product;
                        final cartIndex =
                            _cart.indexWhere((i) => i.code == item.productCode);
                        if (cartIndex != -1) {
                          _cart[cartIndex] = OrderItem.fromProduct(
                            currentProduct,
                            quantity: item.quantity,
                            selectedUnit: item.unit,
                            note: item.note,
                          );
                        }
                      } else if (resolution == 'remove') {
                        _cart.removeWhere((i) => i.code == item.productCode);
                      }
                      // 'keep' doesn't need changes as we loaded with draft prices
                    }
                  });
                  _saveToDraft(immediate: true);
                  Navigator.pop(context);
                },
                child: const Text('تطبيق الحلول'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<bool> _saveToDraft({bool immediate = true}) async {
    if (_cart.isEmpty && _orderNoteCtrl.text.isEmpty) return false;

    final draft = OrderDraft(
      id: _draftId,
      customerId: _customerId ?? '',
      customerName: _customerName ?? '',
      note: _orderNoteCtrl.text,
      updatedAt: DateTime.now(),
      items: _cart
          .map((i) => DraftItem(
                productCode: i.code,
                productName: i.name,
                unit: i.selectedUnit ?? '',
                quantity: i.quantity ?? 0,
                price: i.priceOffer ?? 0,
                note: i.note,
                originalProduct: _allProducts
                    .cast<Product?>()
                    .firstWhere((p) => p?.code == i.code, orElse: () => null),
              ))
          .toList(),
      customTitle: widget.draft?.customTitle,
    );

    try {
      final id = await context
          .read<DraftsProvider>()
          .saveDraft(draft, immediate: immediate);
      if (immediate && mounted) setState(() => _draftId = id);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveDraftManually() async {
    if (_cart.isEmpty && _orderNoteCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف مادة أو ملاحظة قبل حفظ المسودة')),
      );
      return;
    }
    final saved = await _saveToDraft(immediate: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(saved
            ? 'تم حفظ المسودة على هذا الجهاز'
            : context.read<DraftsProvider>().error ?? 'تعذر حفظ المسودة'),
        backgroundColor: saved ? Colors.green : Colors.red,
      ),
    );
  }

  void _filterProducts() {
    setState(() {
      final query = _searchCtrl.text.toLowerCase();
      _filteredProducts = _allProducts
          .where((p) =>
              p.name.toLowerCase().contains(query) ||
              p.code.toLowerCase().contains(query) ||
              p.oem.toLowerCase().contains(query) ||
              p.category.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _loadProducts({bool forceRefresh = false}) async {
    try {
      final productsProvider = context.read<ProductsProvider>();
      final products = productsProvider.allProducts;
      if (products.isEmpty || forceRefresh) {
        if (products.isEmpty && mounted) setState(() => _loading = true);
        await productsProvider.fetchProducts(forceRefresh: forceRefresh);
      }

      if (mounted) {
        setState(() {
          _allProducts = productsProvider.allProducts;
          _filteredProducts = _allProducts;
          _loading = false;
        });
        if (forceRefresh && productsProvider.lastRefreshThrottled) {
          if (!_refreshNoticeShown) {
            _refreshNoticeShown = true;
            final seconds = productsProvider.manualRefreshRemaining.inSeconds;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'يرجى الانتظار قليلًا قبل التحديث مجددًا'
                  '${seconds > 0 ? ' (باقي $seconds ثانية)' : ''}',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          _refreshNoticeShown = false;
        }
        if (!productsProvider.lastRefreshThrottled &&
            _allProducts.isEmpty &&
            productsProvider.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'تعذر تحميل المنتجات: ${productsProvider.errorMessage}',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('خطأ في تحميل المنتجات: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showProductDetails(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          product: product,
          session: widget.session,
        ),
      ),
    );
  }

  Widget _buildSaveStatus(DraftsProvider provider) {
    switch (provider.saveStatus) {
      case SaveStatus.saving:
        return const Center(
            child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ));
      case SaveStatus.saved:
        return const Tooltip(
            message: 'محفوظ محلياً',
            child: Icon(Icons.cloud_done_outlined, color: Colors.green));
      case SaveStatus.error:
        return const Tooltip(
            message: 'تعذر الحفظ',
            child: Icon(Icons.cloud_off, color: Colors.red));
      default:
        return const SizedBox.shrink();
    }
  }

  void _showAddItemDialog(Product product) {
    final qtyCtrl = TextEditingController(text: '1');
    final noteCtrl = TextEditingController();
    String selectedUnit = product.unit;
    final List<String> units = ['قطعة', 'كرتونة', 'درزن', 'كيس', 'متر', 'كجم'];

    if (!units.contains(selectedUnit)) {
      units.insert(0, selectedUnit);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ProductImageWidget(
                    imageUrl: product.imageUrl,
                    width: 60,
                    height: 60,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                        Text('\$${product.price}',
                            style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'إنقاص الكمية',
                          onPressed: () {
                            final value = double.tryParse(qtyCtrl.text) ?? 1;
                            setSheetState(() {
                              qtyCtrl.text = (value - 1)
                                  .clamp(1, double.infinity)
                                  .toString();
                            });
                          },
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Expanded(
                          child: TextField(
                            controller: qtyCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              labelText: 'الكمية',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'زيادة الكمية',
                          onPressed: () {
                            final value = double.tryParse(qtyCtrl.text) ?? 0;
                            setSheetState(() {
                              qtyCtrl.text = (value + 1).toString();
                            });
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedUnit,
                      decoration: const InputDecoration(
                        labelText: 'الوحدة',
                        border: OutlineInputBorder(),
                      ),
                      items: units
                          .map(
                              (u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (val) => setSheetState(
                          () => selectedUnit = val ?? selectedUnit),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات للمادة (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final qty = double.tryParse(qtyCtrl.text);
                    if (qty == null || qty <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('أدخل كمية صحيحة أكبر من صفر')),
                      );
                      return;
                    }
                    setState(() {
                      _cart.add(OrderItem.fromProduct(
                        product,
                        quantity: qty,
                        selectedUnit: selectedUnit,
                        note: noteCtrl.text,
                      ));
                    });
                    _saveToDraft(immediate: true);
                    Navigator.pop(context);
                  },
                  child: const Text('إضافة للطلب'),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      qtyCtrl.dispose();
      noteCtrl.dispose();
    });
  }

  void _submitOrder({bool fromReviewDialog = false}) async {
    if (_cart.isEmpty || _isSubmitting) return;
    if ((_customerId ?? '').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isStaffOrder
              ? 'اختر الزبون صاحب الطلب أولاً'
              : 'تعذر تحديد حساب الزبون'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // التحقق المسبق من صحة البيانات
    for (final item in _cart) {
      if ((item.quantity ?? 0) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('الكمية للصنف ${item.name} يجب أن تكون أكبر من صفر'),
            backgroundColor: Colors.orange));
        return;
      }
    }

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      final clientRequestId = 'REQ-${DateTime.now().millisecondsSinceEpoch}';

      final order = Order(
        orderId: '',
        orderNumber: '',
        customerId: _customerId!,
        customerName: _customerName ?? '',
        createdBy: (widget.session['name'] ??
                widget.session['full_name'] ??
                widget.session['username'] ??
                widget.session['user_id'])
            ?.toString(),
        createdByRole: widget.session['role']?.toString(),
        status: 'pending',
        currency: 'USD',
        note: _orderNoteCtrl.text,
        clientRequestId: clientRequestId,
        items: _cart
            .map((i) => OrderItem(
                  itemId: '',
                  code: i.code,
                  name: i.name,
                  unit: i.selectedUnit ?? i.unit,
                  quantityRequested: i.quantity,
                  quantityApproved: 0,
                  quantityPrepared: 0,
                  priceOffer: i.priceOffer,
                  defaultPrice: i.defaultPrice,
                  finalPrice: 0,
                  currency: 'USD',
                  status: 'pending',
                  stockAvailable: i.stockAvailable,
                  customerNote: i.note,
                ))
            .toList(),
      );

      final ordersProvider = context.read<OrdersProvider>();
      final draftsProvider = context.read<DraftsProvider>();
      final orderId = await ordersProvider.createOrder(
        order,
        customerId: order.customerId,
      );

      if (orderId.isNotEmpty) {
        messenger.showSnackBar(const SnackBar(
            content: Text('تم إرسال الطلب بنجاح'),
            backgroundColor: Colors.green));
        if (_draftId != null) {
          await draftsProvider.deleteDraft(_draftId!);
        }
        if (mounted) {
          setState(() => _cart.clear());
          navigator.pop();
          if (fromReviewDialog) navigator.pop();
        }
      } else {
        throw Exception('فشل الحصول على رقم الطلب');
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('فشل الإرسال: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DraftsProvider>();
    final customerQuery = _customerSearchCtrl.text.trim().toLowerCase();
    final matchingCustomers = customerQuery.isEmpty
        ? <Customer>[]
        : _customers
            .where((customer) =>
                customer.name.toLowerCase().contains(customerQuery) ||
                (customer.phone ?? '').toLowerCase().contains(customerQuery) ||
                (customer.company ?? '').toLowerCase().contains(customerQuery))
            .take(8)
            .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('طلب جديد'),
        actions: [
          _buildSaveStatus(provider),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadProducts(forceRefresh: true),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          if (provider.error != null)
            Container(
              color: Colors.red.shade100,
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(provider.error!,
                          style: const TextStyle(color: Colors.red))),
                  IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => provider.resetStatus()),
                ],
              ),
            ),
          // شريط اسم الزبون
          if (_isStaffOrder) ...[
            _buildCustomerSelector(matchingCustomers),
          ] else
            CustomerInfoBarWidget(customerName: _customerName),

          // حقل البحث
          SearchFieldWidget(
            controller: _searchCtrl,
            hintText: 'ابحث عن منتج...',
            onChanged: (_) => _filterProducts(),
          ),

          // قائمة المنتجات
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredProducts.isEmpty
                    ? const Center(child: Text('لا توجد منتجات'))
                    : GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.75,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _filteredProducts.length,
                        itemBuilder: (context, index) {
                          final p = _filteredProducts[index];
                          return ProductCardWidget(
                            product: p,
                            onTap: () => _showAddItemDialog(p),
                            onLongPress: () => _showProductDetails(p),
                          );
                        },
                      ),
          ),

          // منطقة السلة والإرسال
          CartSummaryWidget(
            cartItems: _cart,
            isSubmitting: _isSubmitting,
            onSaveDraftTap: _saveDraftManually,
            onReviewTap: () => CartSummaryWidget.showReviewDialog(
              context: context,
              cartItems: _cart,
              onSubmit: () => _submitOrder(fromReviewDialog: true),
              onRemoveItem: (item) {
                setState(() => _cart.remove(item));
                _saveToDraft(immediate: true);
              },
              isSubmitting: _isSubmitting,
            ),
            onSubmitTap: _submitOrder,
          ),

          // ملاحظات عامة
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _orderNoteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات عامة للطلب (اختياري)',
                border: OutlineInputBorder(),
                filled: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSelector(List<Customer> matchingCustomers) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _customerSearchCtrl,
            decoration: InputDecoration(
              labelText: 'الزبون صاحب الطلب',
              hintText: 'اكتب اسم الزبون للبحث',
              prefixIcon: const Icon(Icons.person_search),
              suffixIcon: IconButton(
                tooltip: 'مسح الزبون',
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _customerId = null;
                    _customerName = null;
                    _customerSearchCtrl.clear();
                  });
                },
              ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              setState(() {
                if (value.trim() != _customerName) {
                  _customerId = null;
                  _customerName = null;
                }
              });
            },
          ),
          if (_customerId != null && _customerName != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('سيتم حفظ الطلب باسم: $_customerName'),
            ),
          if (_customerId == null && matchingCustomers.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border.all(color: Theme.of(context).dividerColor),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: matchingCustomers.length,
                itemBuilder: (context, index) {
                  final customer = matchingCustomers[index];
                  return ListTile(
                    dense: true,
                    title: Text(customer.name),
                    subtitle: Text([
                      if ((customer.company ?? '').isNotEmpty)
                        customer.company!,
                      if ((customer.phone ?? '').isNotEmpty) customer.phone!,
                    ].join(' • ')),
                    onTap: () {
                      setState(() {
                        _customerId = customer.id;
                        _customerName = customer.name;
                        _customerSearchCtrl.text = customer.name;
                        _customerSearchCtrl.selection = TextSelection.collapsed(
                            offset: _customerSearchCtrl.text.length);
                      });
                      FocusScope.of(context).unfocus();
                    },
                  );
                },
              ),
            ),
          if (_customers.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('تعذر تحميل قائمة الزبائن أو لا توجد بيانات محفوظة'),
            ),
        ],
      ),
    );
  }
}
