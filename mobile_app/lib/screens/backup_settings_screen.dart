import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../app_config.dart';

/// شاشة إعدادات النسخ الاحتياطي
class BackupSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const BackupSettingsScreen({super.key, required this.session});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  bool _autoBackup = true;
  String _backupFrequency = 'daily';
  bool _isBackingUp = false;

  Future<void> _performBackup() async {
    setState(() => _isBackingUp = true);
    try {
      final response = await http.post(
        Uri.parse(AppConfig.baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'action': 'backupData',
          'username': widget.session['username'],
          'token': widget.session['token'],
        }),
      );
      final data = json.decode(response.body);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              data['success'] == true ? 'تم النسخ الاحتياطي بنجاح' : 'فشل النسخ الاحتياطي',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: \$e')),
        );
      }
    } finally {
      setState(() => _isBackingUp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات النسخ الاحتياطي')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('النسخ الاحتياطي التلقائي'),
            subtitle: const Text('تفعيل النسخ الاحتياطي التلقائي للبيانات'),
            value: _autoBackup,
            onChanged: (v) => setState(() => _autoBackup = v),
          ),
          ListTile(
            title: const Text('تكرار النسخ الاحتياطي'),
            subtitle: Text(_getFrequencyText()),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _showFrequencyDialog(),
          ),
          const Divider(),
          ListTile(
            title: const Text('نسخ احتياطي الآن'),
            subtitle: const Text('إنشاء نسخة احتياطية فورية'),
            leading: const Icon(Icons.backup),
            onTap: _isBackingUp ? null : _performBackup,
          ),
          if (_isBackingUp)
            const LinearProgressIndicator(),
        ],
      ),
    );
  }

  String _getFrequencyText() {
    switch (_backupFrequency) {
      case 'daily':
        return 'يومياً';
      case 'weekly':
        return 'أسبوعياً';
      case 'monthly':
        return 'شهرياً';
      default:
        return 'يومياً';
    }
  }

  void _showFrequencyDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تكرار النسخ الاحتياطي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('يومياً'),
              onTap: () {
                setState(() => _backupFrequency = 'daily');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('أسبوعياً'),
              onTap: () {
                setState(() => _backupFrequency = 'weekly');
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: const Text('شهرياً'),
              onTap: () {
                setState(() => _backupFrequency = 'monthly');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
