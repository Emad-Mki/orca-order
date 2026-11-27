import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/order_detail_provider.dart';
import '../models/order_item.dart';
import '../utils/number_utils.dart';
import '../utils/guarded_navigation.dart';
import '../utils/smart_product_search.dart';
import '../repositories/product_repository.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../widgets/product_image_widget.dart';
import '../services/api_service.dart';
import '../utils/order_discount.dart';

import '../services/database_service.dart';

class PricingItem {
  final String productId;
  final String productCode;
  final String productName;
  final String imageUrl;
  final double requestedQuantity;
  final double? initialPriceOffer;
  final int stockAvailable;

  double quantity;
  String unit;
  double? unitPrice; // Null means not yet priced
  bool available;
  String note;
  bool isNewlyAdded;

  // Multi-unit support
  List<String> availableUnits;
  Map<String, double> unitFactors;
  double basePriceSnapshot;

  late TextEditingController quantityController;
  late TextEditingController priceController;

  PricingItem({
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.imageUrl,
    required this.requestedQuantity,
    required this.quantity,
    required this.unit,
    required this.stockAvailable,
    this.unitPrice,
    this.initialPriceOffer,
    this.available = true,
    this.note = '',
    this.isNewlyAdded = false,
    this.availableUnits = const [],
    this.unitFactors = const {},
    this.basePriceSnapshot = 0.0,
  }) {
    quantityController = TextEditingController(text: _formatNum(quantity));
    priceController = TextEditingController(
        text: unitPrice != null ? _formatNum(unitPrice!) : '');

    if (availableUnits.isEmpty) {
      availableUnits = [unit];
    }
    if (unitFactors.isEmpty) {
      unitFactors = {unit: 1.0};
    }
  }

  static bool needsOfferPriceOverride(
      List<PricingItem> pricedItems, List<OrderItem> originalItems) {
    return pricedItems.any((priced) {
      if (!priced.available) return false;
      return originalItems.any((original) =>
          original.code == priced.productId &&
          original.offer?.price != null &&
          priced.effectivePrice != original.offer!.price);
    });
  }

  static String _formatNum(double n) =>
      n % 1 == 0 ? n.toInt().toString() : n.toString();

  void dispose() {
    quantityController.dispose();
    priceController.dispose();
  }

  double get effectivePrice => unitPrice ?? initialPriceOffer ?? 0.0;
  double get lineTotal =>
      available ? roundOrderAmount(quantity * effectivePrice) : 0;
  bool get isPriceSuggested => unitPrice == null && initialPriceOffer != null;

  factory PricingItem.fromModel(OrderItem item, {Product? product}) {
    List<String> units = [];
    Map<String, double> factors = {};
    double bPrice = item.basePriceSnapshot ?? 0.0;

    // Preference 1: Use snapshots from the item itself (historical consistency)
    if (item.unit1 != null && item.unit1!.isNotEmpty) {
      units.add(item.unit1!);
      factors[item.unit1!] = 1.0;
      if (item.unit2 != null && item.unit2!.isNotEmpty) {
        units.add(item.unit2!);
        factors[item.unit2!] = item.factor2 ?? 1.0;
      }
      if (item.unit3 != null && item.unit3!.isNotEmpty) {
        units.add(item.unit3!);
        factors[item.unit3!] = item.factor3 ?? 1.0;
      }
    }
    // Preference 2: Fallback to current product data if snapshots are missing
    else if (product != null) {
      units = product.units ?? [];
      if (units.isEmpty) {
        units.add(product.unit);
      }
      factors = {product.unit: 1.0};
      if (product.unit2 != null && product.unit2!.isNotEmpty) {
        factors[product.unit2!] = product.factor2 ?? 1.0;
        if (!units.contains(product.unit2)) units.add(product.unit2!);
      }
      if (product.unit3 != null && product.unit3!.isNotEmpty) {
        factors[product.unit3!] = product.factor3 ?? 1.0;
        if (!units.contains(product.unit3)) units.add(product.unit3!);
      }
      if (bPrice == 0) bPrice = product.price;
    }
    // Preference 3: Minimal fallback
    else {
      units = [item.unit];
      factors = {item.unit: 1.0};
      if (bPrice == 0) {
        bPrice = item.finalPrice ?? item.priceOffer ?? item.defaultPrice ?? 0.0;
      }
    }

    return PricingItem(
      productId: item.code,
      productCode: item.code,
      productName: item.name,
      imageUrl: item.imageUrl ?? '',
      requestedQuantity: item.quantityRequested ?? 0.0,
      quantity: item.quantityApproved ?? item.quantityRequested ?? 0.0,
      unit: item.unit,
      stockAvailable: product?.stock ?? item.stockAvailable,
      unitPrice: item.finalPrice,
      initialPriceOffer: item.priceOffer ?? item.defaultPrice,
      available: !item.isUnavailable,
      note: item.accountantNote ?? '',
      availableUnits: units,
      unitFactors: factors,
      basePriceSnapshot: bPrice,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': productCode,
      'quantity_approved': quantity,
      'unit': unit,
      'final_price': unitPrice ?? initialPriceOffer,
      'status': available ? 'available' : 'unavailable',
      'accountant_note': note,
      'is_newly_added': isNewlyAdded,
    };
  }
}

