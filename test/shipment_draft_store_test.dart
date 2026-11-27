import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/services/shipment_draft_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const store = ShipmentDraftStore();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('persists and clears shipment drafts by account scope', () async {
    await store.save('prod:user-1', {'order_id': 'ORD-1', 'bag_count': 2});
    await store.save('prod:user-2', {'order_id': 'ORD-2'});

    expect(await store.load('prod:user-1'), {
      'order_id': 'ORD-1',
      'bag_count': 2,
    });
    expect(await store.load('prod:user-2'), {'order_id': 'ORD-2'});
    await store.clear('prod:user-1');
    expect(await store.load('prod:user-1'), isNull);
    expect(await store.load('prod:user-2'), {'order_id': 'ORD-2'});
  });

  test('reports corrupt saved drafts instead of silently discarding them',
      () async {
    SharedPreferences.setMockInitialValues({
      'shipment_draft_v1_cHJvZDp1c2VyLTE=': '[]',
    });

    await expectLater(
      store.load('prod:user-1'),
      throwsFormatException,
    );
  });
}
