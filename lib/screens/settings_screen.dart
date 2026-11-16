import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../utils/permissions.dart';
import '../widgets/app_update_settings_tile.dart';
import 'profile_screen.dart';
import 'sales_settings_screen.dart';

/// شاشة الإعدادات
class SettingsScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const SettingsScreen({super.key, required this.session});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _csvIdCtrl = TextEditingController();
  bool _loading = false;
  bool _savingTheme = false;

  @override
  void dispose() {
    _csvIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _updateConfig() async {
    setState(() => _loading = true);
    try {
      await ApiService().post({
        'action': 'updateConfig',
        'csv_file_id': _csvIdCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تعذر حفظ الإعدادات: $error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncNow() async {
    setState(() => _loading = true);
    try {
      final response = await ApiService().post({
        'action': 'syncFromDrive',
        'csv_file_id': _csvIdCtrl.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'تمت المزامنة')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تعذرت المزامنة: $error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _rebuildImages() async {
    setState(() => _loading = true);
    try {
      final response = await ApiService().post(
        {'action': 'rebuildImageIndex'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'تمت إعادة بناء فهرس الصور بنجاح',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث فهرس الصور: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeThemeMode(ThemeMode mode) async {
    final appState = context.findAncestorStateOfType<OrcaAppState>();
    if (appState == null) return;
    setState(() => _savingTheme = true);
    try {
      await appState.setThemeMode(mode);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حفظ تفضيل المظهر: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _savingTheme = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ApiService().currentUser ?? widget.session;
    final userName = (session['full_name'] ??
            session['name'] ??
            session['username'] ??
            'مستخدم')
        .toString();
    final role = PermissionHelper.fromString(
      session['role']?.toString() ?? 'user',
    );
    final canManageSystem = role == AppRole.admin;
    final canManageSalesSettings =
        role == AppRole.admin || role == AppRole.accountant;
    final canSyncData =
        PermissionHelper.hasPermission(role, AppPermission.viewSettings);

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppUpdateSettingsTile(),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(userName.isEmpty ? 'م' : userName.substring(0, 1)),
              ),
              title: Text(userName),
              subtitle: Text(PermissionHelper.getRoleNameAr(role)),
            ),
          ),
          const SizedBox(height: 16),
          Text('تفضيلات الجهاز',
              style: Theme.of(context).textTheme.titleMedium),
          DropdownButtonFormField<ThemeMode>(
            initialValue:
                context.findAncestorStateOfType<OrcaAppState>()?.themeMode ??
                    ThemeMode.system,
            decoration: const InputDecoration(labelText: 'مظهر التطبيق'),
            items: const [
              DropdownMenuItem(
                value: ThemeMode.system,
                child: Text('اتباع إعداد الجهاز'),
              ),
              DropdownMenuItem(
                value: ThemeMode.light,
                child: Text('فاتح'),
              ),
              DropdownMenuItem(
                value: ThemeMode.dark,
                child: Text('داكن'),
              ),
            ],
            onChanged: _savingTheme || _loading
                ? null
                : (mode) {
                    if (mode != null) _changeThemeMode(mode);
                  },
          ),
          if (_savingTheme) const LinearProgressIndicator(),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('الملف الشخصي'),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProfileScreen(session: session),
              ),
            ),
          ),
          if (canManageSalesSettings)
            ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: const Text('إعدادات البيع والعملات'),
              subtitle: const Text('عملة الفاتورة وأسعار الصرف والدقة'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SalesSettingsScreen(),
                ),
              ),
            ),
          if (canManageSystem || canSyncData) ...[
            const Divider(height: 32),
            Text(canManageSystem ? 'إعدادات النظام' : 'مزامنة البيانات',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (canManageSystem) ...[
              TextField(
                controller: _csvIdCtrl,
                enabled: !_loading,
                decoration: const InputDecoration(
                  labelText: 'معرف ملف CSV من Google Drive',
                  border: OutlineInputBorder(),
                  helperText: 'اتركه فارغاً للاحتفاظ بالمعرف الحالي',
                ),
              ),
              const SizedBox(height: 16),
            ],
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canManageSystem)
                  FilledButton.icon(
                    onPressed: _loading ? null : _updateConfig,
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ الإعدادات'),
                  ),
                if (canSyncData)
                  FilledButton.tonalIcon(
                    onPressed: _loading ? null : _syncNow,
                    icon: const Icon(Icons.sync),
                    label: const Text('مزامنة البيانات'),
                  ),
                if (canManageSystem)
                  OutlinedButton.icon(
                    onPressed: _loading ? null : _rebuildImages,
                    icon: const Icon(Icons.image_search),
                    label: const Text('تحديث فهرس الصور'),
                  ),
              ],
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ],
      ),
    );
  }
}
