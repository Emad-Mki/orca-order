import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../main.dart';
import 'homepage_screen.dart';
import 'profile_screen.dart';

/// شاشة الإعدادات
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _csvIdCtrl = TextEditingController();
  bool _loading = false;

  void _updateConfig() async {
    setState(() => _loading = true);
    try {
      final session = context.findAncestorStateOfType<HomePageState>()?.widget.session;
      await ApiService().post({
        'action': 'updateConfig',
        'csv_file_id': _csvIdCtrl.text.trim(),
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _syncNow() async {
    setState(() => _loading = true);
    try {
      final session = context.findAncestorStateOfType<HomePageState>()?.widget.session;
      final res = await ApiService().post({
        'action': 'syncFromDrive',
        'csv_file_id': _csvIdCtrl.text.trim(),
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'تمت المزامنة')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _rebuildImages() async {
    setState(() => _loading = true);
    try {
      final session = context.findAncestorStateOfType<HomePageState>()?.widget.session;
      final res = await ApiService().post({
        'action': 'rebuildImageIndex',
        'username': session?['username'],
        'token': session?['token'],
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'] ?? 'تمت إعادة بناء فهرس الصور بنجاح')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.findAncestorStateOfType<HomePageState>()?.widget.session['role'];
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (role == 'admin') ...[
          const Text('إعدادات المزامنة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _csvIdCtrl,
            decoration: const InputDecoration(
              labelText: 'معرف ملف CSV من Google Drive',
              border: OutlineInputBorder(),
              helperText: 'اتركه فارغاً لاستخدام المعرف الافتراضي',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _updateConfig,
                  icon: const Icon(Icons.save),
                  label: const Text('حفظ الإعدادات'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loading ? null : _syncNow,
                  icon: const Icon(Icons.sync),
                  label: const Text('مزامنة البيانات'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _loading ? null : _rebuildImages,
              icon: const Icon(Icons.image_search),
              label: const Text('تحديث فهرس الصور'),
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
            ),
          ),
          const Divider(height: 40),
        ],
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: const Text('الملف الشخصي'),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())),
        ),
        SwitchListTile(
          value: Theme.of(context).brightness == Brightness.dark,
          onChanged: (val) {
            context.findAncestorStateOfType<OrcaAppState>()?.toggleTheme();
          },
          title: const Text('الوضع الليلي'),
          secondary: const Icon(Icons.dark_mode_outlined),
        ),
      ],
    );
  }
}

// ProfileScreen moved to profile_screen.dart
