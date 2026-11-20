import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/order_draft.dart';
import 'package:orca_order/models/product.dart';
import 'package:orca_order/repositories/local_repository.dart';
import 'package:orca_order/services/database_service.dart';

void main() {
  late AppDatabase database;
  late LocalRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = LocalRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('saving refreshed products removes stale cache entries', () async {
    await repository.saveProducts([
      _product('old', price: 2),
      _product('updated', price: 3),
    ]);

    await repository.saveProducts([
      _product('updated', price: 4),
    ]);

    final products = await repository.getProducts();
    expect(products.map((product) => product.code), ['updated']);
    expect(products.single.price, 4);
  });

  test('clearing product cache preserves account drafts', () async {
    await repository.saveProducts([_product('cached', price: 2)]);
    await repository.saveDraft(OrderDraft(
      customerId: 'customer-1',
      customerName: 'Customer',
      updatedAt: DateTime(2026),
      items: const [],
    ));
    await repository.clearProductCache();
    expect(await repository.getProducts(), isEmpty);
    expect(await repository.getAllDrafts(), hasLength(1));
  });

  test('saving a draft persists product snapshots in the draft items table',
      () async {
    final product = _product('snapshot-item', price: 7);
    await repository.saveDraft(OrderDraft(
      customerId: 'customer-1',
      customerName: 'Customer',
      updatedAt: DateTime(2026),
      items: [
        DraftItem(
          productCode: product.code,
          productName: product.name,
          unit: product.unit,
          quantity: 2,
          price: product.price,
          originalProduct: product,
        ),
      ],
    ));

    final drafts = await repository.getAllDrafts();
    expect(drafts.single.items.single.originalProduct?.code, product.code);
  });

  test('upgrades legacy draft items missing product_data_json', () async {
    await database.close();
    database = AppDatabase(
      NativeDatabase.memory(
        setup: (database) {
          database.execute('''
            CREATE TABLE order_drafts (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              environment TEXT NOT NULL,
              account_id TEXT NOT NULL,
              customer_id TEXT NOT NULL,
              customer_name TEXT NOT NULL,
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0,
              note TEXT,
              status TEXT NOT NULL DEFAULT 'draft'
            )
          ''');
          database.execute('''
            CREATE TABLE order_draft_items (
              id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
              draft_id INTEGER NOT NULL REFERENCES order_drafts(id) ON DELETE CASCADE,
              product_code TEXT NOT NULL,
              product_name TEXT NOT NULL,
              unit TEXT NOT NULL,
              quantity_micros INTEGER NOT NULL,
              price_micros INTEGER NOT NULL,
              note TEXT
            )
          ''');
          database.execute('PRAGMA user_version = 3');
        },
      ),
    );

    repository = LocalRepository(database);
    final product = _product('migrated-item', price: 5);
    await repository.saveDraft(OrderDraft(
      customerId: 'customer-1',
      customerName: 'Customer',
      updatedAt: DateTime(2026),
      items: [
        DraftItem(
          productCode: product.code,
          productName: product.name,
          unit: product.unit,
          quantity: 1,
          price: product.price,
          originalProduct: product,
        ),
      ],
    ));

    final drafts = await repository.getAllDrafts();
    expect(drafts.single.items.single.originalProduct?.code, product.code);
  });
}

Product _product(String code, {required double price}) => Product(
      code: code,
      name: code,
      category: 'Category',
      origin: '',
      unit: 'piece',
      price: price,
    );
