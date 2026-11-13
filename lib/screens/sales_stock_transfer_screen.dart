import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../services/api_service.dart';

class SalesStockTransferScreen extends StatefulWidget {
  const SalesStockTransferScreen({super.key});

  @override
  State<SalesStockTransferScreen> createState() =>
      _SalesStockTransferScreenState();
}

class _SalesStockTransferScreenState extends State<SalesStockTransferScreen> {
  final _search = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _reason = TextEditingController();
  List<Map<String, dynamic>> _salespeople = [];
  List<Product> _products = [];
  String? _sellerId;
  Product? _product;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _quantity.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<ProductsProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiService().post({'action': 'salespeople_list'});
      final raw = response['salespeople'];
      if (raw is! List) throw StateError('استجابة قائمة المندوبين غير صالحة');
      await provider.fetchProducts();
      if (!mounted) return;
      setState(() {
        _salespeople = raw
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _products = provider.allProducts;
        _sellerId ??= _salespeople.isEmpty
            ? null
            : _salespeople.first['user_id']?.toString();
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _transfer() async {
    final selectedSeller = _sellerId;
    final selectedProduct = _product;
    final qty = int.tryParse(_quantity.text);
    if (selectedSeller == null ||
        selectedProduct == null ||
        qty == null ||
        qty <= 0 ||
        _reason.text.trim().isEmpty) {
      setState(() => _error = 'اختر المندوب والمادة وأدخل كمية وسبب صالحين.');
      return;
    }
    if (qty > selectedProduct.quantity) {
      setState(() => _error = 'الكمية تتجاوز المتاح في المخزون المركزي.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد تحويل المخزون'),
        content: Text(
          'تحويل $qty ${selectedProduct.unit} من ${selectedProduct.name} '
          'إلى المندوب المختار؟ ستنقص الكمية من المخزون المركزي.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد التحويل'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ApiService().post({
        'action': 'sales_stock_transfer',
        'seller_user_id': selectedSeller,
        'code': selectedProduct.code,
        'quantity': qty,
        'reason': _reason.text.trim(),
      });
      if (!mounted) return;
      setState(() {
        _saving = false;
        _quantity.text = '1';
        _reason.clear();
        _error = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم التحويل. المتاح للمندوب الآن: ${result['available_quantity']}',
          ),
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'تعذر تحويل المخزون: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final products = _products
        .where((product) =>
            query.isEmpty ||
            product.name.toLowerCase().contains(query) ||
            product.code.toLowerCase().contains(query) ||
            product.oem.toLowerCase().contains(query))
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('تخصيص مخزون للمندوب'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _salespeople.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      OutlinedButton(
                        onPressed: _load,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _salespeople.isEmpty
                  ? const Center(child: Text('لا يوجد مندوبون مفعلون'))
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _sellerId,
                          decoration:
                              const InputDecoration(labelText: 'المندوب'),
                          items: _salespeople
                              .map((seller) => DropdownMenuItem(
                                    value: seller['user_id']?.toString(),
                                    child: Text(
                                      '${seller['full_name']} (${seller['username']})',
                                    ),
                                  ))
                              .toList(),
                          onChanged: (value) =>
                              setState(() => _sellerId = value),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'بحث عن مادة',
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 260,
                          child: products.isEmpty
                              ? const Center(child: Text('لا توجد مواد'))
                              : ListView.builder(
                                  itemCount: products.length,
                                  itemBuilder: (context, index) {
                                    final product = products[index];
                                    return RadioListTile<String>(
                                      value: product.code,
                                      groupValue: _product?.code,
                                      title: Text(product.name),
                                      subtitle: Text(
                                        '${product.code} · ${product.unit} · '
                                        'متاح مركزيًا: ${product.quantity}',
                                      ),
                                      onChanged: (_) =>
                                          setState(() => _product = product),
                                    );
                                  },
                                ),
                        ),
                        TextField(
                          controller: _quantity,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'الكمية الصحيحة المراد تحويلها',
                          ),
                        ),
                        TextField(
                          controller: _reason,
                          maxLines: 2,
                          decoration: const InputDecoration(
                            labelText: 'سبب التحويل (مطلوب)',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: _error!.startsWith('تم التحويل')
                                  ? Colors.green
                                  : Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _saving ? null : _transfer,
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.swap_horiz),
                          label: const Text('تحويل من المخزون المركزي'),
                        ),
                      ],
                    ),
    );
  }
}
