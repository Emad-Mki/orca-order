import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'sales_invoice_screen.dart';

class SalesInvoicesScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const SalesInvoicesScreen({super.key, required this.session});

  @override
  State<SalesInvoicesScreen> createState() => _SalesInvoicesScreenState();
}

class _SalesInvoicesScreenState extends State<SalesInvoicesScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _invoices = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  String? _error;
  DateTimeRange? _dateRange;
  String _paymentFilter = 'all';
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService().sales.getInvoices(
              query: _search.text,
              fromDate: _dateRange?.start.toIso8601String(),
              toDate: _dateRange == null
                  ? null
                  : DateTime(
                      _dateRange!.end.year,
                      _dateRange!.end.month,
                      _dateRange!.end.day,
                      23,
                      59,
                      59,
                    ).toIso8601String(),
              paymentMethod: _paymentFilter == 'all' ? null : _paymentFilter,
              status: _statusFilter == 'all' ? null : _statusFilter,
            ),
        ApiService().sales.getSummary(
              fromDate: _dateRange?.start.toIso8601String(),
              toDate: _dateRange == null
                  ? null
                  : DateTime(
                      _dateRange!.end.year,
                      _dateRange!.end.month,
                      _dateRange!.end.day,
                      23,
                      59,
                      59,
                    ).toIso8601String(),
            ),
      ]);
      final invoiceRows = results[0]['invoices'];
      if (invoiceRows is! List) {
        throw StateError('استجابة الفواتير غير صالحة');
      }
      if (!mounted) return;
      setState(() {
        _invoices = invoiceRows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _summary = results[1];
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

  void _showDetails(Map<String, dynamic> invoice) {
    final items = (invoice['items'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('فاتورة ${invoice['invoice_id']}'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('العميل: ${invoice['customer_name'] ?? 'زبائن محل'}'),
                if ((invoice['buyer_name'] ?? '').toString().isNotEmpty)
                  Text('المشتري: ${invoice['buyer_name']}'),
                if ((invoice['buyer_phone'] ?? '').toString().isNotEmpty)
                  Text('الهاتف: ${invoice['buyer_phone']}'),
                Text('التاريخ: ${invoice['invoice_date'] ?? ''}'),
                const Divider(),
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${item['name_snapshot']} · ${item['quantity']} '
                        '${item['unit']} × ${item['unit_price']} = '
                        '${item['line_total']} ${invoice['currency']}',
                      ),
                    )),
                const Divider(),
                Text('المجموع: ${invoice['subtotal']} ${invoice['currency']}'),
                Text('الحسم: ${invoice['discount']} ${invoice['currency']}'),
                Text('الصافي: ${invoice['net_total']} ${invoice['currency']}'),
                Text(
                  'المقبوض: ${invoice['amount_received']} '
                  '${invoice['payment_currency']} · '
                  '${_paymentMethodName(invoice['payment_method']?.toString())}',
                ),
                Text(
                    'الباقي المرتجع: ${invoice['change_amount']} ${invoice['payment_currency']}'),
                if ((invoice['payment_reference'] ?? '').toString().isNotEmpty)
                  Text('مرجع القبض: ${invoice['payment_reference']}'),
                if ((invoice['notes'] ?? '').toString().isNotEmpty)
                  Text('ملاحظات: ${invoice['notes']}'),
              ],
            ),
          ),
        ),
        actions: [
          if (_canVoidInvoices && invoice['status'] == 'posted')
            TextButton(
              onPressed: () => _voidInvoice(invoice),
              child: const Text('إلغاء موثق'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  bool get _canVoidInvoices => const {'admin', 'accountant', 'مدير', 'محاسب'}
      .contains(widget.session['role']?.toString());

  Future<void> _voidInvoice(Map<String, dynamic> invoice) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إلغاء الفاتورة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيُعكس المخزون والمقبوضات في سجل تدقيق. '
              'إلغاء شام كاش هنا قيد محاسبي فقط وليس تحويلًا ماليًا فعليًا.',
            ),
            TextField(
              controller: reasonController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'سبب الإلغاء'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('رجوع'),
          ),
          TextButton(
            onPressed: () {
              final value = reasonController.text.trim();
              if (value.length >= 3) Navigator.pop(context, value);
            },
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;
    try {
      await ApiService().sales.voidInvoice(
            invoiceId: invoice['invoice_id'].toString(),
            reason: reason,
          );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إلغاء الفاتورة وعكس آثارها')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر إلغاء الفاتورة: $error')),
      );
    }
  }

  String _paymentMethodName(String? method) => switch (method) {
        'cash_syp' => 'نقدي سوري',
        'cash_usd' => 'نقدي دولار',
        'sham_cash' => 'شام كاش',
        _ => method ?? 'غير محدد',
      };

  Future<void> _selectDateRange() async {
    final today = DateTime.now();
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 10),
      lastDate: DateTime(today.year + 1),
      initialDateRange: _dateRange,
    );
    if (selected == null || !mounted) return;
    setState(() => _dateRange = selected);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final sales = Map<String, dynamic>.from(
      _summary['sales_by_invoice_currency'] as Map? ?? const {},
    );
    final receipts = Map<String, dynamic>.from(
      _summary['receipts_by_payment_currency_and_method'] as Map? ?? const {},
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('فواتيري ومقبوضاتي'),
        actions: [
          IconButton(
            onPressed: _load,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: widget.session['role'] == 'salesperson' ||
              widget.session['role'] == 'user' ||
              widget.session['role'] == 'مندوب مبيعات'
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SalesInvoiceScreen(),
                  ),
                );
                if (created == true) _load();
              },
              icon: const Icon(Icons.add),
              label: const Text('فاتورة جديدة'),
            )
          : null,
      body: Column(
        children: [
          if (!_loading && _error == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الفواتير: ${_summary['invoices_count'] ?? 0}'),
                      ...sales.entries.map(
                        (entry) => Text(
                          'مبيعات ${entry.key}: '
                          '${(entry.value as num).toStringAsFixed(2)}',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _statusFilter,
                                decoration: const InputDecoration(
                                  labelText: 'حالة الفاتورة',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Text('كل الحالات'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'posted',
                                    child: Text('مرحلة'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'voided',
                                    child: Text('ملغاة'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(
                                      () => _statusFilter = value ?? 'all');
                                  _load();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _paymentFilter,
                                decoration: const InputDecoration(
                                  labelText: 'طريقة القبض',
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'all',
                                    child: Text('كل الطرق'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'cash_syp',
                                    child: Text('نقدي سوري'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'cash_usd',
                                    child: Text('نقدي دولار'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'sham_cash',
                                    child: Text('شام كاش'),
                                  ),
                                ],
                                onChanged: (value) {
                                  setState(
                                    () => _paymentFilter = value ?? 'all',
                                  );
                                  _load();
                                },
                              ),
                            ),
                            IconButton(
                              onPressed: _selectDateRange,
                              tooltip: _dateRange == null
                                  ? 'تحديد الفترة'
                                  : 'الفترة: ${_dateRange!.start.toString().substring(0, 10)} - ${_dateRange!.end.toString().substring(0, 10)}',
                              icon: const Icon(Icons.date_range),
                            ),
                            if (_dateRange != null)
                              IconButton(
                                onPressed: () {
                                  setState(() => _dateRange = null);
                                  _load();
                                },
                                tooltip: 'مسح الفترة',
                                icon: const Icon(Icons.clear),
                              ),
                          ],
                        ),
                      ),
                      ...receipts.entries.map(
                        (entry) => Text(
                          'مقبوض ${entry.key}: '
                          '${(entry.value as num).toStringAsFixed(2)}',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'بحث برقم الفاتورة أو المشتري أو طريقة القبض',
                suffixIcon: IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.search),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('تعذر تحميل الفواتير: $_error'),
                            OutlinedButton(
                              onPressed: _load,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        ),
                      )
                    : _invoices.isEmpty
                        ? const Center(child: Text('لا توجد فواتير بعد'))
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 88),
                            itemCount: _invoices.length,
                            itemBuilder: (context, index) {
                              final invoice = _invoices[index];
                              return Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                child: ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.receipt_long),
                                  ),
                                  title: Text(
                                    '${invoice['invoice_id']} · '
                                    '${invoice['net_total']} ${invoice['currency']}',
                                  ),
                                  subtitle: Text(
                                    '${invoice['buyer_name'] ?? 'زبائن محل'} · '
                                    '${invoice['invoice_date'] ?? ''} · '
                                    '${_paymentMethodName(invoice['payment_method']?.toString())}',
                                  ),
                                  trailing: const Icon(Icons.chevron_left),
                                  onTap: () => _showDetails(invoice),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
