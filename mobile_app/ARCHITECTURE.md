# 🏗️ هيكلة تطبيق Orca Order - الدليل الكامل

## 📋 ملخص التحسينات المنفذة

### 1. **الهيكلية الجديدة للمجلدات**
```
lib/
├── main.dart                 # نقطة البداية (يحتوي على UI فقط)
├── app_config.dart           # إعدادات التطبيق
├── order_status_mapper.dart  # تحويل حالات الطلب
├── models/                   # النماذج والكيانات
│   ├── models.dart          # ملف التصدير
│   ├── product.dart         # نموذج المنتج
│   ├── order.dart           # نموذج الطلب (محدث)
│   ├── order_item.dart      # نموذج صنف الطلب
│   └── balance_info.dart    # نموذج الرصيد
├── services/                 # خدمات الاتصال
│   ├── services.dart        # ملف التصدير
│   └── api_service.dart     # خدمة API
├── repositories/             # طبقة الربط بين Models و Services
│   ├── repositories.dart    # ملف التصدير
│   └── order_repository.dart# مستودع الطلبات والمنتجات
├── screens/                  # الشاشات (فارغ - جاهز للنقل)
├── widgets/                  # مكونات UI (فارغ - جاهز للنقل)
└── utils/                    # دوال مساعدة
    ├── utils.dart
    └── number_utils.dart
```

### 2. **الملفات المؤرشفة**
- `archive/main_backup.dart` - نسخة احتياطية قديمة
- `archive/main_backup_orders.dart` - نسخة احتياطية للطلبات
- `backend/Code.gs` - سكربت Google Apps
- `backend/ORCA_ORDER_DATABASE.xlsx` - ملف البيانات

---

## 🔧 التحسينات المُطبقة

### ✅ 1. فصل ApiService إلى ملف مستقل
**الموقع:** `lib/services/api_service.dart`

**الفوائد:**
- كود أنظف في `main.dart`
- سهولة اختبار الخدمة بشكل منفصل
- إمكانية إعادة استخدام الخدمة في أي مكان

**الدوال المتاحة:**
```dart
- isOnline() -> Future<bool>
- getCachedProducts() -> Future<List<Map<String, dynamic>>>
- cacheProducts(List<Map<String, dynamic>>) -> Future<void>
- getLastCacheTimestamp() -> Future<DateTime?>
- post(Map<String, dynamic>) -> Future<Map<String, dynamic>>
- getProducts({forceRefresh}) -> Future<Map<String, dynamic>>
- login(username, password) -> Future<Map<String, dynamic>>
- getOrders({customerId, status}) -> Future<Map<String, dynamic>>
- getOrderDetails(orderId) -> Future<Map<String, dynamic>>
- createOrder(orderData) -> Future<Map<String, dynamic>>
- updateOrderStatus(orderId, status) -> Future<bool>
- getCustomers() -> Future<Map<String, dynamic>>
- getCustomerStatement(customerId) -> Future<Map<String, dynamic>>
- saveOrderPricing(orderId, items) -> Future<bool>
```

### ✅ 2. إنشاء طبقة Repositories
**الموقع:** `lib/repositories/order_repository.dart`

**الفوائد:**
- فصل منطق الأعمال عن واجهة المستخدم
- توحيد طريقة جلب البيانات
- سهولة التبديل بين مصادر البيانات (API، Cache، Local DB)

**المستودعات المتاحة:**

#### OrderRepository
```dart
- getOrders({customerId, status}) -> Future<List<Order>>
- getOrderDetails(orderId) -> Future<Order?>
- createOrder(Order) -> Future<String>
- updateOrderStatus(orderId, status) -> Future<bool>
- saveOrderPricing(orderId, items) -> Future<bool>
```

#### ProductRepository
```dart
- getProducts({forceRefresh}) -> Future<List<Product>>
- searchProducts(query) -> Future<List<Product>>
- getLastCacheTimestamp() -> Future<DateTime?>
- isOnline() -> Future<bool>
```

#### CustomerRepository
```dart
- getCustomers() -> Future<List<Map<String, dynamic>>>
- getCustomerStatement(customerId) -> Future<BalanceInfo?>
```

