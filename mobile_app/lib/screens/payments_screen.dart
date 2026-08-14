import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> with SingleTickerProviderStateMixin {
  List<dynamic> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      final data = await ApiService().post({
        'action': 'getPayments',
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) {
        setState(() {
          _payments = data['payments'] ?? [];
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
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _payments.length,
      itemBuilder: (context, index) {
        final p = _payments[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.payment, color: Colors.green),
            title: Text('دفعة بقيمة \$${p['amount']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
            subtitle: Text('العميل: ${p['customer_id']}\nالتاريخ: ${p['payment_date']}'),
            trailing: Text(p['method'] ?? '', style: const TextStyle(fontStyle: FontStyle.italic)),
          ),
        );
      },
    );
  }
}