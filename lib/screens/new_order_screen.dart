import 'dart:async';
import 'package:flutter/material.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../models/order_offer.dart';
import '../providers/drafts_provider.dart';
import '../providers/products_provider.dart';
import '../providers/orders_provider.dart';
import '../providers/customer_provider.dart';
import '../services/api_service.dart';
import '../utils/permissions.dart';
import '../utils/guarded_navigation.dart';
import '../utils/smart_product_search.dart';
import 'product_detail_screen.dart';
import '../widgets/widgets.dart';

/// شاشة إنشاء طلب جديد
class NewOrderScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  final Map<String, dynamic>? customer;
  final OrderDraft? draft;
  final Product? initialProduct;
  final Map<String, dynamic>? initialOffer;
  final Future<Map<String, dynamic>> Function()? offerLoader;
  final Future<Map<String, dynamic>> Function()? productLoader;
  const NewOrderScreen(
      {super.key,
      required this.session,
      this.customer,
      this.draft,
      this.initialProduct,
      this.initialOffer,
      this.offerLoader,
      this.productLoader});
  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen>
    with WidgetsBindingObserver {
  final List<OrderItem> _cart = [];
  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  SmartProductSearchIndex _productSearchIndex =
      SmartProductSearchIndex(const []);
  Timer? _searchDebounce;
  bool _loading = true;
  bool _isSubmitting = false;
  bool _allowPop = false;
  bool _refreshNoticeShown = false;
  String? _draftLoadError;
  bool _draftReady = false;
  final _orderNoteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _customerSearchCtrl = TextEditingController();
  String? _customerName;
  String? _customerId;
  List<Customer> _customers = [];
  int? _draftId;
  String? _clientRequestId;
  Future<bool>? _initialDraftSave;
  bool get _pendingSubmission => _clientRequestId != null;

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
    _clientRequestId = widget.draft?.clientRequestId;
    _draftReady = widget.draft == null;
    _loadCustomerName();
    _loadInitialData();
    _searchCtrl.addListener(_filterProducts);
    _orderNoteCtrl.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _orderNoteCtrl.dispose();
    _searchCtrl.dispose();
    _customerSearchCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isSubmitting &&
        !_allowPop &&
        (state == AppLifecycleState.inactive ||
            state == AppLifecycleState.paused)) {
      _saveToDraft(immediate: true);
    }
  }

  void _onNoteChanged() {
    if (_draftId != null || _initialDraftSave != null) {
      _saveToDraft(immediate: false);
    }
  }

  void _resetClientRequestId() {
    _clientRequestId = null;
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
    if (!mounted) return;
    if (widget.initialProduct != null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final initialOffer = widget.initialOffer == null
              ? null
              : OrderOffer(widget.initialOffer!);
          if (initialOffer?.isBundle == true) {
            _showAddBundleDialog(initialOffer!);
          } else {
            _showAddItemDialog(widget.initialProduct!, offer: initialOffer);
          }
        }
      });
    }
    if (widget.draft != null) {
      final missing = widget.draft!.items.where((item) =>
          item.originalProduct == null &&
          !_allProducts.any((product) => product.code == item.productCode));
      if (missing.isNotEmpty) {
        setState(() {
          _draftLoadError =
              'تعذر استعادة بيانات بعض المواد (${missing.map((item) => item.productCode).join('، ')}). '
              'المسودة الأصلية محفوظة؛ تحقق من الاتصال وأعد فتحها.';
        });
        return;
      }
      final changedCurrency = widget.draft!.items.where((item) {
        final product = _pendingSubmission && item.originalProduct != null
            ? item.originalProduct
            : _allProducts.cast<Product?>().firstWhere(
                  (product) => product?.code == item.productCode,
                  orElse: () => item.originalProduct,
                );
        return product != null &&
            product.currency.toUpperCase() !=
                widget.draft!.currency.toUpperCase();
      });
      if (changedCurrency.isNotEmpty) {
        setState(() {
          _draftLoadError =
              'تغيرت عملة بعض مواد المسودة (${changedCurrency.map((item) => item.productCode).join('، ')}). '
              'لم تُعدل المسودة؛ يرجى مراجعة بيانات الأسعار قبل إعادة فتحها.';
        });
        return;
      }
      setState(() {
        _cart.clear();
        for (var item in widget.draft!.items) {
          final p = _pendingSubmission && item.originalProduct != null
              ? item.originalProduct
              : _allProducts.cast<Product?>().firstWhere(
                    (element) => element?.code == item.productCode,
                    orElse: () => null,
                  );

          if (p != null) {
            _cart.add(OrderItem.fromProduct(
              p,
              quantity: item.quantity,
              selectedUnit: item.unit,
              note: item.note,
              overridePrice:
                  item.offer?.price ?? item.expectedUnitPrice ?? item.price,
              offer: item.offer,
              expectedUnitPrice: item.expectedUnitPrice,
            ));
          } else if (item.originalProduct != null) {
            _cart.add(OrderItem.fromProduct(
              item.originalProduct!,
              quantity: item.quantity,
              selectedUnit: item.unit,
              note: item.note,
              overridePrice:
                  item.offer?.price ?? item.expectedUnitPrice ?? item.price,
              offer: item.offer,
              expectedUnitPrice: item.expectedUnitPrice,
            ));
          }
        }
        _orderNoteCtrl.text = widget.draft!.note ?? '';
        _draftReady = true;
      });

      // Check for changes and offer resolution
      if (!_pendingSubmission) _validateAndResolveConflicts();
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
      if (item.offer != null || item.expectedUnitPrice != null) continue;
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
      } else if (current.priceForUnit(item.unit) != item.price) {
        conflicts.add({
          'type': 'price_change',
          'item': item,
          'current': current,
          'message':
              'تغير سعر ${item.productName} (${item.unit}) من ${item.price} إلى ${current.priceForUnit(item.unit) ?? 'غير مضبوط'}.',
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
                                      onPressed: conflict['resolved'] ==
                                                  'update' ||
                                              (conflict['current'] as Product)
                                                      .priceForUnit(
                                                          (conflict['item']
                                                                  as DraftItem)
                                                              .unit) ==
                                                  null
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
                        final cartIndex = _cart.indexWhere((i) =>
                            i.code == item.productCode &&
                            (i.selectedUnit ?? i.unit) == item.unit &&
                            i.priceOffer == item.price &&
                            (i.note ?? '') == (item.note ?? ''));
                        if (cartIndex != -1) {
                          _cart[cartIndex] = OrderItem.fromProduct(
                            currentProduct,
                            quantity: item.quantity,
                            selectedUnit: item.unit,
                            note: item.note,
                          );
                        }
                      } else if (resolution == 'remove') {
                        final index = _cart.indexWhere((i) =>
                            i.code == item.productCode &&
                            (i.selectedUnit ?? i.unit) == item.unit &&
                            i.priceOffer == item.price &&
                            (i.note ?? '') == (item.note ?? ''));
                        if (index >= 0) _cart.removeAt(index);
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
    if (_draftLoadError != null || !_draftReady) return false;
    final initialSave = _initialDraftSave;
    if (initialSave != null) {
      if (!await initialSave || !mounted) return false;
    }
    if (_cart.isEmpty && _orderNoteCtrl.text.isEmpty && _draftId == null) {
      return false;
    }
    if (_draftId == null) {
      final save = _persistDraft(immediate: true);
      _initialDraftSave = save;
      try {
        return await save;
      } finally {
        _initialDraftSave = null;
      }
    }
    return _persistDraft(immediate: immediate);
  }

  Future<bool> _persistDraft({required bool immediate}) async {
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
                offer: i.offer,
                expectedUnitPrice: i.expectedUnitPrice,
                originalProduct: i.product ??
                    _allProducts.cast<Product?>().firstWhere(
                        (p) => p?.code == i.code,
                        orElse: () => null),
              ))
          .toList(),
      currency: _cart.isNotEmpty
          ? _cart.first.currency
          : widget.draft?.currency ?? 'USD',
      customTitle: widget.draft?.customTitle,
      clientRequestId: _clientRequestId,
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

  Future<void> _handleBack() async {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_isSubmitting) return;
    if (_draftLoadError != null || !_draftReady) {
      popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
      return;
    }
    if (_pendingSubmission) {
      popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
      return;
    }
    if (_cart.isEmpty && _orderNoteCtrl.text.trim().isEmpty) {
      popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طلب غير محفوظ'),
        content: const Text('يمكنك حفظ الطلب كمسودة على هذا الجهاز.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            child: const Text('متابعة التحرير'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: Text(widget.draft == null
                ? 'تجاهل وحذف المسودة'
                : 'إغلاق مع الاحتفاظ بالمسودة'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'draft'),
            child: const Text('حفظ مسودة'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'continue') return;
    if (choice == 'discard' && widget.draft == null) {
      final provider = context.read<DraftsProvider>();
      if (_initialDraftSave != null) {
        await _initialDraftSave;
      }
      if (!mounted) return;
      if (_draftId != null) {
        await provider.deleteDraft(_draftId!);
        if (!mounted) return;
        if (provider.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('تعذر حذف المسودة: ${provider.error}'),
          ));
          return;
        }
      }
    }
    if (choice == 'draft') {
      final saved = await _saveToDraft();
      if (!mounted) return;
      if (!saved) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text(context.read<DraftsProvider>().error ?? 'تعذر حفظ المسودة'),
        ));
        return;
      }
    }
    popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
  }

  void _filterProducts() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      setState(() {
        _filteredProducts = _productSearchIndex.search(_searchCtrl.text);
      });
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
          _productSearchIndex = SmartProductSearchIndex(_allProducts);
          _filteredProducts = _productSearchIndex.search(_searchCtrl.text);
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
          onAddToOrder: () => _showAddItemDialog(product),
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

  void _showAddItemDialog(Product product, {OrderOffer? offer}) {
    if (_pendingSubmission || _isSubmitting) return;
    if (offer?.isBundle == true) {
      _showAddBundleDialog(offer!);
      return;
    }
    if (_cart.any((item) =>
        item.currency.toUpperCase() != product.currency.toUpperCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يمكن جمع عملات مختلفة في الطلب نفسه'),
        ),
      );
      return;
    }
    final qtyCtrl = TextEditingController(
        text: offer?.minimum != null && offer!.minimum! > 0
            ? offer.minimum.toString()
            : '1');
    final noteCtrl = TextEditingController();
    final units = product.availableUnits;
    if (units.isEmpty || product.hasConflictingUnits) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(units.isEmpty
              ? 'لا توجد وحدة معرفة لهذا المنتج'
              : 'تعريف وحدات المنتج متعارض؛ يرجى مراجعة بياناته'),
        ),
      );
      qtyCtrl.dispose();
      noteCtrl.dispose();
      return;
    }
    if (offer != null &&
        (offer.id.isEmpty ||
            offer.revision.isEmpty ||
            offer.productCode != product.code ||
            !units.contains(offer.unit) ||
            offer.currency.toUpperCase() != product.currency.toUpperCase() ||
            offer.minimum == null ||
            offer.minimum! <= 0 ||
            offer.price == null ||
            offer.price! <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('بيانات العرض غير مكتملة أو لا تطابق المنتج')));
      qtyCtrl.dispose();
      noteCtrl.dispose();
      return;
    }
    String selectedUnit = offer?.unit ??
        (units.contains(product.unit) ? product.unit : units.first);
    bool adding = false;

    final route = ModalBottomSheetRoute<void>(
      isScrollControlled: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
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
          child: SingleChildScrollView(
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
                          Text(
                            offer != null
                                ? 'سعر العرض: ${offer.price} ${offer.currency}'
                                : product.priceForUnit(selectedUnit) == null
                                    ? 'سعر هذه الوحدة غير مضبوط'
                                    : '${product.currency} ${product.priceForUnit(selectedUnit)}',
                            style: TextStyle(
                              color: product.priceForUnit(selectedUnit) == null
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (offer != null)
                  Text(
                      'العرض للوحدة ${offer.unit}، الحد الأدنى ${offer.minimum} ${offer.unit}. السعر يحتاج تأكيد الخادم قبل الإرسال.'),
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                      child: units.length == 1 || offer != null
                          ? InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'الوحدة',
                                border: OutlineInputBorder(),
                              ),
                              child: Text(selectedUnit),
                            )
                          : DropdownButtonFormField<String>(
                              initialValue: selectedUnit,
                              decoration: const InputDecoration(
                                labelText: 'الوحدة',
                                border: OutlineInputBorder(),
                              ),
                              items: units
                                  .map((u) => DropdownMenuItem(
                                      value: u, child: Text(u)))
                                  .toList(),
                              onChanged: (val) => setSheetState(
                                () => selectedUnit = val ?? selectedUnit,
                              ),
                            ),
                    ),
                  ],
                ),
                if (units.length > 1 && offer == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      product.priceForUnit(selectedUnit) == null
                          ? 'لا يمكن إرسال الطلب قبل ضبط سعر هذه الوحدة'
                          : 'السعر للوحدة المختارة: ${product.priceForUnit(selectedUnit)} ${product.currency}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: product.priceForUnit(selectedUnit) == null
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                          ),
                    ),
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
                    onPressed: adding ||
                            (offer == null &&
                                product.priceForUnit(selectedUnit) == null) ||
                            product.factorForUnit(selectedUnit) == null ||
                            !product.factorForUnit(selectedUnit)!.isFinite ||
                            product.factorForUnit(selectedUnit)! <= 0
                        ? null
                        : () {
                            if (adding) return;
                            final qty = double.tryParse(qtyCtrl.text);
                            if (qty == null || !qty.isFinite || qty <= 0) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('أدخل كمية صحيحة أكبر من صفر')),
                              );
                              return;
                            }
                            if (offer != null && qty < offer.minimum!) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'الحد الأدنى للعرض ${offer.minimum} ${offer.unit}')),
                              );
                              return;
                            }
                            setSheetState(() => adding = true);
                            _resetClientRequestId();
                            final itemNote = noteCtrl.text.trim();
                            setState(() {
                              final price = offer?.price ??
                                  product.priceForUnit(selectedUnit);
                              final existingIndex = _cart.indexWhere((item) =>
                                  item.code == product.code &&
                                  (item.selectedUnit ?? item.unit) ==
                                      selectedUnit &&
                                  item.priceOffer == price &&
                                  item.expectedUnitPrice == null &&
                                  item.offer?.id == offer?.id &&
                                  item.offer?.revision == offer?.revision &&
                                  (item.offer == null ||
                                      (offer != null &&
                                          item.offer!.sameTerms(offer))) &&
                                  item.currency == product.currency &&
                                  (item.note ?? '').trim() == itemNote);
                              if (existingIndex >= 0) {
                                final existing = _cart[existingIndex];
                                _cart[existingIndex] = existing.copyWith(
                                  quantity: (existing.quantity ?? 0) + qty,
                                  quantityRequested:
                                      (existing.quantity ?? 0) + qty,
                                );
                              } else {
                                _cart.add(OrderItem.fromProduct(
                                  product,
                                  quantity: qty,
                                  selectedUnit: selectedUnit,
                                  note: noteCtrl.text,
                                  overridePrice: offer?.price,
                                  offer: offer,
                                ));
                              }
                            });
                            _saveToDraft(immediate: true);
                            Navigator.pop(context);
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'تمت إضافة ${product.name} إلى الطلب')),
                            );
                          },
                    child: const Text('إضافة للطلب'),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
    Navigator.of(context).push(route);
    route.completed.whenComplete(() {
      qtyCtrl.dispose();
      noteCtrl.dispose();
    });
  }

  void _showAddBundleDialog(OrderOffer offer) {
    if (_pendingSubmission || _isSubmitting) return;
    final controller = TextEditingController(text: '1');
    final components = <({
      Product product,
      String unit,
      double quantity,
      double oldPrice,
      double offerPrice
    })>[];
    for (final item in offer.bundleItems) {
      final code = item['product_code']?.toString() ?? '';
      final unit = item['unit']?.toString() ?? '';
      final product = _allProducts.cast<Product?>().firstWhere(
            (candidate) => candidate?.code == code,
            orElse: () => null,
          );
      final quantity = double.tryParse('${item['quantity']}');
      final oldPrice = double.tryParse('${item['old_price']}');
      final offerPrice = double.tryParse('${item['offer_price']}');
      if (product == null ||
          !product.availableUnits.contains(unit) ||
          product.factorForUnit(unit) == null ||
          quantity == null ||
          quantity <= 0 ||
          oldPrice == null ||
          offerPrice == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر تحميل بيانات أحد منتجات الحزمة'),
        ));
        controller.dispose();
        return;
      }
      components.add((
        product: product,
        unit: unit,
        quantity: quantity,
        oldPrice: oldPrice,
        offerPrice: offerPrice,
      ));
    }
    if (components.length < 2) {
      controller.dispose();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('بيانات مكونات الحزمة غير مكتملة'),
      ));
      return;
    }
    if (_cart.any((item) =>
        item.currency.toUpperCase() != offer.currency.toUpperCase())) {
      controller.dispose();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('لا يمكن جمع عملات مختلفة في الطلب نفسه'),
      ));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(offer.data['title']?.toString().trim().isNotEmpty == true
              ? offer.data['title'].toString()
              : 'عرض مجموعة منتجات'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('محتويات الحزمة وأسعار كل قطعة:'),
                  const SizedBox(height: 8),
                  for (final component in components)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            ProductImageWidget(
                              imageUrl: component.product.imageUrl,
                              height: 48,
                              width: 48,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${component.quantity} × ${component.product.name} (${component.unit})\n'
                                '${component.oldPrice} ← ${component.offerPrice} ${offer.currency} للقطعة',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: false,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'عدد الحزم',
                      helperText: 'ستُضاف جميع المكونات بالكميات المحددة',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'السعر الإجمالي للحزمة: ${offer.price} ${offer.currency}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final count = double.tryParse(controller.text.trim());
                if (count == null ||
                    !count.isFinite ||
                    count <= 0 ||
                    count != count.roundToDouble()) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('أدخل عدداً صحيحاً من الحزم'),
                    ),
                  );
                  return;
                }
                _resetClientRequestId();
                setState(() {
                  for (final component in components) {
                    final quantity = component.quantity * count;
                    final price = offer.priceFor(
                      component.product.code,
                      component.unit,
                    )!;
                    final existingIndex = _cart.indexWhere((item) =>
                        item.offer?.id == offer.id &&
                        item.code == component.product.code &&
                        (item.selectedUnit ?? item.unit) == component.unit);
                    if (existingIndex >= 0) {
                      final existing = _cart[existingIndex];
                      _cart[existingIndex] = existing.copyWith(
                        quantity: (existing.quantity ?? 0) + quantity,
                        quantityRequested: (existing.quantity ?? 0) + quantity,
                      );
                    } else {
                      _cart.add(OrderItem.fromProduct(
                        component.product,
                        quantity: quantity,
                        selectedUnit: component.unit,
                        overridePrice: price,
                        offer: offer,
                      ));
                    }
                  }
                });
                _saveToDraft(immediate: true);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text('تمت إضافة $count حزمة كاملة إلى الطلب'),
                  ),
                );
              },
              child: const Text('إضافة الحزمة للطلب'),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  Future<bool> _refreshOffersForSubmission({required bool pending}) async {
    final hasOffers = _cart.any((item) => item.offer != null);
    final hasExpected = _cart.any((item) => item.expectedUnitPrice != null);
    if (!hasOffers && !hasExpected) return true;
    final offers = <String, OrderOffer>{};
    DateTime? serverTime;
    if (hasOffers) {
      final response = await (widget.offerLoader?.call() ??
          ApiService().post({'action': 'offer_list'}, useCache: false));
      final payload = response['data'] is Map
          ? Map<String, dynamic>.from(response['data'])
          : response;
      serverTime = DateTime.tryParse((payload['server_time'] ?? '').toString());
      final rows = payload['offers'];
      if (serverTime == null || rows is! List) {
        throw StateError('تعذر التحقق من العروض من الخادم');
      }
      for (final row in rows) {
        if (row is Map) {
          final offer = OrderOffer(Map<String, dynamic>.from(row));
          if (offer.id.isNotEmpty) offers[offer.id] = offer;
        }
      }
    }
    final replacements = <int, OrderItem>{};
    final messages = <String>[];
    final checkedBundleOffers = <String>{};
    List<Product>? freshProducts;
    Future<void> loadFreshProducts() async {
      if (freshProducts == null) {
        final response = await (widget.productLoader?.call() ??
            ApiService().post({'action': 'product_list'},
                useCache: false, forceRefresh: true));
        final rows = response['products'] ?? response['data'];
        if (rows is! List) {
          throw StateError('تعذر تحديث أسعار المنتجات من الخادم');
        }
        freshProducts = rows
            .whereType<Map>()
            .map((row) => Product.fromJson(Map<String, dynamic>.from(row)))
            .toList();
      }
    }

    Future<Product> freshProduct(OrderItem item, String unit) async {
      await loadFreshProducts();
      final product = freshProducts!.cast<Product?>().firstWhere(
            (product) => product?.code == item.code,
            orElse: () => null,
          );
      final price = product?.priceForUnit(unit);
      final factor = product?.factorForUnit(unit);
      if (product == null ||
          product.currency.toUpperCase() != item.currency.toUpperCase() ||
          price == null ||
          !price.isFinite ||
          price < 0 ||
          factor == null ||
          !factor.isFinite ||
          factor <= 0) {
        throw StateError(
            'تعذر التحقق من السعر العادي أو الوحدة للصنف ${item.name}؛ احذف الصنف أو راجع بياناته.');
      }
      return product;
    }

    // Retry an uncertain request unchanged after refreshing availability.
    // The server checks its request id before any price validation.
    if (pending) {
      if (hasExpected) await loadFreshProducts();
      return true;
    }
    for (var index = 0; index < _cart.length; index++) {
      final item = _cart[index];
      final previous = item.offer;
      final quantity = item.quantity ?? 0;
      final unit = item.selectedUnit ?? item.unit;
      if (previous == null) {
        if (item.expectedUnitPrice == null) continue;
        final product = await freshProduct(item, unit);
        final price = product.priceForUnit(unit)!;
        replacements[index] = OrderItem.fromProduct(product,
            quantity: quantity,
            selectedUnit: unit,
            note: item.note,
            overridePrice: price,
            expectedUnitPrice: price);
        messages.add(
            '${item.name}: السعر العادي الحالي $price ${item.currency} لكل $unit (السابق ${item.expectedUnitPrice}).');
        continue;
      }
      final current = offers[previous.id];
      if (previous.isBundle) {
        if (!checkedBundleOffers.add(previous.id)) continue;
        final indices = <int>[];
        for (var candidate = 0; candidate < _cart.length; candidate++) {
          if (_cart[candidate].offer?.id == previous.id) indices.add(candidate);
        }
        final currentComponents = current?.bundleItems ?? const [];
        final validCurrent = current != null &&
            current.isBundle &&
            indices.length == previous.bundleItems.length &&
            indices.every((lineIndex) {
              final line = _cart[lineIndex];
              return current.usableFor(
                code: line.code,
                selectedUnit: line.selectedUnit ?? line.unit,
                itemCurrency: line.currency,
                quantity: line.quantity ?? 0,
                serverTime: serverTime!,
              );
            }) &&
            currentComponents.length == previous.bundleItems.length &&
            indices
                    .map((lineIndex) =>
                        '${_cart[lineIndex].code}\u001f${_cart[lineIndex].selectedUnit ?? _cart[lineIndex].unit}')
                    .toSet()
                    .length ==
                currentComponents.length &&
            indices
                    .map((lineIndex) {
                      final line = _cart[lineIndex];
                      final component = current.bundleItems.firstWhere(
                        (entry) =>
                            entry['product_code']?.toString() == line.code &&
                            entry['unit']?.toString() ==
                                (line.selectedUnit ?? line.unit),
                        orElse: () => const <String, dynamic>{},
                      );
                      final componentQuantity =
                          double.tryParse('${component['quantity']}');
                      return componentQuantity == null ||
                              componentQuantity <= 0 ||
                              (line.quantity ?? 0) % componentQuantity != 0
                          ? -1
                          : ((line.quantity ?? 0) / componentQuantity).round();
                    })
                    .toSet()
                    .length ==
                1 &&
            !indices.any((lineIndex) {
              final line = _cart[lineIndex];
              return !current.bundleItems.any(
                (entry) =>
                    entry['product_code']?.toString() == line.code &&
                    entry['unit']?.toString() ==
                        (line.selectedUnit ?? line.unit),
              );
            });
        if (validCurrent) {
          for (final lineIndex in indices) {
            final line = _cart[lineIndex];
            final unit = line.selectedUnit ?? line.unit;
            final price = current.priceFor(line.code, unit)!;
            replacements[lineIndex] =
                line.copyWith(offer: current, priceOffer: price);
          }
          messages.add(previous.sameTerms(current)
              ? '${previous.data['title'] ?? 'الحزمة'}: السعر الحالي للحزمة ${current.price} ${current.currency}.'
              : '${previous.data['title'] ?? 'الحزمة'}: تغيرت شروط الحزمة؛ السعر الجديد ${current.price} ${current.currency}.');
        } else {
          for (final lineIndex in indices) {
            final line = _cart[lineIndex];
            final unit = line.selectedUnit ?? line.unit;
            final product = await freshProduct(line, unit);
            final regularPrice = product.priceForUnit(unit)!;
            replacements[lineIndex] = OrderItem.fromProduct(product,
                quantity: line.quantity ?? 0,
                selectedUnit: unit,
                note: line.note,
                overridePrice: regularPrice,
                expectedUnitPrice: regularPrice);
          }
          messages.add(
              '${previous.data['title'] ?? 'الحزمة'}: العرض لم يعد صالحاً أو اكتملت شروطه؛ تم اقتراح السعر العادي لكل المكونات.');
        }
        continue;
      }
      if (current != null &&
          current.usableFor(
            code: item.code,
            selectedUnit: unit,
            itemCurrency: item.currency,
            quantity: quantity,
            serverTime: serverTime!,
          )) {
        if (!previous.sameTerms(current)) {
          replacements[index] =
              item.copyWith(offer: current, priceOffer: current.price);
          messages.add(
              '${item.name}: سعر العرض ${previous.price} ← ${current.price} ${item.currency} لكل $unit (الحد الأدنى ${current.minimum}).');
        } else {
          messages.add(
              '${item.name}: سعر العرض الحالي ${current.price} ${item.currency} لكل $unit (الحد الأدنى ${current.minimum}).');
        }
      } else {
        final product = await freshProduct(item, unit);
        final regularPrice = product.priceForUnit(unit)!;
        replacements[index] = OrderItem.fromProduct(product,
            quantity: quantity,
            selectedUnit: unit,
            note: item.note,
            overridePrice: regularPrice,
            expectedUnitPrice: regularPrice);
        final reason = current != null &&
                current.minimum != null &&
                quantity < current.minimum!
            ? 'الكمية أقل من الحد الأدنى ${current.minimum} $unit'
            : 'العرض متوقف أو منتهي أو تغيرت شروطه';
        messages.add(
            '${item.name}: $reason. السعر العادي المقترح $regularPrice ${item.currency} لكل $unit بدلاً من ${previous.price}.');
      }
    }
    if (!mounted) return false;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
            replacements.isEmpty ? 'تأكيد أسعار العروض' : 'تغيرت شروط العرض'),
        content: SingleChildScrollView(
          child: Text('${messages.join('\n\n')}\n\n'
              'هل توافق على الأسعار الموضحة قبل إرسال الطلب؟'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('العودة للمراجعة')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('أوافق على الأسعار')),
        ],
      ),
    );
    if (accepted != true || !mounted) return false;
    setState(() {
      replacements.forEach((index, item) => _cart[index] = item);
    });
    return true;
  }

  Future<void> _submitOrder({bool fromReviewDialog = false}) async {
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
      final quantity = item.quantity;
      if (quantity == null || !quantity.isFinite || quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('الكمية للصنف ${item.name} يجب أن تكون أكبر من صفر'),
            backgroundColor: Colors.orange));
        return;
      }
      if (!item.hasConfiguredUnitPrice && item.offer == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'سعر الوحدة ${item.selectedUnit ?? item.unit} غير مضبوط للصنف ${item.name}'),
          backgroundColor: Colors.orange,
        ));
        return;
      }
      if (!item.hasConfiguredUnitConversion) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('معامل تحويل الوحدة غير مضبوط للصنف ${item.name}'),
          backgroundColor: Colors.orange,
        ));
        return;
      }
    }

    setState(() => _isSubmitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ordersProvider = context.read<OrdersProvider>();
    final draftsProvider = context.read<DraftsProvider>();

    final hadPendingSubmission = _pendingSubmission;
    try {
      if (!await _refreshOffersForSubmission(pending: hadPendingSubmission)) {
        return;
      }
      _clientRequestId ??= 'REQ-${DateTime.now().microsecondsSinceEpoch}-'
          '${Random.secure().nextInt(0x7fffffff)}';
      if (!await _saveToDraft(immediate: true)) {
        if (!hadPendingSubmission) _clientRequestId = null;
        throw Exception('تعذر حفظ المسودة قبل إرسال الطلب');
      }
      final clientRequestId = _clientRequestId!;

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
        currency: _cart.first.currency,
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
                  finalPrice: null,
                  currency: i.currency,
                  status: 'pending',
                  stockAvailable: i.stockAvailable,
                  customerNote: i.note,
                  offer: i.offer,
                  expectedUnitPrice: i.expectedUnitPrice,
                ))
            .toList(),
      );

      final orderId = await ordersProvider.createOrder(
        order,
        customerId: order.customerId,
      );

      if (orderId.isNotEmpty) {
        if (_draftId != null) {
          await draftsProvider.deleteDraft(_draftId!);
          if (draftsProvider.error != null) {
            throw StateError(
                'تم إرسال الطلب، لكن تعذر حذف مسودته المحلية: ${draftsProvider.error}');
          }
        }
        messenger.showSnackBar(const SnackBar(
            content: Text('تم إرسال الطلب بنجاح'),
            backgroundColor: Colors.green));
        if (mounted) {
          setState(() => _cart.clear());
          if (fromReviewDialog) {
            navigator.pop();
            popAfterGuard(context,
                allowPop: () => setState(() => _allowPop = true), result: true);
          } else {
            popAfterGuard(context,
                allowPop: () => setState(() => _allowPop = true), result: true);
          }
        }
      } else {
        throw Exception('فشل الحصول على رقم الطلب');
      }
    } catch (e) {
      const preWriteErrors = {
        'CUSTOMER_NOT_FOUND',
        'INVALID_ORDER_ITEM',
        'PRODUCT_NOT_FOUND',
        'PRODUCT_CURRENCY_MISMATCH',
        'CONFLICTING_PRODUCT_UNITS',
        'INVALID_PRODUCT_UNIT',
        'UNIT_CONVERSION_REQUIRED',
        'UNIT_PRICE_REQUIRED',
      };
      if ((!hadPendingSubmission ||
              (e is ApiException &&
                  (e.code == 'OFFER_CHANGED' || e.code == 'PRICE_CHANGED'))) &&
          mounted &&
          e is ApiException &&
          (preWriteErrors.contains(e.code) ||
              e.code == 'OFFER_CHANGED' ||
              e.code == 'PRICE_CHANGED')) {
        final pendingId = _clientRequestId;
        _clientRequestId = null;
        if (!await _saveToDraft(immediate: true)) {
          _clientRequestId = pendingId;
        }
      }
      messenger.showSnackBar(SnackBar(
          content: Text(e is ApiException &&
                  (e.code == 'OFFER_CHANGED' || e.code == 'PRICE_CHANGED')
              ? 'تغير ${e.code == 'OFFER_CHANGED' ? 'العرض' : 'السعر'} قبل الإرسال ولم يُحفظ الطلب. أعد المحاولة لمراجعة الأسعار الحالية.'
              : 'فشل الإرسال: $e'),
          backgroundColor: Colors.red));
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

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
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
        body: _draftLoadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(_draftLoadError!, textAlign: TextAlign.center),
                ),
              )
            : !_draftReady
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      if (_pendingSubmission)
                        const MaterialBanner(
                          content: Text(
                              'نتيجة الإرسال غير مؤكدة. أعد المحاولة بالطلب نفسه؛ التعديل معطل حتى تتأكد النتيجة.'),
                          actions: [SizedBox.shrink()],
                        ),
                      if (provider.error != null)
                        Container(
                          color: Colors.red.shade100,
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline,
                                  color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(provider.error!,
                                      style:
                                          const TextStyle(color: Colors.red))),
                              IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => provider.resetStatus()),
                            ],
                          ),
                        ),
                      // شريط اسم الزبون
                      if (_isStaffOrder) ...[
                        IgnorePointer(
                          ignoring: _pendingSubmission || _isSubmitting,
                          child: _buildCustomerSelector(matchingCustomers),
                        ),
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
                                        onLongPress: () =>
                                            _showProductDetails(p),
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
                          guideAccountId: PermissionHelper.fromString(
                                      widget.session['role']?.toString() ??
                                          '') ==
                                  AppRole.customer
                              ? widget.session['user_id']?.toString()
                              : null,
                          cartItems: _cart,
                          onSubmit: () => _submitOrder(fromReviewDialog: true),
                          onRemoveItem: (item) {
                            if (_pendingSubmission || _isSubmitting) return;
                            _resetClientRequestId();
                            setState(() {
                              if (item.offer?.isBundle == true) {
                                _cart.removeWhere((entry) =>
                                    entry.offer?.id == item.offer!.id);
                              } else {
                                _cart.remove(item);
                              }
                            });
                            _saveToDraft(immediate: false);
                            if (item.offer?.isBundle == true && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تم حذف الحزمة بجميع مكوناتها'),
                                ),
                              );
                            }
                          },
                          onUpdateItem: (item, quantity, unit) {
                            if (_pendingSubmission || _isSubmitting) return;
                            if (item.offer?.isBundle == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'مكونات الحزمة وكمياتها مرتبطة؛ احذف الحزمة كاملة وأضفها من جديد لتغيير العدد.'),
                                ),
                              );
                              return;
                            }
                            final product = item.product;
                            if (product == null) return;
                            if (unit != (item.selectedUnit ?? item.unit) &&
                                (product.priceForUnit(unit) == null ||
                                    product.factorForUnit(unit) == null ||
                                    !product.factorForUnit(unit)!.isFinite ||
                                    product.factorForUnit(unit)! <= 0)) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text(
                                    'سعر الوحدة أو معامل تحويلها غير مضبوط'),
                              ));
                              return;
                            }
                            final index = _cart.indexOf(item);
                            if (index < 0) return;
                            _resetClientRequestId();
                            setState(() {
                              if (unit == (item.selectedUnit ?? item.unit)) {
                                item.quantity = quantity;
                              } else {
                                _cart[index] = OrderItem.fromProduct(
                                  product,
                                  quantity: quantity,
                                  selectedUnit: unit,
                                  note: item.note,
                                  expectedUnitPrice:
                                      item.expectedUnitPrice == null
                                          ? null
                                          : product.priceForUnit(unit),
                                );
                              }
                            });
                            _saveToDraft(immediate: false);
                          },
                          isSubmitting: _isSubmitting,
                          canEdit: () => !_pendingSubmission && !_isSubmitting,
                        ),
                        onSubmitTap: _submitOrder,
                      ),

                      // ملاحظات عامة
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: _orderNoteCtrl,
                          readOnly: _pendingSubmission || _isSubmitting,
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
                    _resetClientRequestId();
                    _customerId = null;
                    _customerName = null;
                    _customerSearchCtrl.clear();
                  });
                  if (_draftId != null || _initialDraftSave != null) {
                    _saveToDraft(immediate: false);
                  }
                },
              ),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) {
              final changed =
                  _customerId != null && value.trim() != _customerName;
              setState(() {
                if (value.trim() != _customerName) {
                  _resetClientRequestId();
                  _customerId = null;
                  _customerName = null;
                }
              });
              if (changed && (_draftId != null || _initialDraftSave != null)) {
                _saveToDraft(immediate: false);
              }
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
                        _resetClientRequestId();
                        _customerId = customer.id;
                        _customerName = customer.name;
                        _customerSearchCtrl.text = customer.name;
                        _customerSearchCtrl.selection = TextSelection.collapsed(
                            offset: _customerSearchCtrl.text.length);
                      });
                      if (_draftId != null || _initialDraftSave != null) {
                        _saveToDraft(immediate: false);
                      }
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
