import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/product.dart';
import 'package:orca_order/providers/products_provider.dart';
import 'package:orca_order/repositories/local_repository.dart';
import 'package:orca_order/repositories/product_repository.dart';
import 'package:orca_order/screens/products_screen.dart';
import 'package:orca_order/services/database_service.dart';
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
}
