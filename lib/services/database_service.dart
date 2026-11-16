import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'database_service.g.dart';

// Tables definitions
class LocalProducts extends Table {
  TextColumn get environment => text().withLength(min: 1, max: 50)();
  TextColumn get accountId => text().withLength(min: 1, max: 50)();
  TextColumn get code => text().withLength(min: 1, max: 50)();
  TextColumn get name => text()();
  TextColumn get category => text()();
  TextColumn get unit => text()();
  IntColumn get priceMicros =>
      integer()(); // Store as micros to avoid double precision issues
  IntColumn get stockMicros => integer()();
  TextColumn get currency =>
      text().withLength(min: 3, max: 3).withDefault(const Constant('USD'))();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get jsonData =>
      text()(); // Store original JSON for non-indexed fields

  @override
  Set<Column> get primaryKey => {environment, accountId, code};
}

@DataClassName('LocalOrderDraft')
class OrderDrafts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get environment => text().withLength(min: 1, max: 50)();
  TextColumn get accountId => text().withLength(min: 1, max: 50)();
  TextColumn get customerId => text()();
  TextColumn get customerName => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get note => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get currency =>
      text().withLength(min: 3, max: 3).withDefault(const Constant('USD'))();
  TextColumn get customTitle => text().nullable()();
}

@DataClassName('LocalOrderItem')
class OrderDraftItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get draftId =>
      integer().references(OrderDrafts, #id, onDelete: KeyAction.cascade)();
  TextColumn get productCode => text().withLength(min: 1, max: 50)();
  TextColumn get productName => text()();
  TextColumn get unit => text()();
  IntColumn get quantityMicros => integer()();
  IntColumn get priceMicros => integer()();
  TextColumn get note => text().nullable()();
  TextColumn get productDataJson =>
      text().nullable()(); // Snapshot of product data for recovery
}

class LocalOrders extends Table {
  TextColumn get orderId => text()();
  TextColumn get environment => text()();
  TextColumn get accountId => text()();
  TextColumn get orderNumber => text()();
  TextColumn get customerId => text()();
  TextColumn get customerName => text()();
  TextColumn get status => text()();
  TextColumn get currency => text()();
  DateTimeColumn get createdAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  IntColumn get totalAmountMicros => integer().nullable()();
  TextColumn get jsonData => text()();

  @override
  Set<Column> get primaryKey => {orderId, environment, accountId};
}

class SyncMetadata extends Table {
  TextColumn get key => text()();
  TextColumn get environment => text()();
  TextColumn get accountId => text()();
  DateTimeColumn get lastSync => dateTime()();

  @override
  Set<Column> get primaryKey => {key, environment, accountId};
}

class LocalCustomers extends Table {
  TextColumn get id => text()();
  TextColumn get environment => text()();
  TextColumn get accountId => text()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get category => text().nullable()();
  IntColumn get balanceMicros => integer().withDefault(const Constant(0))();
  TextColumn get currency => text().withDefault(const Constant('USD'))();
  TextColumn get jsonData => text()();

  @override
  Set<Column> get primaryKey => {id, environment, accountId};
}

@DriftDatabase(tables: [
  LocalProducts,
  OrderDrafts,
  OrderDraftItems,
  LocalOrders,
  LocalCustomers,
  SyncMetadata
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(localOrders);
            await m.deleteTable('sync_metadata');
            await m.createTable(syncMetadata);
          }
          if (from < 3) {
            await m.createTable(localCustomers);
          }
          if (from < 4) {
            await m.addColumn(orderDrafts, orderDrafts.currency);
            await m.addColumn(orderDrafts, orderDrafts.customTitle);
          }
          if (from < 5) {
            await m.addColumn(orderDraftItems, orderDraftItems.productDataJson);
          }
        },
        beforeOpen: (details) async {
          if (details.wasCreated) {
            // Initial setup if needed
          }
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  // Helper methods for transactions
  Future<int> saveOrderDraft({
    required OrderDraftsCompanion draft,
    required List<OrderDraftItemsCompanion> items,
    required String environment,
    required String accountId,
  }) {
    return transaction(() async {
      final draftId = draft.id.present
          ? draft.id.value
          : await into(orderDrafts).insert(draft);

      if (draft.id.present) {
        final updated = await (update(orderDrafts)
              ..where((row) =>
                  row.id.equals(draftId) &
                  row.environment.equals(environment) &
                  row.accountId.equals(accountId)))
            .write(draft);
        if (updated != 1) {
          throw StateError('المسودة غير موجودة أو لا تخص الحساب الحالي');
        }
      }

      await (delete(orderDraftItems)
            ..where((row) => row.draftId.equals(draftId)))
          .go();

      for (var item in items) {
        await into(orderDraftItems)
            .insert(item.copyWith(draftId: Value(draftId)));
      }
      return draftId;
    });
  }

  Future<void> deleteOrderDraft({
    required int draftId,
    required String environment,
    required String accountId,
  }) {
    return transaction(() async {
      final ownedDraft = await (select(orderDrafts)
            ..where((row) =>
                row.id.equals(draftId) &
                row.environment.equals(environment) &
                row.accountId.equals(accountId)))
          .getSingleOrNull();
      if (ownedDraft == null) return;

      await (delete(orderDraftItems)
            ..where((row) => row.draftId.equals(draftId)))
          .go();
      await (delete(orderDrafts)
            ..where((row) =>
                row.id.equals(draftId) &
                row.environment.equals(environment) &
                row.accountId.equals(accountId)))
          .go();
    });
  }

  Future<void> updateDraftNote(
    int draftId,
    String note, {
    required String environment,
    required String accountId,
  }) async {
    await (update(orderDrafts)
          ..where((t) =>
              t.id.equals(draftId) &
              t.environment.equals(environment) &
              t.accountId.equals(accountId)))
        .write(OrderDraftsCompanion(
            note: Value(note), updatedAt: Value(DateTime.now())));
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'orca_order_v2.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
