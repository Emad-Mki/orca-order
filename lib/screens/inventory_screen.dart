import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/product.dart';
import '../widgets/product_image_widget.dart';
import '../widgets/product_skeleton_widget.dart';
import 'inventory_movements_screen.dart';
import 'homepage_screen.dart';
import '../utils/permissions.dart';
import '../utils/smart_product_search.dart';

class InventoryScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const InventoryScreen({super.key, required this.session});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product> _products = [];
  SmartProductSearchIndex _searchIndex = SmartProductSearchIndex(const []);
  Timer? _searchDebounce;
  String _query = '';
  bool _isLoading = true;
  String? _error;
  final _search = TextEditingController();
  String _stockFilter = 'all';
  String? _group;
  String? _subGroup;
  Future<void>? _fetchRequest;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() {
    if (_fetchRequest != null) return _fetchRequest!;
    final request = _performFetchInventory();
    _fetchRequest = request;
    return request.whenComplete(() => _fetchRequest = null);
  }

  Future<void> _performFetchInventory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = ApiService().token;
      final data = await ApiService().products.getProducts(forceRefresh: true);
      if (token != ApiService().token) {
        throw StateError('تغير الحساب أثناء تحميل المخزون');
      }
      final list = data['products'] ?? data['data'];
      if (list is! List) {
        throw const FormatException(
            'استجابة المنتجات لا تحتوي على قائمة صالحة');
      }
      final products = list.map((p) {
        if (p is! Map) throw const FormatException('بيانات منتج غير صالحة');
        return Product.fromJson(Map<String, dynamic>.from(p));
      }).toList();
      if (mounted) {
        setState(() {
          _products = products;
          _searchIndex = SmartProductSearchIndex(products);
          if (!products.any((p) => p.group == _group)) _group = null;
          if (!products.any((p) =>
              (_group == null || p.group == _group) &&
              p.subGroup == _subGroup)) {
            _subGroup = null;
          }
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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _showAdjustDialog(Product p) {
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool isAdding = true;
    bool saving = false;

    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text('تعديل مخزون: ${p.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('المخزون الحالي: ${p.quantity}'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('إضافة (+)'),
                        selected: isAdding,
                        onSelected: (val) =>
                            setDialogState(() => isAdding = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('خصم (-)'),
                        selected: !isAdding,
                        onSelected: (val) =>
                            setDialogState(() => isAdding = false),
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الكمية'),
                ),
                TextField(
                  controller: noteCtrl,
                  decoration:
                      const InputDecoration(labelText: 'ملاحظات (اختياري)'),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('إلغاء')),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        final qty = double.tryParse(qtyCtrl.text);
                        if (qty == null ||
                            !qty.isFinite ||
                            qty <= 0 ||
                            noteCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text('أدخل كمية موجبة وسبب التسوية'),
                          ));
                          return;
                        }
                        setDialogState(() => saving = true);

                        final homeState =
                            context.findAncestorStateOfType<HomePageState>();
                        final session = homeState?.widget.session;
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);

                        try {
                          await ApiService().post({
                            'action': 'adjust_inventory',
                            'code': p.code,
                            'quantity': isAdding ? qty : -qty,
                            'type': isAdding ? 'receipt' : 'adjustment',
                            'note': noteCtrl.text,
                            'username': session?['username'],
                            'token': session?['token'],
                          });

                          navigator.pop();
                          await _fetchInventory();
                          scaffoldMessenger.showSnackBar(const SnackBar(
                              content: Text('تم تحديث المخزون'),
                              backgroundColor: Colors.green));
                        } catch (e) {
                          if (context.mounted) {
                            setDialogState(() => saving = false);
                          }
                          scaffoldMessenger
                              .showSnackBar(SnackBar(content: Text('خطأ: $e')));
                        }
                      },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    Navigator.of(context, rootNavigator: true).push(route);
    route.completed.whenComplete(() {
      qtyCtrl.dispose();
      noteCtrl.dispose();
    });
  }

  void _showLowStockRequestDialog(Product p) {
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('طلب نواقص: ${p.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'الكمية المطلوبة'),
            ),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'ملاحظات إضافية'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final qty = double.tryParse(qtyCtrl.text) ?? 0;
              if (qty <= 0) return;

              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final session = context
                  .findAncestorStateOfType<HomePageState>()
                  ?.widget
                  .session;
              try {
                await ApiService().post({
                  'action': 'createLowStockRequest',
                  'code': p.code,
                  'requested_qty': qty,
                  'note': noteCtrl.text,
                  'username': session?['username'],
                  'token': session?['token'],
                });
                if (!mounted) return;
                navigator.pop();
                messenger.showSnackBar(const SnackBar(
                    content: Text('تم إرسال طلب النواقص للمسؤول')));
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(content: Text('خطأ: $e')));
              }
            },
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final role = PermissionHelper.fromString(
      widget.session['role']?.toString() ?? 'user',
    );
    final canAdjust = role == AppRole.admin;
    final groups = _products
        .map((p) => p.group)
        .where((g) => g.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final subGroups = _products
        .where((p) => _group == null || p.group == _group)
        .map((p) => p.subGroup)
        .where((g) => g.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final filtered = _searchIndex.search(_query).where((p) {
      final quantity = p.stockQuantity ?? p.quantity;
      final matchesStock = _stockFilter == 'all' ||
          (_stockFilter == 'positive' && quantity > 0) ||
          (_stockFilter == 'zero' && quantity == 0) ||
          (_stockFilter == 'negative' && quantity < 0);
      return matchesStock &&
          (_group == null || p.group == _group) &&
          (_subGroup == null || p.subGroup == _subGroup);
    }).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('المخزون')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _search,
                    decoration: const InputDecoration(
                      hintText: 'بحث بالاسم أو رمز المادة',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _searchDebounce?.cancel();
                      _searchDebounce = Timer(
                        const Duration(milliseconds: 220),
                        () {
                          if (mounted) setState(() => _query = value);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _stockFilter,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('الكل')),
                      DropdownMenuItem(value: 'positive', child: Text('موجب')),
                      DropdownMenuItem(value: 'zero', child: Text('صفر')),
                      DropdownMenuItem(value: 'negative', child: Text('سالب')),
                    ],
                    onChanged: (value) =>
                        setState(() => _stockFilter = value ?? 'all'),
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 12,
            children: [
              DropdownButton<String>(
                value: _group,
                hint: const Text('المجموعة'),
                items: groups
                    .map((group) =>
                        DropdownMenuItem(value: group, child: Text(group)))
                    .toList(),
                onChanged: (value) => setState(() {
                  _group = value;
                  _subGroup = null;
                }),
              ),
              DropdownButton<String>(
                value: _subGroup,
                hint: const Text('المجموعة الفرعية'),
                items: subGroups
                    .map((group) =>
                        DropdownMenuItem(value: group, child: Text(group)))
                    .toList(),
                onChanged: (value) => setState(() => _subGroup = value),
              ),
              if (_group != null || _subGroup != null)
                TextButton(
                    onPressed: () => setState(() {
                          _group = null;
                          _subGroup = null;
                        }),
                    child: const Text('مسح')),
            ],
          ),
          if (_isLoading && _products.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          if (_error != null && _products.isNotEmpty)
            MaterialBanner(
                content: Text('تعذر تحديث المخزون: $_error'),
                actions: [
                  TextButton(
                      onPressed: _fetchInventory,
                      child: const Text('إعادة المحاولة')),
                ]),
          Expanded(
            child: _isLoading && _products.isEmpty
                ? const ProductSkeletonWidget(isGrid: false)
                : _error != null && _products.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('تعذر تحميل المخزون:\n$_error',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _fetchInventory,
                              icon: const Icon(Icons.refresh),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchInventory,
                        child: filtered.isEmpty
                            ? const Center(child: Text('لا توجد مواد مطابقة'))
                            : ListView.builder(
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final p = filtered[index];
                                  final quantity =
                                      p.stockQuantity ?? p.quantity;
                                  final isLow = quantity < 10;
                                  return Card(
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    child: ListTile(
                                      leading: ProductImageWidget(
                                        imageUrl: p.imageUrl,
                                        width: 48,
                                        height: 48,
                                      ),
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              InventoryMovementsScreen(
                                                  productCode: p.code),
                                        ),
                                      ),
                                      title: Text(
                                        p.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Text(
                                          'الكود: ${p.code} | الوحدة: ${p.unit}'),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: (isLow
                                                      ? theme.colorScheme.error
                                                      : theme
                                                          .colorScheme.primary)
                                                  .withValues(alpha: 0.14),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              quantity.toString(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: isLow
                                                    ? theme.colorScheme.error
                                                    : theme.colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          IconButton(
                                            tooltip: 'سجل الحركات',
                                            icon: Icon(
                                              Icons.history,
                                              color: theme
                                                  .colorScheme.onSurfaceVariant,
                                            ),
                                            onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    InventoryMovementsScreen(
                                                        productCode: p.code),
                                              ),
                                            ),
                                          ),
                                          if (role == AppRole.admin ||
                                              role == AppRole.warehouse)
                                            IconButton(
                                              tooltip: 'طلب نواقص',
                                              icon: const Icon(
                                                  Icons
                                                      .assignment_late_outlined,
                                                  color: Colors.orange),
                                              onPressed: () =>
                                                  _showLowStockRequestDialog(p),
                                            ),
                                          if (canAdjust)
                                            IconButton(
                                              tooltip: 'تسوية مخزون موثقة',
                                              icon: const Icon(Icons.edit_note,
                                                  color: Colors.blue),
                                              onPressed: () =>
                                                  _showAdjustDialog(p),
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}
