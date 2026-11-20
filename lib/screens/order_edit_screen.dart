import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../models/order_item.dart';
import '../models/product.dart';
import '../repositories/order_repository.dart';
import '../repositories/product_repository.dart';
import '../services/database_service.dart';
import '../utils/permissions.dart';
import '../utils/guarded_navigation.dart';

class OrderEditScreen extends StatefulWidget {
  final Order order;
  final AppRole role;

  const OrderEditScreen({
    super.key,
    required this.order,
    required this.role,
  });

  @override
  State<OrderEditScreen> createState() => _OrderEditScreenState();
}

class _OrderEditScreenState extends State<OrderEditScreen> {
  final _noteController = TextEditingController();
  final List<_EditableOrderItem> _items = [];
  bool _isSaving = false;
  bool _allowPop = false;
  late final String _initialValues;
  late final bool _isCustomer = widget.role == AppRole.customer;
  late final bool _canEditPrice = !_isCustomer &&
      const {'priced', 'customer_confirmed', 'approved'}
          .contains(widget.order.status.toLowerCase());

  @override
  void initState() {
    super.initState();
    _noteController.text = widget.order.note ?? '';
    for (final item in widget.order.items ?? const <OrderItem>[]) {
      _items.add(_EditableOrderItem.fromOrderItem(
        item,
        isCustomer: _isCustomer,
        canEditPrice: _canEditPrice,
      ));
    }
    _initialValues = _currentValues();
  }

  String _currentValues() => jsonEncode({
        'note': _noteController.text,
        'items': _items
            .map((item) => [
                  item.code,
                  item.quantityController.text,
                  item.unitController.text,
                  item.priceController.text,
                  item.noteController.text,
                ])
            .toList(),
      });

