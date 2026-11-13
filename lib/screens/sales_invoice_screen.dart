import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/products_provider.dart';
import '../services/api_service.dart';
import '../widgets/product_image_widget.dart';

class SalesInvoiceScreen extends StatefulWidget {
  const SalesInvoiceScreen({super.key});

  @override
  State<SalesInvoiceScreen> createState() => _SalesInvoiceScreenState();
}

class _SalesInvoiceScreenState extends State<SalesInvoiceScreen> {
  final _search = TextEditingController();
  final _discount = TextEditingController(text: '0');
  final _received = TextEditingController();
  final _buyerName = TextEditingController();
  final _buyerPhone = TextEditingController();
  final _notes = TextEditingController();
  final _paymentReference = TextEditingController();
  final Map<String, _SalesLine> _cart = {};

  List<Product> _products = [];
  Map<String, dynamic>? _config;
  String _paymentMethod = 'cash_syp';
  String _selectedGroup = 'all';
  String _selectedSubGroup = 'all';
  bool _loading = true;
  bool _submitting = false;
  String? _error;
  String? _requestId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _discount.dispose();
    _received.dispose();
    _buyerName.dispose();
    _buyerPhone.dispose();
    _notes.dispose();
    _paymentReference.dispose();
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
      await Future.wait([
        configFuture,
        provider.fetchProducts(forceRefresh: true),
      ]);
      final config = _extractResponseMap(await configFuture, 'configuration');
      if (provider.allProducts.isEmpty && provider.errorMessage != null) {
        throw StateError(provider.errorMessage!);
      }
      final invoiceCurrency = _normalizeCurrency(config['invoice_currency']);
      final shamCurrency = _normalizeCurrency(config['sham_cash_currency']);
      final rate = _numberValue(config['rate_syp_per_usd']);
      final usdDecimals = _numberValue(config['usd_decimals']);
      final sypDecimals = _numberValue(config['syp_decimals']);
      if (invoiceCurrency == null) {
        throw StateError(
          'لم يحدد المسؤول عملة الفاتورة بعد. يرجى التواصل مع المدير أو المحاسب.',
        );
      }
      if (config['cash_box_configured'] != true) {
        throw StateError(
            'لم يُربط حسابك بصندوق التحصيل بعد. تواصل مع المسؤول.');
      }
      if (!_isValidCurrencyPrecision(usdDecimals) ||
          !_isValidCurrencyPrecision(sypDecimals)) {
        throw StateError(
          'لم تكتمل إعدادات دقة العملات. يرجى التواصل مع المدير أو المحاسب.',
        );
      }
      config['invoice_currency'] = invoiceCurrency;
      config['sham_cash_currency'] = shamCurrency;
      config['rate_syp_per_usd'] = rate;
      config['usd_decimals'] = usdDecimals;
      config['syp_decimals'] = sypDecimals;
      if (!mounted) return;
      setState(() {
        _config = config;
        _products = provider.allProducts;
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

  Map<String, dynamic> _extractResponseMap(
    Map<String, dynamic> response,
    String key,
  ) {
    final direct = response[key];
    if (direct is Map) return Map<String, dynamic>.from(direct);

    final data = response['data'];
    if (data is Map) {
      final nested = data[key];
      if (nested is Map) return Map<String, dynamic>.from(nested);
      return Map<String, dynamic>.from(data);
    }

    return Map<String, dynamic>.from(response);
  }

  String? _normalizeCurrency(dynamic value) {
    final currency = value?.toString().trim().toUpperCase();
    return currency == 'USD' || currency == 'SYP' ? currency : null;
  }

  double? _numberValue(dynamic value) {
    if (value is num && value.isFinite) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null && parsed.isFinite) return parsed;
    }
    return null;
  }

  bool _isValidCurrencyPrecision(dynamic value) =>
      value is double &&
      value.isFinite &&
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

  String get _invoiceCurrency => _config?['invoice_currency']?.toString() ?? '';

