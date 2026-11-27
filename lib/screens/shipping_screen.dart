import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../app_config.dart';
import '../services/api_service.dart';
import '../services/shipment_draft_store.dart';
import '../utils/permissions.dart';
import '../utils/shipment_summary.dart';

class ShippingScreen extends StatefulWidget {
  const ShippingScreen({super.key});

  @override
  State<ShippingScreen> createState() => _ShippingScreenState();
}

class _ShippingScreenState extends State<ShippingScreen> {
  final _api = ApiService();
  final _shipmentDraftStore = const ShipmentDraftStore();
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _shipments = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;
  String? _statusFilter;
  String? _carrierFilter;
  DateTime? _dateFilter;
  Timer? _draftSaveTimer;
  bool _draftSaveWarningShown = false;

  String get _role => PermissionHelper.fromString(
        _api.currentUser?['role']?.toString() ?? '',
      ).name;
  bool get _canManage =>
      const {'admin', 'manager', 'accountant', 'warehouse'}.contains(_role);
  bool get _canUpdateStatus =>
      const {'admin', 'manager', 'warehouse'}.contains(_role);
  bool get _isAdmin => _role == 'admin';
  String? get _draftScope {
    final user = _api.currentUser;
    final userId =
        (user?['user_id'] ?? user?['username'] ?? '').toString().trim();
    if (userId.isEmpty) return null;
    return '${AppConfig.environmentName}:${AppConfig.apiUrl}:$userId';
  }

  @override
  void initState() {
    super.initState();
    _fetchShipments();
  }

