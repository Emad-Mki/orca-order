import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_config.dart';
import '../providers/products_provider.dart';
import '../services/api_service.dart';
import '../services/invoice_product_images.dart';
import '../services/sales_invoice_store.dart';
import '../utils/number_utils.dart';
import '../utils/permissions.dart';
import '../widgets/product_image_widget.dart';
import 'sales_invoice_screen.dart';
import 'sales_invoice_pdf_screen.dart';

class SalesInvoicesScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  final String? customerId;
  const SalesInvoicesScreen(
      {super.key, required this.session, this.customerId});

  @override
  State<SalesInvoicesScreen> createState() => _SalesInvoicesScreenState();
}

class _SalesInvoicesScreenState extends State<SalesInvoicesScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _invoices = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _salespeople = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  bool _offline = false;
  String? _storageError;
  int _loadGeneration = 0;
  String? _error;
  DateTimeRange? _dateRange;
  String _paymentFilter = 'all';
  String _statusFilter = 'all';
  String _financialFilter = 'all';
  String? _sellerFilter;
  String? _customerFilter;
  final Set<String> _collectingInvoiceIds = {};
  final Map<String, Map<String, dynamic>> _pendingCollections = {};

  @override
  void initState() {
    super.initState();
    _customerFilter = widget.customerId;
    _load();
  }

  @override
  void didUpdateWidget(covariant SalesInvoicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session['user_id'] != widget.session['user_id'] ||
        oldWidget.session['id'] != widget.session['id'] ||
        oldWidget.session['role'] != widget.session['role'] ||
        oldWidget.customerId != widget.customerId) {
      _customers = [];
      _salespeople = [];
      _sellerFilter = null;
      _customerFilter = widget.customerId;
      _load();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final api = ApiService();
    final token = api.token;
    final account = (widget.session['user_id'] ?? widget.session['id'])
            ?.toString()
            .trim() ??
        '';
    final role = _role.name;
    final environment = '${AppConfig.environmentName}:${AppConfig.apiUrl}';
    bool authorized() {
      final current = api.currentUser;
      return token != null &&
          token.isNotEmpty &&
          api.token == token &&
          (current?['user_id'] ?? current?['id'])?.toString().trim() ==
              account &&
          PermissionHelper.fromString(current?['role']?.toString() ?? '')
                  .name ==
              role &&
          '${AppConfig.environmentName}:${AppConfig.apiUrl}' == environment &&
          {'admin', 'accountant', 'manager', 'salesperson'}.contains(role) &&
          account.isNotEmpty;
    }

    final query = _search.text;
    final from = _dateRange?.start;
    final to = _dateRange == null
        ? null
        : DateTime(_dateRange!.end.year, _dateRange!.end.month,
            _dateRange!.end.day, 23, 59, 59);
    final payment = _paymentFilter == 'all' ? null : _paymentFilter;
    final status = _statusFilter == 'all' ? null : _statusFilter;
    final financial = _financialFilter == 'all' ? null : _financialFilter;
    final seller = _sellerFilter;
    final customer = _customerFilter;
    setState(() {
      _loading = true;
      _error = null;
      _storageError = null;
      _offline = false;
      _invoices = [];
      _summary = {};
    });
    bool active() => mounted && generation == _loadGeneration && authorized();
    if (!authorized()) {
      if (mounted && generation == _loadGeneration) {
        setState(() {
          _error = 'الجلسة غير صالحة لعرض الفواتير';
          _loading = false;
        });
      }
      return;
    }
    final store = SalesInvoiceStore(
        environment: environment, userId: account, role: role);
    try {
      final cached = await store.list(
        query: query,
        fromDate: from,
        toDate: to,
        status: status,
        financialStatus: financial,
        paymentMethod: payment,
        sellerId: seller,
        customerId: customer,
      );
      final choices = _canFilterAllSales ? await store.list() : cached;
      if (!active()) return;
      if (cached.isNotEmpty) {
        setState(() {
          _invoices = cached;
          _offline = true;
          _loading = false;
          _addOfflineFilterChoices(choices);
        });
      }
    } catch (error) {
      debugPrint('Invoice cache unavailable: ${error.runtimeType}');
      if (active()) {
        setState(() => _storageError = 'تعذرت قراءة الفواتير المحفوظة');
      }
    }
    if (!active()) return;
    try {
      final result = await api.sales.getInvoices(
        query: query,
        fromDate: from?.toIso8601String(),
        toDate: to?.toIso8601String(),
        paymentMethod: payment,
        status: status,
        financialStatus: financial,
        sellerId: seller,
        customerId: customer,
      );
      final invoiceRows = result['invoices'];
      if (invoiceRows is! List) {
        throw StateError('استجابة الفواتير غير صالحة');
      }
      if (!active()) return;
      final invoices = invoiceRows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      setState(() {
        _invoices = invoices;
        _offline = false;
        _loading = false;
      });
      try {
        if (invoices.length != invoiceRows.length) {
          throw const FormatException('Invalid invoice snapshot');
        }
        await store.merge(invoices);
        if (mounted && active()) {
          final products = context.read<ProductsProvider>();
          unawaited(_cacheInvoiceImages(
            invoices,
            products,
            InvoiceProductImages(
                scope: invoiceImageScope(environment, account, role)),
            active,
          ));
        }
      } catch (_) {
        if (active()) {
          setState(
              () => _storageError = 'تعذر حفظ الفواتير للاستخدام دون اتصال');
        }
      }
      if (!active()) return;
      try {
        final summary = await api.sales.getSummary(
          fromDate: from?.toIso8601String(),
          toDate: to?.toIso8601String(),
          sellerId: seller,
          customerId: customer,
        );
        if (active()) setState(() => _summary = summary);
      } catch (error) {
        debugPrint('Invoice summary unavailable: ${error.runtimeType}');
      }
      if (_canFilterAllSales && active()) {
        try {
          final ancillary = await Future.wait([
            api.sales.getCustomers(),
            api.sales.getSalespeople(),
          ]);
          if (active()) {
            setState(() {
              _customers = ancillary[0];
              _salespeople = ancillary[1];
            });
          }
        } catch (error) {
          debugPrint(
              'Invoice filter choices unavailable: ${error.runtimeType}');
        }
      }
    } catch (error) {
      if (!active()) return;
      if (error is ApiException && error.transportFailure) {
        try {
          final cached = await store.list(
            query: query,
            fromDate: from,
            toDate: to,
            status: status,
            financialStatus: financial,
            paymentMethod: payment,
            sellerId: seller,
            customerId: customer,
          );
          final choices = _canFilterAllSales ? await store.list() : cached;
          if (!active()) return;
          setState(() {
            _invoices = cached;
            _offline = true;
            _loading = false;
            _addOfflineFilterChoices(choices);
          });
          return;
        } catch (_) {
          if (active()) {
            setState(() => _storageError = 'تعذرت قراءة الفواتير المحفوظة');
          }
        }
      }
      if (active()) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  void _addOfflineFilterChoices(List<Map<String, dynamic>> choices) {
    if (!_canFilterAllSales) return;
    for (final row in choices) {
      final sellerId = row['seller_id']?.toString();
      if (sellerId != null &&
          sellerId.isNotEmpty &&
          !_salespeople.any((s) => '${s['user_id']}' == sellerId)) {
        _salespeople.add({
          'user_id': sellerId,
          'full_name': row['seller_name'] ?? sellerId,
        });
      }
      final customerId = row['customer_id']?.toString();
      if (customerId != null &&
          customerId.isNotEmpty &&
          !_customers.any((c) => '${c['customer_id']}' == customerId)) {
        _customers.add({
          'customer_id': customerId,
          'full_name': row['customer_name'] ?? customerId,
        });
      }
    }
  }

  Future<void> _cacheInvoiceImages(
    List<Map<String, dynamic>> invoices,
    ProductsProvider products,
    InvoiceProductImages imageStore,
    bool Function() active,
  ) async {
    try {
      if (products.allProducts.isEmpty) await products.fetchProducts();
      if (!active()) return;
      final urls = {
        for (final product in products.allProducts)
          if (product.imageUrl?.trim().isNotEmpty == true)
            product.code: product.imageUrl!,
      };
      for (final invoice in invoices) {
        if (!active()) return;
        final id = invoice['invoice_id']?.toString() ?? '';
        final items = invoice['items'];
        if (id.isEmpty || items is! List) continue;
        final images = <String, String>{};
        for (final item in items.whereType<Map>()) {
          final code = item['code']?.toString() ?? '';
          final url = urls[code];
          if (url != null) images[code] = url;
        }
        await imageStore.cache(id, images);
      }
    } catch (error) {
      debugPrint('Invoice image caching failed: ${error.runtimeType}');
    }
  }

  AppRole get _role =>
      PermissionHelper.fromString(widget.session['role']?.toString() ?? '');

  bool get _canFilterAllSales => const {
        AppRole.admin,
        AppRole.accountant,
        AppRole.manager
      }.contains(_role);

  bool get _canCreateInvoices => const {
        AppRole.admin,
        AppRole.accountant,
        AppRole.manager,
        AppRole.salesperson,
      }.contains(_role);

  void _showDetails(Map<String, dynamic> invoice) {
    final items = (invoice['items'] as List? ?? const [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    final productsByCode = {
      for (final product in context.read<ProductsProvider>().allProducts)
        product.code: product,
    };
    final invoiceNumber =
        invoice['invoice_number']?.toString().trim().isNotEmpty == true
            ? invoice['invoice_number'].toString()
            : invoice['invoice_id'].toString();
    final creatorName =
        (invoice['creator_name'] ?? invoice['seller_name'] ?? '').toString();
    final creatorRole = invoice['creator_role']?.toString() ?? '';
    final detailNavigator = Navigator.of(context);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(invoiceNumber, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${invoice['invoice_date'] ?? ''} · '
              '${_financialStatusName(invoice['financial_status']?.toString())}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الزبون: ${invoice['customer_name'] ?? 'زبائن محل'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        if ((invoice['buyer_name'] ?? '').toString().isNotEmpty)
                          Text('المشتري: ${invoice['buyer_name']}'),
                        if ((invoice['buyer_phone'] ?? '')
                            .toString()
                            .isNotEmpty)
                          Text('الهاتف: ${invoice['buyer_phone']}'),
                        if (creatorName.isNotEmpty)
                          Text(
                            'أنشأها: $creatorName'
                            '${creatorRole.isEmpty ? '' : ' · ${PermissionHelper.getRoleNameAr(PermissionHelper.fromString(creatorRole))}'}',
                          ),
                        Text('مرجع داخلي: ${invoice['invoice_id']}'),
                        if ((invoice['shipment_summary'] ?? '')
                            .toString()
                            .isNotEmpty)
                          Text('الطرود: ${invoice['shipment_summary']}'),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Text('المواد', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                ...items.map((item) {
                  final code = item['code']?.toString() ?? '';
                  final product = productsByCode[code];
                  final currency = invoice['currency']?.toString() ?? 'USD';
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: ProductImageWidget(
                              imageUrl: product?.imageUrl,
                              width: 52,
                              height: 52,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['name_snapshot']?.toString() ?? code,
                                  softWrap: true,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                    'الرمز: $code · الوحدة: ${item['unit'] ?? ''}'),
                                Text(
                                  'الكمية: ${item['quantity'] ?? 0} · '
                                  'سعر الوحدة: ${formatMoneyShort(item['unit_price'], currency: currency)}',
                                ),
                                Text(
                                  'إجمالي البند: ${formatMoneyShort(item['line_total'], currency: currency)}',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if ((item['note'] ?? '').toString().isNotEmpty)
                                  Text('ملاحظة: ${item['note']}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('الإجماليات',
                            style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          'المجموع: ${formatMoneyShort(invoice['subtotal'], currency: 'USD')}',
                        ),
                        Text(
                          'الحسم: ${formatMoneyShort(invoice['discount'], currency: 'USD')}',
                        ),
                        Text(
                          'صافي الفاتورة: ${formatMoneyShort(invoice['net_total'], currency: 'USD')}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const Divider(),
                        Text(
                          'إجمالي المستلم: ${formatMoneyShort(invoice['total_received_usd'] ?? invoice['amount_received'] ?? 0, currency: 'USD')}',
                        ),
                        Text(
                          'الباقي المعاد للزبون: ${formatMoneyShort(invoice['total_refunded_usd'] ?? invoice['change_amount'] ?? 0, currency: 'USD')}',
                        ),
                        Text(
                          'صافي المسدد: ${formatMoneyShort(invoice['total_paid_usd'] ?? invoice['net_received'] ?? 0, currency: 'USD')}',
                        ),
                        Text(
                          'متبقٍ على الزبون: ${formatMoneyShort(invoice['balance_due_usd'] ?? 0, currency: 'USD')}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(),
                Text('وسائل الدفع',
                    style: Theme.of(context).textTheme.titleMedium),
                ...((invoice['payments'] as List? ?? const [])
                    .whereType<Map>()
                    .map((row) => Map<String, dynamic>.from(row))
                    .map((payment) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${payment['action_type'] == 'pay' ? 'باقي معاد' : 'مبلغ مستلم'} · '
                            '${payment['payment_method'] ?? payment['method']}',
                          ),
                          subtitle: Text(
                            '${formatMoneyShort(payment['amount'], currency: payment['currency']?.toString() ?? 'USD')}'
                            ' · مكافئ ${formatMoneyShort(payment['invoice_equivalent'] ?? 0, currency: 'USD')}'
                            '${payment['currency'] == 'SYP' && payment['exchange_rate'] != null ? ' · سعر الصرف ${payment['exchange_rate']} ل.س لكل USD' : ''}'
                            '${(payment['reference'] ?? '').toString().isEmpty ? '' : ' · ${payment['reference']}'}'
                            '${(payment['note'] ?? '').toString().isEmpty ? '' : '\n${payment['note']}'}',
                          ),
                        ))),
                if (invoice['needs_financial_review'] == true)
                  const Text(
                    'تنبيه: توجد حركة قديمة تحتاج مراجعة يدوية؛ لم يُخمن سعرها.',
                  ),
                if ((invoice['notes'] ?? '').toString().isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('ملاحظات: ${invoice['notes']}'),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SalesInvoicePdfScreen(invoice: invoice),
              ),
            ),
            child: const Text('معاينة PDF'),
          ),
          if (_canCollectInvoice(invoice))
            TextButton(
              onPressed: _offline ||
                      _collectingInvoiceIds
                          .contains(invoice['invoice_id'].toString())
                  ? null
                  : () async {
                      final saved = await _collectInvoice(invoice);
                      if (saved && mounted) {
                        detailNavigator.pop();
                        await _load();
                      }
                    },
              child: Text(
                _collectingInvoiceIds.contains(invoice['invoice_id'].toString())
                    ? 'جارٍ التحصيل...'
                    : 'تسجيل تحصيل',
              ),
            ),
          if (_canVoidInvoices && invoice['status'] == 'posted')
            TextButton(
              onPressed: _offline ? null : () => _voidInvoice(invoice),
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

  bool _canCollectInvoice(Map<String, dynamic> invoice) {
    final isSalesperson = _role == AppRole.salesperson;
    final canCollect = const {
      AppRole.admin,
      AppRole.manager,
      AppRole.accountant,
      AppRole.salesperson,
    }.contains(_role);
    final isOwnInvoice = !isSalesperson ||
        invoice['seller_id']?.toString() ==
            (widget.session['user_id'] ?? widget.session['id'])?.toString();
    final balance = double.tryParse(
          invoice['balance_due_usd']?.toString() ?? '0',
        ) ??
        0;
    return canCollect &&
        isOwnInvoice &&
        invoice['status'] == 'posted' &&
        balance > 0.005;
  }

  Future<bool> _collectInvoice(Map<String, dynamic> invoice) async {
    if (_offline) return false;
    final invoiceId = invoice['invoice_id'].toString();
    final pending = _pendingCollections[invoiceId];
    final pendingPayload = pending?['payload'] as Map<String, dynamic>?;
    final pendingLines =
        (pendingPayload?['received_lines'] as List? ?? const [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
    final lines = pendingLines.isEmpty
        ? <_CollectionLine>[_CollectionLine()]
        : pendingLines.map(_CollectionLine.fromMap).toList();
    var confirmCredit = pendingPayload?['confirm_customer_credit'] == true;
    var dialogError = '';

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          double totalUsd() => lines.fold(0, (total, line) {
                final amount = double.tryParse(line.amount.text) ?? 0;
                if (!line.isSyp) return total + amount;
                final equivalent = double.tryParse(line.equivalent.text.trim());
                if (equivalent != null && equivalent > 0) {
                  return total + equivalent;
                }
                final rate = double.tryParse(line.rate.text.trim());
                return rate != null && rate > 0 ? total + amount / rate : total;
              });

          final balance = double.tryParse(
                invoice['balance_due_usd']?.toString() ?? '0',
              ) ??
              0;
          final exceedsBalance = totalUsd() - balance > 0.005;
          final isWalkIn = invoice['customer_id'] == 'CUS-SHOP';
          final isRetry = pendingPayload != null;

          return AlertDialog(
            title: Text(
              isRetry
                  ? 'إعادة محاولة التحصيل ${invoice['invoice_id']}'
                  : 'تحصيل فاتورة ${invoice['invoice_id']}',
            ),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'المتبقي: ${formatMoneyShort(balance, currency: 'USD')}',
                    ),
                    if (isRetry)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'تُعاد المحاولة بالبيانات نفسها ومعرف العملية نفسه لمنع التكرار.',
                        ),
                      ),
                    ...lines.asMap().entries.map((entry) {
                      final index = entry.key;
                      final line = entry.value;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: line.method,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                          labelText: 'وسيلة القبض'),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'cash_usd',
                                            child: Text('نقدي USD')),
                                        DropdownMenuItem(
                                            value: 'cash_syp',
                                            child: Text('نقدي SYP')),
                                        DropdownMenuItem(
                                            value: 'sham_cash_usd',
                                            child: Text('شام كاش USD')),
                                        DropdownMenuItem(
                                            value: 'sham_cash_syp',
                                            child: Text('شام كاش SYP')),
                                      ],
                                      onChanged: isRetry
                                          ? null
                                          : (value) => setDialogState(() {
                                                if (value != null) {
                                                  line.method = value;
                                                }
                                              }),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: line.amount,
                                      enabled: !isRetry,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      decoration: InputDecoration(
                                          labelText:
                                              'المبلغ ${line.isSyp ? 'SYP' : 'USD'}'),
                                      onChanged: (_) => setDialogState(() {}),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: isRetry || lines.length == 1
                                        ? null
                                        : () => setDialogState(() {
                                              lines.removeAt(index).dispose();
                                            }),
                                    icon:
                                        const Icon(Icons.remove_circle_outline),
                                  ),
                                ],
                              ),
                              if (line.isSyp)
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: line.equivalent,
                                        enabled: !isRetry,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                            labelText: 'المقابل USD'),
                                        onChanged: (_) => setDialogState(() {}),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: line.rate,
                                        enabled: !isRetry,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                            labelText: 'ل.س لكل USD'),
                                        onChanged: (_) => setDialogState(() {}),
                                      ),
                                    ),
                                  ],
                                ),
                              TextField(
                                controller: line.reference,
                                enabled: !isRetry,
                                decoration: const InputDecoration(
                                    labelText: 'مرجع اختياري'),
                              ),
                              TextField(
                                controller: line.note,
                                enabled: !isRetry,
                                decoration: const InputDecoration(
                                    labelText: 'ملاحظة اختيارية'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        onPressed: isRetry
                            ? null
                            : () => setDialogState(
                                () => lines.add(_CollectionLine())),
                        icon: const Icon(Icons.add),
                        label: const Text('إضافة وسيلة'),
                      ),
                    ),
                    if (exceedsBalance)
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: confirmCredit,
                        onChanged: isRetry || isWalkIn
                            ? null
                            : (value) =>
                                setDialogState(() => confirmCredit = value),
                        title: const Text('اعتماد الزيادة رصيدًا دائنًا'),
                        subtitle: Text(
                          isWalkIn
                              ? 'لا يمكن إسناد رصيد دائن إلى زبائن محل.'
                              : formatMoneyShort(
                                  totalUsd() - balance,
                                  currency: 'USD',
                                ),
                        ),
                      ),
                    if (dialogError.isNotEmpty)
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          dialogError,
                          style: TextStyle(
                              color: Theme.of(dialogContext).colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(isRetry ? 'إغلاق' : 'إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  final payloadLines = <Map<String, dynamic>>[];
                  try {
                    for (final line in lines) {
                      final amount = double.tryParse(line.amount.text.trim());
                      if (amount == null || !amount.isFinite || amount <= 0) {
                        throw StateError('أدخل مبلغًا موجبًا لكل سطر.');
                      }
                      final row = <String, dynamic>{
                        'method': line.method,
                        'amount': amount,
                        'reference': line.reference.text.trim(),
                        'note': line.note.text.trim(),
                      };
                      if (line.isSyp) {
                        final equivalent =
                            double.tryParse(line.equivalent.text.trim());
                        final rate = double.tryParse(line.rate.text.trim());
                        if ((equivalent == null || equivalent <= 0) &&
                            (rate == null || rate <= 0)) {
                          throw StateError(
                              'حدد المقابل بالدولار أو سعر الصرف.');
                        }
                        if (equivalent != null) {
                          row['equivalent_usd'] = equivalent;
                        }
                        if (rate != null) row['exchange_rate'] = rate;
                      }
                      payloadLines.add(row);
                    }
                    if (exceedsBalance && (isWalkIn || !confirmCredit)) {
                      throw StateError(
                          'أكد الرصيد الدائن لزبون محدد أو صحح المبلغ.');
                    }
                    if (isRetry &&
                        jsonEncode(payloadLines) !=
                            jsonEncode(pendingPayload['received_lines'])) {
                      throw StateError(
                          'بيانات إعادة المحاولة يجب أن تبقى كما هي.');
                    }
                    Navigator.pop(dialogContext, {
                      'received_lines': payloadLines,
                      'confirm_customer_credit': confirmCredit,
                    });
                  } catch (error) {
                    setDialogState(() {
                      dialogError =
                          error.toString().replaceFirst('Bad state: ', '');
                    });
                  }
                },
                child: Text(isRetry ? 'إعادة المحاولة' : 'تسجيل التحصيل'),
              ),
            ],
          );
        },
      ),
    );
    for (final line in lines) {
      line.dispose();
    }
    if (result == null || !mounted) return false;

    final requestId = pending?['request_id']?.toString() ??
        'collect-$invoiceId-${DateTime.now().microsecondsSinceEpoch}';
    final requestPayload = <String, dynamic>{
      'client_request_id': requestId,
      'invoice_id': invoiceId,
      ...result,
    };
    _pendingCollections[invoiceId] = {
      'request_id': requestId,
      'payload': result,
    };
    setState(() => _collectingInvoiceIds.add(invoiceId));
    try {
      await ApiService().sales.collectInvoicePayment(requestPayload);
      _pendingCollections.remove(invoiceId);
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر تأكيد التحصيل. أعد المحاولة بالبيانات نفسها لتجنب التكرار: $error',
            ),
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _collectingInvoiceIds.remove(invoiceId));
      }
    }
  }

  bool get _canVoidInvoices =>
      const {AppRole.admin, AppRole.accountant}.contains(_role);

  Future<void> _voidInvoice(Map<String, dynamic> invoice) async {
    if (_offline) return;
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

  String _financialStatusName(String? status) => switch (status) {
        'paid' => 'مسددة',
        'partial' => 'مدفوعة جزئيًا',
        'unpaid' => 'غير مدفوعة',
        'voided' => 'ملغاة',
        _ => 'غير محددة',
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
    final financial = Map<String, dynamic>.from(
      _summary['financial_summary_usd'] as Map? ?? const {},
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
      floatingActionButton: _canCreateInvoices
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
      body: CustomScrollView(
        slivers: [
          if (_offline)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: Text(
                    'دون اتصال: البيانات المحفوظة قديمة وغير مكتملة، وقد توجد فواتير غير معروضة. التحصيل والإلغاء متوقفان.'),
              ),
            ),
          if (_storageError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_storageError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ),
          if (!_loading && _error == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_offline && _summary.isNotEmpty) ...[
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              Text(
                                  'الفواتير: ${_summary['invoices_count'] ?? 0}'),
                              Text(
                                'المحصل ${formatMoneyShort(financial['paid_usd'] ?? 0, currency: 'USD')}',
                              ),
                              Text(
                                'المتبقي ${formatMoneyShort(financial['outstanding_usd'] ?? 0, currency: 'USD')}',
                              ),
                              Text('جزئية ${financial['partial_count'] ?? 0}'),
                              Text(
                                  'غير مدفوعة ${financial['unpaid_count'] ?? 0}'),
                            ],
                          ),
                          if (sales.isNotEmpty || receipts.isNotEmpty)
                            ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding:
                                  const EdgeInsetsDirectional.only(start: 8),
                              visualDensity: VisualDensity.compact,
                              title: const Text('تفاصيل المبيعات والقبض'),
                              children: [
                                ...sales.entries.map(
                                  (entry) => ListTile(
                                    dense: true,
                                    title: Text('مبيعات ${entry.key}'),
                                    trailing: Text(
                                      (entry.value as num).toStringAsFixed(2),
                                    ),
                                  ),
                                ),
                                ...receipts.entries.map(
                                  (entry) => ListTile(
                                    dense: true,
                                    title: Text('مقبوض ${entry.key}'),
                                    trailing: Text(
                                      (entry.value as num).toStringAsFixed(2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ] else if (!_offline)
                          const Text('الملخص غير متاح'),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth < 380
                                  ? constraints.maxWidth
                                  : 180.0;
                              return Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (_canFilterAllSales)
                                    SizedBox(
                                      width: width,
                                      child: DropdownButtonFormField<String?>(
                                        initialValue: _sellerFilter,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                            labelText: 'المندوب'),
                                        items: [
                                          const DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text('كل المندوبين'),
                                          ),
                                          ..._salespeople.map((seller) =>
                                              DropdownMenuItem<String?>(
                                                value: seller['user_id']
                                                    .toString(),
                                                child: Text(
                                                  seller['full_name']
                                                          ?.toString() ??
                                                      '',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              )),
                                        ],
                                        onChanged: (value) {
                                          setState(() => _sellerFilter = value);
                                          _load();
                                        },
                                      ),
                                    ),
                                  if (_canFilterAllSales &&
                                      widget.customerId == null)
                                    SizedBox(
                                      width: width,
                                      child: DropdownButtonFormField<String?>(
                                        initialValue: _customerFilter,
                                        isExpanded: true,
                                        decoration: const InputDecoration(
                                            labelText: 'الزبون'),
                                        items: [
                                          const DropdownMenuItem<String?>(
                                            value: null,
                                            child: Text('كل الزبائن'),
                                          ),
                                          ..._customers.map((customer) =>
                                              DropdownMenuItem<String?>(
                                                value: customer['customer_id']
                                                    .toString(),
                                                child: Text(
                                                  customer['full_name']
                                                          ?.toString() ??
                                                      '',
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              )),
                                        ],
                                        onChanged: (value) {
                                          setState(
                                              () => _customerFilter = value);
                                          _load();
                                        },
                                      ),
                                    ),
                                  SizedBox(
                                    width: width,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _statusFilter,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                          labelText: 'حالة الفاتورة'),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'all',
                                            child: Text('كل الحالات')),
                                        DropdownMenuItem(
                                            value: 'posted',
                                            child: Text('مرحلة')),
                                        DropdownMenuItem(
                                            value: 'voided',
                                            child: Text('ملغاة')),
                                      ],
                                      onChanged: (value) {
                                        setState(() =>
                                            _statusFilter = value ?? 'all');
                                        _load();
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: width,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _financialFilter,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                          labelText: 'حالة السداد'),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'all',
                                            child: Text('كل السداد')),
                                        DropdownMenuItem(
                                            value: 'unpaid',
                                            child: Text('غير مدفوعة')),
                                        DropdownMenuItem(
                                            value: 'partial',
                                            child: Text('جزئية')),
                                        DropdownMenuItem(
                                            value: 'paid',
                                            child: Text('مسددة')),
                                      ],
                                      onChanged: (value) {
                                        setState(() =>
                                            _financialFilter = value ?? 'all');
                                        _load();
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: width,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _paymentFilter,
                                      isExpanded: true,
                                      decoration: const InputDecoration(
                                          labelText: 'طريقة القبض'),
                                      items: const [
                                        DropdownMenuItem(
                                            value: 'all',
                                            child: Text('كل الطرق')),
                                        DropdownMenuItem(
                                            value: 'cash_syp',
                                            child: Text('نقدي سوري')),
                                        DropdownMenuItem(
                                            value: 'cash_usd',
                                            child: Text('نقدي دولار')),
                                        DropdownMenuItem(
                                            value: 'sham_cash_syp',
                                            child: Text('شام كاش سوري')),
                                        DropdownMenuItem(
                                            value: 'sham_cash_usd',
                                            child: Text('شام كاش دولار')),
                                      ],
                                      onChanged: (value) {
                                        setState(() =>
                                            _paymentFilter = value ?? 'all');
                                        _load();
                                      },
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _selectDateRange,
                                    icon: const Icon(Icons.date_range),
                                    label: Text(_dateRange == null
                                        ? 'الفترة'
                                        : '${_dateRange!.start.toString().substring(0, 10)} – '
                                            '${_dateRange!.end.toString().substring(0, 10)}'),
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
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
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
          ),
          if (_loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
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
              ),
            )
          else if (_invoices.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(_offline
                    ? 'لا توجد فواتير محفوظة تطابق المرشحات؛ قد توجد فواتير أخرى على الخادم.'
                    : 'لا توجد فواتير بعد'),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 88),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
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
                          '${invoice['invoice_number'] ?? invoice['invoice_id']} · '
                          '${formatMoneyShort(invoice['net_total'], currency: invoice['currency']?.toString() ?? 'USD')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${invoice['customer_name'] ?? invoice['buyer_name'] ?? 'زبائن محل'} · '
                          '${invoice['creator_name'] ?? invoice['seller_name'] ?? ''} · '
                          '${invoice['invoice_date'] ?? ''} · '
                          '${_financialStatusName(invoice['financial_status']?.toString())} · '
                          'مدفوع ${formatMoneyShort(invoice['total_paid_usd'] ?? invoice['net_received'] ?? 0, currency: 'USD')} · '
                          'متبقٍ ${formatMoneyShort(invoice['balance_due_usd'] ?? 0, currency: 'USD')}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        minVerticalPadding: 4,
                        contentPadding: const EdgeInsetsDirectional.only(
                          start: 10,
                          end: 8,
                          top: 2,
                          bottom: 2,
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => _showDetails(invoice),
                      ),
                    );
                  },
                  childCount: _invoices.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CollectionLine {
  String method = 'cash_usd';
  final TextEditingController amount = TextEditingController();
  final TextEditingController equivalent = TextEditingController();
  final TextEditingController rate = TextEditingController();
  final TextEditingController reference = TextEditingController();
  final TextEditingController note = TextEditingController();

  _CollectionLine();

  _CollectionLine.fromMap(Map<String, dynamic> row) {
    method = row['method']?.toString() ?? 'cash_usd';
    amount.text = row['amount']?.toString() ?? '';
    equivalent.text = row['equivalent_usd']?.toString() ?? '';
    rate.text = row['exchange_rate']?.toString() ?? '';
    reference.text = row['reference']?.toString() ?? '';
    note.text = row['note']?.toString() ?? '';
  }

  bool get isSyp => method.endsWith('_syp');

  void dispose() {
    amount.dispose();
    equivalent.dispose();
    rate.dispose();
    reference.dispose();
    note.dispose();
  }
}