  String? get _paymentCurrency {
    switch (_paymentMethod) {
      case 'cash_syp':
        return 'SYP';
      case 'cash_usd':
        return 'USD';
      case 'sham_cash':
        return _normalizeCurrency(_config?['sham_cash_currency']);
      default:
        return null;
    }
  }

  int _decimals(String currency) {
    final value = _config == null
        ? null
        : _numberValue(
            _config![currency == 'USD' ? 'usd_decimals' : 'syp_decimals'],
          );
    return value?.toInt() ?? 0;
  }

  double get _subtotal =>
      _cart.values.fold(0, (total, line) => total + line.total);

  double get _discountValue => double.tryParse(_discount.text) ?? 0;

  double get _netTotal {
    final decimals = _decimals(_invoiceCurrency);
    final factor = pow(10, decimals).toDouble();
    return ((_subtotal - _discountValue) * factor).round() / factor;
  }

  double? get _equivalentReceived {
    final amount = double.tryParse(_received.text);
    final payCurrency = _paymentCurrency;
    if (amount == null || amount < 0 || payCurrency == null) return null;
    if (payCurrency == _invoiceCurrency) return amount;
    final rate = _numberValue(_config?['rate_syp_per_usd']);
    if (rate == null || rate <= 0) return null;
    if (_invoiceCurrency == 'USD' && payCurrency == 'SYP') {
      return amount / rate;
    }
    if (_invoiceCurrency == 'SYP' && payCurrency == 'USD') {
      return amount * rate;
    }
    return null;
  }

  double? get _changePreview {
    final equivalent = _equivalentReceived;
    final payCurrency = _paymentCurrency;
    if (equivalent == null || payCurrency == null) return null;
    final rate = _numberValue(_config?['rate_syp_per_usd']) ?? 1;
    final invoiceDifference = equivalent - _netTotal;
    final change = payCurrency == _invoiceCurrency
        ? invoiceDifference
        : _invoiceCurrency == 'USD'
            ? invoiceDifference * rate
            : invoiceDifference / rate;
    final factor = pow(10, _decimals(payCurrency)).toDouble();
    return (change * factor).round() / factor;
  }

