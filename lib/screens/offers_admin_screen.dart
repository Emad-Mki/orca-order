import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/products_provider.dart';
import '../services/api_service.dart';
import '../services/offers_change_notifier.dart';
import '../utils/permissions.dart';
import '../widgets/product_image_widget.dart';

typedef OfferRequest = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> body);

class OffersAdminScreen extends StatefulWidget {
  const OffersAdminScreen({super.key, required this.session, this.request});

  final Map<String, dynamic> session;
  final OfferRequest? request;

  @override
  State<OffersAdminScreen> createState() => _OffersAdminScreenState();
}

class _OffersAdminScreenState extends State<OffersAdminScreen> {
  List<Map<String, dynamic>> _offers = [];
  bool _loading = false;
  bool _busy = false;
  bool _dialogOpen = false;
  String? _error;
  String _query = '';
  String _status = '';
  String? _serverTime;

  bool get _authorized {
    final session = ApiService().currentUser ?? widget.session;
    return const {
      AppRole.admin,
      AppRole.manager,
      AppRole.accountant
    }.contains(PermissionHelper.fromString(session['role']?.toString() ?? ''));
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> body) =>
      widget.request?.call(body) ?? ApiService().post(body, useCache: false);

  @override
  void initState() {
    super.initState();
    if (_authorized) {
      _load();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _authorized) {
          context.read<ProductsProvider>().fetchProducts();
        }
      });
    }
  }

  Future<void> _load() async {
    if (_loading || !_authorized) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _post({'action': 'offer_list', 'manage': true});
      final items = response['offers'];
      if (items is! List || items.any((item) => item is! Map)) {
        throw const FormatException('قائمة العروض غير صالحة');
      }
      if (!mounted) return;
      setState(() {
        _offers = items.map((item) => Map<String, dynamic>.from(item)).toList();
        if (!_offers.any((offer) => offer['status'] == _status)) _status = '';
        _serverTime = response['server_time']?.toString();
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذر تحميل العروض: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _mutate(Map<String, dynamic> body) async {
    if (_busy || _loading || !_authorized) return;
    setState(() => _busy = true);
    try {
      await _post(body);
      offersRevision.value++;
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_error == null
            ? 'تم حفظ التغيير'
            : 'تم التغيير، لكن تعذر تحديث القائمة. حاول التحديث.'),
      ));
    } catch (e) {
      if (mounted) {
        final uncertain = e is ApiException && e.transportFailure;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(uncertain
              ? 'تعذر تأكيد نتيجة العملية: $e. حدّث القائمة قبل إعادة المحاولة.'
              : 'تعذر تنفيذ العملية: $e'),
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _edit(
      [Map<String, dynamic>? offer, bool duplicate = false]) async {
    if (_busy || _loading || _dialogOpen || !_authorized) return;
    _dialogOpen = true;
    Map<String, dynamic>? result;
    try {
      result = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => _OfferEditor(offer: offer, duplicate: duplicate),
        ),
      );
    } finally {
      _dialogOpen = false;
    }
    if (result != null && mounted) {
      await _mutate({'action': 'offer_save', 'offer': result});
    }
  }

  Future<void> _archive(Map<String, dynamic> offer) async {
    if (_busy || _loading || _dialogOpen || !_authorized) return;
    _dialogOpen = true;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('أرشفة العرض؟'),
          content:
              Text('سيتم أرشفة "${offer['title'] ?? ''}". هل تريد المتابعة؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('أرشفة')),
          ],
        ),
      );
    } finally {
      _dialogOpen = false;
    }
    if (confirmed == true && mounted) {
      await _mutate({
        'action': 'offer_archive',
        'offer_id': offer['offer_id'],
        'revision': offer['revision'],
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_authorized) {
      return const Scaffold(
          body: Center(child: Text('غير مصرح بإدارة العروض')));
    }
    final products = context.watch<ProductsProvider>().allProducts;
    final statuses = _offers
        .map((offer) => offer['status']?.toString() ?? '')
        .where((status) => status.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final filtered = _offers.where((offer) {
      final query = _query.trim().toLowerCase();
      final matches = [
        offer['title'],
        offer['product_code'],
        ...products
            .where((p) => p.code == offer['product_code']?.toString())
            .map((p) => p.name),
      ].any((value) => value?.toString().toLowerCase().contains(query) == true);
      return matches && (_status.isEmpty || offer['status'] == _status);
    }).toList();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PopScope(
        canPop: !_busy,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('إدارة العروض'),
            actions: [
              IconButton(
                tooltip: 'تحديث',
                onPressed: _loading || _busy ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _loading || _busy ? null : () => _edit(),
            icon: const Icon(Icons.add),
            label: const Text('عرض جديد'),
          ),
          body: Column(children: [
            if (_loading || _busy) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'بحث بالعنوان أو المنتج أو الرمز',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
                DropdownButtonFormField<String>(
                  initialValue: statuses.contains(_status) ? _status : '',
                  decoration: const InputDecoration(labelText: 'الحالة'),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('كل الحالات')),
                    ...statuses.map((status) => DropdownMenuItem(
                        value: status, child: Text(_statusLabel(status)))),
                  ],
                  onChanged: (value) => setState(() => _status = value ?? ''),
                ),
                if (_serverTime != null)
                  Text('وقت الخادم: ${_displayDate(_serverTime)}',
                      style: Theme.of(context).textTheme.bodySmall),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ]),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(_loading ? 'جارٍ التحميل' : 'لا توجد عروض'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final offer = filtered[index];
                        final matching = products.where(
                            (p) => p.code == offer['product_code']?.toString());
                        final product =
                            matching.isEmpty ? null : matching.first;
                        return Card(
                          child: ListTile(
                            leading: ProductImageWidget(
                                imageUrl: product?.imageUrl,
                                width: 52,
                                height: 52),
                            title: Text(offer['title']?.toString() ?? ''),
                            subtitle: Text(
                                '${product?.name ?? offer['product_code'] ?? ''}\n'
                                '${offer['offer_price'] ?? ''} ${offer['currency'] ?? ''} / ${offer['unit'] ?? ''} • ${_statusLabel(offer['status']?.toString() ?? '')}'),
                            isThreeLine: true,
                            onTap: () => _preview(context, offer, product),
                            trailing: PopupMenuButton<String>(
                              enabled: !_busy && !_loading,
                              tooltip: 'خيارات العرض',
                              onSelected: (value) {
                                if (value == 'edit') _edit(offer);
                                if (value == 'copy') _edit(offer, true);
                                if (value == 'archive') _archive(offer);
                              },
                              itemBuilder: (_) => [
                                if (offer['status']?.toString().toLowerCase() !=
                                    'archived')
                                  const PopupMenuItem(
                                      value: 'edit', child: Text('تعديل')),
                                const PopupMenuItem(
                                    value: 'copy',
                                    child: Text('نسخ كعرض غير مفعّل')),
                                if (offer['status']?.toString().toLowerCase() !=
                                    'archived')
                                  const PopupMenuItem(
                                      value: 'archive', child: Text('أرشفة')),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

String _statusLabel(String status) => switch (status.toLowerCase()) {
      'active' => 'نشط',
      'scheduled' => 'مجدول',
      'upcoming' => 'قادم',
      'expired' => 'منتهي',
      'inactive' => 'غير مفعّل',
      'disabled' => 'غير مفعّل',
      'archived' => 'مؤرشف',
      '' => 'غير محدد',
      _ => status,
    };

String _displayDate(dynamic value) {
  final text = value?.toString() ?? '';
  if (text.isEmpty) return 'غير محدد';
  return DateTime.tryParse(text)?.toLocal().toString().substring(0, 16) ?? text;
}

bool _enabled(dynamic value) =>
    value == true ||
    value == 1 ||
    value?.toString().toLowerCase() == 'true' ||
    value == '1';

List<String> _validUnits(Product product) {
  if (product.hasConflictingUnits) return [];
  return product.availableUnits.where((unit) {
    final factor = product.factorForUnit(unit);
    return factor != null && factor.isFinite && factor > 0;
  }).toList();
}

void _preview(
    BuildContext context, Map<String, dynamic> offer, Product? product) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(offer['title']?.toString() ?? 'معاينة العرض'),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
              child: ProductImageWidget(
                  imageUrl: product?.imageUrl, width: 120, height: 120)),
          Text('${product?.name ?? ''} (${offer['product_code'] ?? ''})'),
          Text(
              'السعر السابق: ${offer['old_price'] ?? '—'} ${offer['currency'] ?? ''} / ${offer['unit'] ?? ''}'),
          Text(
              'سعر العرض: ${offer['offer_price'] ?? ''} ${offer['currency'] ?? ''} / ${offer['unit'] ?? ''}'),
          Text(
              'الحد الأدنى: ${offer['min_quantity'] ?? ''} ${offer['unit'] ?? ''}'),
          Text('من: ${_displayDate(offer['starts_at'])}'),
          Text('إلى: ${_displayDate(offer['ends_at'])}'),
          Text('الحالة: ${_statusLabel(offer['status']?.toString() ?? '')}'),
          Text(
              'التفعيل: ${_enabled(offer['enabled']) ? 'مفعّل' : 'غير مفعّل'}'),
          if ((offer['note']?.toString() ?? '').isNotEmpty)
            Text('ملاحظة: ${offer['note']}'),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))
      ],
    ),
  );
}

class _OfferEditor extends StatefulWidget {
  const _OfferEditor({this.offer, required this.duplicate});
  final Map<String, dynamic>? offer;
  final bool duplicate;

  @override
  State<_OfferEditor> createState() => _OfferEditorState();
}

class _OfferEditorState extends State<_OfferEditor> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _oldPrice = TextEditingController();
  final _offerPrice = TextEditingController();
  final _quantity = TextEditingController();
  final _note = TextEditingController();
  final _sort = TextEditingController();
  Product? _product;
  String? _unit;
  String _currency = 'USD';
  bool _isEnabled = false;
  DateTime? _start;
  DateTime? _end;
  bool _invalidStart = false;
  bool _invalidEnd = false;

  @override
  void initState() {
    super.initState();
    final offer = widget.offer ?? {};
    _title.text = offer['title']?.toString() ?? '';
    _oldPrice.text = offer['old_price']?.toString() ?? '';
    _offerPrice.text = offer['offer_price']?.toString() ?? '';
    _quantity.text = offer['min_quantity']?.toString() ?? '1';
    _note.text = offer['note']?.toString() ?? '';
    _sort.text = offer['sort_order']?.toString() ?? '0';
    _currency = offer['currency']?.toString().trim() ?? 'USD';
    if (_currency.isEmpty) _currency = 'USD';
    _isEnabled = !widget.duplicate && _enabled(offer['enabled']);
    final start = offer['starts_at']?.toString() ?? '';
    final end = offer['ends_at']?.toString() ?? '';
    _start = DateTime.tryParse(start)?.toLocal();
    _end = DateTime.tryParse(end)?.toLocal();
    _invalidStart = start.isNotEmpty && _start == null;
    _invalidEnd = end.isNotEmpty && _end == null;
    final products = context.read<ProductsProvider>().allProducts;
    final matches =
        products.where((p) => p.code == offer['product_code']?.toString());
    if (matches.isNotEmpty) {
      _product = matches.first;
      final unit = offer['unit']?.toString();
      if (_validUnits(_product!).contains(unit)) _unit = unit;
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _oldPrice,
      _offerPrice,
      _quantity,
      _note,
      _sort
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _selectProduct(Product product) {
    setState(() {
      _product = product;
      final units = _validUnits(product);
      _unit = units.isEmpty ? null : units.first;
      _currency = product.currency.trim().isEmpty ? 'USD' : product.currency;
      _oldPrice.text =
          _unit == null ? '' : (product.priceForUnit(_unit!)?.toString() ?? '');
      if (_title.text.trim().isEmpty) _title.text = product.name;
    });
  }

  Future<void> _pickProduct() async {
    final product = await showDialog<Product>(
      context: context,
      builder: (_) => const _ProductPicker(),
    );
    if (product != null && mounted) _selectProduct(product);
  }

  Future<void> _pickDate(bool start) async {
    final existing = start ? _start : _end;
    final now = DateTime.now();
    final initial = existing ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(initial.year < 2000 ? initial.year : 2000),
      lastDate: DateTime(initial.year > 2100 ? initial.year : 2100, 12, 31),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    setState(() {
      final value =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (start) {
        _start = value;
        _invalidStart = false;
      } else {
        _end = value;
        _invalidEnd = false;
      }
    });
  }

  String? _number(String? value, {bool positive = false}) {
    final text = value?.trim() ?? '';
    final number = double.tryParse(text);
    if (number == null ||
        !number.isFinite ||
        (positive ? number <= 0 : number < 0)) {
      return positive ? 'أدخل رقماً أكبر من صفر' : 'أدخل رقماً غير سالب';
    }
    return null;
  }

  Map<String, dynamic>? _buildOffer() {
    if (!_form.currentState!.validate()) return null;
    if (_product == null ||
        _unit == null ||
        _invalidStart ||
        _invalidEnd ||
        (_start != null && _end != null && !_end!.isAfter(_start!))) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'اختر منتجاً ووحدة صالحين وتأكد من صحة الجدول وأن النهاية بعد البداية'),
      ));
      return null;
    }
    final result = <String, dynamic>{
      if (widget.offer != null && !widget.duplicate) ...{
        'offer_id': widget.offer!['offer_id'],
        'revision': widget.offer!['revision'],
      },
      'product_code': _product!.code,
      'title': _title.text.trim(),
      'unit': _unit,
      'old_price': double.parse(_oldPrice.text.trim()),
      'offer_price': double.parse(_offerPrice.text.trim()),
      'currency': _currency,
      'min_quantity': double.parse(_quantity.text.trim()),
      'starts_at': _start?.toUtc().toIso8601String(),
      'ends_at': _end?.toUtc().toIso8601String(),
      'note': _note.text.trim(),
      'enabled': _isEnabled,
      'sort_order': int.parse(_sort.text.trim()),
    };
    return result;
  }

  void _submit() {
    final result = _buildOffer();
    if (result != null) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final products = context.watch<ProductsProvider>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
            title: Text(widget.duplicate
                ? 'نسخ العرض'
                : widget.offer == null
                    ? 'عرض جديد'
                    : 'تعديل العرض')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            if (widget.duplicate) const Text('تُحفظ النسخة غير مفعّلة.'),
            if (products.errorMessage != null)
              Text('تعذر تحميل المنتجات: ${products.errorMessage}'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ProductImageWidget(
                  imageUrl: _product?.imageUrl, width: 60, height: 60),
              title: Text(_product?.name ?? 'اختر منتجاً من الكتالوج'),
              subtitle: Text(_product?.code ??
                  (widget.offer?['product_code']?.toString() ?? '')),
              trailing: const Icon(Icons.search),
              onTap: _pickProduct,
            ),
            if (_product != null && _validUnits(_product!).isEmpty)
              const Text(
                  'وحدات المنتج غير صالحة أو متعارضة؛ يرجى تحديث الكتالوج.'),
            DropdownButtonFormField<String>(
              key: ValueKey('${_product?.code}:$_unit'),
              initialValue: _unit,
              decoration: const InputDecoration(labelText: 'الوحدة'),
              items: (_product == null ? <String>[] : _validUnits(_product!))
                  .map((unit) =>
                      DropdownMenuItem(value: unit, child: Text(unit)))
                  .toList(),
              onChanged: (unit) => setState(() {
                _unit = unit;
                _oldPrice.text = unit == null
                    ? ''
                    : (_product?.priceForUnit(unit)?.toString() ?? '');
              }),
              validator: (value) => value == null ? 'اختر وحدة' : null,
            ),
            TextFormField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'عنوان العرض'),
                validator: (value) =>
                    value?.trim().isNotEmpty == true ? null : 'العنوان مطلوب'),
            TextFormField(
                controller: _oldPrice,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText:
                        'السعر السابق لكل ${_unit ?? 'وحدة'} ($_currency)',
                    helperText: 'يُقترح سعر وحدة المنتج ويمكن تعديله'),
                validator: _number),
            TextFormField(
                controller: _offerPrice,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'سعر العرض لكل ${_unit ?? 'وحدة'} ($_currency)'),
                validator: _number),
            TextFormField(
                controller: _quantity,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'الحد الأدنى للكمية (${_unit ?? 'وحدة'})'),
                validator: (value) => _number(value, positive: true)),
            TextFormField(
                controller: _sort,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'ترتيب العرض'),
                validator: (value) => int.tryParse(value?.trim() ?? '') == null
                    ? 'أدخل عدداً صحيحاً'
                    : null),
            TextFormField(
                controller: _note,
                decoration: const InputDecoration(labelText: 'ملاحظة'),
                maxLines: 2),
            SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('مفعّل'),
                value: _isEnabled,
                onChanged: widget.duplicate
                    ? null
                    : (value) => setState(() => _isEnabled = value)),
            for (final start in [true, false])
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(start
                    ? 'بداية العرض (التوقيت المحلي)'
                    : 'نهاية العرض (التوقيت المحلي)'),
                subtitle: Text((start ? _invalidStart : _invalidEnd)
                    ? 'تاريخ غير صالح، اختر تاريخاً جديداً'
                    : _displayDate(start
                        ? _start?.toIso8601String()
                        : _end?.toIso8601String())),
                onTap: () => _pickDate(start),
                trailing: IconButton(
                  tooltip: 'مسح التاريخ',
                  icon: const Icon(Icons.clear),
                  onPressed: () => setState(() {
                    if (start) {
                      _start = null;
                      _invalidStart = false;
                    } else {
                      _end = null;
                      _invalidEnd = false;
                    }
                  }),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () {
                final offer = _buildOffer();
                if (offer != null) _preview(context, offer, _product);
              },
              child: const Text('معاينة العرض'),
            ),
            FilledButton(onPressed: _submit, child: const Text('حفظ العرض')),
          ]),
        ),
      ),
    );
  }
}

