# تحديثات صفحة الطلبات - تعليمات التنفيذ

## 1. إضافة النماذج الجديدة في بداية الملف (بعد imports):

```dart
class OrderStatus {
  static const String pending = 'pending'; // قيد المعالجة
  static const String priced = 'priced'; // تم التسعير
  static const String approved = 'approved'; // تمت الموافقة
  static const String customerChanged = 'customer_changed'; // تم التعديل
  static const String preparing = 'preparing'; // قيد التجهيز
  static const String shipping = 'shipping'; // منتهي
  static const String cancelled = 'cancelled'; // ملغى

  static String getArabicStatus(String status) {
    switch (status) {
      case pending: return 'قيد المعالجة';
      case priced: return 'تم التسعير';
      case approved: return 'تمت الموافقة';
      case customerChanged: return 'تم التعديل';
      case preparing: return 'قيد التجهيز';
      case shipping: return 'منتهي (قيد الشحن)';
      case cancelled: return 'ملغى';
      default: return status;
    }
  }

  static Color getStatusColor(String status) {
    switch (status) {
      case pending: return Colors.orange;
      case priced: return Colors.blue;
      case approved: return Colors.green;
      case customerChanged: return Colors.amber;
      case preparing: return Colors.purple;
      case shipping: return Colors.teal;
      case cancelled: return Colors.red;
      default: return Colors.grey;
    }
  }
}

class CartItem {
  final Product product;
  double quantity;
  String? note;
  String? selectedUnit;

  CartItem({required this.product, this.quantity = 1.0, this.note, this.selectedUnit});

  Map<String, dynamic> toJson() => {
    'code': product.code,
    'name': product.name,
    'quantity': quantity,
    'unit': selectedUnit ?? product.unit,
    'note': note ?? '',
  };
}
```

## 2. استبدال OrdersScreen بالكامل:

السمات الرئيسية للتحديث:
- **تبويبات حسب مرحلة الطلب**: قيد المعالجة، تم التسعير، تمت الموافقة، قيد التجهيز، منتهي، ملغى
- **فلترة حسب الزبون**: للمدير والمحاسب فقط
- **نقطة خضراء للطلبات الجديدة**: تظهر حتى يقرأها المحاسب
- **ترتيب حسب الأحدث أولاً**
- **عرض اسم الزبون وتاريخ الطلب ورقم تسلسلي**

## 3. الميزات المطلوبة التي تم تنفيذها:

1. ✅ تصنيف الطلبات لقوائم حسب المرحلة
2. ✅ تعليم الطلبات الجديدة بنقطة خضراء
3. ✅ إظهار اسم الزبون والتاريخ والوقت والترقيم التسلسلي
4. ✅ خيار عرض فواتير زبون واحد (للمدير/المحاسب)
5. ✅ ترتيب وفق الأحدث أولاً
6. ✅ تعليم الطلب كمقروء عند الدخول له

## 4. الخطوات التالية المطلوبة (في الـ Backend):

- إضافة حقل `is_read` أو `is_new` للطلبات
- إضافة endpoint لـ `markOrderAsRead`
- إضافة endpoint لـ `getOrders` يدعم الفلترة بـ `customer_id`
- إضافة حالات الطلب الجديدة في قاعدة البيانات
