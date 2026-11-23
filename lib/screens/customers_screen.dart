import 'dart:async';

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/permissions.dart';
import '../widgets/order_skeleton.dart';
import '../widgets/sales_customer_form.dart';
import 'customer_statement_screen.dart';
import 'new_order_screen.dart';
import 'orders_screen.dart';
import 'sales_invoices_screen.dart';

typedef CustomerPageLoader = Future<Map<String, dynamic>> Function({
  required int limit,
  required int offset,
  required String query,
  required String status,
});

class CustomersScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  final CustomerPageLoader? pageLoader;
  const CustomersScreen({super.key, required this.session, this.pageLoader});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;
  String? _error;
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _searchDebounce;
  String _statusFilter = 'all';
  Future<void>? _fetchRequest;
  int _revision = 0;
  int? _nextOffset;
  SalesCustomerRequest? _pendingCustomer;
  bool _creatingCustomer = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _fetchCustomers();
  }

  void _onScroll() {
    if (_scroll.position.extentAfter < 300 &&
        _nextOffset != null &&
        _error == null &&
        _fetchRequest == null &&
        !(_searchDebounce?.isActive ?? false)) {
      _loadPage(_revision, _nextOffset!);
    }
  }

  void _filtersChanged() {
    _revision++;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) _fetchCustomers();
    });
    setState(() {});
  }

  Future<void> _fetchCustomers() async {
    _searchDebounce?.cancel();
    final revision = ++_revision;
    final active = _fetchRequest;
    if (active != null) await active;
    if (identical(_fetchRequest, active)) _fetchRequest = null;
    if (!mounted || revision != _revision) return;
    await _loadPage(revision, 0);
  }

  Future<void> _loadPage(int revision, int offset) {
    if (_fetchRequest != null) return _fetchRequest!;
    final request = _performFetchCustomers(revision, offset);
    _fetchRequest = request;
    return request.whenComplete(() {
      if (identical(_fetchRequest, request)) _fetchRequest = null;
    });
  }

  Future<void> _performFetchCustomers(int revision, int offset) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = ApiService().token;
      final loader = widget.pageLoader ?? ApiService().customers.getCustomers;
      final data = await loader(
        limit: 50,
        offset: offset,
        query: _search.text.trim(),
        status: _statusFilter,
      );
      if (token != ApiService().token) {
        throw StateError('تغير الحساب أثناء تحميل العملاء');
      }
      final list = data['customers'];
      if (list is! List) {
        throw const FormatException('استجابة العملاء لا تحتوي على قائمة صالحة');
      }
      final customers = list.map((c) {
        if (c is! Map) throw const FormatException('بيانات عميل غير صالحة');
        return Map<String, dynamic>.from(c);
      }).toList();
      final next = data['next_offset'];
      if (next != null && (next is! int || next <= offset)) {
        throw const FormatException('مؤشر صفحة العملاء غير صالح');
      }
      if (mounted && revision == _revision) {
        setState(() {
          if (offset == 0) {
            _customers = customers;
          } else {
            final ids =
                _customers.map((c) => c['customer_id'].toString()).toSet();
            _customers.addAll(
                customers.where((c) => ids.add(c['customer_id'].toString())));
          }
          _nextOffset = next as int?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && revision == _revision) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _openCustomer(Map<String, dynamic> customer) async {
    final id = customer['customer_id']?.toString() ?? '';
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('معرف العميل غير متوفر')),
      );
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CustomerDetails(
          session: widget.session,
          customer: customer,
          onUpdated: _fetchCustomers,
        ),
      ),
    );
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
      await _pendingCustomer!.submit();
      _pendingCustomer = null;
      await _fetchCustomers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء السجل التجاري')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'تعذر تأكيد إنشاء العميل: $error. أعد المحاولة للعملية نفسها.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _creatingCustomer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _search.text.trim().toLowerCase();
    final filtered = _customers.where((raw) {
      final c = raw;
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
      appBar: AppBar(
        title: const Text('العملاء'),
        actions: [
          if ({AppRole.admin, AppRole.manager, AppRole.accountant}.contains(
              PermissionHelper.fromString(
                  widget.session['role']?.toString() ?? '')))
            IconButton(
              tooltip: _pendingCustomer == null
                  ? 'إضافة زبون تجاري'
                  : 'إعادة محاولة إضافة الزبون',
              onPressed: _creatingCustomer ? null : _createCustomer,
              icon: const Icon(Icons.person_add_alt_1),
            ),
        ],
      ),
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
                    onChanged: (_) => _filtersChanged(),
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
                    onChanged: (value) {
                      _statusFilter = value ?? 'all';
                      _filtersChanged();
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading && _customers.isNotEmpty)
            const LinearProgressIndicator(minHeight: 2),
          if (_error != null && _customers.isNotEmpty)
            MaterialBanner(
              content: Text('تعذر تحديث العملاء: $_error'),
              actions: [
                TextButton(
                    onPressed: _fetchCustomers,
                    child: const Text('إعادة المحاولة'))
              ],
            ),
          Expanded(
            child: _isLoading && _customers.isEmpty
                ? const OrderListSkeleton()
                : _error != null && _customers.isEmpty
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
                              controller: _scroll,
                              padding: const EdgeInsets.all(8),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final c = filtered[index];
                                final balance = c['balance'] is num
                                    ? (c['balance'] as num).toDouble()
                                    : double.tryParse(
                                        c['balance']?.toString() ?? '');
                                final review =
                                    c['needs_financial_review'] == true;
                                final loginTypes = c['login_customer_types'];
                                final role = PermissionHelper.fromString(
                                    widget.session['role']?.toString() ?? '');
                                return Card(
                                  child: ListTile(
                                    onTap: () => _openCustomer(c),
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          theme.colorScheme.primaryContainer,
                                      child: Icon(
                                        Icons.person,
                                        color: theme
                                            .colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    title: Text(
                                        c['full_name']?.toString() ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${c['company_name'] ?? ''}\n${c['phone'] ?? ''} | ${c['province'] ?? ''}\nالحالة: ${c['status'] ?? '-'}'),
                                        if ({
                                              AppRole.admin,
                                              AppRole.manager,
                                              AppRole.accountant
                                            }.contains(role) &&
                                            loginTypes is List &&
                                            loginTypes.isNotEmpty)
                                          Text(
                                              'نوع حساب الدخول المرتبط: ${loginTypes.join('، ')}'),
                                        const SizedBox(height: 4),
                                        if (PermissionHelper.hasPermission(
                                            PermissionHelper.fromString(widget
                                                    .session['role']
                                                    ?.toString() ??
                                                ''),
                                            AppPermission.viewAllStatements))
                                          Text(
                                            review || balance == null
                                                ? 'الرصيد يحتاج إلى مراجعة'
                                                : balance > 0
                                                    ? 'مدين: \$${balance.abs()}'
                                                    : balance < 0
                                                        ? 'دائن: \$${balance.abs()}'
                                                        : 'الرصيد: \$0',
                                            style: TextStyle(
                                              color: (balance ?? 0) > 0
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
                                        if (PermissionHelper.hasPermission(
                                                PermissionHelper.fromString(
                                                    widget.session['role']
                                                            ?.toString() ??
                                                        ''),
                                                AppPermission.createOrder) &&
                                            c['status']
                                                    ?.toString()
                                                    .toLowerCase() !=
                                                'inactive')
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
                                        if (PermissionHelper.hasPermission(
                                            PermissionHelper.fromString(widget
                                                    .session['role']
                                                    ?.toString() ??
                                                ''),
                                            AppPermission.viewAllStatements))
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
                                                                    'customer_id']
                                                                ?.toString()))),
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

class _CustomerDetails extends StatelessWidget {
  final Map<String, dynamic> session;
  final Map<String, dynamic> customer;
  final Future<void> Function() onUpdated;

  const _CustomerDetails({
    required this.session,
    required this.customer,
    required this.onUpdated,
  });

  Future<void> _edit(BuildContext context) async {
    final fields = <String, TextEditingController>{
      for (final field in [
        'full_name',
        'company_name',
        'phone',
        'province',
        'address',
        'notes'
      ])
        field: TextEditingController(text: customer[field]?.toString() ?? ''),
    };
    var saving = false;
    final route = DialogRoute<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: const Text('تعديل السجل التجاري'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final entry in {
                    'full_name': 'الاسم',
                    'company_name': 'الشركة',
                    'phone': 'الهاتف',
                    'province': 'المدينة',
                    'address': 'العنوان',
                    'notes': 'الملاحظات',
                  }.entries)
                    TextField(
                      controller: fields[entry.key],
                      decoration: InputDecoration(labelText: entry.value),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (fields['full_name']!.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('اسم العميل مطلوب')),
                          );
                          return;
                        }
                        setDialogState(() => saving = true);
                        try {
                          await ApiService().customers.updateCustomer(
                            customer['customer_id'].toString(),
                            {
                              for (final entry in fields.entries)
                                entry.key: entry.value.text.trim()
                            },
                          );
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (error) {
                          if (!context.mounted) return;
                          setDialogState(() => saving = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('تعذر تعديل العميل: $error')),
                          );
                        }
                      },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
    Navigator.of(context, rootNavigator: true).push(route);
    final updated = await route.completed;
    for (final controller in fields.values) {
      controller.dispose();
    }
    if (updated == true && context.mounted) {
      Navigator.pop(context);
      await onUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = customer['customer_id'].toString();
    final role = PermissionHelper.fromString(session['role']?.toString() ?? '');
    final active = customer['status']?.toString().toLowerCase() != 'inactive';
    return Scaffold(
      appBar:
          AppBar(title: Text(customer['full_name']?.toString() ?? 'العميل')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('سجل عميل تجاري',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Text('الشركة: ${customer['company_name'] ?? '-'}'),
          Text('الهاتف: ${customer['phone'] ?? '-'}'),
          Text('المدينة: ${customer['province'] ?? '-'}'),
          Text('العنوان: ${customer['address'] ?? '-'}'),
          Text('الحالة: ${customer['status'] ?? '-'}'),
          const Divider(height: 32),
          if ({AppRole.admin, AppRole.manager, AppRole.accountant}
                  .contains(role) &&
              id != 'CUS-SHOP')
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('تعديل السجل التجاري'),
              onTap: () => _edit(context),
            ),
          if (PermissionHelper.hasPermission(role, AppPermission.viewAllOrders))
            ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: const Text('طلبات العميل'),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OrdersScreen(session: session, customerId: id),
                  )),
            ),
          if ({AppRole.admin, AppRole.manager, AppRole.accountant}
              .contains(role))
            ListTile(
              leading: const Icon(Icons.receipt_long),
              title: const Text('فواتير المبيعات'),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SalesInvoicesScreen(session: session, customerId: id),
                  )),
            ),
          if (PermissionHelper.hasPermission(
              role, AppPermission.viewAllStatements))
            ListTile(
              leading: const Icon(Icons.account_balance_wallet_outlined),
              title: const Text('كشف الحساب'),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerStatementScreen(customerId: id),
                  )),
            ),
          if (active &&
              PermissionHelper.hasPermission(role, AppPermission.createOrder))
            ListTile(
              leading: const Icon(Icons.add_shopping_cart),
              title: const Text('طلب جديد للعميل'),
              onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        NewOrderScreen(session: session, customer: customer),
                  )),
            ),
        ],
      ),
    );
  }
}
