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

// --- سجل التدقيق (Audit Log) ---
class AuditLogScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const AuditLogScreen({super.key, required this.session});
  
  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String _filterUser = 'all';
  String _filterEntity = 'all';
  DateTime? _startDate;
  DateTime? _endDate;
  
  @override
  void initState() {
    super.initState();
    _fetchLogs();
  }
  
  Future<void> _fetchLogs() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().post({
        'action': 'getAuditLog',
        'username': widget.session['username'],
        'token': widget.session['token'],
        if (_filterUser != 'all') 'filter_user': _filterUser,
        if (_filterEntity != 'all') 'filter_entity': _filterEntity,
        if (_startDate != null) 'start_date': _startDate!.toIso8601String().split('T')[0],
        if (_endDate != null) 'end_date': _endDate!.toIso8601String().split('T')[0],
      });
      if (mounted) {
        setState(() {
          _logs = data['logs'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<void> _selectDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked;
        else _endDate = picked;
      });
      _fetchLogs();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DropdownButton<String>(
                value: _filterUser,
                hint: const Text('المستخدم'),
                items: [('all', 'الكل'), ('admin', 'مدير'), ('accountant', 'محاسب'), ('warehouse', 'مستودع')]
                    .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2))).toList(),
                onChanged: (v) => setState(() { _filterUser = v!; _fetchLogs(); }),
              ),
              DropdownButton<String>(
                value: _filterEntity,
                hint: const Text('الكيان'),
                items: [('all', 'الكل'), ('product', 'منتج'), ('invoice', 'فاتورة'), ('customer', 'عميل'), ('user', 'مستخدم'), ('payment', 'دفعة')]
                    .map((e) => DropdownMenuItem(value: e.$1, child: Text(e.$2))).toList(),
                onChanged: (v) => setState(() { _filterEntity = v!; _fetchLogs(); }),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(_startDate != null ? _startDate!.toIso8601String().split('T')[0] : 'من تاريخ'),
                onPressed: () => _selectDate(true),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today),
                label: Text(_endDate != null ? _endDate!.toIso8601String().split('T')[0] : 'إلى تاريخ'),
                onPressed: () => _selectDate(false),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('تحديث'),
                onPressed: _fetchLogs,
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _logs.length,
            itemBuilder: (_, i) {
              final log = _logs[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: ExpansionTile(
                  leading: Icon(_getActionIcon(log['action']), color: Colors.blue),
                  title: Text('${log['username']} - ${log['action']}'),
                  subtitle: Text('${log['entity_type']}: ${log['entity_id']}'),
                  trailing: Text(_formatDate(log['timestamp']), style: const TextStyle(fontSize: 12)),
                  children: [
                    if (log['old_values'] != null && (log['old_values'] as Map).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('القيم السابقة:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(log['old_values'].toString()),
                          ],
                        ),
                      ),
                    if (log['new_values'] != null && (log['new_values'] as Map).isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('القيم الجديدة:', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(log['new_values'].toString()),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  IconData _getActionIcon(String action) {
    if (action.contains('create') || action.contains('إضافة')) return Icons.add_circle;
    if (action.contains('update') || action.contains('تعديل')) return Icons.edit;
    if (action.contains('delete') || action.contains('حذف')) return Icons.delete;
    return Icons.history;
  }
  
  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime dt;
    if (timestamp is DateTime) {
      dt = timestamp;
    } else if (timestamp is String) {
      dt = DateTime.parse(timestamp);
    } else {
      return timestamp.toString();
    }
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// --- إعدادات النسخ الاحتياطي ---
class BackupSettingsScreen extends StatefulWidget {
  final Map<String, dynamic> session;
  const BackupSettingsScreen({super.key, required this.session});
  
  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  bool _isBackingUp = false;
  String _lastBackupDate = 'غير متوفر';
  
  @override
  void initState() {
    super.initState();
    _getLastBackupDate();
  }
  
  Future<void> _getLastBackupDate() async {
    try {
      final data = await ApiService().post({
        'action': 'getLastBackupDate',
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        setState(() {
          _lastBackupDate = data['last_backup_date'] ?? 'غير متوفر';
        });
      }
    } catch (e) {
      // تجاهل الخطأ
    }
  }
  
  Future<void> _createBackup() async {
    setState(() => _isBackingUp = true);
    try {
      final data = await ApiService().post({
        'action': 'createBackup',
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إنشاء النسخة الاحتياطية بنجاح')));
        _getLastBackupDate();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }
  
  Future<void> _exportData(String entityType) async {
    try {
      final data = await ApiService().post({
        'action': 'exportToCsv',
        'entity_type': entityType,
        'username': widget.session['username'],
        'token': widget.session['token'],
      });
      if (mounted) {
        final csvContent = data['csv_content'] ?? '';
        // عرض محتوى CSV أو تحميله
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('تصدير $entityType'),
            content: SizedBox(
              width: double.maxFinite,
              height: 300,
              child: SingleChildScrollView(
                child: SelectableText(csvContent, style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('آخر نسخة احتياطية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_lastBackupDate, style: const TextStyle(fontSize: 18, color: Colors.blue)),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _isBackingUp ? null : _createBackup,
                    icon: _isBackingUp ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.backup),
                    label: Text(_isBackingUp ? 'جاري الإنشاء...' : 'إنشاء نسخة احتياطية الآن'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text('تصدير البيانات كـ CSV', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.people),
          title: const Text('تصدير العملاء'),
          trailing: const Icon(Icons.download),
          onTap: () => _exportData('customers'),
        ),
        ListTile(
          leading: const Icon(Icons.inventory),
          title: const Text('تصدير المنتجات'),
          trailing: const Icon(Icons.download),
          onTap: () => _exportData('products'),
        ),
        ListTile(
          leading: const Icon(Icons.receipt),
          title: const Text('تصدير الفواتير'),
          trailing: const Icon(Icons.download),
          onTap: () => _exportData('invoices'),
        ),
        ListTile(
          leading: const Icon(Icons.payments),
          title: const Text('تصدير الدفعات'),
          trailing: const Icon(Icons.download),
          onTap: () => _exportData('payments'),
        ),
      ],
    );
  }
}

// ============================================================================
// شاشات إضافية مطلوبة (Additional Required Screens)
// ============================================================================

// شاشة تفاصيل المنتج
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final bool addToCart;
  final Function(OrderItem)? onAddToCart;
  
  const ProductDetailScreen({super.key, required this.product, this.addToCart = false, this.onAddToCart});
  
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  String _selectedUnit = '';
  double _currentPrice = 0.0;
  final TextEditingController _noteCtrl = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _selectedUnit = widget.product.unit;
    _currentPrice = widget.product.price;
  }
  
  void _updatePrice(String unit) {
    double factor = 1.0;
    if (unit == widget.product.unit2) {
      factor = widget.product.factor2 ?? 1.0;
    } else if (unit == widget.product.unit3) {
      factor = widget.product.factor3 ?? 1.0;
    }
    
    setState(() {
      _selectedUnit = unit;
      _currentPrice = widget.product.price * factor;
    });
  }
  
  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }
  
  Widget _buildProductImage(Product product, {double? size, double? height}) {
    final imageUrl = product.imageUrl;
    
    if (imageUrl == null || imageUrl.isEmpty) {
      return Container(
        width: size,
        height: height ?? size,
        color: Colors.grey[300],
        child: const Icon(Icons.image, size: 50, color: Colors.grey),
      );
    }
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: height ?? size,
        fit: BoxFit.contain,
        imageBuilder: (context, imageProvider) => Container(
          width: size,
          height: height ?? size,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: imageProvider,
              fit: BoxFit.contain,
            ),
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        placeholder: (context, url) => Container(
          width: size,
          height: height ?? size,
          color: Colors.grey[200],
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          width: size,
          height: height ?? size,
          color: Colors.grey[300],
          child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
        ),
      ),
    );
  }
  
  // Static helper function to build Google Drive image URL
  static String? _buildImageUrlStatic(String? imageIdentifier) {
    if (imageIdentifier == null || imageIdentifier.isEmpty) return null;
    
    // If already a full HTTP URL, return as is
    if (imageIdentifier.startsWith('http://') || imageIdentifier.startsWith('https://')) {
      return imageIdentifier;
    }
    
    // Check if it's a Google Drive file ID (various formats)
    if (imageIdentifier.contains('drive.google.com')) {
      // Extract file ID from Google Drive URL
      RegExp regExp = RegExp(r'/d/([a-zA-Z0-9_-]+)');
      Match? match = regExp.firstMatch(imageIdentifier);
      if (match != null) {
        String fileId = match.group(1)!;
        return 'https://lh3.googleusercontent.com/d/$fileId=w400-h400-p-k-no-nu';
      }
      
      // Try another pattern for ?id= format
      regExp = RegExp(r'[?&]id=([a-zA-Z0-9_-]+)');
      match = regExp.firstMatch(imageIdentifier);
      if (match != null) {
        String fileId = match.group(1)!;
        return 'https://lh3.googleusercontent.com/d/$fileId=w400-h400-p-k-no-nu';
      }
    }
    
    // If it contains 'googleusercontent.com', it's already a valid URL
    if (imageIdentifier.contains('googleusercontent.com')) {
      return imageIdentifier;
    }
    
    // Assume it's a raw file ID and construct the URL
    String cleanId = imageIdentifier.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    if (cleanId.isNotEmpty && cleanId.length > 5) {
      return 'https://lh3.googleusercontent.com/d/$cleanId=w400-h400-p-k-no-nu';
    }
    
    return null;
  }
  
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // صورة المنتج الكبيرة
            GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (_) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: _buildProductImage(widget.product, size: 400),
                  ),
                );
              },
              child: _buildProductImage(widget.product, height: 300),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // السعر
                  (_currentPrice) > 0
                    ? Text('السعر: $_currentPrice ${widget.product.currency ?? ""}', 
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.green, fontWeight: FontWeight.bold))
                    : const Text('يرجى التواصل لمعرفة السعر', 
                        style: TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // المعلومات الأساسية
                  _buildInfoRow('الرمز', widget.product.code ?? ''),
                  _buildInfoRow('التصنيف', widget.product.category ?? ''),
                  _buildInfoRow('المخزون', '${widget.product.stock ?? 0}'),
                  _buildInfoRow('الوحدة الافتراضية', widget.product.uomName ?? widget.product.unit),
                  
                  // اختيار الوحدة
                  const SizedBox(height: 16),
                  Text('اختر الوحدة:', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedUnit,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                    items: (widget.product.units ?? [widget.product.unit]).toSet().map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                    onChanged: (val) => _updatePrice(val!),
                  ),
                  
                  // اختيار الكمية
                  const SizedBox(height: 16),
                  Text('الكمية:', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(text: '$_quantity'),
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            filled: true,
                          ),
                          onChanged: (val) => _quantity = int.tryParse(val) ?? 1,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(onPressed: () => setState(() => _quantity = (_quantity - 1).clamp(1, 9999)), icon: const Icon(Icons.remove)),
                      IconButton.filled(onPressed: () => setState(() => _quantity = (_quantity + 1).clamp(1, 9999)), icon: const Icon(Icons.add)),
                    ],
                  ),
                  
                  // ملاحظة على المنتج
                  const SizedBox(height: 16),
                  TextField(
                    controller: _noteCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة على المنتج (اختياري)',
                      border: OutlineInputBorder(),
                      filled: true,
                    ),
                  ),
                  
                  // الوصف
                  if (widget.product.description != null && widget.product.description!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text('الوصف:', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(widget.product.description!, style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                  ],
                  
                  // زر الإضافة للسلة
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (widget.onAddToCart != null) {
                          // Create a copy of the product with the updated price for this unit
                          final adjustedProduct = Product(
                            code: widget.product.code,
                            name: widget.product.name,
                            category: widget.product.category,
                            origin: widget.product.origin,
                            unit: widget.product.unit,
                            price: _currentPrice,
                            imageUrl: widget.product.imageUrl,
                            currency: widget.product.currency,
                            stock: widget.product.stock,
                            description: widget.product.description,
                            units: widget.product.units,
                            uomName: widget.product.uomName,
                          );
                          
                          final item = OrderItem(
                            product: adjustedProduct,
                            quantity: _quantity.toDouble(),
                            selectedUnit: _selectedUnit,
                            note: _noteCtrl.text.isEmpty ? null : _noteCtrl.text,
                          );
                          widget.onAddToCart!(item);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تمت إضافة $_quantity $_selectedUnit من "${widget.product.name}" للسلة'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('إضافة للسلة'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value),
        ],
      ),
    );
  }
}