class _ProductPicker extends StatefulWidget {
  const _ProductPicker();
  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductsProvider>();
    final query = _query.trim().toLowerCase();
    final products = provider.allProducts
        .where((product) =>
            product.code.trim().isNotEmpty &&
            (product.name.toLowerCase().contains(query) ||
                product.code.toLowerCase().contains(query) ||
                product.oem.toLowerCase().contains(query)))
        .toList();
    return AlertDialog(
      title: const Text('اختيار منتج'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              autofocus: true,
              decoration:
                  const InputDecoration(labelText: 'بحث بالاسم أو الرمز'),
              onChanged: (value) => setState(() => _query = value)),
          if (provider.isLoading) const LinearProgressIndicator(),
          if (provider.errorMessage != null)
            Text('تعذر تحميل المنتجات: ${provider.errorMessage}'),
          if (provider.errorMessage != null)
            TextButton(
                onPressed: () => provider.fetchProducts(),
                child: const Text('إعادة المحاولة')),
          Flexible(
            child: products.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16), child: Text('لا توجد منتجات'))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      return ListTile(
                        leading: ProductImageWidget(
                            imageUrl: product.imageUrl, width: 48, height: 48),
                        title: Text(product.name),
                        subtitle: Text(product.code),
                        onTap: () => Navigator.pop(context, product),
                      );
                    },
                  ),
          ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('إلغاء'))
      ],
    );
  }
}
