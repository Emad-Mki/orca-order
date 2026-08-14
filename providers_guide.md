# دليل استخدام Providers في تطبيق Orca Order

## نظرة عامة

تم تطبيق نمط **Provider** لإدارة الحالة في التطبيق، مما يوفر:
- فصل منطق الأعمال عن واجهة المستخدم
- إدارة مركزية للحالة
- تحسين الأداء بتجنب إعادة البناء غير الضروري
- سهولة الاختبار والصيانة

## الـ Providers المتوفرة

### 1. AuthProvider
**المسار:** `lib/providers/auth_provider.dart`

**المسؤوليات:**
- إدارة حالة تسجيل الدخول/الخروج
- تخزين بيانات المستخدم الحالي
- التحقق من الصلاحيات

**الاستخدام:**
```dart
// الحصول على provider
final authProvider = context.watch<AuthProvider>();

// الوصول للبيانات
final user = authProvider.currentUser;
final role = authProvider.userRole;
final isAuthenticated = authProvider.isAuthenticated;

// تسجيل الدخول
final success = await authProvider.login(username, password);

// تسجيل الخروج
await authProvider.logout();
```

---

### 2. OrdersProvider
**المسار:** `lib/providers/orders_provider.dart`

**المسؤوليات:**
- جلب قائمة الطلبات
- الفلترة حسب الحالة
- البحث برقم الطلب أو اسم العميل
- إضافة/تحديث/حذف الطلبات

**الاستخدام:**
```dart
final ordersProvider = context.watch<OrdersProvider>();

// جلب الطلبات
await ordersProvider.fetchOrders(status: 'pending');

// الوصول للقائمة المفلترة
final orders = ordersProvider.orders;

// تحديث الفلتر
ordersProvider.setFilter('priced');

// البحث
ordersProvider.setSearchQuery('OR-2024');

// إعادة تعيين الفلاتر
ordersProvider.resetFilters();
```

---

### 3. OrderDetailProvider
**المسار:** `lib/providers/order_detail_provider.dart`

**المسؤوليات:**
- جلب تفاصيل طلب معين
- إدارة عملية التسعير
- تعديل أسعار وكميات البنود
- حساب المجاميع (subtotal, total)

**الاستخدام:**
```dart
final detailProvider = context.watch<OrderDetailProvider>();

// جلب التفاصيل
await detailProvider.fetchOrderDetails(orderId);

// الوصول للبيانات
final order = detailProvider.currentOrder;
final items = detailProvider.items;
final subtotal = detailProvider.subtotal;
final total = detailProvider.total;

// تحديث سعر صنف
detailProvider.updateItemPrice(itemId, newPrice);

// تحديث الخصم
detailProvider.setDiscount(50.0);

// حفظ التسعير
final success = await detailProvider.savePricing();
```

---

### 4. ProductsProvider
**المسار:** `lib/providers/products_provider.dart`

**المسؤوليات:**
- جلب كتالوج المنتجات
- البحث والتصنيف
- إدارة الفلاتر

**الاستخدام:**
```dart
final productsProvider = context.watch<ProductsProvider>();

// جلب المنتجات
await productsProvider.fetchProducts();

// الوصول للمنتجات المفلترة
final products = productsProvider.products;

// الحصول على التصنيفات
final categories = productsProvider.categories;

// البحث
productsProvider.setSearchQuery('bearing');

// فلترة حسب التصنيف
productsProvider.setCategory('Engine Parts');

// إعادة التعيين
productsProvider.resetFilters();
```

---

### 5. CustomerProvider
**المسار:** `lib/providers/customer_provider.dart`

**المسؤوليات:**
- إدارة بيانات العملاء
- تحديث الأرصدة
- تسجيل الدفعات

**الاستخدام:**
```dart
final customerProvider = context.watch<CustomerProvider>();

// جلب العملاء
await customerProvider.fetchCustomers();

// الوصول للعملاء
final customers = customerProvider.customers;

// تحديث الرصيد
await customerProvider.updateCustomerBalance(customerId, newBalance);

// تسجيل دفعة
await customerProvider.recordPayment(customerId, amount, notes: 'دفعة مقدمة');
```

---

## أفضل الممارسات

### 1. استخدام `watch` vs `read`

```dart
// استخدم watch داخل build للوصول للبيانات وإعادة البناء عند التغيير
final orders = context.watch<OrdersProvider>().orders;

// استخدم read للأحداث التي لا تحتاج إعادة بناء
context.read<OrdersProvider>().fetchOrders();
```

### 2. تجنب إعادة البناء غير الضروري

```dart
// ❌ سيء: يعيد بناء widget بأكمله
@override
Widget build(BuildContext context) {
  final provider = context.watch<MyProvider>();
  return Column(
    children: [
      Text(provider.someValue), // فقط هذا يحتاج تحديث
      OtherWidget(), // لا يتأثر
    ],
  );
}

// ✅ جيد: عزل الجزء المتأثر
@override
Widget build(BuildContext context) {
  return Column(
    children: [
      Consumer<MyProvider>(
        builder: (context, provider, _) => Text(provider.someValue),
      ),
      OtherWidget(),
    ],
  );
}
```

### 3. استخدام Consumer للودجات الصغيرة

```dart
Consumer<AuthProvider>(
  builder: (context, auth, _) => Text('مرحباً ${auth.currentUser?.name}'),
)
```

### 4. الوصول للـ Provider خارج شجرة الودجات

```dart
// في دالة غير widget
final provider = Provider.of<OrdersProvider>(context, listen: false);
await provider.fetchOrders();
```

---

## مثال كامل: شاشة تستخدم Provider

```dart
class OrdersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('الطلبات')),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(hintText: 'بحث...'),
              onChanged: (query) {
                context.read<OrdersProvider>().setSearchQuery(query);
              },
            ),
          ),
          
          // قائمة الطلبات
          Expanded(
            child: Consumer<OrdersProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return Center(child: CircularProgressIndicator());
                }
                
                if (provider.orders.isEmpty) {
                  return Center(child: Text('لا توجد طلبات'));
                }
                
                return ListView.builder(
                  itemCount: provider.orders.length,
                  itemBuilder: (context, index) {
                    final order = provider.orders[index];
                    return ListTile(
                      title: Text(order.orderNumber ?? ''),
                      subtitle: Text(order.customerName ?? ''),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.read<OrdersProvider>().fetchOrders();
        },
        child: Icon(Icons.refresh),
      ),
    );
  }
}
```

---

## استكشاف الأخطاء

### المشكلة: الـ widget لا يتحدثث عند تغيير البيانات
**الحل:** تأكد من استخدام `notifyListeners()` بعد أي تغيير في البيانات.

### المشكلة: إعادة بناء متكررة
**الحل:** استخدم `Consumer` بدلاً من `watch` للودجات الكبيرة.

### المشكلة: خطأ "Provider not found"
**الحل:** تأكد من أن الـ Provider مسجل في `MultiProvider` في `main.dart`.

---

## الملفات المحدثة

1. `/workspace/mobile_app/lib/main.dart` - إضافة MultiProvider
2. `/workspace/mobile_app/lib/providers/` - مجلد الـ Providers الجديد
3. `/workspace/mobile_app/pubspec.yaml` - إضافة مكتبة provider

## الخطوة التالية

الانتقال إلى **الخطوة 2.3**: إكمال الدوال الناقصة في `OrderRepository` لدعم الـ Providers الجديدة.
