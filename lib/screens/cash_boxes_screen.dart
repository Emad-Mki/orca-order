import 'dart:math';

import 'package:flutter/material.dart';

import '../services/api_service.dart';

class CashBoxesScreen extends StatefulWidget {
  const CashBoxesScreen({super.key});

  @override
  State<CashBoxesScreen> createState() => _CashBoxesScreenState();
}

class _CashBoxesScreenState extends State<CashBoxesScreen> {
  Map<String, dynamic> _balances = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ApiService().sales.getCashBoxBalances();
      final balances = response['balances'];
      if (balances is! Map) throw StateError('استجابة أرصدة الصناديق غير صالحة');
      if (!mounted) return;
      setState(() {
        _balances = Map<String, dynamic>.from(balances);
        _loading = false;
      });
    } catch (error) {
      if (mounted) setState(() {
        _error = _message(error);
        _loading = false;
      });
    }
  }

  String _message(Object error) => error is ApiException
      ? error.message
      : error.toString().replaceFirst('Bad state: ', '');

  String _key(String box, String currency) =>
      '${box == 'cash_box' ? 'cash_box' : 'sham_cash'}_${currency.toLowerCase()}';

  Future<void> _openBox(String box, String currency) async {
    final amount = TextEditingController();
    final rate = TextEditingController();
    final reason = TextEditingController();
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('رصيد افتتاحي · ${_boxName(box)} $currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'الرصيد الافتتاحي $currency'),
            ),
            if (currency == 'SYP')
              TextField(
                controller: rate,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'سعر تاريخي (ل.س لكل USD)',
                  helperText: 'اتركه فارغًا إن لم يكن موثقًا؛ سيطلب كشف الصندوق مراجعة.',
                ),
              ),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'سبب التوثيق'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              'amount': amount.text.trim(),
              'rate': rate.text.trim(),
              'reason': reason.text.trim(),
            }),
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );
    amount.dispose();
    rate.dispose();
    reason.dispose();
    if (values == null) return;
    final parsed = double.tryParse(values['amount']!);
    if (parsed == null || !parsed.isFinite || parsed < 0 ||
        values['reason']!.length < 3) {
      setState(() => _error = 'أدخل رصيدًا صالحًا وسببًا واضحًا.');
      return;
    }
    try {
      await ApiService().sales.setCashBoxOpeningBalance(
            boxName: box,
            currency: currency,
            amount: parsed,
            reason: values['reason']!,
            exchangeRate: values['rate']!.isEmpty
                ? null
                : double.tryParse(values['rate']!),
            clientRequestId:
                '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}',
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الرصيد الافتتاحي مع سجل تدقيق.')),
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = _message(error));
    }
  }

  Future<void> _showStatement(String box, String currency) async {
    try {
      final data = await ApiService().sales.getCashBoxStatement(
            boxName: box,
            currency: currency,
          );
      if (!mounted) return;
      final movements = (data['movements'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.78,
            child: Column(
              children: [
                ListTile(
                  title: Text('حركة ${_boxName(box)} · $currency'),
                  subtitle: Text('الرصيد الحالي: ${data['balance']} $currency'),
                ),
                if (data['needs_manual_review'] == true)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: Text(
                      'توجد حركات سورية تاريخية بلا مقابل دولاري موثق؛ لم يُخمن سعرها.',
                    ),
                  ),
                Expanded(
                  child: movements.isEmpty
                      ? const Center(child: Text('لا توجد حركات مسجلة.'))
                      : ListView.builder(
                          itemCount: movements.length,
                          itemBuilder: (context, index) {
                            final row = movements[index];
                            final isReceive = row['action_type'] != 'pay';
                            return ListTile(
                              leading: Icon(
                                isReceive
                                    ? Icons.south_west
                                    : Icons.north_east,
                                color: isReceive
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.error,
                              ),
                              title: Text(
                                '${isReceive ? 'استلام' : 'صرف'} '
                                '${row['amount']} $currency',
                              ),
                              subtitle: Text(
                                '${row['date'] ?? ''} · ${row['method'] ?? ''}\n'
                                'مرجع: ${row['reference'] ?? '—'} · '
                                '${row['note'] ?? ''}',
                              ),
                              trailing: row['equivalent_usd'] == null
                                  ? const Text('مراجعة')
                                  : Text('${row['equivalent_usd']} USD'),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل كشف الصندوق: ${_message(error)}')),
        );
      }
    }
  }

  String _boxName(String box) => box == 'cash_box' ? 'نقدي' : 'شام كاش';

  @override
  Widget build(BuildContext context) {
    final boxes = const [
      ('cash_box', 'USD'),
      ('cash_box', 'SYP'),
      ('sham_cash', 'USD'),
      ('sham_cash', 'SYP'),
    ];
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('الصناديق والحركات'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _balances.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      OutlinedButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    const Text(
                      'تُعرض أرصدة كل صندوق بعملته الأصلية فقط؛ لا تُجمع العملات المختلفة.',
                    ),
                    for (final (box, currency) in boxes)
                      Card(
                        child: ListTile(
                          leading: Icon(
                            box == 'cash_box' ? Icons.payments_outlined : Icons.account_balance_wallet_outlined,
                            color: theme.colorScheme.primary,
                          ),
                          title: Text('${_boxName(box)} · $currency'),
                          subtitle: Text('${_balances[_key(box, currency)] ?? 0} $currency'),
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                tooltip: 'كشف الحركات',
                                onPressed: () => _showStatement(box, currency),
                                icon: const Icon(Icons.list_alt),
                              ),
                              IconButton(
                                tooltip: 'رصيد افتتاحي موثق',
                                onPressed: () => _openBox(box, currency),
                                icon: const Icon(Icons.add_card),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                      ),
                  ],
                ),
    );
  }
}
