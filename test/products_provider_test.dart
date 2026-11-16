import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/product.dart';
import 'package:orca_order/providers/products_provider.dart';
import 'package:orca_order/repositories/local_repository.dart';
import 'package:orca_order/repositories/product_repository.dart';
import 'package:orca_order/services/database_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late ProductsProvider provider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = AppDatabase(NativeDatabase.memory());
    await LocalRepository(database).saveProducts([
      _product('ENG-1', ' Engines ', subGroup: 'Pistons', oem: 'OEM-101'),
      _product('ENG-2', 'engines  ', subGroup: 'Filters'),
      _product('BODY-1', 'Body'),
      _product('OLD-1', '', category: 'قديم'),
    ]);
    provider = ProductsProvider(ProductRepository(database));
    await provider.fetchProducts();
  });

  tearDown(() async {
    await database.close();
  });

  test('all products remain visible by default and categories are normalized',
      () {
    expect(provider.selectedCategory, isNull);
    expect(provider.products, hasLength(4));
    expect(provider.categories, ['Body', 'Engines']);
  });

  test('selecting a parent group includes every child group only', () {
    provider.selectCategory('Engines');

    expect(
        provider.products.map((product) => product.code), ['ENG-1', 'ENG-2']);
    expect(provider.subGroups, ['Filters', 'Pistons']);

    provider.selectCategory(null);
    expect(provider.products, hasLength(4));
    expect(provider.subGroups, isEmpty);
  });

  test('selecting a child group filters within the selected parent', () {
    provider.selectCategory('Engines');
    provider.selectSubGroup('Pistons');

    expect(provider.products.map((product) => product.code), ['ENG-1']);

    provider.selectCategory('Body');
    expect(provider.selectedSubGroup, isNull);
    expect(provider.products.map((product) => product.code), ['BODY-1']);
  });

  test('search combines with group selection and matches OEM numbers', () {
    provider.selectCategory('Engines');
    provider.setSearchQuery('OEM-101');

    expect(provider.products.map((product) => product.code), ['ENG-1']);
  });

  test('view mode is saved locally without changing the product results',
      () async {
    final visibleCodes =
        provider.products.map((product) => product.code).toList();

    await provider.setViewMode(ProductViewMode.list);

    final preferences = await SharedPreferences.getInstance();
    expect(provider.viewMode, ProductViewMode.list);
    expect(preferences.getString('product_view_mode'), 'list');
    expect(provider.products.map((product) => product.code), visibleCodes);
  });

  test('refresh clears a selected group that no longer exists', () async {
    provider.selectCategory('Removed');
    await provider.fetchProducts();

    expect(provider.selectedCategory, isNull);
    expect(provider.products, hasLength(4));
  });

  test('failed manual refresh retains products and enforces the cooldown',
      () async {
    final visibleCodes =
        provider.products.map((product) => product.code).toList();

    await provider.fetchProducts(forceRefresh: true);

    expect(provider.isLoading, isFalse);
    expect(provider.errorMessage, isNotNull);
    expect(provider.products.map((product) => product.code), visibleCodes);

    await provider.fetchProducts(forceRefresh: true);

    expect(provider.lastRefreshThrottled, isTrue);
    expect(provider.manualRefreshRemaining, greaterThan(Duration.zero));
    expect(provider.products.map((product) => product.code), visibleCodes);
  });
}

Product _product(
  String code,
  String group, {
  String category = 'غير مصنف',
  String subGroup = '',
  String oem = '',
}) {
  return Product(
    code: code,
    name: code,
    category: category,
    group: group,
    subGroup: subGroup,
    oem: oem,
    origin: '',
    unit: 'piece',
    price: 0,
  );
}
