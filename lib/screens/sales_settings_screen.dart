import 'dart:convert';

import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../settings/setting_definitions.dart';
import '../utils/guarded_navigation.dart';

class SalesSettingsScreen extends StatefulWidget {
  const SalesSettingsScreen({
    super.key,
    this.loadSettings,
    this.saveSettings,
  });

  final Future<Map<String, dynamic>> Function()? loadSettings;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
      saveSettings;

  @override
  State<SalesSettingsScreen> createState() => _SalesSettingsScreenState();
}

class _SalesSettingsScreenState extends State<SalesSettingsScreen> {
  final _rate = TextEditingController();
  final _usdDecimals = TextEditingController();
  final _sypDecimals = TextEditingController();
  String? _invoiceCurrency;
  String? _shamCurrency;
  String? _productCurrency;
  bool _loading = true;
  bool _saving = false;
  bool _allowPop = false;
  String? _error;
  Map<String, dynamic>? _loadedSettings;
  String? _baseline;

  Map<String, dynamic> get _formValues => {
        'invoice_currency': _invoiceCurrency,
        'sham_cash_currency': _shamCurrency,
        'default_product_currency': _productCurrency,
        'rate_syp_per_usd': _rate.text.trim(),
        'usd_decimals': _usdDecimals.text.trim(),
        'syp_decimals': _sypDecimals.text.trim(),
      };

  bool get _dirty => _baseline != null && jsonEncode(_formValues) != _baseline;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _rate.dispose();
    _usdDecimals.dispose();
    _sypDecimals.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response =
          await (widget.loadSettings ?? ApiService().sales.getSettings)();
      final settings = _extractSettings(response);
      if (!mounted) return;
      setState(() {
        _invoiceCurrency =
            settings['invoice_currency']?.toString().toUpperCase() == 'USD'
                ? 'USD'
                : null;
        _shamCurrency = _validCurrency(settings['sham_cash_currency']);
        _productCurrency = _validCurrency(settings['default_product_currency']);
        _rate.text = settings['rate_syp_per_usd']?.toString() ?? '';
        _usdDecimals.text = settings['usd_decimals']?.toString() ?? '';
        _sypDecimals.text = settings['syp_decimals']?.toString() ?? '';
        _loadedSettings = settings;
        _baseline = jsonEncode(_formValues);
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

  Map<String, dynamic> _extractSettings(Map<String, dynamic> response) {
    final settings = response['settings'];
    if (settings is Map) return Map<String, dynamic>.from(settings);

    final data = response['data'];
    if (data is Map) {
      final nestedSettings = data['settings'];
      if (nestedSettings is Map) {
        return Map<String, dynamic>.from(nestedSettings);
      }
      return Map<String, dynamic>.from(data);
    }

    throw StateError('استجابة إعدادات البيع غير صالحة');
  }

  String? _validCurrency(dynamic value) {
    final normalized = value?.toString().trim().toUpperCase();
    return normalized == 'USD' || normalized == 'SYP' ? normalized : null;
  }

  String _errorMessage(Object error) {
    if (error is ApiException) return error.message;
    if (error is StateError) return error.message.toString();
    return error.toString().replaceFirst('Bad state: ', '');
  }

  Future<void> _save() async {
    final usd = int.tryParse(_usdDecimals.text.trim());
    final syp = int.tryParse(_sypDecimals.text.trim());
    final rateText = _rate.text.trim();
    final rate = rateText.isEmpty ? null : double.tryParse(rateText);
    if (!SettingDefinitions.invoiceCurrency.isValid(_invoiceCurrency) ||
        !SettingDefinitions.shamCurrency.isValid(_shamCurrency) ||
        !SettingDefinitions.productCurrency.isValid(_productCurrency) ||
        !SettingDefinitions.usdDecimals.isValid(usd) ||
        !SettingDefinitions.sypDecimals.isValid(syp) ||
        (rateText.isNotEmpty && rate == null) ||
        !SettingDefinitions.exchangeRate.isValid(rate)) {
      setState(() => _error = 'أكمل إعداد العملات والدقة، وتحقق من سعر الصرف.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إعدادات البيع'),
        content: const Text(
          'تُستخدم الإعدادات الجديدة للعمليات الجديدة ولا تعدّل العمليات السابقة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد الحفظ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await (widget.saveSettings ?? ApiService().sales.saveSettings)({
        'invoice_currency': _invoiceCurrency,
        'sham_cash_currency': _shamCurrency,
        'default_product_currency': _productCurrency,
        'rate_syp_per_usd': rateText,
        'usd_decimals': usd,
        'syp_decimals': syp,
        'expected_settings': _loadedSettings,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ إعدادات البيع')),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() => _error = _errorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('تعديلات غير محفوظة'),
            content: const Text('احفظ التعديلات أولاً أو تجاهلها للمتابعة.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('متابعة التحرير'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('تجاهل التعديلات'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _reload() async {
    if (await _confirmDiscard() && mounted) await _load();
  }

  Future<void> _back() async {
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    if (_saving || !await _confirmDiscard() || !mounted) return;
    popAfterGuard(context, allowPop: () => setState(() => _allowPop = true));
  }

  Widget _currencyField({
    required String label,
    required String? value,
    required ValueChanged<String?> onChanged,
    bool usdOnly = false,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: usdOnly && value != 'USD' ? null : value,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem(value: 'USD', child: Text('دولار أمريكي (USD)')),
        if (!usdOnly)
          const DropdownMenuItem(value: 'SYP', child: Text('ليرة سورية (SYP)')),
      ],
      onChanged: _saving ? null : onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('إعدادات البيع والعملات')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadedSettings == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error ?? 'تعذر تحميل الإعدادات'),
                        TextButton(
                            onPressed: _load,
                            child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        'حدد العملة صراحةً. سعر الصرف باتجاه ليرة سورية لكل دولار. '
                        'اتركه فارغًا إن لم تعتمد تحويلًا بين العملتين.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (_dirty) const Text('توجد تعديلات غير محفوظة'),
                      const SizedBox(height: 16),
                      _currencyField(
                        label: 'عملة الفاتورة',
                        value: _invoiceCurrency,
                        onChanged: (value) =>
                            setState(() => _invoiceCurrency = value),
                        usdOnly: true,
                      ),
                      const SizedBox(height: 12),
                      _currencyField(
                        label: 'عملة أسعار المنتجات التي لا تحمل عملة',
                        value: _productCurrency,
                        onChanged: (value) =>
                            setState(() => _productCurrency = value),
                      ),
                      const SizedBox(height: 12),
                      _currencyField(
                        label: 'عملة شام كاش',
                        value: _shamCurrency,
                        onChanged: (value) =>
                            setState(() => _shamCurrency = value),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _rate,
                        onChanged: (_) => setState(() {}),
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'سعر الصرف (SYP لكل 1 USD)',
                          helperText: 'مطلوب عند اختلاف عملة الدفع عن الفاتورة',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _usdDecimals,
                              onChanged: (_) => setState(() {}),
                              enabled: !_saving,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'منازل USD (0–4)'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _sypDecimals,
                              onChanged: (_) => setState(() {}),
                              enabled: !_saving,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                  labelText: 'منازل SYP (0–4)'),
                            ),
                          ),
                        ],
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label:
                            Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الإعدادات'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _saving ? null : _reload,
                        child: const Text('إعادة تحميل من الخادم'),
                      ),
                    ],
                  ),
      ),
    );
  }
}
