import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SystemSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const SystemSettingsScreen({super.key, required this.session});
  
  @override
  State<SystemSettingsScreen> createState() => _SystemSettingsScreenState();
}

class _SystemSettingsScreenState extends State<SystemSettingsScreen> {
  final _companyArCtrl = TextEditingController();
  final _companyEnCtrl = TextEditingController();
  final _logoUrlCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController();
  final _lowStockCtrl = TextEditingController();
  final _invoiceFormatCtrl = TextEditingController();
  String _defaultCurrency = 'USD';
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().post({
        'action': 'getSystemSettings',
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        final settings = data['settings'] ?? {};
        setState(() {
          _companyArCtrl.text = settings['company_name_ar'] ?? 'أوركا أوردر';
          _companyEnCtrl.text = settings['company_name_en'] ?? 'ORCA ORDER';
          _logoUrlCtrl.text = settings['logo_url'] ?? '';
          _defaultCurrency = settings['default_currency'] ?? 'USD';
          _creditLimitCtrl.text = (settings['credit_limit'] ?? 0).toString();
          _lowStockCtrl.text = (settings['low_stock_threshold'] ?? 10).toString();
          _invoiceFormatCtrl.text = settings['invoice_number_format'] ?? 'INV-{YYYY}-{####}';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  void _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      await ApiService().post({
        'action': 'saveSystemSettings',
        'company_name_ar': _companyArCtrl.text.trim(),
        'company_name_en': _companyEnCtrl.text.trim(),
        'logo_url': _logoUrlCtrl.text.trim(),
        'default_currency': _defaultCurrency,
        'credit_limit': double.tryParse(_creditLimitCtrl.text) ?? 0,
        'low_stock_threshold': double.tryParse(_lowStockCtrl.text) ?? 10,
        'invoice_number_format': _invoiceFormatCtrl.text.trim(),
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات بنجاح')));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(controller: _companyArCtrl, decoration: const InputDecoration(labelText: 'اسم الشركة (عربي)', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        TextField(controller: _companyEnCtrl, decoration: const InputDecoration(labelText: 'اسم الشركة (إنكليزي)', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        TextField(controller: _logoUrlCtrl, decoration: const InputDecoration(labelText: 'رابط الشعار (URL)', border: OutlineInputBorder(), helperText: 'رابط صورة من Google Drive أو أي مصدر آخر')),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _defaultCurrency,
          decoration: const InputDecoration(labelText: 'العملة الافتراضية', border: OutlineInputBorder()),
          items: ['USD', 'SYP'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
          onChanged: (v) => setState(() => _defaultCurrency = v!),
        ),
        const SizedBox(height: 16),
        TextField(controller: _creditLimitCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حد الرصيد المسموح للعميل', border: OutlineInputBorder(), helperText: 'عند تجاوزه يتم إيقاف البيع')),
        const SizedBox(height: 16),
        TextField(controller: _lowStockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'حد تنبيه نقص المخزون', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        TextField(controller: _invoiceFormatCtrl, decoration: const InputDecoration(labelText: 'تنسيق أرقام الفواتير', border: OutlineInputBorder(), helperText: 'مثال: INV-{YYYY}-{####}')),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _saveSettings,
            icon: const Icon(Icons.save),
            label: const Text('حفظ الإعدادات'),
          ),
        ),
      ],
    );
  }
}
