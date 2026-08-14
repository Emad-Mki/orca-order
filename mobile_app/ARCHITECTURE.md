# هيكلة مشروع Orca Order - Flutter

## البنية الجديدة للملفات

```
mobile_app/
├── lib/
│   ├── main.dart                    # نقطة الدخول الرئيسية للتطبيق
│   ├── app_config.dart              # إعدادات التطبيق (API URL, الثوابت)
│   ├── order_status_mapper.dart     # تحويل حالات الطلبات
│   │
│   ├── models/                      # النماذج والكيانات
│   │   ├── models.dart              # ملف تصدير جميع النماذج
│   │   ├── product.dart             # نموذج المنتج
│   │   ├── order.dart               # نموذج الطلب
│   │   ├── order_item.dart          # نموذج صنف الطلب
│   │   └── balance_info.dart        # نموذج معلومات الرصيد
│   │
│   ├── services/                    # الخدمات (API، إشعارات، إلخ)
│   │   └── api_service.dart         # خدمة الاتصال بالـ API
│   │
│   ├── repositories/                # طبقة الربط بين الخدمات والنماذج
│   │   └── order_repository.dart    # مستودع الطلبات
│   │
│   ├── utils/                       # دوال مساعدة
│   │   └── number_utils.dart        # أدوات التعامل مع الأرقام والعملات
│   │
│   ├── widgets/                     # مكونات واجهة المستخدم القابلة لإعادة الاستخدام
│   │   └── (يتم إضافتها لاحقاً)
│   │
│   └── screens/                     # الشاشات الرئيسية
│       └── (يتم إضافتها لاحقاً)
│
├── archive/                         # ملفات قديمة ونسخ احتياطية
│   ├── main_backup.dart
│   └── main_backup_orders.dart
│
├── backend/                         # كود الـ Backend (Google Apps Script)
│   ├── Code.gs
│   └── ORCA_ORDER_DATABASE.xlsx
│
├── assets/                          # الصور والملفات الثابتة
├── android/                         # كود أندرويد الأصلي
└── test/                            # الاختبارات
```

## التحسينات المُطبقة

### 1. فصل النماذج (Models Separation)
- تم إنشاء مجلد `models/` يحتوي على نماذج منفصلة لكل كيان
- كل نموذج يحتوي على:
  - خصائص واضحة ومحددة النوع
  - دالة `fromJson` محسنة لقراءة البيانات من API
  - دالة `toJson` لتحويل النموذج إلى JSON
  - دوال مساعدة خاصة بالنموذج (مثل `displayPrice`, `total`)

### 2. تحسين معالجة الأسعار
- تم إضافة دوال مساعدة في `number_utils.dart`:
  - `parsePriceFromJson()`: لقراءة الأسعار من JSON بأمان
  - `getFinalPrice()`: الحصول على السعر النهائي بأولويات واضحة
  - `calculateTotal()`: حساب الإجمالي مع استبعاد البنود غير المتوفرة
  
- أولوية قراءة الأسعار:
  1. `final_price` - السعر النهائي المعتمد
  2. `price_offer` / `display_price_snapshot` - سعر العرض
  3. `default_price` - السعر الافتراضي من المنتج

### 3. تنظيف المشروع
- تم نقل ملفات النسخ الاحتياطية إلى مجلد `archive/`
- تقليل حجم `main.dart` بفصل النماذج والخدمات

### 4. معالجة مشكلة ظهور الأسعار بـ 0.00

#### الأسباب المحتملة والحلول:

**أ. التحقق من مصدر البيانات (Backend)**
- تأكد أن Google Apps Script (`Code.gs`) يقرأ الأعمدة الصحيحة من Excel
- تحقق أن حقول الأسعار تُرجع قيماً صحيحة وليست null أو 0

**ب. تحسين قراءة الأسعار في Flutter**
- تم تحديث `Product.fromJson()` للتحقق من حقول متعددة:
  ```dart
  price: _parsePrice(json['price'] ?? json['display_price'] ?? json['final_price'] ?? 0)
  ```

**ج. دوال parsing آمنة**
- جميع دوال تحويل الأسعار تستخدم `double.tryParse()` بدلاً من `double.parse()`
- يتم إرجاع fallback value (0.0) عند فشل التحويل بدلاً من رمي exception

**د. خطوات التشخيص**
1. أضف print() بعد استقبال البيانات للتحقق من القيم الخام:
   ```dart
   print('Raw item data: $item');
   print('Final price: ${item['final_price']}');
   print('Price offer: ${item['price_offer']}');
   ```

2. تحقق من استجابة API في `main.dart`:
   ```dart
   final data = await ApiService().post({...});
   print('API Response: $data');
   ```

### 5. الخطوات التالية المقترحة

1. **فصل الخدمات**: انقل `ApiService` إلى ملف منفصل في `services/`
2. **إضافة Repository Pattern**: أنشئ طبقة repositories للربط بين الخدمات وUI
3. **State Management**: استخدم Provider أو Bloc لإدارة الحالة
4. **اختبارات**: أضف اختبارات unit tests للنماذج ودوال الحساب
5. **فصل الشاشات**: انقل كل شاشة إلى ملف منفصل في `screens/`

## ملاحظات مهمة

- لا تقم بتعديل الملفات في `archive/` - هذه للاحتفاظ فقط
- أي تغيير في هيكل بيانات Excel يجب تحديثه في `Code.gs` وفي نماذج Flutter
- استخدم `formatMoneyShort()` للعرض السريع و `formatMoney()` للعرض التفصيلي
