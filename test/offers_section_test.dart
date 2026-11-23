import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/product.dart';
import 'package:orca_order/providers/products_provider.dart';
import 'package:orca_order/repositories/product_repository.dart';
import 'package:orca_order/services/api_service.dart';
import 'package:orca_order/services/database_service.dart';
import 'package:orca_order/services/offers_change_notifier.dart';
import 'package:orca_order/utils/permissions.dart';
import 'package:orca_order/widgets/offers_section.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Products extends ProductRepository {
  _Products(super.db);

  @override
  Future<List<Product>> getProducts({bool forceRefresh = false}) async => [
        Product(
          code: 'P1',
          name: 'منتج',
          category: '',
          origin: '',
          unit: 'قطعة',
          price: 20,
        )
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('caches online offers, warns offline and refreshes on changes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(NativeDatabase.memory());
    final products = ProductsProvider(_Products(db));
    await products.fetchProducts();
    addTearDown(() async {
      products.dispose();
      await db.close();
    });
    var offline = false;
    var requests = 0;
    var hasOffers = true;
    Future<Map<String, dynamic>> load() async {
      requests++;
      if (offline) {
        throw const ApiException(
            code: 'NETWORK_ERROR', message: 'offline', transportFailure: true);
      }
      return {
        'server_time': '2030-01-01T00:00:00Z',
        'offers': hasOffers
            ? [
                {
                  'offer_id': 'O1',
                  'product_code': 'P1',
                  'unit': 'قطعة',
                  'currency': 'USD',
                  'old_price': 20,
                  'offer_price': 15,
                  'min_quantity': 2,
                  'ends_at': '2030-01-02T00:00:00Z',
                }
              ]
            : [],
      };
    }

    Widget app() => ChangeNotifierProvider.value(
          value: products,
          child: MaterialApp(
            home: Scaffold(
              body: OffersSection(
                session: const {'user_id': 'customer1'},
                role: AppRole.customer,
                loadOffers: load,
              ),
            ),
          ),
        );
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.text('عروض وتخفيضات'), findsOneWidget);
    expect(find.text('خصم 25.0%'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    offline = true;
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.textContaining('عروض محفوظة دون اتصال'), findsOneWidget);
    expect(find.text('خصم 25.0%'), findsOneWidget);
    offline = false;
    hasOffers = false;
    final previous = requests;
    offersRevision.value++;
    await tester.pumpAndSettle();
    expect(requests, greaterThan(previous));
    expect(find.text('عروض وتخفيضات'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
