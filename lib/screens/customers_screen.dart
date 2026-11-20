import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/permissions.dart';
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
  String? _error;
  final _search = TextEditingController();
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
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
      if (mounted)
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _search.text.trim().toLowerCase();
    final filtered = _customers.where((raw) {
      final c = Map<String, dynamic>.from(raw as Map);
      final matchesQuery = query.isEmpty ||
          '${c['full_name'] ?? ''} ${c['company_name'] ?? ''} ${c['phone'] ?? ''}'
              .toLowerCase()
              .contains(query);
      final status = c['status']?.toString().toLowerCase();
      final matchesStatus = _statusFilter == 'all' ||
          (_statusFilter == 'active' &&
              (status == null || status == 'active')) ||
          (_statusFilter == 'inactive' && status == 'inactive');
      return matchesQuery && matchesStatus;
    }).toList();
    return Scaffold(
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
                      hintText: 'بحث بالاسم أو الهاتف أو الشركة',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('الكل')),
                      DropdownMenuItem(value: 'active', child: Text('نشط')),
                      DropdownMenuItem(value: 'inactive', child: Text('متوقف')),
                    ],
                    onChanged: (value) =>
                        setState(() => _statusFilter = value ?? 'all'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('تعذر تحميل العملاء:\n$_error',
                                textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              onPressed: _fetchCustomers,
                              icon: const Icon(Icons.refresh),
                              label: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? const Center(child: Text('لا يوجد عملاء مطابقون'))
                        : RefreshIndicator(
                            onRefresh: _fetchCustomers,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final c = Map<String, dynamic>.from(
                                    filtered[index] as Map);
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          theme.colorScheme.primaryContainer,
                                      child: Icon(
                                        Icons.person,
                                        color: theme
                                            .colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    title: Text(c['full_name'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${c['company_name'] ?? ''}\n${c['phone'] ?? ''}'),
                                        const SizedBox(height: 4),
                                        if (PermissionHelper.hasPermission(
                                            PermissionHelper.fromString(widget
                                                    .session['role']
                                                    ?.toString() ??
                                                ''),
                                            AppPermission.viewAllStatements))
                                          Text(
                                            'الرصيد: \$${c['balance'] ?? 0}',
                                            style: TextStyle(
                                              color: (c['balance'] ?? 0) > 0
                                                  ? Colors.red
                                                  : Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(
                                              Icons.add_shopping_cart,
                                              color: Colors.green),
                                          onPressed: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                  builder: (_) =>
                                                      NewOrderScreen(
                                                          session:
                                                              widget.session,
                                                          customer: c))),
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
                                                  builder: (_) =>
                                                      CustomerStatementScreen(
                                                          customerId: c[
                                                              'customer_id']))),
                                          tooltip: 'كشف الحساب',
                                        ),
                                      ],
                                    ),
                                    isThreeLine: true,
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
