import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/products_provider.dart';
import '../services/api_service.dart';
import '../utils/number_utils.dart';
import '../utils/guarded_navigation.dart';
import '../widgets/product_image_widget.dart';
import '../widgets/sales_customer_form.dart';
import '../widgets/guided_tour.dart';
import '../services/guide_coordinator.dart';
import '../utils/permissions.dart';
import '../utils/smart_product_search.dart';

class SalesInvoiceScreen extends StatefulWidget {
  const SalesInvoiceScreen({super.key});

  @override
  State<SalesInvoiceScreen> createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends State<SalesInvoiceScreen> {
  final _search = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _buyerName = TextEditingController();
  final _buyerPhone = TextEditingController();
  final _notes = TextEditingController();
  final Map<String, _SalesLine> _cart = {};
  final List<_PaymentLine> _received = [];
  final List<_PaymentLine> _refunded = [];

  List<Product> _products = [];
  SmartProductSearchIndex _productSearchIndex =
      SmartProductSearchIndex(const []);
  Timer? _searchDebounce;
  String _debouncedSearch = '';
  List<Map<String, dynamic>> _customers = [];
  Map<String, dynamic>? _config;
  String? _customerId;
  String _selectedGroup = 'all';
  String _selectedSubGroup = 'all';
  bool _settleFull = false;
  bool _confirmCredit = false;
  bool _loading = true;
  bool _submitting = false;
  bool _allowPop = false;
  String? _error;
  String? _requestId;
  SalesCustomerRequest? _pendingCustomer;
  bool _creatingCustomer = false;

  bool get _isSubmissionLocked => _submitting || _requestId != null;

  Future<void> _handleBack() async {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_submitting) return;
    final hasChanges = _cart.isNotEmpty ||
        _customerId != null ||
        _buyerName.text.trim().isNotEmpty ||
        _buyerPhone.text.trim().isNotEmpty ||
        _notes.text.trim().isNotEmpty ||
        _discount.text.trim() != '0' ||
        [..._received, ..._refunded].any((line) =>
            line.amount.text.trim().isNotEmpty ||
            line.equivalent.text.trim().isNotEmpty ||
            line.rate.text.trim().isNotEmpty ||
            line.reference.text.trim().isNotEmpty ||
            line.note.text.trim().isNotEmpty);
    if (!hasChanges && _requestId == null) {
      popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فاتورة غير محفوظة'),
        content: Text(_requestId == null
            ? 'مغادرة الصفحة ستفقد بيانات الفاتورة.'
            : 'تعذر تأكيد نتيجة الحفظ. تحقق من الفواتير قبل إنشاء فاتورة جديدة لتجنب التكرار.'),
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

  String get _creatorName =>
      ApiService().currentUser?['full_name']?.toString() ??
      ApiService().currentUser?['username']?.toString() ??
      'المستخدم الحالي';

  @override
  void initState() {
    super.initState();
    _received.add(_PaymentLine());
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _searchDebounce?.cancel();
    _discount.dispose();
    _buyerName.dispose();
    _buyerPhone.dispose();
    _notes.dispose();
    for (final line in [..._received, ..._refunded]) {
      line.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final provider = context.read<ProductsProvider>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final configFuture = ApiService().sales.getConfiguration();
      final customersFuture = ApiService().sales.getCustomers();
      await Future.wait([
        configFuture,
        customersFuture,
        provider.fetchProducts(forceRefresh: true),
      ]);
      final config = _extractMap(await configFuture, 'configuration');
      final customers = await customersFuture;
      final invoiceCurrency = _normalizeCurrency(config['invoice_currency']);
      final usdDecimals = _numberValue(config['usd_decimals']);
      final sypDecimals = _numberValue(config['syp_decimals']);
      if (invoiceCurrency != 'USD') {
        throw StateError('عملة الفواتير يجب أن تكون الدولار (USD).');
      }
      if (!_validPrecision(usdDecimals) || !_validPrecision(sypDecimals)) {
        throw StateError('إعداد دقة الدولار والليرة غير مكتمل.');
      }
      if (provider.allProducts.isEmpty && provider.errorMessage != null) {
        throw StateError(provider.errorMessage!);
      }
      if (!mounted) return;
      setState(() {
        _config = config;
        _customers = customers;
        _products = provider.allProducts;
        _productSearchIndex = SmartProductSearchIndex(_products);
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorMessage(error);
          _loading = false;
        });
      }
    }
  }

  Map<String, dynamic> _extractMap(
    Map<String, dynamic> response,
    String key,
  ) {
    final value = response[key] ?? response['data']?[key];
    if (value is Map) return Map<String, dynamic>.from(value);
    final data = response['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return response;
  }

  String? _normalizeCurrency(dynamic value) {
    final currency = value?.toString().trim().toUpperCase();
    return currency == 'USD' || currency == 'SYP' ? currency : null;
  }

  double? _numberValue(dynamic value) {
    if (value is num && value.isFinite) return value.toDouble();
    if (value is String) {
      final result = double.tryParse(value.trim());
      if (result != null && result.isFinite) return result;
    }
    return null;
  }

  bool _validPrecision(double? value) =>
      value != null &&
      value == value.roundToDouble() &&
      value >= 0 &&
      value <= 4;

  String _errorMessage(Object error) {
    if (error is ApiException) return error.message;
    if (error is StateError) return error.message.toString();
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
  }

  int _decimals(String currency) =>
      (_numberValue(
              _config?[currency == 'USD' ? 'usd_decimals' : 'syp_decimals'])
          ?.toInt()) ??
      0;

  double _round(double value, String currency) {
    final factor = pow(10, _decimals(currency)).toDouble();
    return (value * factor).round() / factor;
  }

  double get _subtotal =>
      _cart.values.fold(0, (total, line) => total + line.total);
  double get _discountValue => double.tryParse(_discount.text) ?? 0;
  double get _netTotal => _round(_subtotal - _discountValue, 'USD');

  double? _lineUsd(_PaymentLine line, {required bool allowInference}) {
    final amount = double.tryParse(line.amount.text);
    if (amount == null || !amount.isFinite || amount <= 0) return null;
    if (line.currency == 'USD') return _round(amount, 'USD');
    final equivalent = double.tryParse(line.equivalent.text);
    if (equivalent != null && equivalent.isFinite && equivalent > 0) {
      return _round(equivalent, 'USD');
    }
    final rate = double.tryParse(line.rate.text);
    if (rate != null && rate.isFinite && rate > 0) {
      return _round(amount / rate, 'USD');
    }
    return allowInference ? null : null;
  }

  double get _receivedUsd => _received.fold(
        0,
        (sum, line) => sum + (_lineUsd(line, allowInference: false) ?? 0),
      );
  double get _refundedUsd => _refunded.fold(
        0,
        (sum, line) => sum + (_lineUsd(line, allowInference: false) ?? 0),
      );
  double get _netPaidUsd => _round(_receivedUsd - _refundedUsd, 'USD');

  double? get _inferredRate {
    final unknownSypReceived = _received.where(
      (line) =>
          line.currency == 'SYP' &&
          _lineUsd(line, allowInference: false) == null,
    );
    final unknownSypRefunded = _refunded.where(
      (line) =>
          line.currency == 'SYP' &&
          _lineUsd(line, allowInference: false) == null,
    );
    if (unknownSypReceived.isEmpty && unknownSypRefunded.isEmpty) return null;
    final netSyp = unknownSypReceived.fold(
          0.0,
          (sum, line) => sum + (double.tryParse(line.amount.text) ?? 0),
        ) -
        unknownSypRefunded.fold(
          0.0,
          (sum, line) => sum + (double.tryParse(line.amount.text) ?? 0),
        );
    final knownUsd = _netPaidUsd;
    final neededUsd = _netTotal - knownUsd;
    if (netSyp == 0 || neededUsd == 0 || netSyp * neededUsd <= 0) return null;
    final rate = netSyp / neededUsd;
    return rate.isFinite && rate > 0 ? rate : null;
  }

  double get _previewNetPaid {
    final missingSypReceived = _received.where(
      (line) =>
          line.currency == 'SYP' &&
          _lineUsd(line, allowInference: false) == null,
    );
    final missingSypRefunded = _refunded.where(
      (line) =>
          line.currency == 'SYP' &&
          _lineUsd(line, allowInference: false) == null,
    );
    final inferred = _settleFull ? _inferredRate : null;
    if (inferred == null) return _netPaidUsd;
    final received = missingSypReceived.fold(
      0.0,
      (sum, line) => sum + (double.tryParse(line.amount.text) ?? 0) / inferred,
    );
    final refunded = missingSypRefunded.fold(
      0.0,
      (sum, line) => sum + (double.tryParse(line.amount.text) ?? 0) / inferred,
    );
    return _round(_netPaidUsd + received - refunded, 'USD');
  }

  String _newRequestId() {
    final random = Random.secure();
    final suffix = List.generate(
      4,
      (_) => random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  void _addProduct(Product product) {
    setState(() {
      final old = _cart[product.code];
      _cart[product.code] = old == null
          ? _SalesLine(product: product, quantity: 1, unitPrice: product.price)
          : old.copyWith(quantity: old.quantity + 1);
    });
  }

  void _removePaymentLine(List<_PaymentLine> lines, _PaymentLine line) {
    setState(() {
      lines.remove(line);
      line.dispose();
    });
  }

  void _addPaymentLine(List<_PaymentLine> lines) {
    setState(() => lines.add(_PaymentLine()));
  }

  Future<void> _createCustomer() async {
    if (_creatingCustomer) return;
    setState(() => _creatingCustomer = true);
    try {
      if (_pendingCustomer == null) {
        final result = await showSalesCustomerForm(context);
        if (result == null || !mounted) return;
        _pendingCustomer = SalesCustomerRequest(
          name: result['name']!,
          phone: result['phone']!,
        );
      }
      final customer = await _pendingCustomer!.submit();
      if (!mounted) return;
      setState(() {
        _pendingCustomer = null;
        _customers = [..._customers, customer];
        _customerId = customer['customer_id'].toString();
      });
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            '${_errorMessage(error)}. أعد محاولة إضافة الزبون للعملية نفسها.');
      }
    } finally {
      if (mounted) setState(() => _creatingCustomer = false);
    }
  }

  List<Map<String, dynamic>> _paymentPayload(List<_PaymentLine> lines) {
    return lines
        .where((line) => line.amount.text.trim().isNotEmpty)
        .map((line) {
      final amount = double.tryParse(line.amount.text.trim());
      if (amount == null || !amount.isFinite || amount <= 0) {
        throw StateError('أدخل مبلغًا موجبًا لكل حركة مالية.');
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
        }
        if (rate != null && rate > 0) payload['exchange_rate'] = rate;
        if (!_settleFull &&
            (payload['equivalent_usd'] == null &&
                payload['exchange_rate'] == null)) {
          throw StateError(
              'أدخل المقابل بالدولار أو سعر الصرف لكل حركة سورية.');
        }
      }
      return payload;
    }).toList();
  }

  String _paymentMethodName(String method) => switch (method) {
        'cash_usd' => 'نقدي USD',
        'cash_syp' => 'نقدي SYP',
        'sham_cash_usd' => 'شام كاش USD',
        'sham_cash_syp' => 'شام كاش SYP',
        _ => method,
      };

  Future<void> _reviewAndSubmit() async {
    if (_cart.isEmpty || _discountValue < 0 || _discountValue > _subtotal) {
      setState(() => _error = 'تحقق من المواد والحسم.');
      return;
    }
    if (_previewNetPaid > _netTotal + 0.005 &&
        (_customerId == null || _customerId == 'CUS-SHOP' || !_confirmCredit)) {
      setState(() {
        _error =
            'صافي المقبوض يتجاوز الفاتورة. أعد الباقي أو اختر زبونًا محددًا وأكد تسجيل الزيادة كرصيد دائن.';
      });
      return;
    }
    if (_previewNetPaid < _netTotal - 0.005 &&
        (_customerId == null || _customerId == 'CUS-SHOP')) {
      setState(() =>
          _error = 'لوجود دين متبقٍ، اختر زبونًا محددًا أو أنشئ سجل زبون.');
      return;
    }
    final hasUnresolvedSyp = [..._received, ..._refunded].any(
      (line) =>
          line.currency == 'SYP' &&
          line.amount.text.trim().isNotEmpty &&
          _lineUsd(line, allowInference: false) == null,
    );
    if (_settleFull && hasUnresolvedSyp && _inferredRate == null) {
      setState(() => _error =
          'لا يمكن استنتاج سعر صرف وحيد؛ أدخل المقابل أو السعر لكل سطر.');
      return;
    }
    List<Map<String, dynamic>> received;
    List<Map<String, dynamic>> refunded;
    try {
      received = _paymentPayload(_received);
      refunded = _paymentPayload(_refunded);
    } catch (error) {
      setState(() => _error = _errorMessage(error));
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) {
        String paymentSummary(_PaymentLine line, {required bool refund}) {
          final amount = double.tryParse(line.amount.text) ?? 0;
          final equivalent = _lineUsd(line, allowInference: false) ??
              (_settleFull && _inferredRate != null && line.currency == 'SYP'
                  ? amount / _inferredRate!
                  : null);
          final enteredRate = double.tryParse(line.rate.text);
          final enteredEquivalent = double.tryParse(line.equivalent.text);
          final rate = line.currency == 'SYP'
              ? enteredRate ??
                  (enteredEquivalent != null && enteredEquivalent > 0
                      ? amount / enteredEquivalent
                      : _inferredRate)
              : null;
          return '${refund ? 'باقي معاد' : 'مبلغ مستلم'} · '
              '${_paymentMethodName(line.method)}\n'
              '${formatMoneyShort(amount, currency: line.currency)}'
              '${equivalent == null ? '' : ' · مكافئ ${formatMoneyShort(equivalent, currency: 'USD', decimalPlaces: _decimals('USD'))}'}'
              '${rate == null ? '' : ' · سعر الصرف ${rate.toStringAsFixed(2)} ل.س لكل USD'}';
        }

        var customerName = 'زبائن محل';
        if (_customerId != null) {
          final matches = _customers.where(
            (customer) => customer['customer_id'].toString() == _customerId,
          );
          customerName = matches.isEmpty
              ? _customerId!
              : matches.first['full_name']?.toString() ?? _customerId!;
        }
        return AlertDialog(
          title: const Text('مراجعة الفاتورة والتسوية'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'رقم الفاتورة وتاريخها يحددان عند الحفظ النهائي.',
                  ),
                  Text('الزبون: $customerName'),
                  Text('أنشأها: $_creatorName'),
                  if (_buyerName.text.trim().isNotEmpty)
                    Text('المشتري: ${_buyerName.text.trim()}'),
                  const Divider(),
                  Text('المواد (${_cart.length})',
                      style: Theme.of(context).textTheme.titleSmall),
                  ..._cart.values.map(
                    (line) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${line.product.name} · ${line.product.code}\n'
                        '${line.quantity} ${line.product.unit} × '
                        '${formatMoneyShort(line.unitPrice, currency: 'USD', decimalPlaces: _decimals('USD'))} = '
                        '${formatMoneyShort(line.total, currency: 'USD', decimalPlaces: _decimals('USD'))}'
                        '${line.note.trim().isEmpty ? '' : '\n${line.note.trim()}'}',
                      ),
                    ),
                  ),
                  const Divider(),
                  Text('الإجماليات',
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    'المجموع: ${formatMoneyShort(_subtotal, currency: 'USD', decimalPlaces: _decimals('USD'))}',
                  ),
                  Text(
                    'الحسم: ${formatMoneyShort(_discountValue, currency: 'USD', decimalPlaces: _decimals('USD'))}',
                  ),
                  Text(
                    'صافي الفاتورة: ${formatMoneyShort(_netTotal, currency: 'USD', decimalPlaces: _decimals('USD'))}',
                  ),
                  if (_settleFull && _inferredRate != null)
                    Text(
                      'سعر الصرف المستنتج: ${_inferredRate!.toStringAsFixed(2)} ل.س لكل USD',
                    ),
                  const Divider(),
                  Text('المبالغ المستلمة',
                      style: Theme.of(context).textTheme.titleSmall),
                  ..._received
                      .where((line) => line.amount.text.trim().isNotEmpty)
                      .map((line) => Text(paymentSummary(line, refund: false))),
                  if (!_received
                      .any((line) => line.amount.text.trim().isNotEmpty))
                    const Text('لا يوجد مبلغ مستلم.'),
                  const SizedBox(height: 8),
                  Text('الباقي المعاد للزبون',
                      style: Theme.of(context).textTheme.titleSmall),
                  ..._refunded
                      .where((line) => line.amount.text.trim().isNotEmpty)
                      .map((line) => Text(paymentSummary(line, refund: true))),
                  if (!_refunded
                      .any((line) => line.amount.text.trim().isNotEmpty))
                    const Text('لا يوجد باقي معاد.'),
                  const Divider(),
                  Text(
                    'صافي المسدد: ${formatMoneyShort(_previewNetPaid, currency: 'USD', decimalPlaces: _decimals('USD'))}',
                  ),
                  Text(
                    _previewNetPaid > _netTotal + 0.005
                        ? 'رصيد دائن للزبون: ${formatMoneyShort(_previewNetPaid - _netTotal, currency: 'USD', decimalPlaces: _decimals('USD'))}'
                        : 'متبقٍ على الزبون: ${formatMoneyShort(max(0, _netTotal - _previewNetPaid), currency: 'USD', decimalPlaces: _decimals('USD'))}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_notes.text.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('ملاحظات: ${_notes.text.trim()}'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('رجوع')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('حفظ الفاتورة')),
          ],
        );
      },
    );
    if (approved == true) {
      await _submit(received: received, refunded: refunded);
    }
  }

  Future<void> _submit({
    required List<Map<String, dynamic>> received,
    required List<Map<String, dynamic>> refunded,
  }) async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    _requestId ??= _newRequestId();
    try {
      final result = await ApiService().sales.createInvoice({
        'client_request_id': _requestId,
        'items': _cart.values
            .map((line) => {
                  'code': line.product.code,
                  'unit': line.product.unit,
                  'quantity': line.quantity,
                  'unit_price': line.unitPrice,
                  'note': line.note,
                })
            .toList(),
        'customer_id': _customerId,
        'discount': _discountValue,
        'received_lines': received,
        'refunded_lines': refunded,
        'settle_full': _settleFull,
        'confirm_customer_credit': _confirmCredit,
        'buyer_name': _buyerName.text.trim(),
        'buyer_phone': _buyerPhone.text.trim(),
        'notes': _notes.text.trim(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حفظ الفاتورة ${result['invoice_number'] ?? result['invoice_id']} · '
            'المتبقي ${formatMoneyShort(result['balance_due_usd'], currency: 'USD', decimalPlaces: _decimals('USD'))}',
          ),
        ),
      );
      popAfterGuard(context,
          allowPop: () => setState(() => _allowPop = true), result: true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = _errorMessage(error);
          _submitting = false;
        });
      }
    }
  }

  Widget _paymentSection(String title, List<_PaymentLine> lines, bool refund) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                    child: Text(title, style: theme.textTheme.titleMedium)),
                IconButton(
                  tooltip: 'إضافة سطر',
                  onPressed:
                      _isSubmissionLocked ? null : () => _addPaymentLine(lines),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (lines.isEmpty)
              Text(refund ? 'لا يوجد مبلغ معاد.' : 'لا يوجد مبلغ مستلم بعد.'),
            ...lines.map((line) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: line.method,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'الصندوق والوسيلة'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'cash_usd', child: Text('نقدي دولار')),
                              DropdownMenuItem(
                                  value: 'cash_syp', child: Text('نقدي سوري')),
                              DropdownMenuItem(
                                  value: 'sham_cash_usd',
                                  child: Text('شام كاش دولار')),
                              DropdownMenuItem(
                                  value: 'sham_cash_syp',
                                  child: Text('شام كاش سوري')),
                            ],
                            onChanged: _isSubmissionLocked
                                ? null
                                : (method) {
                                    if (method == null) return;
                                    line.method = method;
                                    setState(() {});
                                  },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: line.amount,
                            enabled: !_isSubmissionLocked,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                                labelText: 'المبلغ ${line.currency}'),
                            onChanged: (value) {
                              _searchDebounce?.cancel();
                              _searchDebounce = Timer(
                                const Duration(milliseconds: 220),
                                () {
                                  if (mounted) {
                                    setState(() => _debouncedSearch = value);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: 'إزالة السطر',
                          onPressed: _isSubmissionLocked
                              ? null
                              : () => _removePaymentLine(lines, line),
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
                              enabled: !_isSubmissionLocked,
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
                              enabled: !_isSubmissionLocked,
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
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: line.reference,
                            enabled: !_isSubmissionLocked,
                            decoration: const InputDecoration(
                                labelText: 'مرجع التحويل (اختياري)'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: line.note,
                            enabled: !_isSubmissionLocked,
                            decoration: const InputDecoration(
                                labelText: 'ملاحظة (اختياري)'),
                          ),
                        ),
                      ],
                    ),
                    if (line.currency == 'SYP' &&
                        line.amount.text.isNotEmpty &&
                        _lineUsd(line, allowInference: false) == null &&
                        _settleFull &&
                        _inferredRate != null)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          'المقابل المتوقع: ${formatMoneyShort(
                            (double.tryParse(line.amount.text) ?? 0) /
                                _inferredRate!,
                            currency: 'USD',
                            decimalPlaces: _decimals('USD'),
                          )}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: _InvoiceAppBar(),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _config == null) {
      return PopScope(
        canPop: _allowPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _handleBack();
        },
        child: Scaffold(
          appBar: const _InvoiceAppBar(),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: _load, child: const Text('إعادة المحاولة')),
                ],
              ),
            ),
          ),
        ),
      );
    }
    final query = _debouncedSearch;
    final groups = _products
        .map((p) => p.group.trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final subGroups = _products
        .where((p) => _selectedGroup == 'all' || p.group == _selectedGroup)
        .map((p) => p.subGroup.trim())
        .where((v) => v.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final filteredProducts = _productSearchIndex
        .search(query)
        .where((product) =>
            (_selectedGroup == 'all' || product.group == _selectedGroup) &&
            (_selectedSubGroup == 'all' ||
                product.subGroup == _selectedSubGroup))
        .toList();
    final theme = Theme.of(context);
    final previewPaid = _previewNetPaid;
    final paymentStatus = previewPaid <= 0.005
        ? 'غير مدفوعة'
        : previewPaid >= _netTotal - 0.005
            ? 'مسددة'
            : 'مدفوعة جزئيًا';
    final statusColor = paymentStatus == 'مسددة'
        ? theme.colorScheme.primary
        : paymentStatus == 'غير مدفوعة'
            ? theme.colorScheme.error
            : theme.colorScheme.tertiary;

    final session = ApiService().currentUser;
    final role =
        PermissionHelper.fromString(session?['role']?.toString() ?? '');
    final canGuide = const {
      AppRole.admin,
      AppRole.manager,
      AppRole.accountant,
      AppRole.salesperson,
    }.contains(role);
    return GuidedTour(
      accountId: canGuide
          ? (session ?? const <String, dynamic>{})['user_id']?.toString()
          : null,
      name: 'invoice',
      targetCount: 4,
      ready: GuideCoordinator.ready,
      canStart: () =>
          !_isSubmissionLocked &&
          !_creatingCustomer &&
          _cart.isEmpty &&
          _customerId == null &&
          MediaQuery.viewInsetsOf(context).bottom == 0,
      builder: (context, target) => Scaffold(
        appBar: const _InvoiceAppBar(),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: target(
                0,
                'ابحث عن المواد وأضفها للفاتورة قبل مراجعتها.',
                TextField(
                    controller: _search,
                    enabled: !_isSubmissionLocked,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'ابحث بالاسم أو الكود أو OEM',
                      border: OutlineInputBorder(),
                    )),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedGroup,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'المجموعة'),
                      items: [
                        const DropdownMenuItem(
                            value: 'all', child: Text('كل المجموعات')),
                        ...groups.map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(v, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: _isSubmissionLocked
                          ? null
                          : (value) => setState(() {
                                _selectedGroup = value ?? 'all';
                                _selectedSubGroup = 'all';
                              }),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedSubGroup,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الفرعية'),
                      items: [
                        const DropdownMenuItem(
                            value: 'all', child: Text('كل الفرعيات')),
                        ...subGroups.map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(v, overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: _isSubmissionLocked
                          ? null
                          : (value) => setState(
                                () => _selectedSubGroup = value ?? 'all',
                              ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 170,
              child: filteredProducts.isEmpty
                  ? const Center(child: Text('لا توجد مواد'))
                  : ListView.builder(
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        return ListTile(
                          leading: ProductImageWidget(
                            imageUrl: product.imageUrl,
                            width: 42,
                            height: 42,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          title: Text(product.name),
                          subtitle: Text(
                            '${product.code} · ${product.unit} · '
                            '${product.price} USD · متاح: ${product.quantity}',
                          ),
                          trailing: IconButton(
                            onPressed: _isSubmissionLocked
                                ? null
                                : () => _addProduct(product),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                children: [
                  if (_cart.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: Text('أضف مادة إلى الفاتورة')),
                    ),
                  ..._cart.entries.map((entry) {
                    final code = entry.key;
                    final line = entry.value;
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: ProductImageWidget(
                                    imageUrl: line.product.imageUrl,
                                    width: 48,
                                    height: 48,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${line.product.name}\n'
                                    '${line.product.code} · ${line.product.unit}',
                                    softWrap: true,
                                    style: theme.textTheme.titleSmall,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed:
                                      _isSubmissionLocked || line.quantity <= 1
                                          ? null
                                          : () => setState(() => _cart[code] =
                                              line.copyWith(
                                                  quantity: line.quantity - 1)),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text('${line.quantity}'),
                                IconButton(
                                  onPressed: _isSubmissionLocked
                                      ? null
                                      : () => setState(() => _cart[code] =
                                          line.copyWith(
                                              quantity: line.quantity + 1)),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextFormField(
                                    key: ValueKey('price-$code'),
                                    initialValue: line.unitPrice.toString(),
                                    enabled: !_isSubmissionLocked,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                        labelText: 'سعر الوحدة USD'),
                                    onChanged: (value) {
                                      final price = double.tryParse(value);
                                      if (price != null && price >= 0) {
                                        setState(() => _cart[code] =
                                            line.copyWith(unitPrice: price));
                                      }
                                    },
                                  ),
                                ),
                                IconButton(
                                  onPressed: _isSubmissionLocked
                                      ? null
                                      : () =>
                                          setState(() => _cart.remove(code)),
                                  tooltip: 'إزالة',
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                            if (line.quantity > line.product.quantity)
                              Text(
                                'تنبيه: تجاوز الرصيد المسجل؛ سيسجل الرصيد سالبًا.',
                                style: TextStyle(
                                    color: theme.colorScheme.tertiary),
                              ),
                            Text(
                                'إجمالي السطر: ${formatMoneyShort(line.total, currency: 'USD', decimalPlaces: _decimals('USD'))}'),
                            TextFormField(
                              key: ValueKey('note-$code'),
                              initialValue: line.note,
                              enabled: !_isSubmissionLocked,
                              minLines: 1,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'ملاحظة المادة'),
                              onChanged: (value) => setState(() =>
                                  _cart[code] = line.copyWith(note: value)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  target(
                    1,
                    'اختر حساب الزبون المناسب قبل تسجيل الدفعات.',
                    DropdownButtonFormField<String>(
                        initialValue: _customerId ?? 'CUS-SHOP',
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'حساب الزبون'),
                        items: [
                          const DropdownMenuItem(
                              value: 'CUS-SHOP',
                              child: Text('زبائن محل — دون دين')),
                          ..._customers.map((customer) {
                            final id = customer['customer_id'].toString();
                            final name =
                                customer['full_name']?.toString() ?? id;
                            return DropdownMenuItem(
                                value: id,
                                child: Text(name,
                                    overflow: TextOverflow.ellipsis));
                          }),
                        ],
                        onChanged: _isSubmissionLocked
                            ? null
                            : (value) => setState(
                                  () => _customerId =
                                      value == 'CUS-SHOP' ? null : value,
                                )),
                  ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: _isSubmissionLocked || _creatingCustomer
                          ? null
                          : _createCustomer,
                      icon: const Icon(Icons.person_add_alt_1),
                      label: Text(_pendingCustomer == null
                          ? 'إضافة زبون دون حساب دخول'
                          : 'إعادة محاولة إضافة الزبون'),
                    ),
                  ),
                  TextField(
                    controller: _buyerName,
                    enabled: !_isSubmissionLocked,
                    decoration: const InputDecoration(
                        labelText: 'اسم المشتري (اختياري)'),
                  ),
                  TextField(
                    controller: _buyerPhone,
                    enabled: !_isSubmissionLocked,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                        labelText: 'هاتف المشتري (اختياري)'),
                  ),
                  TextField(
                    controller: _notes,
                    enabled: !_isSubmissionLocked,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'ملاحظات'),
                  ),
                  TextField(
                    controller: _discount,
                    enabled: !_isSubmissionLocked,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'الحسم الثابت (USD)',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تسوية الفاتورة بالكامل'),
                    subtitle: const Text(
                        'استنتاج سعر SYP/USD عند وجود معطيات كافية فقط'),
                    value: _settleFull,
                    onChanged: _isSubmissionLocked
                        ? null
                        : (value) => setState(() => _settleFull = value),
                  ),
                  target(
                      2,
                      'أدخل وسائل الدفع والمبالغ المستلمة، وراجع المتبقي.',
                      _paymentSection(
                          'المبالغ المستلمة من الزبون', _received, false)),
                  _paymentSection(
                      'المبالغ المعادة للزبون (باقي دفع)', _refunded, true),
                  if (previewPaid > _netTotal + 0.005)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('اعتماد الزيادة رصيدًا دائنًا للزبون'),
                      subtitle:
                          const Text('لن تنشأ زيادة على حساب «زبائن محل».'),
                      value: _confirmCredit,
                      onChanged: _customerId == null ||
                              _customerId == 'CUS-SHOP' ||
                              _isSubmissionLocked
                          ? null
                          : (value) => setState(() => _confirmCredit = value),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          'مستلم ${formatMoneyShort(_receivedUsd, currency: 'USD', decimalPlaces: _decimals('USD'))}',
                        ),
                        Text(
                          'معاد ${formatMoneyShort(_refundedUsd, currency: 'USD', decimalPlaces: _decimals('USD'))}',
                        ),
                        Text(
                          'صافي المسدد ${formatMoneyShort(previewPaid, currency: 'USD', decimalPlaces: _decimals('USD'))}',
                        ),
                        Text(
                          'حالة السداد: $paymentStatus',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(_error!,
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'صافي الفاتورة ${formatMoneyShort(_netTotal, currency: 'USD', decimalPlaces: _decimals('USD'))}',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        _previewNetPaid > _netTotal + 0.005
                            ? 'رصيد دائن ${formatMoneyShort(_previewNetPaid - _netTotal, currency: 'USD', decimalPlaces: _decimals('USD'))}'
                            : 'متبقٍ ${formatMoneyShort(max(0, _netTotal - _previewNetPaid), currency: 'USD', decimalPlaces: _decimals('USD'))}',
                        textAlign: TextAlign.end,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: target(
                    3,
                    'اختر الزبون وأدخل الدفعات في نموذج الفاتورة، ثم راجعها قبل الحفظ.',
                    FilledButton.icon(
                        onPressed: _submitting ? null : _reviewAndSubmit,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.receipt_long),
                        label: Text(
                          _submitting
                              ? 'جارٍ الحفظ...'
                              : _requestId == null
                                  ? 'مراجعة وحفظ الفاتورة'
                                  : 'إعادة المحاولة بنفس البيانات',
                        )),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InvoiceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _InvoiceAppBar();

  @override
  Widget build(BuildContext context) =>
      AppBar(title: const Text('فاتورة مبيع بالدولار'));

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _PaymentLine {
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

class _SalesLine {
  final Product product;
  final int quantity;
  final double unitPrice;
  final String note;

  const _SalesLine({
    required this.product,
    required this.quantity,
    required this.unitPrice,
    this.note = '',
  });

  double get total => quantity * unitPrice;

  _SalesLine copyWith({int? quantity, double? unitPrice, String? note}) =>
      _SalesLine(
        product: product,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
        note: note ?? this.note,
      );
}
