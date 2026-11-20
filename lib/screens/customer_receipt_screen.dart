import 'dart:math';

import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../utils/guarded_navigation.dart';

class CustomerReceiptScreen extends StatefulWidget {
  const CustomerReceiptScreen({super.key});

  @override
  State<CustomerReceiptScreen> createState() => _CustomerReceiptScreenState();
}

class _CustomerReceiptScreenState extends State<CustomerReceiptScreen> {
  final List<_ReceiptLine> _lines = [_ReceiptLine()];
  final Map<String, TextEditingController> _allocations = {};
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _invoices = [];
  String? _customerId;
  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;
  bool _confirmCredit = false;
  String? _error;
  String? _requestId;

  Future<void> _back() async {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_saving) return;
    final dirty = _customerId != null ||
        _allocations.values.any((value) => value.text.trim().isNotEmpty) ||
        _lines.any((line) =>
            line.amount.text.trim().isNotEmpty ||
            line.equivalent.text.trim().isNotEmpty ||
            line.rate.text.trim().isNotEmpty ||
            line.reference.text.trim().isNotEmpty ||
            line.note.text.trim().isNotEmpty);
    if (!dirty && _requestId == null) {
      popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('سند قبض غير محفوظ'),
        content: Text(_requestId == null
            ? 'مغادرة الصفحة ستفقد بيانات السند.'
            : 'تعذر تأكيد نتيجة الحفظ. تحقق من السندات قبل إنشاء سند جديد لتجنب التكرار.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('متابعة التحرير'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('مغادرة الصفحة'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    for (final line in _lines) {
      line.dispose();
    }
    for (final controller in _allocations.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _newRequestId() {
    final random = Random.secure();
    return '${DateTime.now().microsecondsSinceEpoch}-'
        '${List.generate(3, (_) => random.nextInt(1 << 32).toRadixString(16)).join()}';
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final customers = await ApiService().sales.getCustomers();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = _message(error);
          _loading = false;
        });
    }
  }

  Future<void> _loadInvoices(String customerId) async {
    setState(() {
      _loading = true;
      _error = null;
      _invoices = [];
      for (final controller in _allocations.values) {
        controller.dispose();
      }
      _allocations.clear();
    });
    try {
      final response = await ApiService().sales.getInvoices(
            customerId: customerId,
            status: 'posted',
          );
      final rows = response['invoices'];
      if (rows is! List) throw StateError('استجابة فواتير الزبون غير صالحة');
      if (!mounted) return;
      setState(() {
        _invoices = rows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .where((row) =>
                (double.tryParse(
                          row['balance_due_usd']?.toString() ?? '0',
                        ) ??
                        0) >
                    0.005 &&
                row['financial_status'] != 'voided')
            .toList();
        for (final invoice in _invoices) {
          _allocations[invoice['invoice_id'].toString()] =
              TextEditingController();
        }
        _loading = false;
      });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = _message(error);
          _loading = false;
        });
    }
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : error.toString().replaceFirst('Bad state: ', '');

  double get _totalUsd => _lines.fold(0, (total, line) {
        final amount = double.tryParse(line.amount.text) ?? 0;
        if (line.currency == 'USD') return total + amount;
        final equivalent = double.tryParse(line.equivalent.text);
        if (equivalent != null && equivalent > 0) return total + equivalent;
        final rate = double.tryParse(line.rate.text);
        if (rate != null && rate > 0) return total + amount / rate;
        return total;
      });

  double get _allocationTotal => _allocations.values.fold(
        0,
        (total, controller) =>
            total + (double.tryParse(controller.text.trim()) ?? 0),
      );

  Future<void> _save() async {
    if (_customerId == null) {
      setState(() => _error = 'اختر الزبون أولًا.');
      return;
    }
    final lines = <Map<String, dynamic>>[];
    try {
      for (final line in _lines) {
        if (line.amount.text.trim().isEmpty) continue;
        final amount = double.tryParse(line.amount.text.trim());
        if (amount == null || !amount.isFinite || amount <= 0) {
          throw StateError('كل مبلغ قبض يجب أن يكون موجبًا.');
        }
        final payload = <String, dynamic>{
          'method': line.method,
          'amount': amount,
          'reference': line.reference.text.trim(),
          'note': line.note.text.trim(),
        };
        if (line.currency == 'SYP') {
          final equivalent = double.tryParse(line.equivalent.text.trim());
          final rate = double.tryParse(line.rate.text.trim());
          if (equivalent != null && equivalent > 0) {
            payload['equivalent_usd'] = equivalent;
          } else if (rate != null && rate > 0) {
            payload['exchange_rate'] = rate;
          } else {
            throw StateError('حدد المقابل بالدولار أو سعر الصرف لكل سطر سوري.');
          }
        }
        lines.add(payload);
      }
      if (lines.isEmpty) throw StateError('أضف مبلغًا واحدًا على الأقل.');
      if (_allocationTotal - _totalUsd > 0.005) {
        throw StateError('مجموع التخصيص يتجاوز قيمة سند القبض.');
      }
      if (_totalUsd - _allocationTotal > 0.005 && !_confirmCredit) {
        throw StateError('أكد تسجيل المبلغ غير المخصص رصيدًا دائنًا للزبون.');
      }
    } catch (error) {
      setState(() => _error = _message(error));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    _requestId ??= _newRequestId();
    try {
      final response = await ApiService().sales.createCustomerReceipt({
        'client_request_id': _requestId,
        'customer_id': _customerId,
        'received_lines': lines,
        'allocations': _allocations.entries
            .where((entry) => entry.value.text.trim().isNotEmpty)
            .map((entry) => {
                  'invoice_id': entry.key,
                  'amount_usd': double.parse(entry.value.text.trim()),
                })
            .toList(),
        'confirm_customer_credit': _confirmCredit,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم إصدار سند ${response['receipt_id']} '
            'بمكافئ ${response['total_usd']} USD',
          ),
        ),
      );
      popAfterGuard(context,
          allowPop: () => setState(() => _allowPop = true), result: true);
    } catch (error) {
      if (mounted)
        setState(() {
          _error = _message(error);
          _saving = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading && _customers.isEmpty) {
      return const Scaffold(
        appBar: _ReceiptAppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: const _ReceiptAppBar(),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _customerId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'الزبون'),
              items: _customers
                  .map((customer) => DropdownMenuItem(
                        value: customer['customer_id'].toString(),
                        child: Text(
                          customer['full_name']?.toString() ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value == null) return;
                      setState(() => _customerId = value);
                      _loadInvoices(value);
                    },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text('وسائل الاستلام',
                      style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  onPressed: _saving
                      ? null
                      : () => setState(() => _lines.add(_ReceiptLine())),
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'إضافة وسيلة',
                ),
              ],
            ),
            ..._lines.asMap().entries.map((entry) {
              final index = entry.key;
              final line = entry.value;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: line.method,
                              isExpanded: true,
                              decoration:
                                  const InputDecoration(labelText: 'الصندوق'),
                              items: const [
                                DropdownMenuItem(
                                    value: 'cash_usd', child: Text('نقدي USD')),
                                DropdownMenuItem(
                                    value: 'cash_syp', child: Text('نقدي SYP')),
                                DropdownMenuItem(
                                    value: 'sham_cash_usd',
                                    child: Text('شام كاش USD')),
                                DropdownMenuItem(
                                    value: 'sham_cash_syp',
                                    child: Text('شام كاش SYP')),
                              ],
                              onChanged: _saving
                                  ? null
                                  : (value) => setState(
                                      () => line.method = value ?? line.method),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: line.amount,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: InputDecoration(
                                  labelText: 'المبلغ ${line.currency}'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          IconButton(
                            onPressed: _saving || _lines.length == 1
                                ? null
                                : () => setState(() {
                                      _lines.removeAt(index);
                                      line.dispose();
                                    }),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                        ],
                      ),
                      if (line.currency == 'SYP')
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: line.equivalent,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'المقابل USD'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: line.rate,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                    labelText: 'ل.س لكل USD'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      TextField(
                          controller: line.reference,
                          decoration:
                              const InputDecoration(labelText: 'مرجع اختياري')),
                      TextField(
                          controller: line.note,
                          decoration: const InputDecoration(
                              labelText: 'ملاحظة اختياري')),
                    ],
                  ),
                ),
              );
            }),
            if (_customerId != null) ...[
              const SizedBox(height: 12),
              Text('تخصيص لفواتير مستحقة (اختياري)',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text('التخصيص لا ينشئ قبضًا جديدًا ولا يغير رصيد الصندوق.'),
              if (_loading)
                const LinearProgressIndicator()
              else if (_invoices.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('لا توجد فواتير مستحقة قابلة للتخصيص.'),
                ),
              ..._invoices.map((invoice) {
                final id = invoice['invoice_id'].toString();
                return Card(
                  child: ListTile(
                    title: Text(id),
                    subtitle: Text(
                      'المتبقي ${invoice['balance_due_usd']} USD · '
                      '${invoice['invoice_date'] ?? ''}',
                    ),
                    trailing: SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _allocations[id],
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'تخصيص USD'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                );
              }),
            ],
            if (_totalUsd - _allocationTotal > 0.005)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _confirmCredit,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _confirmCredit = value),
                title: const Text('اعتماد غير المخصص رصيدًا دائنًا'),
                subtitle: Text(
                  '${(_totalUsd - _allocationTotal).toStringAsFixed(2)} USD',
                ),
              ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'مكافئ السند: ${_totalUsd.toStringAsFixed(2)} USD\n'
                  'المخصص للفواتير: ${_allocationTotal.toStringAsFixed(2)} USD\n'
                  'رصيد دائن غير مخصص: ${max(0, _totalUsd - _allocationTotal).toStringAsFixed(2)} USD',
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              label: Text(_saving ? 'جارٍ حفظ السند...' : 'حفظ سند القبض'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ReceiptAppBar();

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('سند قبض من زبون'));

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _ReceiptLine {
  String method = 'cash_usd';
  final amount = TextEditingController();
  final equivalent = TextEditingController();
  final rate = TextEditingController();
  final reference = TextEditingController();
  final note = TextEditingController();

  String get currency => method.endsWith('_syp') ? 'SYP' : 'USD';

  void dispose() {
    amount.dispose();
    equivalent.dispose();
    rate.dispose();
    reference.dispose();
    note.dispose();
  }
}
