import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'customer_statement_screen.dart';
import 'new_order_screen.dart';

class CustomersScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const CustomersScreen({super.key, required this.session});

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
      final data = await ApiService().post({
        'action': 'getCustomers',
        'username': widget.session['username'],
        'token': widget.session['token'],
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
    final theme = Theme.of(context);
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _customers.length,
      itemBuilder: (context, index) {
        final c = _customers[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            title: Text(c['full_name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${c['company_name'] ?? ''}\n${c['phone'] ?? ''}'),
                const SizedBox(height: 4),
                Text('الرصيد: \$${c['balance'] ?? 0}',
                    style: TextStyle(
                        color:
                            (c['balance'] ?? 0) > 0 ? Colors.red : Colors.green,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon:
                      const Icon(Icons.add_shopping_cart, color: Colors.green),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NewOrderScreen(
                              session: widget.session, customer: c))),
                  tooltip: 'إنشاء طلب للزبون',
                ),
                IconButton(
                  icon: Icon(
                    Icons.receipt_long,
                    color: theme.colorScheme.primary,
                  ),
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => CustomerStatementScreen(
                              customerId: c['customer_id']))),
                  tooltip: 'كشف الحساب',
                ),
              ],
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }
}
