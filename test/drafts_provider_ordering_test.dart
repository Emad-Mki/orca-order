import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/models/order_draft.dart';
import 'package:orca_order/providers/drafts_provider.dart';
import 'package:orca_order/repositories/local_repository.dart';
import 'package:orca_order/services/database_service.dart';

class _ControlledRepository extends LocalRepository {
  _ControlledRepository(super.db);

  String scope = 'production:user-1';
  final firstWrite = Completer<void>();
  final started = Completer<void>();
  final writes = <String>[];
  int _count = 0;

  @override
  String get draftScope => scope;

  @override
  Future<int> saveDraft(OrderDraft draft) async {
    _count++;
    if (_count == 1) {
      started.complete();
      await firstWrite.future;
    }
    writes.add(draft.note!);
    return 1;
  }

  @override
  Future<List<OrderDraft>> getAllDrafts() async => [];
}

OrderDraft _draft(String note) => OrderDraft(
      id: 1,
      customerId: '',
      customerName: '',
      note: note,
      updatedAt: DateTime(2026),
      items: [],
    );

void main() {
  test('in-flight writes cannot overwrite a newer draft', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = _ControlledRepository(db);
    final provider = DraftsProvider(repo);
    final oldWrite = provider.saveDraft(_draft('old'));
    await repo.started.future;
    final newWrite = provider.saveDraft(_draft('new'));
    repo.firstWrite.complete();
    await Future.wait([oldWrite, newWrite]);
    expect(repo.writes, ['old', 'new']);
    provider.dispose();
    await db.close();
  });

  test('queued writes are rejected if the account changes', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final repo = _ControlledRepository(db);
    final provider = DraftsProvider(repo);
    final oldWrite = provider.saveDraft(_draft('old'));
    await repo.started.future;
    final newWrite = provider.saveDraft(_draft('new'));
    final rejected = expectLater(newWrite, throwsStateError);
    repo.scope = 'production:user-2';
    repo.firstWrite.complete();
    await oldWrite;
    await rejected;
    expect(repo.writes, ['old']);
    provider.dispose();
    await db.close();
  });
}
