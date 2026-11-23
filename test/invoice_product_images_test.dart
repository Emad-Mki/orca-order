import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orca_order/services/invoice_product_images.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Uint8List image;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('invoice-images-');
    final asset =
        await rootBundle.load('assets/images/product_placeholder.png');
    image = asset.buffer.asUint8List(asset.offsetInBytes, asset.lengthInBytes);
  });
  tearDown(() async => directory.delete(recursive: true));

  test('persists validated images per invoice and account for offline use',
      () async {
    var downloads = 0;
    final store = InvoiceProductImages(
      scope: 'account-a',
      directory: directory,
      download: (_) async {
        downloads++;
        return image;
      },
    );
    await store.cache('invoice-1', {'A': 'https://example.test/a'});
    await store.cache('invoice-1', {'A': 'https://example.test/new'});
    expect(downloads, 1);
    final offline = InvoiceProductImages(
      scope: 'account-a',
      directory: directory,
      download: (_) => throw StateError('must not download'),
    );
    expect((await offline.read('invoice-1', ['A']))['A'], image);
    expect(await offline.read('invoice-2', ['A']), isEmpty);
    expect(
        await InvoiceProductImages(scope: 'account-b', directory: directory)
            .read('invoice-1', ['A']),
        isEmpty);
  });

  test('invalid and unavailable images leave placeholder fallback', () async {
    final store = InvoiceProductImages(
      scope: 'account',
      directory: directory,
      download: (_) async => Uint8List.fromList([1, 2, 3]),
    );
    await store.cache('invoice', {
      'bad': 'https://example.test/bad',
      'insecure': 'http://example.test/plain',
    });
    expect(await store.read('invoice', ['bad', 'insecure']), isEmpty);
  });
}