  void _addProduct(Product product) {
    if (product.quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد كمية مخصصة متاحة من هذه المادة')),
      );
      return;
    }
    setState(() {
      final existing = _cart[product.code];
      if (existing != null) {
        if (existing.quantity < product.quantity) {
          _cart[product.code] =
              existing.copyWith(quantity: existing.quantity + 1);
        }
      } else {
        _cart[product.code] = _SalesLine(
          product: product,
          quantity: 1,
          unitPrice: product.price,
        );
      }
    });
  }

  void _updateLine(String code, _SalesLine line) {
    setState(() => _cart[code] = line);
  }

  String _newRequestId() {
    final random = Random.secure();
    final suffix = List.generate(
      4,
      (_) => random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
    ).join();
    return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  Future<void> _reviewAndSubmit() async {
    final payCurrency = _paymentCurrency;
    final amount = double.tryParse(_received.text);
    if (_cart.isEmpty ||
        payCurrency == null ||
        amount == null ||
        amount <= 0 ||
        _discountValue < 0 ||
        _discountValue > _subtotal) {
      setState(() => _error = 'تحقق من المواد والحسم والمبلغ وطريقة القبض.');
      return;
    }
    if (_equivalentReceived == null) {
      setState(() =>
          _error = 'سعر الصرف المطلوب غير مضبوط، لا يمكن تأكيد الفاتورة.');
      return;
    }
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مراجعة الفاتورة النقدية'),
        content: Text(
          'المواد قبل الحسم: ${_subtotal.toStringAsFixed(_decimals(_invoiceCurrency))} $_invoiceCurrency\n'
          'الحسم: ${_discountValue.toStringAsFixed(_decimals(_invoiceCurrency))} $_invoiceCurrency\n'
          'الصافي: ${_netTotal.toStringAsFixed(_decimals(_invoiceCurrency))} $_invoiceCurrency\n'
          'المستلم: ${amount.toStringAsFixed(_decimals(payCurrency))} $payCurrency\n'
          'المكافئ بسعر الصرف الحالي: ${_equivalentReceived!.toStringAsFixed(_decimals(_invoiceCurrency))} $_invoiceCurrency\n'
          'الباقي المرتجع: ${_changePreview!.toStringAsFixed(_decimals(payCurrency))} $payCurrency',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('رجوع للتعديل'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ترحيل نقدي'),
          ),
        ],
      ),
    );
    if (approved == true) await _submit();
  }

  Future<void> _submit() async {
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
        'discount': _discountValue,
        'amount_received': double.parse(_received.text),
        'payment_method': _paymentMethod,
        'payment_reference': _paymentReference.text.trim(),
        'buyer_name': _buyerName.text.trim(),
        'buyer_phone': _buyerPhone.text.trim(),
        'notes': _notes.text.trim(),
      });
      if (!mounted) return;
      final invoice = result['invoice_id']?.toString() ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم ترحيل الفاتورة النقدية $invoice')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('فاتورة مبيع نقدية')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null && _config == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('فاتورة مبيع نقدية')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _load,
                  child: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final query = _search.text.trim().toLowerCase();
    final filteredProducts = _products.where((product) {
      final matchesGroup =
          _selectedGroup == 'all' || product.group == _selectedGroup;
      final matchesSubGroup =
          _selectedSubGroup == 'all' || product.subGroup == _selectedSubGroup;
      final matchesSearch = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.code.toLowerCase().contains(query) ||
          product.oem.toLowerCase().contains(query);
      return matchesGroup && matchesSubGroup && matchesSearch;
    }).toList();
    final groups = _products
        .map((product) => product.group.trim())
        .where((group) => group.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final subGroups = _products
        .where(
          (product) =>
              _selectedGroup == 'all' || product.group == _selectedGroup,
        )
        .map((product) => product.subGroup.trim())
        .where((subGroup) => subGroup.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final payCurrency = _paymentCurrency;
    final rate = _numberValue(_config?['rate_syp_per_usd']);
    final needsRate = payCurrency != null && payCurrency != _invoiceCurrency;
    final change = _changePreview;

    return Scaffold(
      appBar: AppBar(title: const Text('فاتورة مبيع نقدية')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ابحث بالاسم أو الكود أو OEM',
                border: OutlineInputBorder(),
              ),
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
                        value: 'all',
                        child: Text('كل المجموعات'),
                      ),
                      ...groups.map(
                        (group) => DropdownMenuItem(
                          value: group,
                          child: Text(group, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(() {
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
                    decoration:
                        const InputDecoration(labelText: 'المجموعة الفرعية'),
                    items: [
                      const DropdownMenuItem(
                        value: 'all',
                        child: Text('كل الفرعيات'),
                      ),
                      ...subGroups.map(
                        (subGroup) => DropdownMenuItem(
                          value: subGroup,
                          child: Text(
                            subGroup,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(
                      () => _selectedSubGroup = value ?? 'all',
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 190,
            child: filteredProducts.isEmpty
                ? const Center(child: Text('لا توجد مواد متاحة'))
                : ListView.builder(
                    itemCount: filteredProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredProducts[index];
                      return ListTile(
                        leading: ProductImageWidget(
                          imageUrl: product.imageUrl,
                          width: 44,
                          height: 44,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        title: Text(product.name),
                        subtitle: Text(
                          '${product.code} · ${product.unit} · '
                          '${product.price} ${product.currency} · '
                          'متاح: ${product.quantity}',
                        ),
                        trailing: IconButton(
                          onPressed: () => _addProduct(product),
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
                          Text(
                            '${line.product.name} · ${line.product.unit}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Row(
                            children: [
                              IconButton(
                                onPressed: line.quantity <= 1
                                    ? null
                                    : () => _updateLine(
                                          code,
                                          line.copyWith(
                                            quantity: line.quantity - 1,
                                          ),
                                        ),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                              Text('${line.quantity}'),
                              IconButton(
                                onPressed:
                                    line.quantity >= line.product.quantity
                                        ? null
                                        : () => _updateLine(
                                              code,
                                              line.copyWith(
                                                quantity: line.quantity + 1,
                                              ),
                                            ),
                                icon: const Icon(Icons.add_circle_outline),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextFormField(
                                  key: ValueKey('price-$code'),
                                  initialValue: line.unitPrice.toString(),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: const InputDecoration(
                                      labelText: 'سعر الوحدة'),
                                  onChanged: (value) {
                                    final price = double.tryParse(value);
                                    if (price != null && price >= 0) {
                                      _updateLine(
                                        code,
                                        line.copyWith(unitPrice: price),
                                      );
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                tooltip: 'إزالة',
                                onPressed: () =>
                                    setState(() => _cart.remove(code)),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: Text(
                              'الإجمالي: ${line.total.toStringAsFixed(_decimals(_invoiceCurrency))} $_invoiceCurrency',
                            ),
                          ),
                          TextFormField(
                            key: ValueKey('note-$code'),
                            initialValue: line.note,
                            decoration: const InputDecoration(
                              labelText: 'ملاحظة المادة (اختياري)',
                            ),
                            onChanged: (value) => _updateLine(
                              code,
                              line.copyWith(note: value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                TextField(
                  controller: _buyerName,
                  decoration:
                      const InputDecoration(labelText: 'اسم المشتري (اختياري)'),
                ),
                TextField(
                  controller: _buyerPhone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'هاتف المشتري (اختياري)'),
                ),
                TextField(
                  controller: _notes,
                  decoration: const InputDecoration(labelText: 'ملاحظات'),
                ),
                TextField(
                  controller: _discount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'حسم ثابت ($_invoiceCurrency)',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethod,
                  decoration: const InputDecoration(labelText: 'طريقة القبض'),
                  items: [
                    const DropdownMenuItem(
                      value: 'cash_syp',
                      child: Text('نقدي سوري (SYP)'),
                    ),
                    const DropdownMenuItem(
                      value: 'cash_usd',
                      child: Text('نقدي دولار (USD)'),
                    ),
                    if (_config?['sham_cash_currency'] == 'USD' ||
                        _config?['sham_cash_currency'] == 'SYP')
                      DropdownMenuItem(
                        value: 'sham_cash',
                        child: Text(
                          'شام كاش (${_config?['sham_cash_currency']})',
                        ),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _paymentMethod = value);
                    }
                  },
                ),
                if (needsRate)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      rate == null
                          ? 'سعر الصرف غير مضبوط؛ لن يسمح الخادم بترحيل الفاتورة.'
                          : 'سعر الصرف: 1 USD = $rate SYP',
                    ),
                  ),
                if (_paymentMethod == 'sham_cash')
                  TextField(
                    controller: _paymentReference,
                    decoration: const InputDecoration(
                      labelText: 'مرجع عملية شام كاش (اختياري)',
                    ),
                  ),
                TextField(
                  controller: _received,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'المبلغ المستلم (${payCurrency ?? ''})',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Text(
                    'مجموع المواد: ${_subtotal.toStringAsFixed(_decimals(_invoiceCurrency))} $_invoiceCurrency'),
                Text(
                    'الصافي بعد الحسم: ${_netTotal.toStringAsFixed(_decimals(_invoiceCurrency))} $_invoiceCurrency'),
                if (change != null && change >= 0 && payCurrency != null)
                  Text(
                    'الباقي المرتجع: ${change.toStringAsFixed(_decimals(payCurrency))} $payCurrency',
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton.icon(
            onPressed: _submitting ? null : _reviewAndSubmit,
            icon: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.receipt_long),
            label: Text(_submitting ? 'جارٍ الترحيل...' : 'مراجعة وترحيل نقدي'),
          ),
        ),
      ),
    );
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
