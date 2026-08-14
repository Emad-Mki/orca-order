/// أدوات آمنة للتعامل مع الأرقام والعملات
/// تمنع أخطاء null عند استخدام toStringAsFixed وتحوّل القيم النصية والـ dynamic بشكل آمن

/// تحويل قيمة ديناميكية إلى double بشكل آمن
double toSafeDouble(dynamic value, {double fallback = 0.0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  
  final normalized = value.toString().trim()
      .replaceAll(',', '')
      .replaceAll('\$', '')
      .replaceAll('USD', '')
      .replaceAll('SYP', '')
      .replaceAll(' ', '');

  if (normalized.isEmpty) return fallback;
  return double.tryParse(normalized) ?? fallback;
}

/// تنسيق القيمة كعملة بشكل آمن
String formatMoney(
  dynamic value, {
  String currency = 'USD',
  bool showUnavailable = false,
  bool isUnavailable = false,
  String unavailableText = 'غير متوفر',
  String unpricedText = 'غير مسعّر',
  bool allowZero = true,
}) {
  if (isUnavailable && showUnavailable) return unavailableText;
  if (value == null || value.toString().trim().isEmpty) return unpricedText;

  final amount = toSafeDouble(value, fallback: double.nan);
  if (amount.isNaN) return unpricedText;
  if (amount == 0.0 && !allowZero) return unpricedText;

  return '${amount.toStringAsFixed(2)} $currency';
}

/// تنسيق مختصر للعملة - يستخدم في القوائم
String formatMoneyShort(dynamic value, {String currency = 'USD'}) {
  if (value == null || value.toString().trim().isEmpty) return '0.00 $currency';
  final amount = toSafeDouble(value, fallback: 0.0);
  return '${amount.toStringAsFixed(2)} $currency';
}

/// التحقق مما إذا كان السعر موجوداً وصالحاً (> 0)
bool hasValidPrice(dynamic value) {
  if (value == null) return false;
  final amount = toSafeDouble(value, fallback: double.nan);
  return !amount.isNaN && amount > 0;
}

/// الحصول على السعر النهائي بأمان من عنصر طلب
dynamic getFinalPrice(Map<String, dynamic> item) {
  final finalPrice = item['final_price'] ?? item['finalPrice'];
  if (finalPrice != null && finalPrice.toString().trim().isNotEmpty) {
    final parsed = toSafeDouble(finalPrice, fallback: double.nan);
    if (!parsed.isNaN && parsed > 0) return parsed;
  }

  final offerPrice = item['price_offer'] ?? 
                     item['priceOffer'] ?? 
                     item['display_price'] ?? 
                     item['displayPrice'] ??
                     item['default_price'];
  
  if (offerPrice != null && offerPrice.toString().trim().isNotEmpty) {
    final parsed = toSafeDouble(offerPrice, fallback: double.nan);
    if (!parsed.isNaN) return parsed;
  }

  return null;
}

bool isItemUnavailable(Map<String, dynamic> item) {
  final status = item['availability_status']?.toString().toLowerCase();
  final isUnavailable = item['is_unavailable'];
  return status == 'unavailable' || 
         status == 'not_available' || 
         isUnavailable == true || 
         isUnavailable.toString().toLowerCase() == 'true';
}

/// حساب إجمالي البنود بأمان
double calculateTotal(List<Map<String, dynamic>> items, {bool excludeUnavailable = true}) {
  return items.fold<double>(0.0, (sum, item) {
    if (excludeUnavailable && isItemUnavailable(item)) return sum;

    final quantity = toSafeDouble(
      item['quantity_approved'] ?? 
      item['approved_quantity'] ?? 
      item['quantity_requested'] ?? 
      item['requested_quantity'],
      fallback: 0.0,
    );

    if (quantity <= 0) return sum;
    final price = toSafeDouble(getFinalPrice(item), fallback: 0.0);
    return sum + (quantity * price);
  });
}

/// دالة مساعدة لقراءة السعر من JSON بأمان
double parsePriceFromJson(dynamic value, {double fallback = 0.0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  
  String str = value.toString().trim();
  if (str.isEmpty || str.toLowerCase() == 'null') return fallback;
  
  str = str.replaceAll(',', '')
           .replaceAll('\$', '')
           .replaceAll('USD', '')
           .replaceAll('SYP', '')
           .replaceAll(' ', '');
  
  return double.tryParse(str) ?? fallback;
}
