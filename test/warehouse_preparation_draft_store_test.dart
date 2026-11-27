import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/services/warehouse_preparation_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const store = WarehousePreparationDraftStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists and clears drafts independently for each order/account',
      () async {
    const firstScope = 'prod:user-1:order-1';
    const secondScope = 'prod:user-1:order-2';
    final draft = {
      'items': [
        {
          'item_id': 'item-1',
          'quantity_prepared': '3',
          'warehouse_package_type': 'carton',
        },
      ],
      'warehouse_note': 'ملاحظة',
    };

    await store.save(firstScope, draft);
    await store.save(secondScope, {'items': []});

    expect(await store.load(firstScope), draft);
    expect(await store.load(secondScope), {'items': []});
    await store.clear(firstScope);
    expect(await store.load(firstScope), isNull);
    expect(await store.load(secondScope), {'items': []});
  });

  test('surfaces corrupt draft data', () async {
    SharedPreferences.setMockInitialValues({
      'warehouse_preparation_draft_v1_cHJvZDp1c2VyLTE6b3JkZXItMQ==': '[]',
    });

    await expectLater(
      store.load('prod:user-1:order-1'),
      throwsFormatException,
    );
  });
}