// شاشة قائمة الطلبات الجديدة
class NewOrdersListScreen extends StatelessWidget {
  final Map<String, dynamic> session;
  
  const NewOrdersListScreen({super.key, required this.session});
  
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('شاشة قائمة الطلبات الجديدة'));
  }
}

// شاشة تسعير الطلبات
class PricingQueueScreen extends StatelessWidget {
  final Map<String, dynamic> session;
  
  const PricingQueueScreen({super.key, required this.session});
  
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('شاشة تسعير الطلبات'));
  }
}

// شاشة الفواتير بانتظار الاعتماد
class PendingApprovalScreen extends StatelessWidget {
  final Map<String, dynamic> session;
  
  const PendingApprovalScreen({super.key, required this.session});
  
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('شاشة الفواتير بانتظار الاعتماد'));
  }
}

// شاشة استيراد وتصدير Excel
class ImportExportScreen extends StatelessWidget {
  final Map<String, dynamic> session;
  
  const ImportExportScreen({super.key, required this.session});
  
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('شاشة استيراد وتصدير Excel'));
  }
}

// شاشة أوامر التجهيز
class PreparationOrdersScreen extends StatelessWidget {
  final Map<String, dynamic> session;
  
  const PreparationOrdersScreen({super.key, required this.session});
  
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('شاشة أوامر التجهيز'));
  }
}
