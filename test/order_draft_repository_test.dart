import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/order_draft.dart';
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

  test('draft create, update, reload, and delete preserve foreign keys',
      () async {
    final id = await repository.saveDraft(_draft(
      items: [_item('OLD-1', 1)],
    ));
    expect(await _draftItemCount(database, id), 1);

    final updatedId = await repository.saveDraft(_draft(
      id: id,
      currency: 'SYP',
      items: [_item('NEW-1', 3), _item('NEW-2', 2)],
    ));
    expect(updatedId, id);

    final reloaded = await repository.getAllDrafts();
    expect(reloaded, hasLength(1));
    expect(reloaded.single.id, id);
    expect(reloaded.single.currency, 'SYP');
    expect(
      reloaded.single.items.map((item) => item.productCode),
      ['NEW-1', 'NEW-2'],
    );

    await repository.deleteDraft(id);
    expect(await repository.getAllDrafts(), isEmpty);
    expect(await _draftItemCount(database, id), 0);
  });

  test('wrong owner or environment cannot delete another local draft',
      () async {
    final id = await database.saveOrderDraft(
      draft: OrderDraftsCompanion.insert(
        environment: 'production',
        accountId: 'USR-other',
        customerId: '',
        customerName: '',
      ),
      items: const [],
      environment: 'production',
      accountId: 'USR-other',
    );
    await database
        .into(database.orderDraftItems)
        .insert(_item('KEEP-1', 1).toCompanion(draftId: id));

    await database.deleteOrderDraft(
      draftId: id,
      environment: 'production',
      accountId: 'USR-current',
    );
    expect(await _draftItemCount(database, id), 1);

    await database.deleteOrderDraft(
      draftId: id,
      environment: 'staging',
      accountId: 'USR-other',
    );
    expect(await _draftItemCount(database, id), 1);
  });

  test('pending submission identifier survives reload and updates', () async {
    final id = await repository.saveDraft(OrderDraft(
      customerId: 'customer-1',
      customerName: 'Customer',
      updatedAt: DateTime.now(),
      items: [
        _draft(items: [_item('ITEM', 2)]).items.single
      ],
      clientRequestId: 'REQ-persisted-123',
    ));
    final restored = (await repository.getAllDrafts()).single;
    expect(restored.id, id);
    expect(restored.clientRequestId, 'REQ-persisted-123');
    expect(restored.items.single.quantity, 2);
  });
}

Future<int> _draftItemCount(AppDatabase database, int draftId) async {
  return (database.select(database.orderDraftItems)
        ..where((row) => row.draftId.equals(draftId)))
      .get()
      .then((rows) => rows.length);
}

OrderDraft _draft({
  int? id,
  String currency = 'USD',
  required List<_DraftItemSeed> items,
}) =>
    OrderDraft(
      id: id,
      customerId: 'customer-1',
      customerName: 'Customer',
      updatedAt: DateTime(2026, 11, 14),
      currency: currency,
      items: items
          .map((item) => DraftItem(
                productCode: item.code,
                productName: item.code,
                unit: 'piece',
                quantity: item.quantity,
                price: 2,
              ))
          .toList(),
    );

class _DraftItemSeed {
  final String code;
  final double quantity;
  const _DraftItemSeed(this.code, this.quantity);

  OrderDraftItemsCompanion toCompanion({int draftId = 0}) =>
      OrderDraftItemsCompanion.insert(
        draftId: draftId,
        productCode: code,
        productName: code,
        unit: 'piece',
        quantityMicros: (quantity * 1000000).round(),
        priceMicros: 2000000,
      );
}

_DraftItemSeed _item(String code, double quantity) =>
    _DraftItemSeed(code, quantity);
