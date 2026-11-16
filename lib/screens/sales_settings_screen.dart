import 'package:flutter/material.dart';
import '../services/api_service.dart';

class SalesSettingsScreen extends StatefulWidget {
  const SalesSettingsScreen({super.key});

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
  String? _error;

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
      final response = await ApiService().sales.getSettings();
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
    if (_invoiceCurrency == null ||
        _shamCurrency == null ||
        _productCurrency == null ||
        usd == null ||
        syp == null ||
        usd < 0 ||
        usd > 4 ||
        syp < 0 ||
        syp > 4 ||
        (rateText.isNotEmpty &&
            (rate == null || !rate.isFinite || rate <= 0))) {
      setState(() => _error = 'أكمل إعداد العملات والدقة، وتحقق من سعر الصرف.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService().sales.saveSettings({
        'invoice_currency': _invoiceCurrency,
        'sham_cash_currency': _shamCurrency,
        'default_product_currency': _productCurrency,
        'rate_syp_per_usd': rateText,
        'usd_decimals': usd,
        'syp_decimals': syp,
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
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات البيع والعملات')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'حدد العملة صراحةً. سعر الصرف باتجاه ليرة سورية لكل دولار. '
                  'اتركه فارغًا إن لم تعتمد تحويلًا بين العملتين.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
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
                  onChanged: (value) => setState(() => _shamCurrency = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _rate,
                  enabled: !_saving,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'منازل USD (0–4)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _sypDecimals,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'منازل SYP (0–4)'),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الإعدادات'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _saving ? null : _load,
                  child: const Text('إعادة تحميل من الخادم'),
                ),
              ],
            ),
    );
  }
}
