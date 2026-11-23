import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'homepage_screen.dart';

class InventoryMovementsScreen extends StatefulWidget {
  final String? productCode;
  const InventoryMovementsScreen({super.key, this.productCode});

  @override
  State<InventoryMovementsScreen> createState() =>
      _InventoryMovementsScreenState();
}

class _InventoryMovementsScreenState extends State<InventoryMovementsScreen> {
  List<dynamic> _movements = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMovements();
  }

  Future<void> _fetchMovements() async {
    if (_isLoading && _movements.isNotEmpty) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final session =
          context.findAncestorStateOfType<HomePageState>()?.widget.session;
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
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.productCode == null
              ? 'سجل حركات المخزون'
              : 'حركات المنتج: ${widget.productCode}')),
      body: RefreshIndicator(
        onRefresh: _fetchMovements,
        child: _isLoading && _movements.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _error != null && _movements.isEmpty
                ? Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('تعذر تحميل الحركات: $_error'),
                    TextButton(
                        onPressed: _fetchMovements,
                        child: const Text('إعادة المحاولة')),
                  ]))
                : _movements.isEmpty
                    ? const Center(child: Text('لا توجد حركات مسجلة'))
                    : ListView.builder(
                        itemCount: _movements.length,
                        itemBuilder: (context, index) {
                          final m = _movements[index];
                          final isReceipt = m['type'] == 'receipt';
                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            child: ListTile(
                              leading: Icon(
                                isReceipt
                                    ? Icons.add_circle_outline
                                    : Icons.remove_circle_outline,
                                color: isReceipt ? Colors.green : Colors.red,
                              ),
                              title: Text(widget.productCode == null
                                  ? 'منتج: ${m['code']}'
                                  : 'الكمية: ${m['quantity']}'),
                              subtitle: Text(
                                  'النوع: ${m['type'] ?? ''} | الكمية: ${m['quantity'] ?? ''}\n'
                                  'المرجع: ${m['reference_id'] ?? '-'}\n'
                                  '${m['note'] ?? ''}\n${m['created_at'] ?? ''}'),
                              trailing: widget.productCode == null
                                  ? Text(
                                      '${isReceipt ? '+' : '-'}${m['quantity']}',
                                      style: TextStyle(
                                          color: isReceipt
                                              ? Colors.green
                                              : Colors.red,
                                          fontWeight: FontWeight.bold))
                                  : null,
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
