import 'package:flutter/material.dart';
import '../services/api_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchInventory();
  }

  Future<void> _fetchInventory() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().post({'action': 'getProducts'});
      var list = data['products'] ?? data['data'] ?? data['items'] ?? data['result'];
      if (mounted) {
        setState(() {
          _products = (list as List).map((p) => Product.fromJson(p)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAdjustDialog(Product p) {
    final qtyCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool isAdding = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                      onSelected: (val) => setDialogState(() => isAdding = true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('خصم (-)'),
                      selected: !isAdding,
                      onSelected: (val) => setDialogState(() => isAdding = false),
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
                decoration: const InputDecoration(labelText: 'ملاحظات (اختياري)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text) ?? 0;
                if (qty <= 0) return;
                
                final session = (context.findAncestorStateOfType<_HomePageState>()?.widget.session);
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
                  if (!mounted) return;
                  Navigator.pop(context);
                  _fetchInventory();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث المخزون'), backgroundColor: Colors.green));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final qty = double.tryParse(qtyCtrl.text) ?? 0;
              if (qty <= 0) return;

              final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
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
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب النواقص للمسؤول')));
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _fetchInventory,
      child: ListView.builder(
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final p = _products[index];
          final isLow = p.quantity < 10;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryMovementsScreen(productCode: p.code))),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('الكود: ${p.code} | الوحدة: ${p.unit}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLow ? Colors.red.shade100 : Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${p.quantity}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isLow ? Colors.red.shade900 : Colors.green.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.history, color: Colors.grey),
                    tooltip: 'سجل الحركات',
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InventoryMovementsScreen(productCode: p.code))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.assignment_late_outlined, color: Colors.orange),
                    tooltip: 'طلب نواقص',
                    onPressed: () => _showLowStockRequestDialog(p),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note, color: Colors.blue),
                    tooltip: 'تعديل مخزون',
                    onPressed: () => _showAdjustDialog(p),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}