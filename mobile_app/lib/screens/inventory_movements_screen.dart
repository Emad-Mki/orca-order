import 'package:flutter/material.dart';
import '../services/api_service.dart';

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

