/// أدوات آمنة للتعامل مع الأرقام والعملات
/// تمنع أخطاء null عند استخدام toStringAsFixed وتحوّل القيم النصية والـ dynamic بشكل آمن

/// تحويل قيمة ديناميكية إلى double بشكل آمن
/// - إذا كانت null ترجع fallback
/// - إذا كانت num (int/double) ترجع قيمتها كـ double
/// - إذا كانت String تحاول parsing بعد إزالة الفواصل والأقواس
double toSafeDouble(dynamic value, {double fallback = 0.0}) {
  if (value == null) return fallback;

  if (value is num) return value.toDouble();

  // التعامل مع السلاسل النصية
  final normalized = value
      .toString()
      .trim()
      .replaceAll(',', '')
      .replaceAll('\$', '')
      .replaceAll('USD', '')
      .replaceAll('SYP', '')
      .replaceAll(' ', '');

  if (normalized.isEmpty) return fallback;

  return double.tryParse(normalized) ?? fallback;
}

/// تنسيق القيمة كعملة بشكل آمن
/// - لا يرمي Exception أبداً عند null
/// - لا يستدعي toStringAsFixed إلا على double مضمون
/// - يتعامل مع الرقم النصي مثل "25.5" أو "1,250.75"
/// - يميز بين: غير متوفر، غير مسعّر، وسعر فعلي
String formatMoney(
  dynamic value, {
  String currency = 'USD',
  bool showUnavailable = false,
  bool isUnavailable = false,
  String unavailableText = 'غير متوفر',
  String unpricedText = 'غير مسعّر',
  bool allowZero = true,
}) {
  // حالة غير متوفر
  if (isUnavailable && showUnavailable) {
    return unavailableText;
  }

  // قيمة null أو فارغة
  if (value == null || value.toString().trim().isEmpty) {
    return unpricedText;
  }

  final amount = toSafeDouble(value, fallback: double.nan);

  // إذا لم يكن الرقم صالحاً
  if (amount.isNaN) {
    return unpricedText;
  }

  // صفر فعلي
  if (amount == 0.0 && !allowZero) {
    return unpricedText;
  }

  return '${amount.toStringAsFixed(2)} $currency';
}

/// تنسيق مختصر للعملة بدون نص "غير مسعّر" - يستخدم في القوائم
String formatMoneyShort(dynamic value, {String currency = 'USD'}) {
  if (value == null || value.toString().trim().isEmpty) {
    return '0.00 $currency';
  }

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
/// يرتجع السعر النهائي إذا وجد، وإلا سعر العرض، وإلا null
dynamic getFinalPrice(Map<String, dynamic> item) {
  // نحاول الحصول على السعر النهائي أولاً
  final finalPrice = item['final_price'] ?? item['finalPrice'];
  
  if (finalPrice != null && finalPrice.toString().trim().isNotEmpty) {
    final parsed = toSafeDouble(finalPrice, fallback: double.nan);
    if (!parsed.isNaN && parsed > 0) {
      return parsed;
    }
  }

  // إذا لم يوجد سعر نهائي، نستخدم سعر العرض
  final offerPrice = item['price_offer'] ?? item['priceOffer'] ?? item['display_price'] ?? item['displayPrice'];
  
  if (offerPrice != null && offerPrice.toString().trim().isNotEmpty) {
    final parsed = toSafeDouble(offerPrice, fallback: double.nan);
    if (!parsed.isNaN) {
      return parsed;
    }
  }

  return null;
}

/// التحقق مما إذا كان البند غير متوفر
bool isItemUnavailable(Map<String, dynamic> item) {
  final status = item['availability_status']?.toString().toLowerCase();
  final isUnavailable = item['is_unavailable'];
  
  return status == 'unavailable' || 
         status == 'not_available' || 
         isUnavailable == true || 
         isUnavailable.toString().toLowerCase() == 'true';
}

/// حساب إجمالي البنود بأمان
/// - البنود غير المتوفرة لا تدخل في الحساب
/// - البنود غير المسعرة لا تسبب crash
double calculateTotal(List<Map<String, dynamic>> items, {bool excludeUnavailable = true}) {
  return items.fold<double>(0.0, (sum, item) {
    // استبعاد البنود غير المتوفرة
    if (excludeUnavailable && isItemUnavailable(item)) {
      return sum;
    }

    // الحصول على الكمية المعتمدة أو المطلوبة
    final quantity = toSafeDouble(
      item['quantity_approved'] ?? item['approved_quantity'] ?? item['quantity_requested'] ?? item['requested_quantity'],
      fallback: 0.0,
    );

    if (quantity <= 0) return sum;

    // الحصول على السعر النهائي
    final price = toSafeDouble(getFinalPrice(item), fallback: 0.0);

    return sum + (quantity * price);
  });
}
