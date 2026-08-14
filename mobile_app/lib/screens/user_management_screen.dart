import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserManagementScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const UserManagementScreen({super.key, required this.session});
  
  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<dynamic> _users = [];
  bool _isLoading = true;
  String _filterRole = 'all';
  
  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }
  
  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().post({
        'action': 'getUsers',
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        setState(() {
          _users = data['users'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _showUserDialog([dynamic user]) {
    final nameCtrl = TextEditingController(text: user?['full_name'] ?? '');
    final usernameCtrl = TextEditingController(text: user?['username'] ?? '');
    final phoneCtrl = TextEditingController(text: user?['phone'] ?? '');
    final passCtrl = TextEditingController();
    String selectedRole = user?['role'] ?? 'customer';
    bool isActive = user?['is_active'] == true || user?['is_active'] == '1';
    
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(user == null ? 'إضافة مستخدم جديد' : 'تعديل المستخدم'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: usernameCtrl, decoration: const InputDecoration(labelText: 'اسم المستخدم', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'الهاتف', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              if (user == null)
                TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الأولية', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'الدور', border: OutlineInputBorder()),
                items: ['admin', 'accountant', 'warehouse', 'customer'].map((r) => DropdownMenuItem(value: r, child: Text(_getRoleName(r)))).toList(),
                onChanged: (v) => selectedRole = v!,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('نشط'),
                value: isActive,
                onChanged: (v) => setState(() => isActive = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              try {
                await ApiService().post({
                  'action': user == null ? 'createUser' : 'updateUser',
                  'username': usernameCtrl.text.trim(),
                  'full_name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                  'role': selectedRole,
                  'is_active': isActive ? '1' : '0',
                  if (user == null && passCtrl.text.isNotEmpty) 'password': passCtrl.text,
                  'target_username': user?['username'],
                  'session_username': widget.session['username'],
                  'token': widget.session['token'],
                });
                if (mounted) {
                  Navigator.pop(context);
                  _fetchUsers();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم الحفظ بنجاح')));
                }
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }
  
  String _getRoleName(String role) {
    switch (role) {
      case 'admin': return 'مدير';
      case 'accountant': return 'محاسب';
      case 'warehouse': return 'مستودع';
      case 'customer': return 'عميل';
      default: return role;
    }
  }
  
  void _resetPassword(String username) async {
    final newPass = DateTime.now().millisecondsSinceEpoch.toString().substring(5, 11);
    try {
      await ApiService().post({
        'action': 'resetPassword',
        'target_username': username,
        'new_password': newPass,
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تم إعادة تعيين كلمة المرور'),
            content: Text('كلمة المرور الجديدة: $newPass\n\nيرجى إبلاغ المستخدم بها وتغييرها عند أول دخول'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('موافق'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    final filteredUsers = _filterRole == 'all' 
        ? _users 
        : _users.where((u) => u['role'] == _filterRole).toList();
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('تصفية حسب الدور: '),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  value: _filterRole,
                  isExpanded: true,
                  items: [('all', 'الكل'), ('admin', 'مدير'), ('accountant', 'محاسب'), ('warehouse', 'مستودع'), ('customer', 'عميل')]
                      .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2))).toList(),
                  onChanged: (v) => setState(() => _filterRole = v!),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredUsers.length,
            itemBuilder: (_, i) {
              final u = filteredUsers[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: u['is_active'] == true || u['is_active'] == '1' ? Colors.green : Colors.grey,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(u['full_name'] ?? ''),
                  subtitle: Text('${u['username']} - ${_getRoleName(u['role'])}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit), onPressed: () => _showUserDialog(u)),
                      IconButton(icon: const Icon(Icons.lock_reset), onPressed: () => _resetPassword(u['username'])),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// --- إعدادات النظام ---