class OrderPricingScreen extends StatefulWidget {
  final Order order;

  const OrderPricingScreen({super.key, required this.order});

  @override
  State<OrderPricingScreen> createState() => _OrderPricingScreenState();
}

class _OrderPricingScreenState extends State<OrderPricingScreen> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _discountController = TextEditingController();
  final TextEditingController _discountReasonController =
      TextEditingController();
  final TextEditingController _accountingInvoiceController =
      TextEditingController();
  List<PricingItem> _pricingItems = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _allowPop = false;
  bool _draftReady = false;
  Timer? _draftSaveDebounce;
  String? _error;
  String? _initialValues;

  String _currentValues() => jsonEncode({
        'note': _noteController.text,
        'discount': _discountController.text,
        'discount_reason': _discountReasonController.text,
        'accounting_invoice_no': _accountingInvoiceController.text,
        'items': _pricingItems
            .map((item) => {
                  ...item.toJson(),
                  'product_name': item.productName,
                  'image_url': item.imageUrl,
                  'requested_quantity': item.requestedQuantity,
                  'initial_price_offer': item.initialPriceOffer,
                  'stock_available': item.stockAvailable,
                  'available_units': item.availableUnits,
                  'unit_factors': item.unitFactors,
                  'base_price_snapshot': item.basePriceSnapshot,
                  'quantity_input': item.quantityController.text,
                  'price_input': item.priceController.text,
                })
            .toList(),
      });

  Future<void> _back() async {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_isSaving) return;
    if (_initialValues == null || _currentValues() == _initialValues) {
      popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسعير غير محفوظ'),
        content: const Text(
            'يمكن حفظ مسودة التسعير على هذا الجهاز أو متابعة التحرير.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'continue'),
            child: const Text('متابعة التحرير'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('حفظ المسودة والخروج'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('تجاهل التعديلات'),
          ),
        ],
      ),
    );
    if (choice == 'save') {
      final saved = await _saveLocalDraft();
      if (!saved && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر حفظ المسودة على هذا الجهاز'),
        ));
        return;
      }
    }
    if (choice == 'discard') {
      try {
        await (await SharedPreferences.getInstance()).remove(_localDraftKey);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('تعذر حذف مسودة التسعير: $error'),
          ));
        }
        return;
      }
    }
    if ((choice == 'save' || choice == 'discard') && mounted) {
      popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
    }
  }

  @override
  void dispose() {
    for (var item in _pricingItems) {
      item.dispose();
    }
    _noteController.dispose();
    _discountController.dispose();
    _discountReasonController.dispose();
    _accountingInvoiceController.dispose();
    _draftSaveDebounce?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _noteController.addListener(_scheduleLocalDraftSave);
    _discountController.addListener(_scheduleLocalDraftSave);
    _discountReasonController.addListener(_scheduleLocalDraftSave);
    _accountingInvoiceController.addListener(_scheduleLocalDraftSave);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final provider = Provider.of<OrderDetailProvider>(context, listen: false);
      final database = Provider.of<AppDatabase>(context, listen: false);
      await provider.fetchOrderDetails(widget.order.orderId);
      if (!mounted) return;

      if (provider.errorMessage != null) {
        setState(() => _error = provider.errorMessage);
      } else {
        // Fetch products to get unit information for multi-unit support
        final productRepository = ProductRepository(database);
        final allProducts = await productRepository.getProducts();
        if (!mounted) return;
        final productMap = {for (var p in allProducts) p.code: p};

        setState(() {
          // Dispose old items before clearing list
          for (var item in _pricingItems) {
            item.dispose();
          }
          _pricingItems = provider.items.map((item) {
            return PricingItem.fromModel(item, product: productMap[item.code]);
          }).toList();
          _noteController.text = provider.currentOrder?.accountantNotes ?? '';
          final currentOrder = provider.currentOrder;
          _discountController.text = currentOrder?.discountInput ??
              (currentOrder?.discount?.toString() ?? '');
          _discountReasonController.text = currentOrder?.discountReason ?? '';
          _accountingInvoiceController.text =
              currentOrder?.accountingInvoiceNo ?? '';
          _initialValues = _currentValues();
        });
        await _restoreLocalDraft();
        if (!mounted) return;
        _draftReady = true;
        for (final item in _pricingItems) {
          item.quantityController.addListener(_scheduleLocalDraftSave);
          item.priceController.addListener(_scheduleLocalDraftSave);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _localDraftKey => 'order_pricing_draft_${widget.order.orderId}';

  void _scheduleLocalDraftSave() {
    if (!_draftReady) return;
    _draftSaveDebounce?.cancel();
    _draftSaveDebounce = Timer(const Duration(milliseconds: 300), () {
      _saveLocalDraft();
    });
  }

  Future<bool> _saveLocalDraft() async {
    if (!_draftReady) return false;
    try {
      final preferences = await SharedPreferences.getInstance();
      return await preferences.setString(_localDraftKey, _currentValues());
    } catch (error) {
      debugPrint('Pricing draft save failed: ${error.runtimeType}');
      return false;
    }
  }

  Future<void> _restoreLocalDraft() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    final saved = preferences.getString(_localDraftKey);
    if (saved == null || saved.isEmpty) return;
    try {
      final decoded = jsonDecode(saved);
      if (decoded is! Map || decoded['items'] is! List) {
        throw const FormatException('مسودة التسعير المحلية غير صالحة');
      }
      final restored = <PricingItem>[];
      for (final value in decoded['items'] as List) {
        if (value is! Map) {
          throw const FormatException('أحد بنود مسودة التسعير غير صالح');
        }
        final item = Map<String, dynamic>.from(value);
        double number(dynamic value, {double fallback = 0}) {
          if (value is num) return value.toDouble();
          return double.tryParse(value?.toString() ?? '') ?? fallback;
        }

        final availableUnits = (item['available_units'] as List? ?? const [])
            .map((unit) => unit.toString())
            .toList();
        final factorsValue = item['unit_factors'];
        final unitFactors = <String, double>{};
        if (factorsValue is Map) {
          factorsValue.forEach((key, factor) {
            unitFactors[key.toString()] = number(factor, fallback: 1);
          });
        }
        final quantityText = item['quantity_input']?.toString() ?? '0';
        final priceText = item['price_input']?.toString() ?? '';
        final quantity = double.tryParse(quantityText);
        final price = priceText.isEmpty ? null : double.tryParse(priceText);
        if (quantity == null || (priceText.isNotEmpty && price == null)) {
          throw const FormatException(
              'تعذر استعادة كمية أو سعر من مسودة التسعير');
        }
        final unit = item['unit']?.toString() ?? '';
        final code = item['code']?.toString() ?? '';
        if (code.isEmpty) {
          throw const FormatException('رمز منتج مفقود في مسودة التسعير');
        }
        restored.add(PricingItem(
          productId: code,
          productCode: code,
          productName: item['product_name']?.toString() ?? '',
          imageUrl: item['image_url']?.toString() ?? '',
          requestedQuantity: number(item['requested_quantity']),
          quantity: quantity,
          unit: unit,
          stockAvailable: number(item['stock_available']).toInt(),
          unitPrice: price,
          initialPriceOffer: item['initial_price_offer'] == null
              ? null
              : number(item['initial_price_offer']),
          available: item['status'] != 'unavailable',
          note: item['accountant_note']?.toString() ?? '',
          isNewlyAdded: item['is_newly_added'] == true,
          availableUnits: availableUnits.isEmpty ? [unit] : availableUnits,
          unitFactors: unitFactors.isEmpty ? {unit: 1} : unitFactors,
          basePriceSnapshot: number(item['base_price_snapshot']),
        ));
      }
      for (final item in _pricingItems) {
        item.dispose();
      }
      setState(() {
        _pricingItems = restored;
        _noteController.text = decoded['note']?.toString() ?? '';
        _discountController.text = decoded['discount']?.toString() ?? '';
        _discountReasonController.text =
            decoded['discount_reason']?.toString() ?? '';
        _accountingInvoiceController.text =
            decoded['accounting_invoice_no']?.toString() ?? '';
      });
    } on FormatException catch (error) {
      await preferences.remove(_localDraftKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تعذر استعادة مسودة التسعير: ${error.message}'),
        ));
      }
    }
  }

  double get _subtotal =>
      _pricingItems.fold(0, (sum, item) => sum + item.lineTotal);

  OrderDiscountCalculation? get _discountCalculation {
    try {
      return calculateOrderDiscount(
        input: _discountController.text,
        subtotal: _subtotal,
      );
    } on FormatException {
      return null;
    }
  }

  void _showAddProductDialog() async {
    final productRepository =
        ProductRepository(Provider.of<AppDatabase>(context, listen: false));
    final List<Product> products = await productRepository.getProducts();

    if (!mounted) return;

    final searchIndex = SmartProductSearchIndex(products);
    var visibleQuery = '';
    Timer? searchDebounce;
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final filtered = searchIndex.search(visibleQuery);

            return AlertDialog(
              title: const Text('إضافة منتج للطلب'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'بحث عن منتج...',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) {
                        searchDebounce?.cancel();
                        searchDebounce = Timer(
                          const Duration(milliseconds: 220),
                          () => setState(() => visibleQuery = value),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final p = filtered[index];
                          return ListTile(
                            title: Text(p.name),
                            subtitle: Text('${p.code} - ${p.price} \$'),
                            onTap: () {
                              final pricingItem = PricingItem(
                                productId: p.code,
                                productCode: p.code,
                                productName: p.name,
                                imageUrl: p.imageUrl ?? '',
                                requestedQuantity: 0,
                                quantity: 1,
                                unit: p.unit,
                                stockAvailable: p.stock,
                                unitPrice: p.price,
                                availableUnits: p.units ?? [p.unit],
                                unitFactors: {
                                  p.unit: 1.0,
                                  if (p.unit2 != null && p.unit2!.isNotEmpty)
                                    p.unit2!: p.factor2 ?? 1.0,
                                  if (p.unit3 != null && p.unit3!.isNotEmpty)
                                    p.unit3!: p.factor3 ?? 1.0,
                                },
                                basePriceSnapshot: p.price,
                                isNewlyAdded: true,
                              );
                              if (_draftReady) {
                                pricingItem.quantityController
                                    .addListener(_scheduleLocalDraftSave);
                                pricingItem.priceController
                                    .addListener(_scheduleLocalDraftSave);
                              }
                              this.setState(() {
                                _pricingItems.add(pricingItem);
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => searchDebounce?.cancel());
  }

  Future<void> _submitPricing({required bool submitForCustomer}) async {
    if (_isSaving) return;

    final discountCalculation = _discountCalculation;
    if (discountCalculation == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'قيمة الحسم غير صالحة. استخدم مبلغاً مثل 25.50 أو نسبة مثل 10%.'),
      ));
      return;
    }
    final currentOrder =
        Provider.of<OrderDetailProvider>(context, listen: false).currentOrder;
    final oldDiscountType = currentOrder?.discountType ??
        ((currentOrder?.discount ?? 0) > 0 ? 'amount' : 'none');
    final oldDiscountInput = currentOrder?.discountInput ??
        ((currentOrder?.discount ?? 0) > 0
            ? currentOrder!.discount!.toString()
            : '');
    final discountChanged =
        (currentOrder?.discount ?? 0) != discountCalculation.amount ||
            oldDiscountType != discountCalculation.type ||
            oldDiscountInput != discountCalculation.input;
    if (discountChanged && _discountReasonController.text.trim().length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('أدخل سبباً مختصراً لتعديل الحسم'),
      ));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final provider = Provider.of<OrderDetailProvider>(context, listen: false);
      final overridesOffer =
          PricingItem.needsOfferPriceOverride(_pricingItems, provider.items);
      if (overridesOffer) {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تأكيد تعديل سعر العرض'),
            content: const Text(
                'عدّلت سعر بند مرتبط بعرض. السعر اليدوي سيحل محل سعر العرض '
                'في التسعير المعتمد، وسيُسجّل التعديل؛ لا يضاف حسم تلقائي آخر.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('مراجعة')),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('تأكيد السعر اليدوي')),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
      }

      final nextAccountingInvoice = _accountingInvoiceController.text
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (nextAccountingInvoice !=
          (provider.currentOrder?.accountingInvoiceNo ?? '').trim()) {
        final response =
            await ApiService().orders.updateAccountingInvoiceNumber(
                  orderId: widget.order.orderId,
                  invoiceNumber: nextAccountingInvoice,
                );
        if (response['ok'] != true && response['success'] != true) {
          throw Exception(
              response['error'] ?? 'تعذر حفظ رقم الفاتورة المحاسبي');
        }
        if (!mounted) return;
      }

      // Map local pricing items back to OrderItem models for the provider
      final List<OrderItem> updatedOrderItems = _pricingItems.map((pItem) {
        // Find if this item already exists in the provider's original list
        final originalItemIndex =
            provider.items.indexWhere((i) => i.code == pItem.productId);

        if (originalItemIndex != -1) {
          // Update existing item
          return provider.items[originalItemIndex].copyWith(
            quantityApproved: pItem.quantity,
            unit: pItem.unit,
            finalPrice: pItem.unitPrice,
            unitFactor: pItem.unitFactors[pItem.unit],
            basePriceSnapshot: pItem.basePriceSnapshot,
            unit1: pItem.availableUnits.isNotEmpty
                ? pItem.availableUnits[0]
                : null,
            unit2: pItem.availableUnits.length > 1
                ? pItem.availableUnits[1]
                : null,
            factor2: pItem.availableUnits.length > 1
                ? pItem.unitFactors[pItem.availableUnits[1]]
                : null,
            unit3: pItem.availableUnits.length > 2
                ? pItem.availableUnits[2]
                : null,
            factor3: pItem.availableUnits.length > 2
                ? pItem.unitFactors[pItem.availableUnits[2]]
                : null,
            status: pItem.available ? 'available' : 'unavailable',
            accountantNote: pItem.note,
          );
        } else {
          // It's a newly added item
          return OrderItem(
            itemId: 'NEW-${DateTime.now().millisecondsSinceEpoch}',
            code: pItem.productId,
            name: pItem.productName,
            unit: pItem.unit,
            quantityRequested: pItem.quantity,
            quantityApproved: pItem.quantity,
            quantityPrepared: 0,
            priceOffer: pItem.effectivePrice,
            defaultPrice: pItem.effectivePrice,
            finalPrice: pItem.unitPrice,
            unitFactor: pItem.unitFactors[pItem.unit],
            basePriceSnapshot: pItem.basePriceSnapshot,
            unit1: pItem.availableUnits.isNotEmpty
                ? pItem.availableUnits[0]
                : null,
            unit2: pItem.availableUnits.length > 1
                ? pItem.availableUnits[1]
                : null,
            factor2: pItem.availableUnits.length > 1
                ? pItem.unitFactors[pItem.availableUnits[1]]
                : null,
            unit3: pItem.availableUnits.length > 2
                ? pItem.availableUnits[2]
                : null,
            factor3: pItem.availableUnits.length > 2
                ? pItem.unitFactors[pItem.availableUnits[2]]
                : null,
            currency: widget.order.currency,
            status: pItem.available ? 'available' : 'unavailable',
            stockAvailable: 0,
            accountantNote: pItem.note,
          );
        }
      }).toList();

      // Update the provider's items list
      provider.setItems(updatedOrderItems);

      if (!mounted) return;
      final success = await provider.savePricing(
        context: context,
        subtotal: _subtotal,
        total: discountCalculation.netTotal,
        discountInput: _discountController.text,
        discountReason: _discountReasonController.text.trim(),
        notes: _noteController.text,
        submitForCustomer: submitForCustomer,
        confirmOfferPriceOverride: overridesOffer,
      );

      if (!mounted) return;

      if (success) {
        _draftReady = false;
        try {
          await (await SharedPreferences.getInstance()).remove(_localDraftKey);
        } catch (error) {
          debugPrint('Pricing draft cleanup failed: ${error.runtimeType}');
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(submitForCustomer
                ? 'تم اعتماد وإرسال التسعير بنجاح'
                : 'تم حفظ مسودة التسعير'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        popAfterGuard(context,
            allowPop: () => setState(() => _allowPop = true), result: true);
      } else {
        throw Exception(provider.errorMessage ?? 'فشل حفظ التسعير');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _updateItemUnit(PricingItem item, String newUnit) {
    if (item.unit == newUnit) return;

    final newFactor = item.unitFactors[newUnit] ?? 1.0;

    setState(() {
      item.unit = newUnit;
      // Suggest new price based on base price and new factor
      if (item.basePriceSnapshot > 0) {
        item.unitPrice = item.basePriceSnapshot * newFactor;
        item.priceController.text = PricingItem._formatNum(item.unitPrice!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تسعير الفاتورة'),
          actions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showAddProductDialog,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('خطأ: $_error',
                          style: TextStyle(color: colors.error)),
                      ElevatedButton(
                          onPressed: _loadData,
                          child: const Text('إعادة المحاولة'))
                    ],
                  ))
                : Column(
                    children: [
                      _buildHeaderCard(),
                      Expanded(
                        child: _pricingItems.isEmpty
                            ? const Center(
                                child: Text('لا توجد بنود في هذه الطلبية'))
                            : ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: _pricingItems.length,
                                itemBuilder: (context, index) {
                                  return _buildPricingItemCard(index);
                                },
                              ),
                      ),
                      _buildSummarySection(),
                    ],
                  ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => _submitPricing(submitForCustomer: false),
                    style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('حفظ كمسودة'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : () => _submitPricing(submitForCustomer: true),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                    ),
                    child: _isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: colors.onPrimary, strokeWidth: 2))
                        : const Text('اعتماد وإرسال للزبون'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(8),
      color: colors.primaryContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('رقم الطلب: ${widget.order.orderNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.order.status,
                    style: TextStyle(
                        color: colors.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('الزبون: ${widget.order.customerName}'),
                Text(widget.order.createdAt.toString().split(' ')[0]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingItemCard(int index) {
    final item = _pricingItems[index];
    final colors = Theme.of(context).colorScheme;
    return Opacity(
      opacity: item.available ? 1.0 : 0.5,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.quantity > item.stockAvailable && item.available)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: colors.errorContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border.all(color: colors.error.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: colors.error),
                      const SizedBox(width: 8),
                      Text(
                        'الكمية المطلوبة تتجاوز المخزون المتاح (${item.stockAvailable})',
                        style: TextStyle(
                            color: colors.onSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductImageWidget(
                    imageUrl: item.imageUrl,
                    width: 56,
                    height: 56,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.productName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('كود: ${item.productCode}',
                            style: TextStyle(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (item.availableUnits.length <= 1)
                              Text('الوحدة: ${item.unit}',
                                  style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12))
                            else
                              Row(
                                children: [
                                  Text('الوحدة: ',
                                      style: TextStyle(
                                          color: colors.onSurfaceVariant,
                                          fontSize: 12)),
                                  DropdownButton<String>(
                                    value:
                                        item.availableUnits.contains(item.unit)
                                            ? item.unit
                                            : item.availableUnits.first,
                                    isDense: true,
                                    underline: Container(),
                                    style: TextStyle(
                                        color: colors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                    items: item.availableUnits
                                        .map((u) => DropdownMenuItem(
                                              value: u,
                                              child: Text(u),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        _updateItemUnit(item, val);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            _buildStockBadge(item),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.error),
                    onPressed: () => setState(() {
                      _pricingItems[index].dispose();
                      _pricingItems.removeAt(index);
                    }),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Quantity Stepper
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('الكمية',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colors.onSurfaceVariant)),
                            if (item.requestedQuantity > 0)
                              Text('مطلوب: ${item.requestedQuantity}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: colors.onSurfaceVariant)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: 45,
                          decoration: BoxDecoration(
                            border: Border.all(color: colors.outline),
                            borderRadius: BorderRadius.circular(8),
                            color: colors.surfaceContainerHighest,
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(Icons.remove_circle_outline,
                                    size: 22, color: colors.error),
                                onPressed: () {
                                  if (item.quantity > 0) {
                                    setState(() {
                                      item.quantity = (item.quantity - 1)
                                          .clamp(0, double.infinity);
                                      item.quantityController.text =
                                          PricingItem._formatNum(item.quantity);
                                    });
                                  }
                                },
                                padding: EdgeInsets.zero,
                              ),
                              Expanded(
                                child: TextFormField(
                                  controller: item.quantityController,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding:
                                        EdgeInsets.symmetric(vertical: 8),
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  onChanged: (val) {
                                    item.quantity = double.tryParse(val) ?? 0;
                                    setState(() {}); // Update subtotal
                                  },
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.add_circle_outline,
                                    size: 22, color: colors.primary),
                                onPressed: () {
                                  setState(() {
                                    item.quantity++;
                                    item.quantityController.text =
                                        PricingItem._formatNum(item.quantity);
                                  });
                                },
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Unit Price
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('سعر الوحدة',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: colors.onSurfaceVariant)),
                            if (item.isPriceSuggested)
                              Icon(Icons.info_outline,
                                  size: 14, color: colors.tertiary),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 45,
                          child: TextFormField(
                            controller: item.priceController,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: item.isPriceSuggested
                                  ? colors.tertiary
                                  : colors.primary,
                            ),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              isDense: true,
                              prefixIcon: Icon(Icons.attach_money,
                                  size: 18,
                                  color: item.isPriceSuggested
                                      ? colors.tertiary
                                      : colors.primary),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 10),
                              fillColor: item.isPriceSuggested
                                  ? colors.tertiaryContainer
                                      .withValues(alpha: 0.35)
                                  : colors.surfaceContainerHighest,
                              filled: true,
                              hintText: item.isPriceSuggested
                                  ? PricingItem._formatNum(
                                      item.initialPriceOffer!)
                                  : '',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            onChanged: (val) {
                              item.unitPrice = double.tryParse(val);
                              setState(() {}); // Update subtotal and status
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('المجموع: ${formatMoneyShort(item.lineTotal)}',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: item.available
                                  ? colors.primary
                                  : colors.onSurfaceVariant)),
                      if (item.isPriceSuggested)
                        Text('سعر مقترح - لم يعتمد',
                            style: TextStyle(
                                fontSize: 10,
                                color: colors.tertiary,
                                fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      if (!item.available)
                        Text('غير متوفر',
                            style: TextStyle(
                                color: colors.error,
                                fontWeight: FontWeight.bold)),
                      Switch(
                        value: item.available,
                        activeThumbColor: colors.primary,
                        activeTrackColor:
                            colors.primary.withValues(alpha: 0.45),
                        onChanged: (val) {
                          setState(() {
                            item.available = val;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              if (!item.available || item.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextFormField(
                    initialValue: item.note,
                    decoration: const InputDecoration(
                        hintText: 'ملاحظة على البند...',
                        border: UnderlineInputBorder()),
                    onChanged: (val) => setState(() => item.note = val),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockBadge(PricingItem item) {
    final bool isLowStock = item.stockAvailable <= 0;
    final bool isOverStock = item.quantity > item.stockAvailable;
    final colors = Theme.of(context).colorScheme;
    final statusColor = isLowStock
        ? colors.error
        : (isOverStock ? colors.tertiary : colors.primary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isLowStock
                ? Icons.error_outline
                : (isOverStock
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline),
            size: 12,
            color: statusColor,
          ),
          const SizedBox(width: 4),
          Text(
            'المخزون: ${item.stockAvailable}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final double previousBalance = widget.order.previousBalance ?? 0.0;
    final discountCalculation = _discountCalculation;
    final netTotal = discountCalculation?.netTotal ?? _subtotal;
    final double totalWithBalance = previousBalance + netTotal;
    final currentOrder =
        Provider.of<OrderDetailProvider>(context, listen: false).currentOrder;
    final oldDiscountType = currentOrder?.discountType ??
        ((currentOrder?.discount ?? 0) > 0 ? 'amount' : 'none');
    final oldDiscountInput = currentOrder?.discountInput ??
        ((currentOrder?.discount ?? 0) > 0
            ? currentOrder!.discount!.toString()
            : '');
    final discountChangedForPreview = discountCalculation != null &&
        ((currentOrder?.discount ?? 0) != discountCalculation.amount ||
            oldDiscountType != discountCalculation.type ||
            oldDiscountInput != discountCalculation.input);
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.outline)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow('إجمالي البنود:', _subtotal,
              isBold: true, currency: widget.order.currency),
          const SizedBox(height: 8),
          TextField(
            controller: _discountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'حسم إجمالي الفاتورة',
              hintText: '10% أو 25.50',
              helperText:
                  'النسبة من إجمالي البنود قبل الحسم، والمبلغ بعملة ${widget.order.currency}. تدخل أسعار العروض وخصومات البنود ضمن الإجمالي؛ والحسم العام يطبق يدوياً بعد ذلك.',
              errorText: discountCalculation == null &&
                      _discountController.text.isNotEmpty
                  ? 'أدخل مبلغاً أو نسبة صحيحة غير سالبة، ولا تتجاوز قيمة الحسم الإجمالي'
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (discountCalculation != null && discountCalculation.amount > 0)
            _buildSummaryRow('الحسم:', -discountCalculation.amount,
                color: colors.error, currency: widget.order.currency),
          _buildSummaryRow('صافي الفاتورة:', netTotal,
              isBold: true,
              color: colors.primary,
              currency: widget.order.currency),
          if (discountChangedForPreview)
            TextField(
              controller: _discountReasonController,
              decoration: const InputDecoration(
                labelText: 'سبب الحسم أو تعديله',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              maxLength: 200,
            ),
          const SizedBox(height: 8),
          TextField(
            controller: _accountingInvoiceController,
            maxLength: 64,
            decoration: const InputDecoration(
              labelText: 'رقم الفاتورة الأصلي في البرنامج المحاسبي (اختياري)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          if (previousBalance != 0)
            _buildSummaryRow('الرصيد السابق:', previousBalance,
                color: previousBalance > 0 ? colors.error : colors.primary,
                currency: widget.order.currency),
          const Divider(height: 16),
          _buildSummaryRow('الإجمالي النهائي:', totalWithBalance,
              isBold: true,
              fontSize: 18,
              color: colors.primary,
              currency: widget.order.currency),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: 'ملاحظات المحاسب العامة',
              border: OutlineInputBorder(),
              fillColor: colors.surfaceContainerHighest,
              filled: true,
              isDense: true,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount,
      {bool isBold = false,
      double fontSize = 14,
      Color? color,
      String currency = 'USD'}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              )),
          Text(formatMoneyShort(amount, currency: currency),
              style: TextStyle(
                fontSize: fontSize + 2,
                fontWeight: FontWeight.bold,
                color: color ??
                    (isBold ? colors.onSurface : colors.onSurfaceVariant),
              )),
        ],
      ),
    );
  }
}