### ✅ 3. تحسين نماذج البيانات

#### Order Model (محدث)
**الموقع:** `lib/models/order.dart`

**الإضافات الجديدة:**
```dart
final double totalAmount;        // إجمالي الطلب
final double previousBalance;    // الرصيد السابق
final double currentBalance;     // الرصيد الحالي
final List<OrderItem>? items;    // عناصر الطلب
```

**تحسينات fromJson:**
- دالة `parsePrice()` مدمجة لقراءة الأسعار بأمان
- دعم حقول متعددة: `total_amount`, `total`, `grand_total`
- تحليل العناصر تلقائياً إذا كانت موجودة
- معالجة أفضل للتنسيقات المختلفة (`$`, `USD`, `,`)

#### OrderItem Model
**الموقع:** `lib/models/order_item.dart`

**الميزات:**
```dart
// أولوية قراءة الأسعار
double get displayPrice {
  if (finalPrice > 0) return finalPrice;
  if (priceOffer > 0) return priceOffer;
  return defaultPrice;
}

// حساب الإجمالي التلقائي
double get total => displayPrice * quantityApproved;

// التحقق من عدم التوفر
bool get isUnavailable => status == 'unavailable';
```

---

## 🎯 حل مشكلة USD $0.00

### السبب الجذري
كانت الأسعار تُقرأ من حقل واحد فقط وقد يكون:
1. الحقل غير موجود في الاستجابة
2. الحقل يحتوي على نص غير قابل للتحويل
3. تنسيق السعر مختلف (فاصلة بدلاً من نقطة)

### الحل المُطبق

#### 1. في OrderItem.fromJson()
```dart
double parsePrice(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  
  String str = value.toString().trim();
  if (str.isEmpty || str.toLowerCase() == 'null') return 0.0;
  
  // إزالة الرموز: $, USD, SYP, الفواصل
  str = str.replaceAll(',', '')
           .replaceAll('\$', '')
           .replaceAll('USD', '')
           .replaceAll('SYP', '')
           .replaceAll(' ', '');
  
  return double.tryParse(str) ?? 0.0; // لا يرمي استثناء
}
```

#### 2. أولويات قراءة الأسعار
```dart
priceOffer: parsePrice(json['price_offer'] ?? json['display_price_snapshot']),
defaultPrice: parsePrice(json['default_price']),
finalPrice: parsePrice(json['final_price']),

// في getter
double get displayPrice {
  if (finalPrice > 0) return finalPrice;  // الأولوية الأولى
  if (priceOffer > 0) return priceOffer;  // الأولوية الثانية
  return defaultPrice;                     //Fallback
}
```

#### 3. في Order Model
```dart
totalAmount: parsePrice(json['total_amount'] ?? json['total'] ?? json['grand_total']),
previousBalance: parsePrice(json['previous_balance']),
currentBalance: parsePrice(json['current_balance'] ?? json['balance']),
```

---

## 📝 خطوات الاستخدام

### 1. استيراد الخدمات والنماذج
```dart
import 'package:orca_app/models/models.dart';
import 'package:orca_app/services/services.dart';
import 'package:orca_app/repositories/repositories.dart';
```

### 2. استخدام Repository بدلاً من ApiService مباشرة
```dart
// ❌ الطريقة القديمة
final api = ApiService();
final response = await api.post({'action': 'getOrders'});
final orders = response['orders'];

// ✅ الطريقة الجديدة
final orderRepo = OrderRepository();
final orders = await orderRepo.getOrders(); // List<Order> قوي النوع
```

### 3. التعامل مع المنتجات
```dart
final productRepo = ProductRepository();

// جلب كل المنتجات
final products = await productRepo.getProducts();

// البحث
final results = await productRepo.searchProducts('أرز');

// التحقق من الكاش
final lastCache = await productRepo.getLastCacheTimestamp();
```

### 4. عرض تفاصيل الطلب
```dart
final orderRepo = OrderRepository();
final order = await orderRepo.getOrderDetails(orderId);

if (order != null) {
  print('الإجمالي: ${order.totalAmount}');
  print('الرصيد السابق: ${order.previousBalance}');
  
  for (var item in order.items ?? []) {
    print('${item.name}: ${item.displayPrice} × ${item.quantityApproved}');
  }
}
```

