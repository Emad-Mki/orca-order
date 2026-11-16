import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/product.dart';
import 'package:orca_order/screens/product_detail_screen.dart';
import 'package:orca_order/widgets/product_availability_badge.dart';
import 'package:orca_order/widgets/product_card_widget.dart';

void main() {
  test('availability comes from the explicit product status only', () {
    expect(
      productAvailabilityFrom(value: 'available'),
      ProductAvailability.available,
    );
    expect(
      productAvailabilityFrom(value: 'unavailable'),
      ProductAvailability.unavailable,
    );
    expect(
      productAvailabilityFrom(
        value: 'preorder',
      ),
      ProductAvailability.preorder,
    );
    expect(
      productAvailabilityFrom(value: null),
      ProductAvailability.unknown,
    );
    expect(
      productAvailabilityFrom(
        value: 'متوفر على الطلب',
      ),
      ProductAvailability.uponRequest,
    );
    expect(
      productAvailabilityFrom(value: 'حجز مسبق'),
      ProductAvailability.preorder,
    );
    expect(
      productAvailabilityFrom(value: 'يتوفر قريبا'),
      ProductAvailability.comingSoon,
    );
  });

  testWidgets('badge shows a compact colored dot and state label', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProductAvailabilityBadge(
            availability: ProductAvailability.uponRequest,
            compact: true,
          ),
        ),
      ),
    );

    expect(find.text('متوفر على الطلب'), findsOneWidget);
    expect(find.byType(Icon), findsNothing);
    expect(find.byType(Container), findsWidgets);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'حالة المنتج: متوفر على الطلب',
      ),
      findsOneWidget,
    );
  });

  testWidgets('product cards use the stored status instead of stock quantity',
      (tester) async {
    final product = Product.fromJson({
      'code': 'P-1',
      'name': 'قطعة اختبار',
      'unit': 'قطعة',
      'quantity': 20,
      'price': 10,
      'availability_status': 'unavailable',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 180,
              height: 280,
              child: ProductCardWidget(
                product: product,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('غير متوفر'), findsOneWidget);
    expect(find.text('متوفر'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'details show required codes and unknown status without stock access',
      (tester) async {
    final product = Product.fromJson({
      'code': '',
      'name': 'قطعة اختبار طويلة الاسم',
      'category': '',
      'origin': '',
      'unit': '',
      'price': null,
      'price_configured': false,
      'oem': '',
      'availability_status': '',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ProductDetailScreen(
          product: product,
          session: const {'role': 'customer'},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('رمز المنتج'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('رقم OEM'), findsOneWidget);
    expect(find.text('_'), findsOneWidget);
    expect(find.text('المنشأ'), findsOneWidget);
    expect(find.text('غير محدد'), findsOneWidget);
    expect(find.text('غير محددة'), findsOneWidget);
    expect(find.text('سعر البيع'), findsOneWidget);
    expect(find.text('الكمية المسجلة:'), findsNothing);
    expect(find.text('إضافة إلى طلب جديد'), findsOneWidget);
  });

  testWidgets('details remain readable in dark theme with enlarged text',
      (tester) async {
    final product = Product(
      code: 'PRODUCT-CODE-WITH-A-LONG-IDENTIFIER',
      name: 'اسم منتج طويل جدًا لاختبار التفاف النص داخل صفحة التفاصيل',
      category: 'الفئة',
      group: 'مجموعة طويلة الاسم للاختبار',
      subGroup: 'مجموعة فرعية',
      origin: 'منشأ طويل للاختبار',
      oem: 'OEM-12345678901234567890',
      unit: 'قطعة',
      price: 12,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.6),
            ),
            child: ProductDetailScreen(
              product: product,
              session: const {'role': 'customer'},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('رقم OEM'), findsOneWidget);
    expect(find.text('غير محددة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
