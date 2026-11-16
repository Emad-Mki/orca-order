import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/permissions.dart';
import 'cash_boxes_screen.dart';
import 'customer_receipt_screen.dart';

class PaymentsScreen extends StatefulWidget {
  final Map<String, dynamic>? session;

  const PaymentsScreen({super.key, this.session});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  List<Map<String, dynamic>> _payments = [];
  bool _loading = true;
  String? _error;
  String _movementFilter = 'all';

  bool get _canIssueReceipt {
    final role =
        PermissionHelper.fromString(widget.session?['role']?.toString() ?? '');
    return const {AppRole.admin, AppRole.manager, AppRole.accountant}
        .contains(role);
  }

  @override
  void initState() {
    super.initState();
    _fetchPayments();
  }

  Future<void> _fetchPayments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiService().post({'action': 'payment_list'});
      final rows = response['payments'];
      if (rows is! List) throw StateError('استجابة الحركات المالية غير صالحة');
      if (!mounted) return;
      setState(() {
        _payments = rows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = error is ApiException
              ? error.message
              : error.toString().replaceFirst('Bad state: ', '');
          _loading = false;
        });
    }
  }

  String _methodName(String? method) => switch (method) {
        'cash_usd' => 'نقدي دولار',
        'cash_syp' => 'نقدي سوري',
        'sham_cash_usd' => 'شام كاش دولار',
        'sham_cash_syp' => 'شام كاش سوري',
        'opening_balance' => 'رصيد افتتاحي',
        'payment_reversal' => 'عكس حركة',
        'invoice_void_refund' => 'رد فاتورة',
        _ => method ?? 'غير مصنف',
      };

  List<Map<String, dynamic>> get _visiblePayments => _payments.where((payment) {
        final isOut = payment['action_type'] == 'pay';
        return _movementFilter == 'all' ||
            (_movementFilter == 'out' && isOut) ||
            (_movementFilter == 'in' && !isOut);
      }).toList();

  @override
  Widget build(BuildContext context) {
    final payments = _visiblePayments;
    return Scaffold(
      appBar: AppBar(
        title: const Text('سندات القبض والحركات'),
        actions: [
          IconButton(
              onPressed: _fetchPayments, icon: const Icon(Icons.refresh)),
          IconButton(
            tooltip: 'الصناديق',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CashBoxesScreen()),
            ),
            icon: const Icon(Icons.account_balance_wallet_outlined),
          ),
        ],
      ),
      floatingActionButton: _canIssueReceipt
          ? FloatingActionButton.extended(
              onPressed: () async {
                final saved = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerReceiptScreen(),
                  ),
                );
                if (saved == true) _fetchPayments();
              },
              icon: const Icon(Icons.add_card),
              label: const Text('سند قبض'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      OutlinedButton(
                        onPressed: _fetchPayments,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : _payments.isEmpty
                  ? const Center(child: Text('لا توجد حركات مالية.'))
                  : Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'عدد الحركات: ${payments.length}',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                              ),
                              DropdownButton<String>(
                                value: _movementFilter,
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() => _movementFilter = value);
                                  }
                                },
                                items: const [
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Text('كل الحركات'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'in',
                                    child: Text('المستلمة'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'out',
                                    child: Text('المصروفة'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: payments.isEmpty
                              ? const Center(
                                  child: Text('لا توجد حركات مطابقة للفلتر.'),
                                )
                              : RefreshIndicator(
                                  onRefresh: _fetchPayments,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 4, 12, 16),
                                    itemCount: payments.length,
                                    itemBuilder: (context, index) {
                                      final payment = payments[index];
                                      final isOut =
                                          payment['action_type'] == 'pay';
                                      final currency =
                                          payment['currency']?.toString() ?? '';
                                      final equivalent =
                                          payment['invoice_equivalent'];
                                      final equivalentText =
                                          equivalent == null ||
                                                  equivalent.toString().isEmpty
                                              ? 'غير مصنف — مراجعة مطلوبة'
                                              : '$equivalent USD';
                                      final reference = (payment['reference'] ??
                                              payment['receipt_id'] ??
                                              payment['order_id'] ??
                                              '')
                                          .toString()
                                          .trim();
                                      return Card(
                                        child: ListTile(
                                          leading: Icon(
                                            isOut
                                                ? Icons.north_east
                                                : Icons.south_west,
                                            color: isOut
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .error
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                          ),
                                          title: Text(
                                            '${isOut ? 'صرف/إعادة' : 'استلام'} '
                                            '${payment['amount']} $currency',
                                          ),
                                          subtitle: Text(
                                            '${payment['customer_name'] ?? 'حركة صندوق'} · '
                                            '${payment['payment_date'] ?? payment['created_at'] ?? ''}\n'
                                            '${_methodName((payment['payment_method'] ?? payment['method'])?.toString())} · '
                                            'الصندوق ${payment['box_type'] ?? 'غير محدد'}\n'
                                            'المكافئ التاريخي: $equivalentText'
                                            '${reference.isEmpty ? '' : '\nالمرجع: $reference'}',
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