  @override
  void dispose() {
    _draftSaveTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchShipments() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final data = await _api.post({'action': 'getShipments'});
      final values = data['shipments'];
      if (values is! List) {
        throw const FormatException('استجابة قائمة الشحنات غير صالحة');
      }
      if (!mounted) return;
      setState(() {
        _shipments = values
            .whereType<Map>()
            .map((shipment) => Map<String, dynamic>.from(shipment))
            .toList();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateShipmentStatus(
      Map<String, dynamic> shipment, String newStatus) async {
    if (!_canUpdateStatus) return;
    if (_isLocked(shipment) && !_isAdmin) {
      _showMessage('لا يمكن تعديل شحنة مسلّمة أو مقفلة');
      return;
    }
    try {
      await _api.post({
        'action': 'updateShipmentStatus',
        'shipmentId': shipment['shipment_id'],
        'status': newStatus,
      });
      if (!mounted) return;
      _showMessage('تم تحديث حالة الشحنة');
      await _fetchShipments();
    } catch (error) {
      if (mounted) _showMessage('تعذر تحديث الحالة: $error');
    }
  }

  Future<void> _showShipmentEditor({Map<String, dynamic>? shipment}) async {
    if (!_canManage || _isSaving) return;
    final editing = shipment != null;
    final locked = editing && _isLocked(shipment);
    if (locked && !_isAdmin) {
      _showMessage('تعديل الشحنة المسلّمة أو المقفلة متاح للمدير العام فقط');
      return;
    }
    final draftScope = editing ? null : _draftScope;
    Map<String, dynamic>? draft;
    if (draftScope != null) {
      Map<String, dynamic>? savedDraft;
      try {
        savedDraft = await _shipmentDraftStore.load(draftScope);
      } catch (error) {
        if (!mounted) return;
        final discardCorruptDraft = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
                  title: const Text('مسودة الشحنة غير صالحة'),
                  content: Text('تعذر قراءة المسودة المحفوظة: $error'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('حذف المسودة وبدء جديد'),
                    ),
                  ],
                ));
        if (!mounted || discardCorruptDraft != true) return;
        try {
          await _shipmentDraftStore.clear(draftScope);
        } catch (clearError) {
          if (mounted) {
            _showMessage('تعذر حذف المسودة غير الصالحة: $clearError');
          }
          return;
        }
      }
      if (savedDraft != null) {
        if (!mounted) return;
        final restoreDraft = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('استعادة مسودة الشحنة؟'),
            content:
                const Text('توجد مسودة محفوظة لهذا الحساب. هل تريد استعادتها؟'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('بدء شحنة جديدة'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('استعادة المسودة'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (restoreDraft == true) {
          draft = savedDraft;
        } else {
          try {
            await _shipmentDraftStore.clear(draftScope);
          } catch (error) {
            _showMessage('تعذر حذف المسودة السابقة: $error');
            return;
          }
        }
      }
    }
    final orderController = TextEditingController(
        text: draft?['order_id']?.toString() ??
            shipment?['order_number']?.toString() ??
            shipment?['order_id']?.toString() ??
            shipment?['invoice_no']?.toString() ??
            shipment?['invoice_id']?.toString() ??
            '');
    final carrierController = TextEditingController(
        text: draft?['carrier']?.toString() ??
            shipment?['carrier']?.toString() ??
            '');
    final trackingController = TextEditingController(
        text: draft?['tracking_no']?.toString() ??
            shipment?['tracking_no']?.toString() ??
            '');
    final destinationController = TextEditingController(
        text: draft?['province']?.toString() ??
            shipment?['province']?.toString() ??
            '');
    final notesController = TextEditingController(
        text:
            draft?['note']?.toString() ?? shipment?['note']?.toString() ?? '');
    final deliveryController = TextEditingController(
        text: draft?['delivery_method']?.toString() ??
            shipment?['delivery_method']?.toString() ??
            'شحن');
    final weightController = TextEditingController(
        text: draft?['weight_kg']?.toString() ??
            shipment?['weight_kg']?.toString() ??
            '');
    final dimensionsController = TextEditingController(
        text: draft?['dimensions']?.toString() ??
            shipment?['dimensions']?.toString() ??
            '');
    final types = ShipmentSummary.packageTypes(draft ?? shipment ?? {});
    final cartonController =
        TextEditingController(text: _typeCount(types, 'carton').toString());
    final bagController =
        TextEditingController(text: _typeCount(types, 'bag').toString());
    final customController = TextEditingController(text: _customLabel(types));
    final customCountController =
        TextEditingController(text: _typeCount(types, 'custom').toString());
    if (editing && types.isEmpty && ShipmentSummary.total(shipment) > 0) {
      customController.text = 'غير مصنف';
      customCountController.text = ShipmentSummary.total(shipment).toString();
    }
    DateTime? shippingDate = DateTime.tryParse(
          draft?['shipping_date']?.toString() ??
              shipment?['shipping_date']?.toString() ??
              '',
        ) ??
        DateTime.now();
    final clientRequestId = draft?['client_request_id']?.toString() ??
        'shipment-${_api.currentUser?['user_id'] ?? 'user'}-${DateTime.now().microsecondsSinceEpoch}';
    final formKey = GlobalKey<FormState>();
    var saving = false;
    String? formError;
    String? draftClearError;
    String? localDraftWarning;
    var draftWrites = Future<String?>.value();
    Map<String, dynamic> draftSnapshot() => {
          'order_id': orderController.text.trim(),
          'delivery_method': deliveryController.text.trim(),
          'carrier': carrierController.text.trim(),
          'tracking_no': trackingController.text.trim(),
          'province': destinationController.text.trim(),
          'shipping_date': shippingDate?.toIso8601String() ?? '',
          'package_types': [
            if (_readCount(cartonController) > 0)
              {
                'type': 'carton',
                'label': 'كرتونة',
                'count': _readCount(cartonController)
              },
            if (_readCount(bagController) > 0)
              {
                'type': 'bag',
                'label': 'كيس',
                'count': _readCount(bagController)
              },
            if (_readCount(customCountController) > 0)
              {
                'type': 'custom',
                'label': customController.text.trim(),
                'count': _readCount(customCountController)
              },
          ],
          'weight_kg': weightController.text.trim(),
          'dimensions': dimensionsController.text.trim(),
          'note': notesController.text.trim(),
          'client_request_id': clientRequestId,
        };
    Future<String?> persistDraft() async {
      if (editing || draftScope == null) return null;
      final snapshot = draftSnapshot();
      final previousWrites = draftWrites;
      final nextWrite = previousWrites.then((_) async {
        try {
          final hasContent = [
                snapshot['order_id'],
                snapshot['carrier'],
                snapshot['tracking_no'],
                snapshot['province'],
                snapshot['note'],
                snapshot['weight_kg'],
                snapshot['dimensions'],
                customController.text.trim(),
              ].any((value) => value?.toString().trim().isNotEmpty == true) ||
              (snapshot['package_types'] as List).isNotEmpty;
          if (!hasContent) {
            await _shipmentDraftStore.clear(draftScope);
            return null;
          }
          await _shipmentDraftStore.save(draftScope, snapshot);
          return null;
        } catch (error) {
          return error.toString();
        }
      });
      draftWrites = nextWrite;
      return nextWrite;
    }

    void scheduleDraftSave() {
      if (editing || draftScope == null) return;
      _draftSaveTimer?.cancel();
      _draftSaveTimer = Timer(const Duration(milliseconds: 350), () async {
        final error = await persistDraft();
        if (error != null && mounted && !_draftSaveWarningShown) {
          _draftSaveWarningShown = true;
          localDraftWarning = error;
          _showMessage('تعذر حفظ المسودة على الجهاز: $error');
        }
      });
    }

    if (!editing && draftScope != null) {
      _draftSaveWarningShown = false;
      for (final controller in [
        orderController,
        carrierController,
        trackingController,
        destinationController,
        notesController,
        deliveryController,
        weightController,
        dimensionsController,
        cartonController,
        bagController,
        customController,
        customCountController,
      ]) {
        controller.addListener(scheduleDraftSave);
      }
    }
    if (!mounted) return;
    final accepted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final preview = ShipmentSummary.format({
            'package_types': [
              if (_readCount(cartonController) > 0)
                {
                  'type': 'carton',
                  'label': 'كرتونة',
                  'count': _readCount(cartonController)
                },
              if (_readCount(bagController) > 0)
                {
                  'type': 'bag',
                  'label': 'كيس',
                  'count': _readCount(bagController)
                },
              if (_readCount(customCountController) > 0)
                {
                  'type': 'custom',
                  'label': customController.text.trim(),
                  'count': _readCount(customCountController)
                },
            ],
          });
          return PopScope(
            canPop: !saving,
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        editing ? 'تعديل بيانات الشحنة' : 'إنشاء شحنة',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: orderController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'رقم الطلب أو الفاتورة *',
                          helperText:
                              'أدخل رقم الطلب أو رقم الفاتورة المرتبطة به',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'رقم الطلب مطلوب'
                                : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: deliveryController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'طريقة الشحن / السائق',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: carrierController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'شركة الشحن',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: trackingController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'رقم التتبع',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: destinationController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'وجهة التسليم',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('تاريخ الشحن'),
                        subtitle: Text(_dateLabel(shippingDate!)),
                        onTap: () async {
                          final selected = await showDatePicker(
                            context: context,
                            initialDate: shippingDate!,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (selected != null) {
                            setSheetState(() => shippingDate = selected);
                            scheduleDraftSave();
                          }
                        },
                      ),
                      const Divider(),
                      Text('الطرود',
                          style: Theme.of(context).textTheme.titleMedium),
                      _counterRow(
                        context,
                        label: 'كرتونة',
                        controller: cartonController,
                        onChanged: () => setSheetState(() {}),
                      ),
                      _counterRow(
                        context,
                        label: 'كيس',
                        controller: bagController,
                        onChanged: () => setSheetState(() {}),
                      ),
                      TextFormField(
                        controller: customController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'نوع آخر (اختياري)',
                          hintText: 'مثال: لفة',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      _counterRow(
                        context,
                        label: 'عدد النوع الآخر',
                        controller: customCountController,
                        onChanged: () => setSheetState(() {}),
                        validator: (value) {
                          final count = int.tryParse(value?.trim() ?? '');
                          if (count == null || count < 0) {
                            return 'أدخل عددًا صحيحًا غير سالب';
                          }
                          if (count > 0 &&
                              customController.text.trim().isEmpty) {
                            return 'اكتب اسم النوع الآخر';
                          }
                          return null;
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          preview,
                          style: Theme.of(context).textTheme.titleSmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: weightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'الوزن (كغ) - اختياري',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return null;
                                }
                                final number = double.tryParse(value.trim());
                                return number == null ||
                                        !number.isFinite ||
                                        number <= 0
                                    ? 'أدخل وزنًا موجبًا'
                                    : null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextFormField(
                              controller: dimensionsController,
                              decoration: const InputDecoration(
                                labelText: 'الحجم - اختياري',
                                hintText: 'الطول × العرض × الارتفاع',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'ملاحظات',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      if (formError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          formError!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: saving
                                  ? null
                                  : () => Navigator.pop(sheetContext, false),
                              child: const Text('إلغاء'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      if (!(formKey.currentState?.validate() ??
                                          false)) {
                                        return;
                                      }
                                      final counts = [
                                        cartonController,
                                        bagController,
                                        customCountController
                                      ];
                                      if (counts.any((controller) =>
                                          int.tryParse(
                                              controller.text.trim()) ==
                                          null)) {
                                        setSheetState(() => formError =
                                            'تحقق من أن أعداد الطرود أعداد صحيحة');
                                        return;
                                      }
                                      if (editing &&
                                          (shipment['shipment_id'] == null ||
                                              shipment['shipment_id']
                                                  .toString()
                                                  .isEmpty)) {
                                        setSheetState(() => formError =
                                            'معرف الشحنة غير متوفر للتعديل');
                                        return;
                                      }
                                      setSheetState(() {
                                        saving = true;
                                        formError = null;
                                      });
                                      setState(() => _isSaving = true);
                                      final packageTypes =
                                          <Map<String, dynamic>>[
                                        if (_readCount(cartonController) > 0)
                                          {
                                            'type': 'carton',
                                            'label': 'كرتونة',
                                            'count':
                                                _readCount(cartonController)
                                          },
                                        if (_readCount(bagController) > 0)
                                          {
                                            'type': 'bag',
                                            'label': 'كيس',
                                            'count': _readCount(bagController)
                                          },
                                        if (_readCount(customCountController) >
                                            0)
                                          {
                                            'type': 'custom',
                                            'label':
                                                customController.text.trim(),
                                            'count': _readCount(
                                                customCountController)
                                          },
                                      ];
                                      try {
                                        _draftSaveTimer?.cancel();
                                        final localDraftError =
                                            await persistDraft();
                                        if (localDraftError != null) {
                                          localDraftWarning = localDraftError;
                                          if (mounted &&
                                              !_draftSaveWarningShown) {
                                            _draftSaveWarningShown = true;
                                            _showMessage(
                                              'تعذر حفظ المسودة على الجهاز: $localDraftError',
                                            );
                                          }
                                        }
                                        final payload = <String, dynamic>{
                                          'action': 'shipment',
                                          'order_id':
                                              orderController.text.trim(),
                                          'delivery_method':
                                              deliveryController.text.trim(),
                                          'carrier':
                                              carrierController.text.trim(),
                                          'tracking_no':
                                              trackingController.text.trim(),
                                          'province':
                                              destinationController.text.trim(),
                                          'shipping_date':
                                              shippingDate!.toIso8601String(),
                                          'package_types': packageTypes,
                                          'weight_kg':
                                              weightController.text.trim(),
                                          'dimensions':
                                              dimensionsController.text.trim(),
                                          'note': notesController.text.trim(),
                                          'client_request_id': clientRequestId,
                                        };
                                        if (editing) {
                                          payload['shipment_id'] =
                                              shipment['shipment_id'];
                                        }
                                        await _api.post(payload);
                                        _draftSaveTimer?.cancel();
                                        if (!editing && draftScope != null) {
                                          try {
                                            await _shipmentDraftStore
                                                .clear(draftScope);
                                          } catch (error) {
                                            draftClearError = error.toString();
                                          }
                                        }
                                        if (!sheetContext.mounted) return;
                                        Navigator.pop(sheetContext, true);
                                      } catch (error) {
                                        setSheetState(() {
                                          saving = false;
                                          formError = 'تعذر حفظ الشحنة: $error'
                                              '${localDraftWarning == null ? '' : '\nتعذر حفظ نسخة محلية من المسودة.'}';
                                        });
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isSaving = false);
                                        }
                                      }
                                    },
                              icon: saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(saving ? 'جارٍ الحفظ' : 'حفظ الشحنة'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
    _draftSaveTimer?.cancel();
    if (!editing && accepted != true) {
      final localDraftError = await persistDraft();
      if (localDraftError != null && mounted && !_draftSaveWarningShown) {
        _draftSaveWarningShown = true;
        localDraftWarning = localDraftError;
        _showMessage('تعذر حفظ المسودة على الجهاز: $localDraftError');
      }
    }
    for (final controller in [
      orderController,
      carrierController,
      trackingController,
      destinationController,
      notesController,
      deliveryController,
      weightController,
      dimensionsController,
      cartonController,
      bagController,
      customController,
      customCountController,
    ]) {
      controller.dispose();
    }
    if (accepted == true && mounted) {
      final warnings = <String>[
        if (localDraftWarning != null)
          'تعذر حفظ المسودة المحلية: $localDraftWarning',
        if (draftClearError != null)
          'تعذر حذف المسودة المحلية: $draftClearError',
      ];
      _showMessage(
        '${editing ? 'تم حفظ تعديلات الشحنة' : 'تم إنشاء الشحنة'}'
        '${warnings.isEmpty ? '' : ' (${warnings.join('؛ ')})'}',
      );
      await _fetchShipments();
    }
  }

  Future<void> _copyTracking(Map<String, dynamic> shipment) async {
    final tracking = shipment['tracking_no']?.toString().trim() ?? '';
    if (tracking.isEmpty) {
      _showMessage('لا يوجد رقم تتبع لنسخه');
      return;
    }
    await Clipboard.setData(ClipboardData(text: tracking));
    if (mounted) _showMessage('تم نسخ رقم التتبع');
  }

  Future<void> _copySummary(Map<String, dynamic> shipment) async {
    final text = _shareText(shipment);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _showMessage('تم نسخ ملخص الشحنة للمشاركة');
  }

  Future<void> _shareSummary(Map<String, dynamic> shipment) async {
    try {
      await SharePlus.instance.share(ShareParams(text: _shareText(shipment)));
    } catch (error) {
      if (mounted) _showMessage('تعذرت مشاركة الشحنة: $error');
    }
  }

  String _shareText(Map<String, dynamic> shipment) {
    final tracking = shipment['tracking_no']?.toString().trim() ?? '';
    final pieces = <String>[
      'الشحنة #${shipment['shipment_id'] ?? ''}',
      'الطلب: ${shipment['order_number'] ?? shipment['order_id'] ?? ''}',
      ShipmentSummary.format(shipment),
      if (shipment['carrier']?.toString().trim().isNotEmpty == true)
        'شركة الشحن: ${shipment['carrier']}',
      if (tracking.isNotEmpty) 'رقم التتبع: $tracking',
      if (shipment['province']?.toString().trim().isNotEmpty == true)
        'الوجهة: ${shipment['province']}',
    ];
    return pieces.join('\n');
  }

  List<Map<String, dynamic>> get _filteredShipments {
    final query = _searchController.text.trim().toLowerCase();
    return _shipments.where((shipment) {
      if (_statusFilter != null && _status(shipment) != _statusFilter) {
        return false;
      }
      if (_carrierFilter != null &&
          shipment['carrier']?.toString() != _carrierFilter) {
        return false;
      }
      if (_dateFilter != null) {
        final date =
            DateTime.tryParse(shipment['shipping_date']?.toString() ?? '');
        if (date == null ||
            date.year != _dateFilter!.year ||
            date.month != _dateFilter!.month ||
            date.day != _dateFilter!.day) {
          return false;
        }
      }
      if (query.isEmpty) return true;
      final searchable = [
        shipment['customer_name'],
        shipment['order_number'],
        shipment['accounting_invoice_no'],
        shipment['invoice_no'],
        shipment['tracking_no'],
        shipment['shipment_id'],
        shipment['order_id'],
      ].whereType<Object>().join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  List<String> get _carriers => _shipments
      .map((shipment) => shipment['carrier']?.toString().trim() ?? '')
      .where((carrier) => carrier.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  @override
  Widget build(BuildContext context) {
    final shipments = _filteredShipments;
    return Scaffold(
      appBar: AppBar(
        title: const Text('الشحن'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _fetchShipments,
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _canManage
          ? FloatingActionButton.extended(
              onPressed: _isSaving ? null : () => _showShipmentEditor(),
              icon: const Icon(Icons.add),
              label: const Text('شحنة جديدة'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear),
                      ),
                hintText: 'بحث بالزبون أو الفاتورة أو التتبع',
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          _buildFilters(context),
          Expanded(child: _buildBody(shipments)),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    final carriers = _carriers;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          DropdownButton<String?>(
            value: _statusFilter,
            hint: const Text('كل الحالات'),
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('كل الحالات')),
              ...const [
                'prepared',
                'shipping',
                'in_transit',
                'delivered',
                'returned',
                'closed'
              ].map((status) => DropdownMenuItem<String?>(
                  value: status, child: Text(_statusLabel(status)))),
            ],
            onChanged: (value) => setState(() => _statusFilter = value),
          ),
          const SizedBox(width: 12),
          DropdownButton<String?>(
            value: carriers.contains(_carrierFilter) ? _carrierFilter : null,
            hint: const Text('كل الشركات'),
            underline: const SizedBox.shrink(),
            items: [
              const DropdownMenuItem<String?>(
                  value: null, child: Text('كل الشركات')),
              ...carriers.map((carrier) => DropdownMenuItem<String?>(
                  value: carrier, child: Text(carrier))),
            ],
            onChanged: (value) => setState(() => _carrierFilter = value),
          ),
          IconButton(
            tooltip: _dateFilter == null
                ? 'تصفية حسب التاريخ'
                : 'التاريخ: ${_dateLabel(_dateFilter!)}',
            onPressed: () async {
              if (_dateFilter != null) {
                setState(() => _dateFilter = null);
                return;
              }
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (date != null) setState(() => _dateFilter = date);
            },
            icon: Icon(_dateFilter == null
                ? Icons.calendar_month
                : Icons.event_available),
          ),
          if (_statusFilter != null ||
              _carrierFilter != null ||
              _dateFilter != null)
            TextButton(
              onPressed: () => setState(() {
                _statusFilter = null;
                _carrierFilter = null;
                _dateFilter = null;
              }),
              child: const Text('مسح الفلاتر'),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(List<Map<String, dynamic>> shipments) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 44),
              const SizedBox(height: 8),
              Text('تعذر تحميل الشحنات\n$_loadError',
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _fetchShipments,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (shipments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_shipping_outlined, size: 48),
              const SizedBox(height: 8),
              Text(_shipments.isEmpty
                  ? 'لا توجد شحنات بعد'
                  : 'لا توجد شحنات تطابق البحث أو الفلاتر'),
              if (_shipments.isEmpty && _canManage) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _showShipmentEditor(),
                  icon: const Icon(Icons.add),
                  label: const Text('إنشاء أول شحنة'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _fetchShipments,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 88),
        itemCount: shipments.length,
        itemBuilder: (context, index) => _shipmentCard(shipments[index]),
      ),
    );
  }

  Widget _shipmentCard(Map<String, dynamic> shipment) {
    final status = _status(shipment);
    final locked = _isLocked(shipment);
    final editable = _canManage && (!locked || _isAdmin);
    final tracking = shipment['tracking_no']?.toString().trim() ?? '';
    final shippingDate =
        DateTime.tryParse(shipment['shipping_date']?.toString() ?? '');
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: CircleAvatar(
            child: Icon(_statusIcon(status)),
          ),
          title: Text(
            'شحنة #${shipment['shipment_id'] ?? '—'}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الطلب: ${shipment['order_number'] ?? shipment['order_id'] ?? '—'}'
                  '${shipment['customer_name'] == null ? '' : ' | ${shipment['customer_name']}'}',
                ),
                Text(ShipmentSummary.format(shipment)),
                if (shipment['carrier']?.toString().trim().isNotEmpty == true)
                  Text('الناقل: ${shipment['carrier']}'),
                if (shipment['province']?.toString().trim().isNotEmpty == true)
                  Text('الوجهة: ${shipment['province']}'),
                if (tracking.isNotEmpty)
                  InkWell(
                    onTap: () => _copyTracking(shipment),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        'التتبع: $tracking  ⧉',
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                    ),
                  ),
                Text(
                  '${_statusLabel(status)} • ${shippingDate == null ? 'التاريخ غير محدد' : _dateLabel(shippingDate)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(
            tooltip: 'إجراءات الشحنة',
            onSelected: (action) {
              if (action == 'edit') {
                _showShipmentEditor(shipment: shipment);
              } else if (action == 'copy') {
                _copySummary(shipment);
              } else if (action == 'share') {
                _shareSummary(shipment);
              } else if (action.startsWith('status:')) {
                _updateShipmentStatus(shipment, action.substring(7));
              }
            },
            itemBuilder: (context) => [
              if (editable)
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.edit),
                    title: Text('تعديل البيانات'),
                  ),
                ),
              const PopupMenuItem(
                value: 'copy',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.copy),
                  title: Text('نسخ الملخص'),
                ),
              ),
              const PopupMenuItem(
                value: 'share',
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.share),
                  title: Text('مشاركة ملخص الشحنة'),
                ),
              ),
              if (_canUpdateStatus && (!locked || _isAdmin)) ...[
                const PopupMenuDivider(),
                for (final item in const {
                  'in_transit': 'قيد النقل',
                  'delivered': 'تم التسليم',
                  'returned': 'مرتجع',
                }.entries)
                  if (item.key != status)
                    PopupMenuItem(
                      value: 'status:${item.key}',
                      child: Text('تغيير الحالة إلى ${item.value}'),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _counterRow(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    required VoidCallback onChanged,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton(
            tooltip: 'إنقاص',
            onPressed: () {
              final current = int.tryParse(controller.text.trim()) ?? 0;
              controller.text = (current > 0 ? current - 1 : 0).toString();
              onChanged();
            },
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 82,
            child: TextFormField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              validator: validator ??
                  (value) {
                    final count = int.tryParse(value?.trim() ?? '');
                    return count == null || count < 0 ? 'عدد صحيح' : null;
                  },
              onChanged: (_) => onChanged(),
            ),
          ),
          IconButton(
            tooltip: 'زيادة',
            onPressed: () {
              final current = int.tryParse(controller.text.trim()) ?? 0;
              controller.text = (current + 1).toString();
              onChanged();
            },
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
    );
  }

  int _typeCount(List<Map<String, dynamic>> types, String type) {
    return types.where((item) => item['type']?.toString() == type).fold<int>(0,
        (sum, item) {
      final value = item['count'];
      return sum + (value is num ? value.toInt() : int.tryParse('$value') ?? 0);
    });
  }

  String _customLabel(List<Map<String, dynamic>> types) {
    return types
        .where((item) => item['type']?.toString() == 'custom')
        .map((item) => (item['label'] ?? item['custom_type'])?.toString() ?? '')
        .firstWhere((value) => value.trim().isNotEmpty, orElse: () => '');
  }

  int _readCount(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  bool _isLocked(Map<String, dynamic> shipment) =>
      const {'delivered', 'closed', 'locked'}.contains(_status(shipment));

  String _status(Map<String, dynamic> shipment) =>
      shipment['status']?.toString().toLowerCase() ?? '';

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'prepared':
        return 'جاهز للشحن';
      case 'shipping':
        return 'قيد الشحن';
      case 'in_transit':
        return 'قيد النقل';
      case 'delivered':
        return 'تم التسليم';
      case 'returned':
        return 'مرتجع';
      case 'closed':
      case 'locked':
        return 'مقفل';
      default:
        return status.isEmpty ? 'غير محدد' : status;
    }
  }

  static IconData _statusIcon(String status) {
    switch (status) {
      case 'in_transit':
      case 'shipping':
        return Icons.local_shipping;
      case 'delivered':
        return Icons.check_circle;
      case 'returned':
        return Icons.assignment_return;
      case 'prepared':
        return Icons.inventory_2;
      default:
        return Icons.info_outline;
    }
  }

  static String _dateLabel(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