  Future<void> _handleBack() async {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_isSaving) return;
    if (_currentValues() == _initialValues) {
      popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديلات غير محفوظة'),
        content: const Text('احفظ التعديلات أولاً أو تجاهلها للعودة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('متابعة التحرير'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تجاهل التعديلات'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _addProduct() async {
    List<Product> products;
    try {
      products =
          await ProductRepository(context.read<AppDatabase>()).getProducts();
    } catch (error) {
      if (mounted) _showError('تعذر تحميل المنتجات: $error');
      return;
    }
    if (!mounted) return;

    final selectedProduct = await showDialog<Product>(
      context: context,
      builder: (dialogContext) {
        var query = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtered = products.where((product) {
              final normalizedQuery = query.toLowerCase();
              return product.name.toLowerCase().contains(normalizedQuery) ||
                  product.code.toLowerCase().contains(normalizedQuery);
            }).toList();

            return AlertDialog(
              title: const Text('إضافة صنف'),
              content: SizedBox(
                width: double.maxFinite,
                height: 420,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'ابحث بالاسم أو الرمز',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (value) => setDialogState(() => query = value),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final product = filtered[index];
                          return ListTile(
                            title: Text(product.name),
                            subtitle: Text(product.code),
                            onTap: () => Navigator.pop(dialogContext, product),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedProduct == null || !mounted) return;
    if (_items.any((item) => item.code == selectedProduct.code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا الصنف موجود في الطلب بالفعل')),
      );
      return;
    }

    setState(() {
      _items.add(_EditableOrderItem.fromProduct(
        selectedProduct,
        canEditPrice: _canEditPrice,
      ));
    });
  }

  Future<void> _save() async {
    if (_items.isEmpty) {
      _showError('لا يمكن حفظ طلب بدون أصناف');
      return;
    }

    final updates = <Map<String, dynamic>>[];
    for (final item in _items) {
      final quantity = double.tryParse(item.quantityController.text.trim());
      if (quantity == null || !quantity.isFinite || quantity <= 0) {
        _showError('أدخل كمية صحيحة للصنف ${item.name}');
        return;
      }

      final price = double.tryParse(item.priceController.text.trim());
      if (_canEditPrice &&
          item.priceController.text.trim().isNotEmpty &&
          (price == null || !price.isFinite || price < 0)) {
        _showError('أدخل سعراً صحيحاً للصنف ${item.name}');
        return;
      }

      updates.add({
        if (item.itemId.isNotEmpty) 'item_id': item.itemId,
        'code': item.code,
        'unit': item.unitController.text.trim(),
        'quantity': quantity,
        'note': item.noteController.text.trim(),
        if (_canEditPrice && price != null) 'price': price,
        // Include tracking metadata if available
        'unit_factor': item.unitFactor,
        'base_price_snapshot': item.basePriceSnapshot,
        'unit_1': item.unit1,
        'unit_2': item.unit2,
        'factor_2': item.factor2,
        'unit_3': item.unit3,
        'factor_3': item.factor3,
      });
    }

    setState(() => _isSaving = true);
    try {
      await OrderRepository(db: context.read<AppDatabase>()).editOrder(
        orderId: widget.order.orderId,
        note: _noteController.text.trim(),
        items: updates,
      );
      if (mounted) {
        popAfterGuard(context,
            allowPop: () => setState(() => _allowPop = true), result: true);
      }
    } catch (error) {
      _showError(error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        appBar: AppBar(title: Text('تعديل الطلب #${widget.order.orderNumber}')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'ملاحظة الطلب',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < _items.length; index++)
              _buildItemCard(index),
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _addProduct,
              icon: const Icon(Icons.add),
              label: const Text('إضافة صنف'),
            ),
            const SizedBox(height: 80),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.all(16),
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ التعديلات'),
          ),
        ),
      ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'حذف الصنف',
                  onPressed: _isSaving
                      ? null
                      : () => setState(() {
                            _items.removeAt(index).dispose();
                          }),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              ],
            ),
            Text(item.code, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.quantityController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'الكمية',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: item.unitController,
                    decoration: const InputDecoration(
                      labelText: 'الوحدة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (_canEditPrice) ...[
              const SizedBox(height: 8),
              TextField(
                controller: item.priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'سعر الوحدة',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              controller: item.noteController,
              decoration: InputDecoration(
                labelText: _isCustomer ? 'ملاحظة الصنف' : 'ملاحظة المحاسب',
                border: const OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableOrderItem {
  final String itemId;
  final String code;
  final String name;
  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController priceController;
  final TextEditingController noteController;

  // Metadata for tracking
  double? unitFactor;
  double? basePriceSnapshot;
  String? unit1;
  String? unit2;
  double? factor2;
  String? unit3;
  double? factor3;

  _EditableOrderItem({
    required this.itemId,
    required this.code,
    required this.name,
    required String quantity,
    required String unit,
    required String price,
    required String note,
    this.unitFactor,
    this.basePriceSnapshot,
    this.unit1,
    this.unit2,
    this.factor2,
    this.unit3,
    this.factor3,
  })  : quantityController = TextEditingController(text: quantity),
        unitController = TextEditingController(text: unit),
        priceController = TextEditingController(text: price),
        noteController = TextEditingController(text: note);

  factory _EditableOrderItem.fromOrderItem(
    OrderItem item, {
    required bool isCustomer,
    required bool canEditPrice,
  }) {
    final quantity = isCustomer
        ? item.quantityRequested
        : item.quantityApproved ?? item.quantityRequested;
    final price = item.finalPrice ?? item.priceOffer ?? item.defaultPrice;
    return _EditableOrderItem(
      itemId: item.itemId,
      code: item.code,
      name: item.name,
      quantity: quantity?.toString() ?? '',
      unit: item.unit,
      price: canEditPrice ? price?.toString() ?? '' : '',
      note: isCustomer ? item.customerNote ?? '' : item.accountantNote ?? '',
      unitFactor: item.unitFactor,
      basePriceSnapshot: item.basePriceSnapshot,
      unit1: item.unit1,
      unit2: item.unit2,
      factor2: item.factor2,
      unit3: item.unit3,
      factor3: item.factor3,
    );
  }

  factory _EditableOrderItem.fromProduct(
    Product product, {
    required bool canEditPrice,
  }) {
    return _EditableOrderItem(
      itemId: '',
      code: product.code,
      name: product.name,
      quantity: '1',
      unit: product.unit,
      price: canEditPrice ? product.price.toString() : '',
      note: '',
      unitFactor: 1.0,
      basePriceSnapshot: product.price,
      unit1: product.unit,
      unit2: product.unit2,
      factor2: product.factor2,
      unit3: product.unit3,
      factor3: product.factor3,
    );
  }

  void dispose() {
    quantityController.dispose();
    unitController.dispose();
    priceController.dispose();
    noteController.dispose();
  }
}