---

## 🔍 تشخيص مشكلة الأسعار (إذا استمرت)

### الخطوة 1: فحص استجابة API
أضف هذا الكود مؤقتاً في `main.dart` عند استقبال الطلب:

```dart
// في دالة جلب تفاصيل الطلب
print('=== DEBUG: ORDER RESPONSE ===');
print('Full Response: $response');

if (response['items']?.isNotEmpty == true) {
  var firstItem = response['items'][0];
  print('First Item Keys: ${firstItem.keys.toList()}');
  print('final_price: ${firstItem['final_price']}');
  print('price_offer: ${firstItem['price_offer']}');
  print('default_price: ${firstItem['default_price']}');
  print('display_price_snapshot: ${firstItem['display_price_snapshot']}');
}
```

### الخطوة 2: التحقق من Backend
راجع ملف `backend/Code.gs`:
```javascript
// تأكد أن السكربت يرجع الحقول الصحيحة
function _handleOrderDetails(params) {
  // ...
  return {
    ok: true,
    order: orderData,
    items: items.map(item => ({
      item_id: item.id,
      final_price: item.final_price,  // ✔ تأكد من وجود هذا الحقل
      price_offer: item.price_offer,  // ✔
      default_price: item.default_price, // ✔
      // ...
    }))
  };
}
```

### الخطوة 3: فحص ملف Excel
- افتح `backend/ORCA_ORDER_DATABASE.xlsx`
- تحقق من ورقة `OrderItems` أو ما يماثلها
- تأكد أن أعمدة الأسعار تحتوي على قيم رقمية وليست نصوصاً
- تحقق من أن الأعمدة لها أسماء صحيحة (`final_price`, `price_offer`, إلخ)

---

## 🚀 الخطوات التالية المقترحة

### 1. نقل الشاشات إلى مجلد screens/
```bash
lib/screens/
├── login_screen.dart
├── home_screen.dart
├── dashboard_screen.dart
├── products_screen.dart
├── orders_screen.dart
├── order_details_screen.dart
├── new_order_screen.dart
├── customers_screen.dart
└── ...
```

### 2. إضافة State Management
اختر أحدها:
- **Provider** - سهل وبسيط
- **Bloc/Cubit** - قوي ومنظم
- **Riverpod** - حديث ومرن

### 3. نقل Widgets الكبيرة
```bash
lib/widgets/
├── product_card.dart
├── order_tile.dart
├── price_display.dart
├── status_badge.dart
└── ...
```

### 4. إضافة اختبارات
```bash
test/
├── models/
│   ├── order_test.dart
│   └── product_test.dart
├── repositories/
│   └── order_repository_test.dart
└── services/
    └── api_service_test.dart
```

### 5. توثيق API
أنشئ ملف `API_DOCUMENTATION.md` يوضح:
- جميع الـ Actions المتاحة
- المعاملات المطلوبة لكل Action
- هيكل الاستجابة المتوقع

---

## ⚠️ ملاحظات مهمة

### الحفاظ على الوظائف الحالية
- ✅ جميع التغييرات **لا تكسر** الكود الحالي
- ✅ `ApiService` ما زال يعمل بنفس الطريقة
- ✅ يمكن استخدام الطرق القديمة والجديدة معاً

### التوافق مع الكود القديم
```dart
// الكود القديم ما زال يعمل
class OrderItem {
  final Product product;
  double quantity;
  // ...
}

// الكود الجديد متاح أيضاً
class OrderItem {
  final String itemId;
  final double finalPrice;
  // ...
}
```

### الأداء
- التخزين المؤقت لم يتغير
- عدد طلبات الشبكة لم يزد
- التحسينات كلها في تنظيم الكود فقط

---

## 📞 الدعم

إذا واجهت أي مشكلة:
1. راجع رسائل الخطأ في Console
2. تحقق من Logs باستخدام `print()`
3. تأكد من تحديث `pubspec.yaml` إذا أضفت مكتبات جديدة
4. شغّل `flutter clean` ثم `flutter pub get`

---

**تم التحديث:** 2025
**الحالة:** ✅ مكتمل
