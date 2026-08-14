import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// شاشة المخزون
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
class ReportsScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const ReportsScreen({super.key, required this.session});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  Map<String, dynamic>? _reportData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().post({
        'action': 'getReports',
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        setState(() {
          _reportData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_reportData == null) return const Center(child: Text('تعذر تحميل التقارير'));

    final statusStats = _reportData!['statusStats'] as List? ?? [];
    final categorySales = _reportData!['categorySales'] as List? ?? [];

    return RefreshIndicator(
      onRefresh: _fetchReports,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('حالة الطلبات',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.3,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: statusStats.map((s) {
                  final double val = (s['value'] as num).toDouble();
                  return PieChartSectionData(
                    color: _getStatusColor(s['name']),
                    value: val,
                    title: '${_getStatusTextAr(s['name'])}\n$val',
                    radius: 60,
                    titleStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('المبيعات حسب التصنيف',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          AspectRatio(
            aspectRatio: 1.5,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: categorySales.isEmpty
                    ? 10
                    : categorySales
                            .map((c) => c['value'] as num)
                            .reduce((a, b) => a > b ? a : b)
                            .toDouble() *
                        1.2,
                barGroups: categorySales.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: (e.value['value'] as num).toDouble(),
                        color: Colors.blueAccent,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        int index = value.toInt();
                        if (index >= 0 && index < categorySales.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              categorySales[index]['name'],
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ...categorySales.map((c) => Card(
                child: ListTile(
                  title: Text(c['name']),
                  trailing: Text('\$${c['value']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green)),
                ),
              )),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Colors.orange;
      case 'priced':
        return Colors.blue;
      case 'customer_confirmed':
        return Colors.purple;
      case 'approved':
        return Colors.green;
      case 'delivered':
        return Colors.grey;
      default:
        return Colors.blueGrey;
    }
  }

  String _getStatusTextAr(String status) {
    switch (status.toLowerCase()) {
      case 'submitted': return 'جديدة';
      case 'priced': return 'مسعرة';
      case 'customer_confirmed': return 'مؤكدة من العميل';
      case 'approved': return 'معتمدة';
      case 'delivered': return 'تم التسليم';
      default: return status;
    }
  }
}

class InventoryMovementsScreen extends StatefulWidget {
  final String? productCode;
  const InventoryMovementsScreen({super.key, this.productCode});

  @override
  State<InventoryMovementsScreen> createState() => _InventoryMovementsScreenState();
}

class _InventoryMovementsScreenState extends State<InventoryMovementsScreen> {
  List<dynamic> _movements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMovements();
  }

  Future<void> _fetchMovements() async {
    setState(() => _isLoading = true);
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      final data = await ApiService().post({
        'action': 'getInventoryMovements',
        'code': widget.productCode,
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) {
        setState(() {
          _movements = data['movements'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.productCode == null ? 'سجل حركات المخزون' : 'حركات المنتج: ${widget.productCode}')),
      body: RefreshIndicator(
        onRefresh: _fetchMovements,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _movements.isEmpty 
            ? const Center(child: Text('لا توجد حركات مسجلة'))
            : ListView.builder(
                itemCount: _movements.length,
                itemBuilder: (context, index) {
                  final m = _movements[index];
                  final isReceipt = m['type'] == 'receipt';
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: Icon(
                        isReceipt ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        color: isReceipt ? Colors.green : Colors.red,
                      ),
                      title: Text(widget.productCode == null ? 'منتج: ${m['code']}' : 'الكمية: ${m['quantity']}'),
                      subtitle: Text('${m['note']}\n${m['created_at']}'),
                      trailing: widget.productCode == null 
                        ? Text('${isReceipt ? '+' : '-'}${m['quantity']}', 
                            style: TextStyle(color: isReceipt ? Colors.green : Colors.red, fontWeight: FontWeight.bold))
                        : null,
                    ),
                  );
                },
              ),
      ),
    );
  }
}

