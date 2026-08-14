# دليل الهجرة إلى البنية الجديدة

## 📋 ملخص التغييرات

تم إعادة هيكلة التطبيق بالكامل لفصل الاهتمامات (Separation of Concerns) وتحسين قابلية الصيانة.

### قبل الهيكلة:
- `main.dart`: 6314 سطر (كل شيء في ملف واحد)
- لا يوجد فصل بين النماذج والخدمات والشاشات
- ملفات احتياطية قديمة في مجلد الإنتاج

### بعد الهيكلة:
- `main.dart`: 111 سطر (فقط نقطة البداية وإدارة الجلسة)
- مجلد `screens/`: 20 شاشة منفصلة
- مجلد `services/`: خدمة API معزولة
- مجلد `repositories/`: طبقة ربط البيانات
- مجلد `models/`: نماذج البيانات
- مجلد `archive/`: الملفات القديمة والاحتياطية

---

## 🏗️ البنية الجديدة

```
lib/
├── main.dart                    # نقطة البداية (111 سطر)
├── models/                      # نماذج البيانات
│   ├── models.dart             # ملف التصدير
│   ├── product.dart
│   ├── order.dart
│   ├── order_item.dart
│   └── balance_info.dart
├── services/                    # الخدمات
│   └── api_service.dart        # خدمة API
├── repositories/                # طبقة الربط
│   └── order_repository.dart   # OrderRepository, ProductRepository, CustomerRepository
├── screens/                     # الشاشات (20 ملف)
│   ├── screens.dart           # ملف التصدير
│   ├── login_page.dart
│   ├── homepage_screen.dart
│   ├── dashboard_screen.dart
│   ├── products_screen.dart
│   ├── orders_screen.dart
│   ├── order_details_screen.dart
│   ├── new_order_screen.dart
│   ├── customers_screen.dart
│   ├── customer_statement_screen.dart
│   ├── payments_screen.dart
│   ├── shipping_screen.dart
│   ├── inventory_screen.dart
│   ├── inventory_movements_screen.dart
│   ├── reports_screen.dart
│   ├── notifications_screen.dart
│   ├── settings_screen.dart
│   ├── profile_screen.dart
│   ├── user_management_screen.dart
│   └── system_settings_screen.dart
├── widgets/                     # مكونات UI (قيد النقل)
└── utils/                       # دوال مساعدة
    └── number_utils.dart       # معالجة الأرقام والأسعار
```

---

## 🔧 كيفية استخدام البنية الجديدة

### 1. استيراد الشاشات
```dart
import 'package:orca_app/screens/screens.dart';

// أو استيراد شاشة محددة
import 'package:orca_app/screens/orders_screen.dart';
```

### 2. استخدام Repository
```dart
import 'package:orca_app/repositories/order_repository.dart';

final orderRepo = OrderRepository();
final orders = await orderRepo.getOrders(username, token);
```

### 3. استخدام ApiService مباشرة
```dart
import 'package:orca_app/services/api_service.dart';

final api = ApiService();
final data = await api.post({'action': 'getOrders', ...});
```

### 4. استخدام النماذج
```dart
import 'package:orca_app/models/models.dart';

final order = Order.fromJson(jsonData);
print(order.totalAmount);
```

---

## ⚠️ ملاحظات مهمة

### مشكلة الأسعار (USD $0.00)
تم تحسين معالجة الأسعار في `number_utils.dart` و`order_item.dart`:

```dart
// الأولوية في قراءة السعر:
1. final_price      - السعر النهائي
2. price_offer      - سعر العرض
3. default_price    - السعر الافتراضي
4. 0.0              - قيمة افتراضية
```

**للتشخيص:**
```dart
print('Keys: ${item.keys.toList()}');
print('final_price: ${item['final_price']}');
print('price_offer: ${item['price_offer']}');
print('default_price: ${item['default_price']}');
```

### الملفات المؤرشفة
- `main_old.dart`: النسخة الأصلية (6314 سطر) - للاحتفاظ بها كمرجع
- `archive/main_backup.dart`: نسخ احتياطية قديمة
- `backend/Code.gs`: كود الـ Backend (Google Apps Script)
- `backend/ORCA_ORDER_DATABASE.xlsx`: ملف Excel

---

## 📝 الخطوات التالية

1. **نقل Widgets الكبيرة** إلى `lib/widgets/`
2. **إضافة State Management** (Provider/Bloc)
3. **كتابة اختبارات** في مجلد `test/`
4. **توثيق API** في `README.md`

---

## ✅ التحقق من العمل

بعد الهيكلة، تأكد من:
1. ✅ تطبيق Flutter يعمل بدون أخطاء
2. ✅ تسجيل الدخول يعمل
3. ✅ عرض الطلبات يعمل
4. ✅ الأسعار تظهر بشكل صحيح
5. ✅ جميع الشاشات يمكن الوصول إليها

---

## 🆘 الدعم

إذا واجهت أي مشاكل:
1. راجع سجلات الخطأ في console
2. تحقق من أن جميع الاستيرادات صحيحة
3. تأكد من أن `pubspec.yaml` يحتوي على جميع dependencies
4. شغّل `flutter clean && flutter pub get`

