import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserManagementScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const UserManagementScreen({super.key, required this.session});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  static const _roles = <String>[
    'customer',
    'salesperson',
    'warehouse',
    'accountant',
    'manager',
    'admin',
  ];
  static const _customerTypes = <String>[
    'زبون جملة',
    'زبون نصف جملة',
    'زبون مفرق',
    'زبون موزع',
  ];

  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String? _error;
  String _filterRole = 'all';
  String _filterStatus = 'all';
  String _filterCustomerType = 'all';
  String _filterCity = 'all';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await ApiService().post({'action': 'users_list'});
      final rows = response['users'];
      if (rows is! List) throw StateError('استجابة قائمة الحسابات غير صالحة');
      if (!mounted) return;
      setState(() {
        _users = rows
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showUserDialog([Map<String, dynamic>? user]) async {
    final name = TextEditingController(text: user?['full_name']?.toString());
    final username = TextEditingController(text: user?['username']?.toString());
    final phone = TextEditingController(text: user?['phone']?.toString());
    final city = TextEditingController(text: user?['city']?.toString());
    final address = TextEditingController(text: user?['address']?.toString());
    final email = TextEditingController(text: user?['email']?.toString());
    final notes =
        TextEditingController(text: user?['internal_notes']?.toString());
    final cashBox =
        TextEditingController(text: user?['cash_box_id']?.toString());
    var role = user?['role']?.toString() ?? 'customer';
    var customerType = user?['customer_type']?.toString() ?? '';
    var active = user?['status'] == 'active';
    var canViewWholesalePrice =
        user?['can_view_wholesale_price'] == true ||
            user?['can_view_wholesale_price'] == 1 ||
            user?['can_view_wholesale_price'] == '1' ||
            user?['can_view_wholesale_price'] == 'true';
    final canManageWholesalePrice =
        widget.session['role']?.toString().toLowerCase() == 'admin';
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(user == null ? 'إضافة حساب' : 'تعديل الحساب'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: username,
                    textDirection: TextDirection.ltr,
                    decoration: const InputDecoration(labelText: 'اسم الدخول'),
                  ),
                  TextField(
                    controller: name,
                    decoration:
                        const InputDecoration(labelText: 'الاسم الكامل'),
                  ),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'الهاتف'),
                  ),
                  TextField(
                    controller: city,
                    decoration: const InputDecoration(labelText: 'المدينة'),
                  ),
                  TextField(
                    controller: address,
                    decoration:
                        const InputDecoration(labelText: 'العنوان (اختياري)'),
                  ),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني (اختياري)'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'الدور'),
                    items: _roles
                        .map((value) => DropdownMenuItem(
                              value: value,
                              child: Text(_roleName(value)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => role = value);
                      }
                    },
                  ),
                  if (role == 'customer')
                    DropdownButtonFormField<String>(
                      initialValue: _customerTypes.contains(customerType)
                          ? customerType
                          : null,
                      decoration:
                          const InputDecoration(labelText: 'نوع الزبون *'),
                      items: _customerTypes
                          .map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => customerType = value);
                        }
                      },
                    ),
                  if (role == 'salesperson')
                    TextField(
                      controller: cashBox,
                      decoration: const InputDecoration(
                        labelText: 'معرف صندوق التحصيل',
                        helperText:
                            'تُخصم مبيعات المندوب من المخزون العام الموحد.',
                      ),
                    ),
                  TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'ملاحظات داخلية'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('الحساب مفعل'),
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                  ),
                  if (canManageWholesalePrice)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('السماح برؤية سعر الجملة'),
                      subtitle: const Text(
                        'يظهر سعر الجملة في بطاقة المنتج لهذا الحساب.',
                      ),
                      value: canViewWholesalePrice,
                      onChanged: (value) => setDialogState(
                        () => canViewWholesalePrice = value,
                      ),
                    ),
                  if (user == null)
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        'كلمة المرور المؤقتة: 654321 — يجب تغييرها عند أول دخول',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      if (name.text.trim().isEmpty ||
                          username.text.trim().isEmpty ||
                          (role == 'customer' &&
                              !_customerTypes.contains(customerType))) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('أكمل الاسم واسم الدخول ونوع الزبون'),
                          ),
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        await ApiService().post({
                          'action': user == null
                              ? 'user_create'
                              : 'user_update_admin',
                          if (user != null) 'user_id': user['user_id'],
                          'username': username.text.trim(),
                          'full_name': name.text.trim(),
                          'phone': phone.text.trim(),
                          'city': city.text.trim(),
                          'address': address.text.trim(),
                          'email': email.text.trim(),
                          'internal_notes': notes.text.trim(),
                          'role': role,
                          'customer_type':
                              role == 'customer' ? customerType : '',
                          'status': active ? 'active' : 'inactive',
                          if (canManageWholesalePrice)
                            'can_view_wholesale_price': canViewWholesalePrice,
                          if (role == 'salesperson')
                            'cash_box_id': cashBox.text.trim(),
                        });
                        if (!mounted || !dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        await _fetchUsers();
                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('تم حفظ الحساب')),
                          );
                        }
                      } catch (error) {
                        if (dialogContext.mounted) {
                          setDialogState(() => saving = false);
                        }
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('تعذر الحفظ: $error')),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    username.dispose();
    phone.dispose();
    city.dispose();
    address.dispose();
    email.dispose();
    notes.dispose();
    cashBox.dispose();
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تعيين كلمة المرور'),
        content: Text(
          'ستُعاد كلمة مرور ${user['full_name']} إلى 654321، '
          'وسيُطلب منه تغييرها عند الدخول التالي وتُبطل جلساته الحالية.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService().post({
        'action': 'user_reset_password',
        'user_id': user['user_id'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تمت إعادة التعيين إلى 654321 وإبطال الجلسات'),
          ),
        );
        await _fetchUsers();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذرت إعادة التعيين: $error')),
        );
      }
    }
  }

  String _roleName(String role) => switch (role) {
        'admin' => 'مدير عام',
        'manager' => 'مدير',
        'accountant' => 'محاسب',
        'warehouse' => 'مدير مستودع',
        'salesperson' => 'مندوب مبيعات',
        'customer' => 'زبون',
        _ => role,
      };

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final filteredUsers = _users.where((user) {
      final matchesRole = _filterRole == 'all' || user['role'] == _filterRole;
      final matchesStatus =
          _filterStatus == 'all' || user['status'] == _filterStatus;
      final matchesCustomerType = _filterCustomerType == 'all' ||
          user['customer_type'] == _filterCustomerType;
      final matchesCity = _filterCity == 'all' || user['city'] == _filterCity;
      final matchesQuery = normalizedQuery.isEmpty ||
          [
            user['full_name'],
            user['username'],
            user['phone'],
            user['city'],
            user['customer_type'],
          ].join(' ').toLowerCase().contains(normalizedQuery);
      return matchesRole &&
          matchesStatus &&
          matchesCustomerType &&
          matchesCity &&
          matchesQuery;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الحسابات'),
        actions: [
          IconButton(
            onPressed: _fetchUsers,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserDialog(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('إضافة حساب'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('تعذر تحميل الحسابات: $_error'),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _fetchUsers,
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          TextField(
                            onChanged: (value) =>
                                setState(() => _query = value),
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText:
                                  'بحث بالاسم أو الدخول أو الهاتف أو المدينة',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _filterRole,
                            decoration: const InputDecoration(
                              labelText: 'تصفية الدور',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('كل الأدوار'),
                              ),
                              ..._roles.map((value) => DropdownMenuItem(
                                    value: value,
                                    child: Text(_roleName(value)),
                                  )),
                            ],
                            onChanged: (value) => setState(
                              () => _filterRole = value ?? 'all',
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _filterStatus,
                            decoration: const InputDecoration(
                                labelText: 'تصفية الحالة'),
                            items: const [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text('كل الحالات'),
                              ),
                              DropdownMenuItem(
                                value: 'active',
                                child: Text('مفعل'),
                              ),
                              DropdownMenuItem(
                                value: 'inactive',
                                child: Text('غير مفعل'),
                              ),
                            ],
                            onChanged: (value) => setState(
                              () => _filterStatus = value ?? 'all',
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _filterCustomerType,
                            decoration: const InputDecoration(
                              labelText: 'تصفية نوع الزبون',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('كل الأنواع'),
                              ),
                              ..._customerTypes.map(
                                (value) => DropdownMenuItem(
                                  value: value,
                                  child: Text(value),
                                ),
                              ),
                            ],
                            onChanged: (value) => setState(
                              () => _filterCustomerType = value ?? 'all',
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _filterCity,
                            decoration: const InputDecoration(
                                labelText: 'تصفية المدينة'),
                            items: [
                              const DropdownMenuItem(
                                value: 'all',
                                child: Text('كل المدن'),
                              ),
                              ..._users
                                  .map((user) => user['city']?.toString() ?? '')
                                  .where((city) => city.isNotEmpty)
                                  .toSet()
                                  .toList()
                                  .map((city) => DropdownMenuItem(
                                        value: city,
                                        child: Text(city),
                                      )),
                            ],
                            onChanged: (value) =>
                                setState(() => _filterCity = value ?? 'all'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filteredUsers.isEmpty
                          ? const Center(child: Text('لا توجد حسابات مطابقة'))
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 88),
                              itemCount: filteredUsers.length,
                              itemBuilder: (context, index) {
                                final user = filteredUsers[index];
                                final active = user['status'] == 'active';
                                final theme = Theme.of(context);
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: active
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme
                                              .surfaceContainerHighest,
                                      child: Icon(
                                        Icons.person,
                                        color: active
                                            ? theme.colorScheme.onPrimary
                                            : theme
                                                .colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    title: Text(
                                      user['full_name']?.toString() ?? '',
                                    ),
                                    subtitle: Text(
                                      '${user['username']} · '
                                      '${_roleName(user['role']?.toString() ?? '')}'
                                      '${user['customer_type'] == null || user['customer_type'] == '' ? '' : ' · ${user['customer_type']}'}'
                                      '${user['city'] == null || user['city'] == '' ? '' : ' · ${user['city']}'}',
                                    ),
                                    trailing: Wrap(
                                      spacing: 0,
                                      children: [
                                        IconButton(
                                          tooltip: 'تعديل',
                                          onPressed: () =>
                                              _showUserDialog(user),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        IconButton(
                                          tooltip: 'إعادة تعيين كلمة المرور',
                                          onPressed: () => _resetPassword(user),
                                          icon: const Icon(Icons.lock_reset),
                                        ),
                                      ],
                                    ),
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
