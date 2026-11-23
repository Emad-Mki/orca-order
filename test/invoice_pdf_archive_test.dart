import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/services/invoice_pdf_archive.dart';

void main() {
  late Directory root;
  setUp(() async =>
      root = await Directory.systemTemp.createTemp('orca-archive-'));
  tearDown(() async => root.delete(recursive: true));

  InvoicePdfArchive archive(String user) => InvoicePdfArchive(
        environment: 'test',
        userId: user,
        role: 'accountant',
        rootDirectory: root,
      );

  test('archives separate immutable exports and isolates accounts', () async {
    final store = archive('one');
    final bytes = Uint8List.fromList('%PDF-test'.codeUnits);
    final first = await store.save(
        bytes: bytes, invoiceId: 'inv-1', templateVersion: 'v1');
    final second = await store.save(
        bytes: bytes, invoiceId: 'inv-1', templateVersion: 'v1');
    expect(first.path, isNot(second.path));
    expect(await first.readAsBytes(), bytes);
    expect((await store.list()).length, 2);
    expect(await archive('two').list(), isEmpty);
    expect(first.path, isNot(contains('inv-1')));
  });

  test('rejects invalid PDFs and untrusted version filenames', () async {
    final store = archive('one');
    await expectLater(
      store.save(
          bytes: Uint8List.fromList('%PDF-x'.codeUnits),
          invoiceId: 'inv',
          templateVersion: '../bad'),
      throwsFormatException,
    );
    expect(await store.list(), isEmpty);
  });
}
