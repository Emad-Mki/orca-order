/// فئة مساعدة لتوحيد حالات الطلبات وعرضها بالعربية
class OrderStatusMapper {
  // الحالات الجديدة المطلوبة للعرض
  static const String processing = 'processing'; // قيد المعالجة
  static const String priced = 'priced'; // تم التسعير
  static const String approved = 'approved'; // تمت الموافقة
  static const String preparing = 'preparing'; // قيد التجهيز
  static const String completed = 'completed'; // منتهي
  static const String cancelled = 'cancelled'; // ملغي

  // تحويل الحالة الداخلية (قديمة أو جديدة) إلى الحالة الموحدة الجديدة
  static String normalizeStatus(String? status) {
    if (status == null || status.isEmpty) return processing;
    final s = status.toLowerCase().trim();

    // قيد المعالجة
    if (s == 'pending' || 
        s == 'submitted' || 
        s == 'pricing' || 
        s == 'customer_changed' || 
        s == processing ||
        s == 'draft') {
      return processing;
    }

    // تم التسعير
    if (s == priced || s == 'fixed') {
      return priced;
    }

    // تمت الموافقة
    if (s == approved || 
        s == 'customer_confirmed' || 
        s == 'confirmed' ||
        s == 'accepted') {
      return approved;
    }

    // قيد التجهيز
    if (s == preparing || 
        s == 'warehouse' || 
        s == 'prepared' ||
        s == 'picking') {
      return preparing;
    }

    // منتهي
    if (s == completed || 
        s == 'shipping' || 
        s == 'delivered' ||
        s == 'shipped' ||
        s == 'finished') {
      return completed;
    }

    // ملغي
    if (s == cancelled || 
        s == 'canceled' || 
        s == 'rejected' ||
        s == 'void') {
      return cancelled;
    }

    // الافتراضي: قيد المعالجة
    return processing;
  }

  // الحصول على الاسم العربي للحالة
  static String getArabicStatus(String? status) {
    final normalized = normalizeStatus(status);
    switch (normalized) {
      case processing:
        return 'قيد المعالجة';
      case priced:
        return 'تم التسعير';
      case approved:
        return 'تمت الموافقة';
      case preparing:
        return 'قيد التجهيز';
      case completed:
        return 'منتهي';
      case cancelled:
        return 'ملغي';
      default:
        return 'قيد المعالجة';
    }
  }

  // الحصول على لون مناسب للحالة
  static int getStatusColorHex(String? status) {
    final normalized = normalizeStatus(status);
    switch (normalized) {
      case processing:
        return 0xFFFF9800; // Orange
      case priced:
        return 0xFF2196F3; // Blue
      case approved:
        return 0xFF4CAF50; // Green
      case preparing:
        return 0xFF9C27B0; // Purple
      case completed:
        return 0xFF009688; // Teal
      case cancelled:
        return 0xFFF44336; // Red
      default:
        return 0xFFFF9800; // Orange
    }
  }

  // الحصول على أيقونة مناسبة للحالة
  static String getStatusIcon(String? status) {
    final normalized = normalizeStatus(status);
    switch (normalized) {
      case processing:
        return 'hourglass_empty';
      case priced:
        return 'price_check';
      case approved:
        return 'check_circle';
      case preparing:
        return 'inventory';
      case completed:
        return 'local_shipping';
      case cancelled:
        return 'cancel';
      default:
        return 'hourglass_empty';
    }
  }

  // التحقق مما إذا كانت الحالة نهائية
  static bool isFinalStatus(String? status) {
    final normalized = normalizeStatus(status);
    return normalized == completed || normalized == cancelled;
  }

  // التحقق مما إذا كان يمكن تعديل الطلب
  static bool canEditOrder(String? status) {
    final normalized = normalizeStatus(status);
    return normalized == processing || normalized == priced;
  }

  // التحقق مما إذا كان يمكن إلغاء الطلب
  static bool canCancelOrder(String? status) {
    final normalized = normalizeStatus(status);
    return normalized == processing || 
           normalized == priced || 
           normalized == approved;
  }
}
