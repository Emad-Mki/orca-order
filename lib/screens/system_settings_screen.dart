import 'package:flutter/material.dart';

import 'sales_settings_screen.dart';
import 'settings_screen.dart';
import 'contact_settings_screen.dart';
import '../utils/permissions.dart';

/// Entry point for settings that already have a real implementation.
class SystemSettingsScreen extends StatelessWidget {
  const SystemSettingsScreen({super.key, required this.session});

  final Map<String, dynamic> session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات النظام')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (PermissionHelper.fromString(session['role']?.toString() ?? '') ==
              AppRole.admin)
            Card(
              child: ListTile(
                leading: const Icon(Icons.contact_phone_outlined),
                title: const Text('التواصل ومحتوى التطبيق'),
                subtitle: const Text(
                  'قنوات التواصل وساعات الدعم والشروط والخصوصية والأسئلة الشائعة',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ContactSettingsScreen(session: session),
                  ),
                ),
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.currency_exchange),
              title: const Text('المبيعات والعملات'),
              subtitle: const Text('سعر الصرف الافتراضي ودقة عرض العملات'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SalesSettingsScreen(),
                ),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('الجهاز والحساب والمزامنة'),
              subtitle: const Text('المظهر والإشعارات والتحديث والملف الشخصي'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(session: session),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
