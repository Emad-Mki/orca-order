# ملخص إعادة الهيكلة - Orca Order Flutter App

## التاريخ
تمت إعادة الهيكلة: 2024

## التغييرات المُطبقة

### 1. هيكلة المجلدات الجديدة

#### ✅ تم الإنشاء:
```
lib/
├── models/           # النماذج والكيانات
│   ├── models.dart
│   ├── product.dart
│   ├── order.dart
│   ├── order_item.dart
│   └── balance_info.dart
│
├── utils/            # الدوال المساعدة
│   ├── utils.dart
│   └── number_utils.dart
│
├── services/         # الخدمات (فارغ - للتمديد المستقبلي)
├── repositories/     # طبقة الربط (فارغ - للتمديد المستقبلي)
├── widgets/          # مكونات UI (فارغ - للتمديد المستقبلي)
└── screens/          # الشاشات (فارغ - للتمديد المستقبلي)

archive/              # ملفات النسخ الاحتياطي
├── main_backup.dart
└── main_backup_orders.dart

backend/              # كود الـ Backend (مفصول)
├── Code.gs
└── ORCA_ORDER_DATABASE.xlsx
```

### 2. الملفات الجديدة

| الملف | الوصف |
|------|-------|
| `models/product.dart` | نموذج المنتج مع تحسين قراءة الأسعار |
| `models/order.dart` | نموذج الطلب |
| `models/order_item.dart` | نموذج صنف الطلب مع دوال حساب الإجمالي |
| `models/balance_info.dart` | نموذج معلومات الرصيد |
| `models/models.dart` | ملف تصدير جميع النماذج |
| `utils/utils.dart` | ملف تصدير الدوال المساعدة |
| `ARCHITECTURE.md` | دليل الهيكلة والتحسينات |
| `.gitignore` | ملفات تجاهل Git |

### 3. التحسينات على `number_utils.dart`

#### دوال جديدة:
- `parsePriceFromJson()` - لقراءة الأسعار من JSON بأمان

#### تحسينات على دوال موجودة:
- `getFinalPrice()` - إضافة `default_price` كأولوية أخيرة
- `calculateTotal()` - تحسين قراءة الكميات من حقول متعددة

### 4. تنظيف المشروع

✅ نقل ملفات النسخ الاحتياطية إلى `archive/`
✅ نقل ملفات الـ Backend إلى `backend/`
✅ إنشاء `.gitignore` لاستبعاد الملفات غير الضرورية

### 5. حل مشكلة ظهور الأسعار بـ 0.00

#### التحسينات المُطبقة:

**أ. في نماذج Flutter:**
```dart
// Product.fromJson()
price: _parsePrice(json['price'] ?? 
                   json['display_price'] ?? 
                   json['final_price'] ?? 
                   0)

// OrderItem.fromJson()
finalPrice: parsePrice(json['final_price']),
priceOffer: parsePrice(json['price_offer'] ?? json['display_price_snapshot']),
defaultPrice: parsePrice(json['default_price']),
```

**ب. أولوية قراءة الأسعار:**
1. `final_price` - السعر النهائي المعتمد
2. `price_offer` / `display_price_snapshot` - سعر العرض
3. `default_price` - السعر الافتراضي
4. `0.0` - قيمة افتراضية أخيرة

**ج. معالجة آمنة للنصوص:**
- إزالة الرموز: `$`, `USD`, `SYP`, `,`, مسافات
- استخدام `double.tryParse()` بدلاً من `double.parse()`
- إرجاع `fallback` عند فشل التحويل

### 6. خطوات التشخيص المقترحة

إذا استمرت مشكلة ظهور الأسعار بـ 0.00:

#### الخطوة 1: فحص استجابة API
أضف في `main.dart` عند استقبال البيانات:
```dart
print('=== DEBUG: API Response ===');
print('Full response: $data');
print('Items: ${data['items']}');
if (data['items'] != null && data['items'].isNotEmpty) {
  print('First item: ${data['items'][0]}');
  print('Final price: ${data['items'][0]['final_price']}');
  print('Price offer: ${data['items'][0]['price_offer']}');
  print('Default price: ${data['items'][0]['default_price']}');
}
```

#### الخطوة 2: فحص Google Apps Script
تحقق في `backend/Code.gs` من:
- دالة `_handleOrderDetails()` ترجع الحقول الصحيحة
- قراءة الأعمدة من Excel صحيحة
- تحويل القيم إلى أرقام قبل الإرسال

#### الخطوة 3: فحص ملف Excel
- تأكد أن أعمدة الأسعار تحتوي على قيم رقمية وليست نصية
- تحقق من أسماء الأعمدة تتطابق مع الكود
- تأكد عدم وجود صيغ Excel تُرجع نص فارغ

### 7. الخطوات التالية المقترحة

#### قريباً:
1. ☐ نقل `ApiService` إلى `services/api_service.dart`
2. ☐ إنشاء `repositories/order_repository.dart`
3. ☐ فصل الشاشات الكبيرة إلى `screens/`
4. ☐ إضافة state management (Provider/Bloc)

#### مستقبلاً:
1. ☐ إضافة اختبارات unit tests
2. ☐ إضافة integration tests
3. ☐ تحسين معالجة الأخطاء
4. ☐ إضافة logging system
5. ☐ دعم offline mode أفضل

## ملاحظات مهمة

⚠️ **تحذيرات:**
- لا تعدل ملفات `archive/` - للاحتفاظ فقط
- أي تغيير في هيكل Excel يجب تحديثه في:
  - `backend/Code.gs`
  - `lib/models/*.dart`
  
✅ **أفضل الممارسات:**
- استخدم `formatMoneyShort()` للعرض السريع
- استخدم `formatMoney()` للعرض التفصيلي
- استخدم النماذج الجديدة بدلاً من الكود القديم في `main.dart`

## التحقق من النجاح

✅ النماذج الجديدة موجودة وتعمل
✅ دوال الأسعار محسّنة
✅ ملفات backup منزوعة من مسار الإنتاج
✅ Backend مفصول في مجلد مستقل
✅ توثيق كامل متوفر

## التواصل

إذا واجهت أي مشاكل:
1. راجع `ARCHITECTURE.md` لفهم الهيكلة
2. اتبع خطوات التشخيص أعلاه
3. تحقق من logs في console
