import 'package:flutter/material.dart';
import '../services/api_service.dart';

/// شاشة قائمة العملاء
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<dynamic> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    try {
      final session = context.findAncestorStateOfType<_HomePageState>()?.widget.session;
      final data = await ApiService().post({
        'action': 'getCustomers',
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) {
        setState(() {
          _customers = data['customers'] ?? [];
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
      itemCount: _customers.length,
      itemBuilder: (context, index) {
        final c = _customers[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xff00658f).withOpacity(0.1),
              child: const Icon(Icons.person, color: Color(0xff00658f)),
            ),
            title: Text(c['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c['company_name'] ?? ''}\n${c['phone'] ?? ''}'),
                const SizedBox(height: 4),
                Text('الرصيد: \$${c['balance'] ?? 0}', 
                  style: TextStyle(color: (c['balance'] ?? 0) > 0 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.receipt_long, color: Color(0xff00658f)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomerStatementScreen(customerId: c['customer_id']))),
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}

