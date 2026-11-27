import 'package:drift/native.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/product.dart';
import 'package:orca_order/providers/products_provider.dart';
import 'package:orca_order/repositories/local_repository.dart';
import 'package:orca_order/repositories/product_repository.dart';
import 'package:orca_order/screens/products_screen.dart';
import 'package:orca_order/screens/product_detail_screen.dart';
import 'package:orca_order/services/database_service.dart';
import 'package:orca_order/services/guide_coordinator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late ProductsProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(NativeDatabase.memory());
    await LocalRepository(database).saveProducts(
      List.generate(
        4,
        (index) => Product(
          id: index + 1,
          code: 'ITEM-${index + 1}',
          name: 'منتج ${index + 1}',
          category: 'الفئة',
          group: 'الفئة',
          origin: '',
          unit: 'قطعة',
          price: 10,
        ),
      ),
    );
    provider = ProductsProvider(ProductRepository(database));
    await provider.fetchProducts();
  });

  tearDown(() async {
    GuideCoordinator.ready = false;
    await database.close();
  });

  testWidgets('phone catalog starts in two-column grid and switches to rows',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(
          home: ProductsScreen(session: {'role': 'customer'}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cards = find.byType(Card);
    expect(cards, findsNWidgets(4));
    final first = tester.getCenter(cards.at(0));
    final second = tester.getCenter(cards.at(1));
    expect((first.dx - second.dx).abs(), greaterThan(40));
    expect((first.dy - second.dy).abs(), lessThan(2));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('عرض السطور'));
    await tester.pumpAndSettle();

    final firstRow = tester.getCenter(cards.at(0));
    final secondRow = tester.getCenter(cards.at(1));
    expect((firstRow.dy - secondRow.dy).abs(), greaterThan(40));
    expect((firstRow.dx - secondRow.dx).abs(), lessThan(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens one product detail and returns to the catalog',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(
        home: ProductsScreen(session: {'role': 'customer'}),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('منتج 1').first);
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsNothing);
    expect(find.text('منتج 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category filters hide on scroll down and return on scroll up',
      (tester) async {
    await LocalRepository(database).saveProducts(
      List.generate(
        30,
        (index) => Product(
          id: index + 1,
          code: 'ITEM-${index + 1}',
          name: 'منتج ${index + 1}',
          category: 'الفئة',
          group: 'الفئة',
          origin: '',
          unit: 'قطعة',
          price: 10,
        ),
      ),
    );
    final scrollingProvider = ProductsProvider(ProductRepository(database));
    await scrollingProvider.fetchProducts();

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: scrollingProvider,
      child: const MaterialApp(
        home: ProductsScreen(session: {'role': 'customer'}),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('الفئة'), findsOneWidget);

    await tester.drag(find.byType(GridView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byTooltip('العودة إلى أعلى القائمة'), findsOneWidget);

    await tester.drag(find.byType(GridView), const Offset(0, 250));
    await tester.pumpAndSettle();

    expect(find.text('الفئة'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scroll-to-top control returns the product list to its start',
      (tester) async {
    await LocalRepository(database).saveProducts(
      List.generate(
        30,
        (index) => Product(
          id: index + 1,
          code: 'ITEM-${index + 1}',
          name: 'منتج ${index + 1}',
          category: 'الفئة',
          group: 'الفئة',
          origin: '',
          unit: 'قطعة',
          price: 10,
        ),
      ),
    );
    final scrollingProvider = ProductsProvider(ProductRepository(database));
    await scrollingProvider.fetchProducts();

    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: scrollingProvider,
      child: const MaterialApp(
        home: ProductsScreen(session: {'role': 'customer'}),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(GridView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byTooltip('العودة إلى أعلى القائمة'), findsOneWidget);

    await tester.tap(find.byTooltip('العودة إلى أعلى القائمة'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('العودة إلى أعلى القائمة'), findsNothing);
    expect(find.byType(ChoiceChip), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion keeps product navigation available',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: provider,
      child: const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: ProductsScreen(session: {'role': 'customer'}),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final transition = tester.widget<OpenContainer<void>>(
      find.byType(OpenContainer<void>).first,
    );
    expect(transition.transitionDuration, Duration.zero);
    await tester.tap(find.text('منتج 1').first);
    await tester.pumpAndSettle();
    expect(find.byType(ProductDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product guide runs only when visible and records skip',
      (tester) async {
    GuideCoordinator.ready = true;
    Widget page(bool visible) => ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: ProductsScreen(
              session: const {'role': 'customer', 'user_id': 'product-user'},
              guideVisible: visible,
            ),
          ),
        );
    await tester.pumpWidget(page(false));
    await tester.pumpAndSettle();
    expect(find.text('تخطي'), findsNothing);
    await tester.pumpWidget(page(true));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('تخطي'), findsOneWidget);
    expect(find.text('ابحث عن المنتج بالاسم أو الرمز أو رقم OEM.'),
        findsOneWidget);
    await tester.tap(find.text('التالي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pump();
    expect(find.text('بدّل بين عرض البطاقات وعرض السطور حسب تفضيلك.'),
        findsOneWidget);
    await tester.tap(find.text('تخطي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('guide.products.v1.product-user'), 'skipped');
    await tester.pumpWidget(page(false));
    await tester.pumpWidget(page(true));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('تخطي'), findsNothing);
  });
}
